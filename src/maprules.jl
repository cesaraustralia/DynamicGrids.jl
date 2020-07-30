# Internal traits for sharing methods
struct _Read_ end
struct _Write_ end

"""
    maprule!(simdata::SimData, rule::Rule)

Map a rule over the grids it uses, doining any setup
and performance optimisation work required.

This is broken into a setup method and an application method
to introduce a function barrier, for type stability.
"""
function maprule! end
maprule!(simdata::SimData, rule::Rule) = begin
    rkeys, rgrids = getgrids(_Read_(), rule, simdata)
    wkeys, wgrids = getgrids(_Write_(), rule, simdata)
    # Copy the source to dest for grids we are writing to, if needed
    maybeupdatedest!(wgrids, rule)
    # Copy or zero out overflow where needed
    handleoverflow!(wgrids)
    # Combine read and write grids to a temporary simdata object
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
    copy!(parent(dest(d)), parent(source(d)))
end

maybecopystatus!(grid::Tuple{Vararg{<:GridData}}) = map(maybecopystatus!, grid)
maybecopystatus!(grid::GridData) =
    maybecopystatus!(sourcestatus(grid), deststatus(grid))
maybecopystatus!(srcstatus, deststatus) = nothing
maybecopystatus!(srcstatus::AbstractArray, deststatus::AbstractArray) =
    @inbounds return srcstatus .= deststatus

_to_readonly(data::Tuple) = map(ReadableGridData, data)
_to_readonly(data::WritableGridData) = ReadableGridData(data)

maprule!(simdata::SimData, opt::PerformanceOpt, rule::Rule, rkeys, rgrids, wkeys, wgrids, mask) =
    let rule=rule, simdata=simdata, rkeys=rkeys, rgrids=rgrids, wkeys=wkeys, wgrid=wgrids
        optmap(opt, rgrids) do i, j
            ismasked(mask, i, j) && return
            readval = readgrids(rkeys, rgrids, i, j)
            writeval = applyrule(simdata, rule, readval, (i, j))
            writegrids!(wgrids, writeval, i, j)
            return
        end
    end
maprule!(simdata::SimData, opt::PerformanceOpt, rule::ManualRule, rkeys, rgrids, wkeys, wgrids, mask) =
    let rule=rule, simdata=simdata, rkeys=rkeys, rgrids=rgrids
        optmap(opt, rgrids) do i, j
            ismasked(mask, i, j) && return
            readval = readgrids(rkeys, rgrids, i, j)
            applyrule!(simdata, rule, readval, (i, j))
            return
        end
    end

"""
    optmap(f, data, ::SparseOpt)

Maps rules over grids with sparse block optimisation. Inactive blocks do not run.
This can lead to order of magnitude performance improvments in sparse
simulations where large areas of the grid are filled with zeros.
"""
optmap(f, ::SparseOpt, data) = begin
    nrows, ncols = gridsize(data)
    r = radius(data)
    # Only use SparseOpt for single-grid rules with grid radii > 0
    if r isa Tuple || r == 0
        optmap(f, NoOpt(), data)
        return
    end

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
    return
end
"""
    optmap(f, data, ::NoOpt)

Maps rule applicator over the grid with no optimisation
"""
optmap(f, ::NoOpt, data) = begin
    nrows, ncols = gridsize(data)
    for j in 1:ncols, i in 1:nrows
        f(i, j)
    end
end


maprule!(simdata::SimData, opt::PerformanceOpt,
         rule::Union{NeighborhoodRule,Chain{R,W,<:Tuple{<:NeighborhoodRule,Vararg}}},
         rkeys, rgrids, wkeys, wgrids, mask) where {R,W} = begin
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
                readval = if rgrids isa Tuple
                    # Get all vals from grids
                    readgrids(keys2vals(readkeys(rule)), rgrids, I...)
                else
                    # Get single val from buffer center
                    buffers[b][r + 1, r + 1]
                end
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
    # rgrids isa Tuple && length(rgrids) > 1 && error("`SparseOpt` can't handle rules with multiple read grids yet. Use `opt=NoOpt()`")

    # Initialise status for the dest. Is this needed?
    srcstatus, dststatus = sourcestatus(griddata), deststatus(griddata)
    dststatus .= false

    # curstatus and newstatus track active status for 4 local blocks
    newstatus = [false false; false false]
    valtype = eltype(dst)


    #= Run the rule row by row. When we move along a row by one cell, we access only
    a single new column of data with the height of 2 blocks, and move the existing
    data in the neighborhood buffers array accross by one column. This saves on reads
    from the main array, and focusses reads and writes in the small buffer array that
    should be in fast local memory. =#

    # Loop down the block COLUMN
    for bi = 1:size(srcstatus, 1)
        lastblockrow = bi == size(srcstatus, 1)
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
        newstatus .= false

        # Loop along the block ROW. This is faster because we are reading
        # 1 column from the main array for 2 blocks at each step, not actually along the row.
        for bj = 1:size(srcstatus, 2)
            lastblockcol = bj == size(srcstatus, 2)
            @inbounds newstatus[1, 1] = newstatus[1, 2]
            @inbounds newstatus[2, 1] = newstatus[2, 2]
            @inbounds newstatus[1, 2] = false
            @inbounds newstatus[2, 2] = false

            bs11, bs21 = bs12, bs22
            bs12, bs22 = if lastblockcol
                # This is the last block, the second half wont run
                false, false
            else
                # Get current block status from the source status array
                @inbounds srcstatus[bi, bj + 1], lastblockrow ? false : srcstatus[bi + 1, bj + 1]
            end

            jstart = blocktoind(bj, blocksize)
            jstop = min(jstart + blocksize - 1, ncols)

            # Skip this block it and its neighbors are inactive
            if !(bs11 | bs12 | bs21 | bs22)
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
                            write = applyrule(simdata, tail(rule), read, I)
                            if wgrids isa Tuple
                                map(wgrids, write) do d, w
                                    @inbounds dest(d)[I...] = w
                                end
                            else
                                @inbounds dest(wgrids)[I...] = write
                            end
                        end
                    end
                else
                    # Zero out cells
                    for j in jstart:jstop
                        for b in 1:rowsinblock
                            I = i + b - 1, j
                            zero_writegrid!(wgrids, I...)
                        end
                    end
                end
                continue
            end

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
                # Which block column are we in, 1 or 2
                curblockj = (j - jstart) ÷ r + 1
                if freshbuffer
                    freshbuffer = false
                else
                    update_buffers!(buffers, src, rowsinblock, hoodsize, r, i, j)
                end

                # Loop over the grid ROWS inside the block
                for b in 1:rowsinblock
                    I = i + b - 1, j
                    ismasked(mask, I...) && continue
                    # Which block row are we in, 1 or 2
                    curblocki = (b - 1) ÷ r + 1
                    readval = if rgrids isa Tuple
                        # Get all vals from grids
                        readgrids(keys2vals(readkeys(rule)), rgrids, I...)
                    else
                        # Get single val from buffer center
                        @inbounds buffers[b][r + 1, r + 1]
                    end
                    @inbounds writeval = applyrule(simdata, bufrules[b], readval, I)
                    @inbounds writegrids!(wgrids, writeval, I...)
                    # Update the status for the block
                    @inbounds newstatus[curblocki, curblockj] |= get_cellstatus(wgrids, rule, writeval)
                end

                # Combine blocks with the previous rows / cols
                @inbounds dststatus[bi, bj] |= newstatus[1, 1]
                if !lastblockcol
                    @inbounds dststatus[bi, bj+1] |= newstatus[1, 2]
                end
                if !lastblockrow
                    @inbounds dststatus[bi+1, bj] |= newstatus[2, 1]
                    # Start new block fresh to remove old status
                    if !lastblockcol
                        @inbounds dststatus[bi+1, bj+1] = newstatus[2, 2]
                    end
                end
            end
        end
    end
end

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

zero_writegrid!(grids::Tuple, I...) =
    map(g -> zero_writegrid!(g, I...), grids)
zero_writegrid!(grid::WritableGridData, I...) =
    @inbounds dest(grid)[I...] = zero(eltype(dest(grid)))

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
readgrids(rkeys::Val, rgrids::ReadableGridData, I...) =
    (return @inbounds rgrids[I...])


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
