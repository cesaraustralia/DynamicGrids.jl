# Internal traits for sharing methods
struct _Read_ end
struct _Write_ end

# Set up the rule data to loop over
maprule!(simdata::SimData, rule::Rule) = begin
    rkeys, rgrids = getgrids(_Read_(), rule, simdata)
    wkeys, wgrids = getgrids(_Write_(), rule, simdata)
    # Copy the source to dest for grids we are writing to,
    # if they need to be copied
    _maybeupdate_dest!(wgrids, rule)
    # Combine read and write grids to a temporary simdata object
    tempsimdata = @set simdata.grids = combinegrids(rkeys, rgrids, wkeys, wgrids)
    # Run the rule loop
    ruleloop(opt(simdata), rule, tempsimdata, rkeys, rgrids, wkeys, wgrids, mask(simdata))
    # Copy the source status to dest status for all write grids
    copystatus!(wgrids)
    # Swap the dest/source of grids that were written to
    wgrids = swapsource(wgrids) |> _to_readonly
    # Combine the written grids with the original simdata
    replacegrids(simdata, wkeys, wgrids)
end

_to_readonly(data::Tuple) = map(ReadableGridData, data)
_to_readonly(data::WritableGridData) = ReadableGridData(data)

_maybeupdate_dest!(ds::Tuple, rule) =
    map(d -> _maybeupdate_dest!(d, rule), ds)
_maybeupdate_dest!(d::WritableGridData, rule::Rule) =
    handleoverflow!(d)
_maybeupdate_dest!(d::WritableGridData, rule::ManualRule) = begin
    copy!(parent(dest(d)), parent(source(d)))
    handleoverflow!(d)
end

# Separated out for both modularity and as a function barrier for type stability

ruleloop(::PerformanceOpt, rule::Rule, simdata::SimData, rkeys, rgrids, wkeys, wgrids, mask) = begin
    nrows, ncols = gridsize(grids(simdata)[1])
    for j in 1:ncols, i in 1:nrows
        ismasked(mask, i, j) && continue
        readval = readgrids(rkeys, rgrids, i, j)
        writeval = applyrule(rule, simdata, readval, (i, j))
        writegrids!(wgrids, writeval, i, j)
    end
end

ruleloop(::PerformanceOpt, rule::ManualRule, simdata::SimData, rkeys, rgrids, wkeys, wgrids, mask) = begin
    nrows, ncols = gridsize(grids(simdata)[1])
    for j in 1:ncols, i in 1:nrows
        ismasked(mask, i, j) && continue
        readval = readgrids(rkeys, rgrids, i, j)
        applyrule!(rule, simdata, readval, (i, j))
    end
end

ruleloop(::SparseOpt, rule::ManualRule, simdata::SimData, rkey, rgrid::GridData, wkeys, wgrids, mask) =
    let rule=rule, simdata=simdata, rkey=rkey, rgrid=rgrid
        runsparse(rgrid) do i, j
            ismasked(mask, i, j) && return
            readval = readgrids(rkey, rgrid, i, j)
            applyrule!(rule, simdata, readval, (i, j))
            return
        end
    end

#= runsparse Runs simulations over sparse blocks. Inactive blocks do not run.
This can lead to order of magnitude performance improvments in sparse
simulations where large areas of the grid are filled with zeros. =#
runsparse(f, data::GridData) = begin
    nrows, ncols = gridsize(data)
    r = radius(data)
    if r > 0
        blocksize = 2r
        status = sourcestatus(data)

        for bj in 1:size(status, 2) - 1, bi in 1:size(status, 1) - 1
            @inbounds status[bi, bj] || continue
            # Convert from padded block to init dimensions
            istart = blocktoind(bi, blocksize) - r
            jstart = blocktoind(bj, blocksize) - r
            # Stop at the init row/column size, not the padding or block multiple
            istop = min(istart + blocksize - 1, nrows)
            jstop = min(jstart + blocksize - 1, ncols)
            # Skip the padding
            istart = max(istart, 1)
            jstart = max(jstart, 1)

            for j in jstart:jstop, i in istart:istop
                f(i, j)
            end
        end
    else
        for j in 1:ncols, i in 1:nrows
            f(i, j)
        end
    end
end

ruleloop(opt::PerformanceOpt, rule::Union{NeighborhoodRule,Chain{R,W,<:Tuple{<:NeighborhoodRule,Vararg}}},
         simdata::SimData, rkeys, rgrids, wkeys, wgrids, mask) where {R,W} = begin
    griddata = simdata[neighborhoodkey(rule)]
    #= Blocks are cell smaller than the hood, because this works very nicely for
    #looking at only 4 blocks at a time. Larger blocks mean each neighborhood is more
    #likely to be active, smaller means handling more than 2 neighborhoods per block.
    It would be good to test if this is the sweet spot for performance,
    it probably isn't for game of life size grids. =#
    r = radius(rule)
    blocksize = 2r
    hoodsize = 2r + 1
    nrows, ncols = gridsize(griddata)
    # We unwrap offset arrays and work with the underlying array
    src, dst = parent(source(griddata)), parent(dest(griddata))
    # Get the preallocated neighborhood buffers
    # Center of the buffer for both axes
    # Build multiple rules for each neighborhood buffer
    buffers, bufrules = spreadbuffers(rule, init(griddata))
    ruleloop(opt, rule, simdata, rkeys, rgrids, wkeys, wgrids,
             griddata, src, dst, buffers, bufrules, r, blocksize, hoodsize, nrows, ncols, mask)
end

ruleloop(opt::NoOpt, rule, simdata::SimData, rkeys, rgrids, wkeys, wgrids,
         griddata, src, dst, buffers, bufrules, r, blocksize, hoodsize, nrows, ncols, mask
         ) where {R,W} = begin

    blockrows, blockcols = indtoblock.(size(src), blocksize)
    # Loop down a block COLUMN
    for bi = 1:blockrows
        rowsinblock = min(blocksize, nrows - blocksize * (bi - 1))
        # Get current block
        i = blocktoind(bi, blocksize)

        # Loop along the block ROW. This is faster because we are reading
        # 1 column from the main array for multiple blocks at each step,
        # not actually along the row.
        for j = 1:ncols
            # Which block column are we in
            if j == 1
                # Reinitialise neighborhood buffers
                for y = 1:hoodsize, b = 1:rowsinblock, x = 1:hoodsize
                    val = src[i + b + x - 2, y]
                    @inbounds buffers[b][x, y] = val
                end
            else
                # Move the neighborhood buffers accross one column
                for b in 1:rowsinblock
                    @inbounds buf = buffers[b]
                    # copyto! uses linear indexing, so 2d dims are transformed manually
                    @inbounds copyto!(buf, 1, buf, hoodsize + 1, (hoodsize - 1) * hoodsize)
                end
                # Copy a new column to each neighborhood buffer
                for b in 1:rowsinblock
                    @inbounds buf = buffers[b]
                    for x in 1:hoodsize
                        @inbounds buf[x, hoodsize] = src[i + b + x - 2, j + 2r]
                    end
                end
            end

            curblockj = indtoblock(j, blocksize)
            # Loop over the grid ROWS inside the block
            for b in 1:rowsinblock
                I = i + b - 1, j
                ismasked(mask, I...) && continue
                # Which block row are we in
                curblocki = b <= r ? 1 : 2
                # Run the rule using buffer b
                readval = readgrids(keys2vals(readkeys(rule)), rgrids, I...)
                writeval = applyrule(bufrules[b], simdata, readval, I)
                writegrids!(wgrids, writeval, I...)
            end
        end
    end
end

#= Run the rule for all cells, writing the result to the dest array
The neighborhood is copied to the rules neighborhood buffer array for performance.
Empty blocks are skipped for NeighborhoodRules. =#
ruleloop(opt::SparseOpt, rule, simdata::SimData, rkeys, rgrids, wkeys, wgrids,
         griddata, src, dst, buffers, bufrules, r, blocksize, hoodsize, nrows, ncols, mask
         ) where {R,W} = begin
    # rgrids isa Tuple && length(rgrids) > 1 && error("`SparseOpt` can't handle rules with multiple read grids yet. Use `opt=NoOpt()`")

    #= Run the rule row by row. When we move along a row by one cell, we access only
    a single new column of data the same hight of the nighborhood, and move the existing
    data in the neighborhood buffer array accross by one column. This saves on reads
    from the main array, and focusses reads and writes in the small buffer array that
    should be in fast local memory. =#

    # Initialise status for the dest. Is this needed?
    # deststatus(data) .= false
    srcstatus, dststatus = sourcestatus(griddata), deststatus(griddata)
    # curstatus and newstatus track active status for 4 local blocks
    newstatus = localstatus(griddata)

    # Loop down the block COLUMN
    for bi = 1:size(srcstatus, 1) - 1
        i = blocktoind(bi, blocksize)
        # Get current block
        rowsinblock = min(blocksize, nrows - blocksize * (bi - 1))
        skippedlastblock = true
        freshbuffer = true

        # Initialise block status for the start of the row
        @inbounds bs11, bs12 = srcstatus[bi,     1], srcstatus[bi,     2]
        @inbounds bs21, bs22 = srcstatus[bi + 1, 1], srcstatus[bi + 1, 2]
        newstatus .= false

        # Loop along the block ROW. This is faster because we are reading
        # 1 column from the main array for 2 blocks at each step, not actually along the row.
        for bj = 1:size(srcstatus, 2) - 1
            @inbounds newstatus[1, 1] = newstatus[1, 2]
            @inbounds newstatus[2, 1] = newstatus[2, 2]
            @inbounds newstatus[1, 2] = false
            @inbounds newstatus[2, 2] = false

            # Get current block status from the source status array
            bs11, bs21 = bs12, bs22
            @inbounds bs12, bs22 = srcstatus[bi, bj + 1], srcstatus[bi + 1, bj + 1]

            jstart = blocktoind(bj, blocksize)
            jstop = min(jstart + blocksize - 1, ncols)

            # Use this block unless it or its neighbors are active
            if !(bs11 | bs12 | bs21 | bs22)
                if !skippedlastblock
                    newstatus .= false
                end
                # Skip this block
                skippedlastblock = true
                # Run the rest of the chain if it exists
                if rule isa Chain && length(rule) > 1 && length(rkeys) > 1
                    # Loop over the grid COLUMNS inside the block
                    for j in jstart:jstop
                        # Loop over the grid ROWS inside the block
                        for b in 1:rowsinblock
                            I = i + b - 1, j
                            ismasked(mask, I...) && continue
                            read = readgrids(rkeys, rgrids, I...)
                            write = applyrule(tail(rule), simdata, read, I)
                            if wgrids isa Tuple
                                map(wgrids, write) do d, w
                                    @inbounds dest(d)[I...] = w
                                end
                            else
                                @inbounds dest(wgrids)[I...] = write
                            end
                        end
                    end
                end
                continue
            end

            # Reinitialise neighborhood buffers if we have skipped a section of the array
            if skippedlastblock
                for y = 1:hoodsize, b in 1:rowsinblock, x = 1:hoodsize
                    val = src[i + b + x - 2, jstart + y - 1]
                    @inbounds buffers[b][x, y] = val
                end
                skippedlastblock = false
                freshbuffer = true
            end

            # Loop over the grid COLUMNS inside the block
            for j in jstart:jstop
                # Which block column are we in
                curblockj = j - jstart < r ? 1 : 2
                if freshbuffer
                    freshbuffer = false
                else
                    # Move the neighborhood buffers accross one column
                    for b in 1:rowsinblock
                        @inbounds buf = buffers[b]
                        # copyto! uses linear indexing, so 2d dims are transformed manually
                        @inbounds copyto!(buf, 1, buf, hoodsize + 1, (hoodsize - 1) * hoodsize)
                    end
                    # Copy a new column to each neighborhood buffer
                    for b in 1:rowsinblock
                        @inbounds buf = buffers[b]
                        for x in 1:hoodsize
                            @inbounds buf[x, hoodsize] = src[i + b + x - 2, j + 2r]
                        end
                    end
                end

                # Loop over the grid ROWS inside the block
                for b in 1:rowsinblock
                    I = i + b - 1, j
                    ismasked(mask, I...) && continue
                    # Which block row are we in
                    curblocki = b <= r ? 1 : 2
                    # Run the rule using buffer b
                    readval = readgrids(keys2vals(readkeys(rule)), rgrids, I...)
                    writeval = applyrule(bufrules[b], simdata, readval, I)
                    writegrids!(wgrids, writeval, I...)
                    # Update the status for the block
                    cellstatus = if writeval isa NamedTuple
                        @inbounds val = writeval[neighborhoodkey(rule)]
                        val != zero(val)
                    else
                        writeval != zero(writeval)
                    end
                    @inbounds newstatus[curblocki, curblockj] |= cellstatus
                end

                # Combine blocks with the previous rows / cols
                @inbounds dststatus[bi, bj] |= newstatus[1, 1]
                @inbounds dststatus[bi, bj+1] |= newstatus[1, 2]
                @inbounds dststatus[bi+1, bj] |= newstatus[2, 1]
                # Start new block fresh to remove old status
                @inbounds dststatus[bi+1, bj+1] = newstatus[2, 2]
            end
        end
    end
    srcstatus .= dststatus
end


# Low-level tools for fetching, manipulating and writing 
# grids reuired in the simulation.

@generated function readgrids(rkeys::Tuple, rdata::Tuple, I...)
    expr = Expr(:tuple)
    for i in 1:length(rdata.parameters)
        push!(expr.args, :(@inbounds rdata[$i][I...]))
    end
    quote
        keys = map(unwrap, rkeys)
        vals = $expr
        NamedTuple{keys,typeof(vals)}(vals)
    end
end
readgrids(rkeys::Val, rdata::ReadableGridData, I...) =
    (return @inbounds rdata[I...])


@generated writegrids!(wdata::Tuple, vals::Union{Tuple,NamedTuple}, I...) = begin
    expr = Expr(:block)
    for i in 1:length(wdata.parameters)
        push!(expr.args, :(@inbounds dest(wdata[$i])[I...] = vals[$i]))
    end
    push!(expr.args, :(nothing))
    expr
end
writegrids!(wdata::GridData{T}, val::T, I...) where T = begin
    @inbounds wdata.dest[I...] = val
    nothing
end


# getdata retreives GridDatGridData to match the requirements of a Rule.

# Choose key source
getgrids(context::_Write_, rule::Rule, simdata::AbstractSimData) =
    getgrids(context, keys(simdata), writekeys(rule), simdata::AbstractSimData)
getgrids(context::_Read_, rule::Rule, simdata::AbstractSimData) =
    getgrids(context, keys(simdata), readkeys(rule), simdata)
@inline getgrids(context, gridkeys, rulekeys, simdata::AbstractSimData) =
    getgrids(context, keys2vals(rulekeys), simdata)
# When there is only one grid, use its key and ignore the rule key
# This can make scripting easier as you can safely ignore the keys
# for smaller models.
@inline getgrids(context, gridkeys::Tuple{Symbol}, rulekeys::Tuple{Symbol}, simdata::AbstractSimData) =
    getgrids(context, (Val(gridkeys[1]),), simdata)
@inline getgrids(context, gridkeys::Tuple{Symbol}, rulekey::Symbol, simdata::AbstractSimData) =
    getgrids(context, Val(gridkeys[1]), simdata)

# Iterate when keys are a tuple
@inline getgrids(context, keys::Tuple{Val,Vararg}, simdata::AbstractSimData) = begin
    k, d = getgrids(context, keys[1], simdata)
    ks, ds = getgrids(context, tail(keys), simdata)
    (k, ks...), (d, ds...)
end
@inline getgrids(context, keys::Tuple{}, simdata::AbstractSimData) = (), ()

# Choose data source
@inline getgrids(::_Write_, key::Val{K}, simdata::AbstractSimData) where K =
    key, WritableGridData(simdata[K])
@inline getgrids(::_Read_, key::Val{K}, simdata::AbstractSimData) where K =
    key, simdata[K]


combinegrids(rkey, rgrids, wkey, wgrids) =
    combinegrids((rkey,), (rgrids,), (wkey,), (wgrids,))
combinegrids(rkey, rgrids, wkeys::Tuple, wgrids::Tuple) =
    combinegrids((rkey,), (rgrids,), wkeys, wgrids)
combinegrids(rkeys::Tuple, rgrids::Tuple, wkey, wgrids) =
    combinegrids(rkeys, rgrids, (wkey,), (wgrids,))
@generated combinegrids(rkeys::Tuple{Vararg{<:Val}}, rgrids::Tuple,
                       wkeys::Tuple{Vararg{<:Val}}, wgrids::Tuple) = begin
    rkeys = _vals2syms(rkeys)
    wkeys = _vals2syms(wkeys)
    keysexp = Expr(:tuple, QuoteNode.(wkeys)...)
    dataexp = Expr(:tuple, :(wgrids...))

    for (i, key) in enumerate(rkeys)
        if !(key in wkeys)
            push!(dataexp.args, :(rgrids[$i]))
            push!(keysexp.args, QuoteNode(key))
        end
    end

    quote
        keys = $keysexp
        vals = $dataexp
        NamedTuple{keys,typeof(vals)}(vals)
    end
end

replacegrids(simdata::AbstractSimData, wkeys, wgrids) =
    @set simdata.grids = replacegrids(grids(simdata), wkeys, wgrids)
@generated replacegrids(allgrids::NamedTuple, wkeys::Tuple, wgrids::Tuple) = begin
    writekeys = map(unwrap, wkeys.parameters)
    allkeys = allgrids.parameters[1]
    expr = Expr(:tuple)
    for key in allkeys
        if key in writekeys
            i = findfirst(k -> k == key, writekeys)
            push!(expr.args, :(wgrids[$i]))
        else
            push!(expr.args, :(allgrids.$key))
        end
    end
    quote
        vals = $expr
        NamedTuple{$allkeys,typeof(vals)}(vals)
    end
end
@generated replacegrids(allgrids::NamedTuple, wkey::Val, wgrids::GridData) = begin
    writekey = unwrap(wkey)
    allkeys = allgrids.parameters[1]
    expr = Expr(:tuple)
    for key in allkeys
        if key == writekey
            push!(expr.args, :(wgrids))
        else
            push!(expr.args, :(allgrids.$key))
        end
    end
    quote
        vals = $expr
        NamedTuple{$allkeys,typeof(vals)}(vals)
    end
end

_vals2syms(x::Type{<:Tuple}) = map(v -> _vals2syms(v), x.parameters)
_vals2syms(::Type{<:Val{X}}) where X = X
