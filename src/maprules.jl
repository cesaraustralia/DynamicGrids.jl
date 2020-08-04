# Internal traits for sharing methods
struct _Read_ end
struct _Write_ end

const GridOrGridTuple = Union{<:GridData,Tuple{Vararg{<:GridData}}}

"""
    maprule!(simdata::SimData, rule::Rule)

Map a rule over the grids it reads from and updating the grids it writes to.

This is broken into a setup method and an application method
to introduce a function barrier, for type stability.
"""
function maprule! end
maprule!(simdata::SimData, rule::Rule) = begin

    #= keys and grids are separated instead of in a NamedTuple as `rgrids` or `wgrids`
    may be a single grid, not a Tuple. But we still need to know what its key is.
    The structure of rgrids and wgrids determines the values that are sent to the rule
    are in a NamedTuple or single value, and wether a tuple of single return value
    is expected. There may be a cleaner way of doing this. =#

    rkeys, rgrids = getgrids(_Read_(), rule, simdata)
    wkeys, wgrids = getgrids(_Write_(), rule, simdata)
    # Copy the source to dest for grids we are writing to, if needed
    maybeupdatedest!(wgrids, rule)
    # Copy or zero out overflow where needed
    handleoverflow!(wgrids)
    # Combine read and write grids to a temporary simdata object.
    # This means that grids not asked for by rules are not available,
    # and grids not specified to write to are read-only.
    tempsimdata = @set simdata.grids = combinegrids(rkeys, rgrids, wkeys, wgrids)
    # Run the rule loop
    maprule!(tempsimdata, opt(simdata), rule, rkeys, rgrids, wkeys, wgrids, mask(simdata))
    # Copy the dest status to dest status if it is in use
    maybecopystatus!(wgrids)
    # Swap the dest/source of grids that were written to
    wgrids = swapsource(wgrids) |> _to_readonly
    # Combine the written grids with the original simdata
    replacegrids(simdata, wkeys, wgrids)
end

maybeupdatedest!(ds::Tuple, rule) =
    map(d -> maybeupdatedest!(d, rule), ds)
maybeupdatedest!(d::WritableGridData, rule::Rule) = nothing
maybeupdatedest!(d::WritableGridData, rule::ManualRule) = begin
    @inbounds copyto!(parent(dest(d)), parent(source(d)))
end

maybecopystatus!(grid::Tuple{Vararg{<:GridData}}) = map(maybecopystatus!, grid)
maybecopystatus!(grid::GridData) =
    maybecopystatus!(sourcestatus(grid), deststatus(grid))
maybecopystatus!(srcstatus, deststatus) = nothing
maybecopystatus!(srcstatus::AbstractArray, deststatus::AbstractArray) =
    @inbounds return srcstatus .= deststatus

_to_readonly(data::Tuple) = map(ReadableGridData, data)
_to_readonly(data::WritableGridData) = ReadableGridData(data)

maprule!(simdata::SimData, opt::PerformanceOpt, rule::Rule,
         rkeys, rgrids::GridOrGridTuple, wkeys, wgrids::GridOrGridTuple, mask) =
    let rule=rule, simdata=simdata, rkeys=rkeys, rgrids=rgrids, wkeys=wkeys, wgrid=wgrids
        optmap(opt, rgrids, wgrids) do i, j
            ismasked(mask, i, j) && return
            readval = readgrids(rkeys, rgrids, i, j)
            writeval = applyrule(simdata, rule, readval, (i, j))
            writegrids!(wgrids, writeval, i, j)
            return
        end
    end
maprule!(simdata::SimData, opt::PerformanceOpt, rule::ManualRule,
         rkeys, rgrids::GridOrGridTuple, wkeys, wgrids::GridOrGridTuple, mask) =
    let rule=rule, simdata=simdata, rkeys=rkeys, rgrids=rgrids
        optmap(opt, rgrids, wgrids) do i, j
            ismasked(mask, i, j) && return
            readval = readgrids(rkeys, rgrids, i, j)
            applyrule!(simdata, rule, readval, (i, j))
            return
        end
    end
maprule!(simdata::SimData, opt::PerformanceOpt,
         rule::Union{NeighborhoodRule,Chain{R,W,<:Tuple{<:NeighborhoodRule,Vararg}}},
         rkeys, rgrids::GridOrGridTuple, wkeys, wgrids::GridOrGridTuple, mask) where {R,W} = begin
    griddata = simdata[neighborhoodkey(rule)]
    #= Blocks are 1 cell smaller than the neighborhood, because this works very nicely
    for looking at only 4 blocks at a time. Larger blocks mean each neighborhood is more
    likely to be active, smaller means handling more than 2 neighborhoods per block.
    It would be good to test if this is the sweet spot for performance =#
    r = radius(rule)
    blocksize = 2r
    hoodsize = 2r + 1
    nrows, ncols = gridsize(griddata)
    # We unwrap offset arrays and work with the underlying array
    src, dst = parent(source(griddata)), parent(dest(griddata))
    # Get the preallocated neighborhood buffers and build multiple rule copies for each
    buffers, bufrules = spreadbuffers(rule, init(griddata))
    mapneighborhoodrule!(simdata, opt, rule, rkeys, rgrids, wkeys, wgrids,
             griddata, src, dst, buffers, bufrules, r, blocksize, hoodsize, nrows, ncols, mask)
end

# Neighorhood buffer optimisation without `SparseOpt`
mapneighborhoodrule!(simdata::SimData, opt::NoOpt, rule, rkeys, rgrids, wkeys, wgrids,
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
                update_buffers!(buffers, src, rowsinblock, hoodsize, r, i, j)
            end

            # Loop over the grid ROWS inside the block
            for b in 1:rowsinblock
                I = i + b - 1, j
                ismasked(mask, I...) && continue
                # Run the rule using buffer b
                readval = readgridsorbuffer(rgrids, buffers[b], rule, r, I...)
                writeval = applyrule(simdata, bufrules[b], readval, I)
                writegrids!(wgrids, writeval, I...)
            end
        end
    end
end
# Neighorhood buffer optimisation combined with `SparseOpt`
mapneighborhoodrule!(simdata::SimData, opt::SparseOpt, rule, rkeys, rgrids, wkeys, wgrids,
         griddata, src, dst, buffers, bufrules, r, blocksize, hoodsize, nrows, ncols, mask
         ) where {R,W} = begin

    srcstatus, dststatus = sourcestatus(griddata), deststatus(griddata)
    # Zero out dest and dest status
    fill!(dst, zero(eltype(dst)))
    fill!(dststatus, false)

    #= Run the rule row by row. When we move along a row by one cell, we access only
    a single new column of data with the height of 2 blocks, and move the existing
    data in the neighborhood buffers array accross by one column. This saves on reads
    from the main array, and focusses reads and writes in the small buffer array that
    should be in fast local memory. =#

    nblockrows, nblockcols = size(srcstatus)
    # Loop down the block COLUMN
    for bi = 1:nblockrows
        lastblockrow = bi == nblockrows
        i = blocktoind(bi, blocksize)
        # Get current block
        rowsinblock = min(blocksize, nrows - blocksize * (bi - 1))
        skippedlastblock = true
        freshbuffer = true

        # Initialise block status for the start of the row
        @inbounds bs11, bs12 = srcstatus[bi, 1], srcstatus[bi, 2]
        bs21, bs22 = if bi == size(srcstatus, 1)
            false, false
        else
            @inbounds srcstatus[bi + 1, 1], srcstatus[bi + 1, 2]
        end
        # New block status
        newbs12 = false
        newbs22 = false

        # Loop along the block ROW. This is faster because we are reading
        # 1 column from the main array for 2 blocks at each step, not actually along the row.
        for bj = 1:nblockcols
            lastblockcol = bj == nblockcols
            # Shuffle new buffer status
            newbs11 = newbs12
            newbs21 = newbs22
            newbs12 = newbs22 = false
            # Shuffle current buffer status
            bs11, bs21 = bs12, bs22
            bs12, bs22 = if lastblockcol
                # This is the last block, the second half wont run
                false, false
            else
                # Get current block status from the source status array
                if lastblockrow
                    @inbounds srcstatus[bi, bj + 1], false
                else
                    @inbounds srcstatus[bi, bj + 1], srcstatus[bi + 1, bj + 1]
                end
            end

            # Skip this block it and its neighbors are inactive
            if !(bs11 | bs12 | bs21 | bs22)
                # Skip this block
                skippedlastblock = true
                # Run the rest of the chain if it exists and more than 1 grid is used
                if rule isa Chain && length(rule) > 1 && length(rkeys) > 1
                    # Loop over the grid COLUMNS inside the block
                    jstart = blocktoind(bj, blocksize)
                    jstop = min(jstart + blocksize - 1, ncols)
                    for j in jstart:jstop
                        # Loop over the grid ROWS inside the block
                        for b in 1:rowsinblock
                            I = i + b - 1, j
                            ismasked(mask, I...) && continue
                            readval = readgrids(rkeys, rgrids, I...)
                            writeval = applyrule(simdata, tail(rule), readval, I)
                            writegrids!(wgrids, writeval, I...)
                        end
                    end
                end
                continue
            end

            # Define area to loop over with the block.
            # It's variable because the last block may be partial
            jstart = blocktoind(bj, blocksize)
            jstop = min(jstart + blocksize - 1, ncols)

            # Reinitialise neighborhood buffers if we have skipped a section of the array
            if skippedlastblock
                for y = 1:hoodsize
                    for b in 1:rowsinblock, x = 1:hoodsize
                        @inbounds val = src[i + b + x - 2, jstart + y - 1]
                        @inbounds buffers[b][x, y] = val
                    end
                end
                skippedlastblock = false
                freshbuffer = true
            end

            # Loop over the grid COLUMNS inside the block
            for j in jstart:jstop
                # Update buffers unless feshly populated
                if freshbuffer
                    freshbuffer = false
                else
                    update_buffers!(buffers, src, rowsinblock, hoodsize, r, i, j)
                end

                # Which block column are we in, 1 or 2
                curblockj = (j - jstart) ÷ r + 1

                # Loop over the grid ROWS inside the block
                for b in 1:rowsinblock
                    # Get the current cell index
                    I = i + b - 1, j
                    # Check the cell isn't masked
                    ismasked(mask, I...) && continue
                    # Get value/s for the cell
                    readval = readgridsorbuffer(rgrids, buffers[b], rule, r, I...)
                    # Run the rule
                    writeval = applyrule(simdata, bufrules[b], readval, I)
                    # Write to the grid
                    writegrids!(wgrids, writeval, I...)
                    # Update the status for the current block
                    cs = get_cellstatus(wgrids, rule, writeval)
                    curblocki = r == 1 ? b : (b - 1) ÷ r + 1
                    if curblocki == 1
                        if curblockj == 1
                            newbs11 |= cs
                        else
                            newbs12 |= cs
                        end
                    else
                        if curblockj == 1
                            newbs21 |= cs
                        else
                            newbs22 |= cs
                        end
                    end
                end
            end

            # Combine new block status with deststatus array
            if !lastblockrow
                @inbounds dststatus[bi, bj] |= newbs11
                @inbounds dststatus[bi+1, bj] |= newbs21
            else
                @inbounds dststatus[bi, bj] |= newbs11
            end
            if !lastblockcol
                if !lastblockrow
                    # Start new block fresh to remove old status
                    @inbounds dststatus[bi, bj+1] |= newbs12
                    @inbounds dststatus[bi+1, bj+1] = newbs22
                else
                    @inbounds dststatus[bi, bj+1] |= newbs12
                end
            end
        end
    end
    return
end


"""
    optmap(f, ::SparseOpt, rdata::GridOrGridTuple, wdata::GridOrGridTuple)

Maps rules over grids with sparse block optimisation. Inactive blocks do not run.
This can lead to order of magnitude performance improvments in sparse
simulations where large areas of the grid are filled with zeros.
"""
optmap(f, ::SparseOpt, rgrids::GridOrGridTuple, wgrids::GridOrGridTuple) = begin
    nrows, ncols = gridsize(wgrids)
    r = radius(rgrids)
    # Only use SparseOpt for single-grid rules with grid radii > 0
    if r isa Tuple || r == 0
        optmap(f, NoOpt(), rgrids, wgrids)
        return
    end

    blocksize = 2r
    status = sourcestatus(rgrids)

    for bj in axes(status, 2), bi in axes(status, 1)
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
    return
end
"""
    optmap(f, ::NoOpt, rgrids::GridOrGridTuple, wgrids::GridOrGridTuple)

Maps rule applicator over the grid with no optimisation
"""
optmap(f, ::NoOpt, rgrids::GridOrGridTuple, wgrids::GridOrGridTuple) = begin
    nrows, ncols = gridsize(wgrids)
    for j in 1:ncols, i in 1:nrows
        f(i, j)
    end
end

# Reduces array reads for single grids, when we can just use
# the center of the neighborhood buffer as the cell state
@inline readgridsorbuffer(rgrids::Tuple, buffer, rule, r, I...) =
    readgrids(keys2vals(readkeys(rule)), rgrids, I...)
@inline readgridsorbuffer(rgrids::ReadableGridData, buffer, rule, r, I...) =
    buffer[r + 1, r + 1]

update_buffers!(buffers, src, rowsinblock, hoodsize, r, i, j) = begin
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

get_cellstatus(wgrids::Tuple, rule, writeval) = begin
    val = writeval[1]
    val != zero(val)
end
get_cellstatus(wgrids::WritableGridData, rule, writeval) =
    writeval != zero(typeof(writeval))



"""
    readgrids(rkeys, rgrids, I...)

Read values from grid/s at index `I`. This occurs for every cell for every rule,
so has to be very fast.

Returns a single value or NamedTuple of values.
"""
function readgrids end
@generated function readgrids(rkeys::Tuple, rgrids::Tuple, I...)
    expr = Expr(:tuple)
    for i in 1:length(rgrids.parameters)
        push!(expr.args, :(@inbounds rgrids[$i][I...]))
    end
    quote
        keys = map(unwrap, rkeys)
        vals = $expr
        NamedTuple{keys,typeof(vals)}(vals)
    end
end
readgrids(rkeys::Val, rgrids::ReadableGridData, I...) = begin
    @inbounds rgrids[I...]
end


"""
    writegrids(rkeys, rgrids, I...)

Write values to grid/s at index `I`. This occurs for every cell for every rule,
so has to be very fast.

Returns a single value or NamedTuple of values.
"""
function writegrids end
@generated writegrids!(wdata::Tuple, vals::Union{Tuple,NamedTuple}, I...) = begin
    expr = Expr(:block)
    for i in 1:length(wdata.parameters)
        push!(expr.args, :(@inbounds dest(wdata[$i])[I...] = vals[$i]))
    end
    push!(expr.args, :(nothing))
    expr
end
writegrids!(wdata::GridData{T}, val::T, I...) where T = begin
    @inbounds dest(wdata)[I...] = val
    nothing
end


"""
    getgrids(context, rule::Rule, simdata::AbstractSimData)

Retreives `GridData` from a `SimData` object to match the requirements of a `Rule`.

Returns a `Tuple` holding the key or `Tuple` of keys, and grid or `Tuple` of grids.
"""
function getgrids end
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


"""
    combinegrids(rkey, rgrids, wkey, wgrids)

Combine grids into a new NamedTuple of grids depending
on the read and write keys required by a rule.
"""
function combinegrids end
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

"""
    replacegrids(simdata::AbstractSimData, newkeys, newgrids)

Replace grids in a NamedTuple with new grids where required.
"""
function replacegrids end
replacegrids(simdata::AbstractSimData, newkeys, newgrids) =
    @set simdata.grids = replacegrids(grids(simdata), newkeys, newgrids)
@generated replacegrids(allgrids::NamedTuple, newkeys::Tuple, newgrids::Tuple) = begin
    newkeys = map(unwrap, newkeys.parameters)
    allkeys = allgrids.parameters[1]
    expr = Expr(:tuple)
    for key in allkeys
        if key in newkeys
            i = findfirst(k -> k == key, newkeys)
            push!(expr.args, :(newgrids[$i]))
        else
            push!(expr.args, :(allgrids.$key))
        end
    end
    quote
        vals = $expr
        NamedTuple{$allkeys,typeof(vals)}(vals)
    end
end
@generated replacegrids(allgrids::NamedTuple, newkey::Val, newgrid::GridData) = begin
    newkey = unwrap(newkey)
    allkeys = allgrids.parameters[1]
    expr = Expr(:tuple)
    for key in allkeys
        if key == newkey
            push!(expr.args, :(newgrid))
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
