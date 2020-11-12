# Internal traits for sharing methodsbst
const GridOrGridTuple = Union{<:GridData,Tuple{Vararg{<:GridData}}}

"""
    maprule!(simdata::SimData, rule::Rule)

Map a rule over the grids it reads from and updating the grids it writes to.

This is broken into a setup method and an application method
to introduce a function barrier, for type stability.
"""
function maprule!(simdata::SimData, rule::Rule)
    #= keys and grids are separated instead of in a NamedTuple as `rgrids` or `wgrids`
    may be a single grid, not a Tuple. But we still need to know what its key is.
    The structure of rgrids and wgrids determines the values that are sent to the rule
    are in a NamedTuple or single value, and wether a tuple of single return value
    is expected. There may be a cleaner way of doing this. =#

    rkeys, rgrids = getreadgrids(rule, simdata)
    wkeys, wgrids = getwritegrids(rule, simdata)
    # Copy the source to dest for grids we are writing to, if needed
    maybeupdatedest!(wgrids, rule)
    # Copy or zero out overflow where needed
    handleoverflow!(wgrids)
    # Combine read and write grids to a temporary simdata object.
    # This means that grids not asked for by rules are not available,
    # and grids not specified to write to are read-only.
    tempsimdata = combinegrids(simdata, rkeys, rgrids, wkeys, wgrids)
    # Run the rule loop
    maprule!(tempsimdata, opt(simdata), rule, rkeys, rgrids, wkeys, wgrids, mask(simdata))
    # Copy the dest status to dest status if it is in use
    maybecopystatus!(wgrids)
    # Swap the dest/source of grids that were written to
    readonly_wgrids = swapsource(wgrids) |> _to_readonly
    # Combine the written grids with the original simdata
    replacegrids(simdata, wkeys, readonly_wgrids)
end
function maprule!(simdata::SimData, rule::GridRule)
    rkeys, rgrids = getreadgrids(rule, simdata)
    wkeys, wgrids = getwritegrids(rule, simdata)
    # Cant use SparseOpt with GridRule yet
    _checkhassparseopt(wgrids)
    tempsimdata = combinegrids(simdata, rkeys, rgrids, wkeys, wgrids)
    # Run the rule loop
    applyrule!(tempsimdata, rule)
    # Combine the written grids with the original simdata
    replacegrids(simdata, wkeys, _to_readonly(wgrids))
end


# GPUopt
function maprule!(
    simdata::SimData, opt::GPUopt, rule::Rule, rkeys, rgrids, wkeys, wgrids, mask
)
    # kernel! = applyrule_kernel!(CUDADevice(),512)
    kernel! = applyrule_kernel!(CPU(),5)
    wait(kernel!(
        simdata, rule, rkeys, rgrids, wkeys, wgrids, mask;
        ndrange=gridsize(simdata)
    ))
end

# GPUopt
function maprule!(
    simdata::SimData, opt::GPUopt, rule::ManualRule, rkeys, rgrids, wkeys, wgrids, mask
)
    # kernel! = applyrule_kernel!(CUDADevice(),512)
    kernel! = applyrule_kernel!(CPU(),5)
    wait(kernel!(
        simdata, rule, rkeys, rgrids, wkeys, wgrids, mask;
        ndrange=gridsize(simdata)
    ))
end

function maprule!(
    simdata::SimData, opt::GPUopt,
    rule::Union{NeighborhoodRule,Chain{<:Any,<:Any,<:Tuple{<:NeighborhoodRule,Vararg}}},
    rkeys, rgrids, wkeys, wgrids, mask
)
    griddata = simdata[neighborhoodkey(rule)]
    src, dst = parent(source(griddata)), parent(dest(griddata))
    r = radius(rule)

    #= Blocks are 1 cell smaller than the neighborhood, because this works very nicely
    for looking at only 4 blocks at a time. Larger blocks mean each neighborhood is more
    likely to be active, smaller means handling more than 2 neighborhoods per block.
    It would be good to test if this is the sweet spot for performance =#
    kernel! = applyrule_kernel!(CUDADevice(),128)
    # kernel! = applyrule_kernel!(CPU(),5)
    wait(kernel!(
        simdata, griddata, rule, rkeys, rgrids, wkeys, wgrids, src, dst, mask;
        ndrange=indtoblock(gridsize(simdata)[1], 2r)
    ))

    return nothing
end

@kernel function applyrule_kernel!(args...)
    bi = @index(Global, NTuple)
    rowkernel(args..., bi[1])
end

# @kernel function applyrule_kernel!(
#     simdata::SimData, rule::ManualRule, rkeys, rgrids, wkeys, wgrids, mask
# )
#     i, j = @index(Global, NTuple)
#     readval = readgrids(rkeys, rgrids, i, j)
#     applyrule!(simdata, rule, readval, (i, j))
# end

# @kernel function applyrule_kernel!(
#     simdata::SimData, rule::Rule, rkeys, rgrids, wkeys, wgrids, mask
# )
#     i, j = @index(Global, NTuple)
#     readval = readgrids(rkeys, rgrids, i, j)
#     writeval = applyrule(simdata, rule, readval, (i, j))
#     writegrids!(wgrids, writeval, i, j)
# end

maybeupdatedest!(ds::Tuple, rule) = map(d -> maybeupdatedest!(d, rule), ds)
maybeupdatedest!(d::WritableGridData, rule::Rule) = nothing
function maybeupdatedest!(d::WritableGridData, rule::ManualRule)
    copyto!(parent(dest(d)), parent(source(d)))
end

maybecopystatus!(grid::Tuple{Vararg{<:GridData}}) = map(maybecopystatus!, grid)
maybecopystatus!(grid::GridData) = maybecopystatus!(sourcestatus(grid), deststatus(grid))
maybecopystatus!(srcstatus, deststatus) = nothing
function maybecopystatus!(srcstatus::AbstractArray, deststatus::AbstractArray)
    copyto!(srcstatus, deststatus)
end

_to_readonly(data::Tuple) = map(ReadableGridData, data)
_to_readonly(data::WritableGridData) = ReadableGridData(data)

_hassparseopt(wgrids::Tuple) = any(o -> o isa SparseOpt, map(opt, wgrids))
_hassparseopt(wgrid) = opt(wgrid) isa SparseOpt

@noinline _checkhassparseopt(wgrids) =
    _hassparseopt(wgrids) && error("Cant use SparseOpt with a GridRule")

function maprule!(
    simdata::SimData, opt, rule::Rule, rkeys, rgrids, wkeys, wgrids, mask
)
    let simdata=simdata, opt=opt, rule=rule, rkeys=rkeys, 
        rgrids=rgrids, wkeys=wkeys, wgrids=wgrids
        optmap(opt, rgrids, wgrids) do i, j
            ismasked(mask, i, j) && return nothing
            readval = readgrids(rkeys, rgrids, i, j)
            writeval = applyrule(simdata, rule, readval, (i, j))
            writegrids!(wgrids, writeval, i, j)
            return nothing
        end
    end
end
function maprule!(
    simdata::SimData, opt, rule::ManualRule, rkeys, rgrids, wkeys, wgrids, mask
)
    let simdata=simdata, opt=opt, rule=rule, rkeys=rkeys, rgrids=rgrids, 
        wkeys=wkeys, wgrids=wgrids
        optmap(opt, rgrids, wgrids) do i, j
            ismasked(mask, i, j) && return
            readval = readgrids(rkeys, rgrids, i, j)
            applyrule!(simdata, rule, readval, (i, j))
            return
        end
    end
end
function maprule!(
    simdata::SimData, opt::PerformanceOpt,
    rule::Union{NeighborhoodRule,Chain{<:Any,<:Any,<:Tuple{<:NeighborhoodRule,Vararg}}},
    rkeys, rgrids, wkeys, wgrids, mask
)
    griddata = simdata[neighborhoodkey(rule)]
    src, dst = parent(source(griddata)), parent(dest(griddata))

    #= Blocks are 1 cell smaller than the neighborhood, because this works very nicely
    for looking at only 4 blocks at a time. Larger blocks mean each neighborhood is more
    likely to be active, smaller means handling more than 2 neighborhoods per block.
    It would be good to test if this is the sweet spot for performance =#
    mapneighborhoodrule!(
        simdata, griddata, opt, rule, rkeys, rgrids, wkeys, wgrids, src, dst, mask
    )
    return nothing
end

# Neighorhood buffer optimisation without `SparseOpt`
# This is too many arguments
function mapneighborhoodrule!(
    simdata::SimData, griddata::GridData{Y,X,R}, opt::NoOpt, rule, 
    rkeys, rgrids, wkeys, wgrids, src, dst, mask
) where {Y,X,R}
    # Loop down a block COLUMN
    for bi = 1:indtoblock(Y, 2R)
        rowkernel(
            simdata, griddata, rule, rkeys, rgrids, 
            wkeys, wgrids, src, dst, mask, bi
        )
    end
    return nothing
end

function rowkernel(
    simdata::SimData, griddata::GridData{Y,X,R}, rule, 
    rkeys, rgrids, wkeys, wgrids, src, dst, mask, bi
) where {Y,X,R}
    B = 2R
    i = blocktoind(bi, B)
    # Loop along the block ROW.
    buffers = initialise_buffers(src, Val{R}(), i, 1)
    blocklen = min(Y, i + B - 1) - i + 1
    for j = 1:X
        buffers = update_buffers(buffers, src, Val{R}(), i, j)
        # Loop over the COLUMN of buffers covering the block
        for b in 1:blocklen
            bufrule = setbuffer(rule, buffers[b])
            I = i + b - 1, j
            ismasked(mask, I...) && continue
            # Run the rule using buffer b
            readval = buffers[b][R+1, R+1]#readgridsorbuffer(rgrids, buffers[b], bufrule, I...)
            # writeval = applyrule(simdata, bufrule, readval, I)
            writegrids!(wgrids, writeval, I...)
        end
    end
end




# Neighorhood buffer optimisation combined with `SparseOpt`
function mapneighborhoodrule!(
    simdata::SimData, griddata::GridData{Y,X,R}, opt::SparseOpt, rule, rkeys, rgrids,
    wkeys, wgrids, src, dst, mask
) where {Y,X,R}
    B = 2R
    S = 2R + 1
    nblockrows, nblockcols = indtoblock(Y, B), indtoblock(X, B)
    srcstatus, dststatus = sourcestatus(griddata), deststatus(griddata)
    buffers = initialise_buffers(src, Val{R}(), 1, 1)
    # Copy src to dst - we don't run every block so this is necessary
    dst .= src
    dststatus .= srcstatus

    #= Run the rule row by row. When we move along a row by one cell, we access only
    a single new column of data with the height of 2 blocks, and move the existing
    data in the neighborhood buffers array across by one column. This saves on reads
    from the main array, and focusses reads and writes in the small buffer array that
    should be in fast local memory. =#

    # Blocks ignore padding! the first block contains padding.

    # Loop down the block COLUMN
    for bi = 1:nblockrows
        i = blocktoind(bi, B)
        # Get current block
        skippedlastblock = true

        # Initialise block status for the start of the row
        # The first column always runs, it's buggy otherwise.
        @inbounds bs11, bs12 = true, true
        @inbounds bs21, bs22 = true, true
        # New block status
        newbs12 = false
        newbs22 = false

        buffers = initialise_buffers(src, Val{R}(), i, 1)
        # Loop along the block ROW. This is faster because we are reading
        # 1 column from the main array for 2 blocks at each step, not actually along the row.
        for bj = 1:nblockcols
            # Shuffle current buffer status
            bs11, bs21 = bs12, bs22
            @inbounds bs12, bs22 = srcstatus[bi, bj + 1], srcstatus[bi + 1, bj + 1]
            # Skip this block if it and the neighboring blocks are inactive
            if !(bs11 | bs12 | bs21 | bs22)
                skippedlastblock = true
                # Run the rest of the chain if it exists and more than 1 grid is used
                if rule isa Chain && length(rule) > 1 && length(rkeys) > 1
                    # Loop over the grid COLUMNS inside the block
                    jstart = blocktoind(bj, B)
                    jstop = min(jstart + B - 1, X)
                    for j in jstart:jstop
                        # Loop over the grid ROWS inside the block
                        blocklen = min(Y, i + B - 1) - i + 1
                        for b in 1:blocklen
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
            jstart = blocktoind(bj, B)
            jstop = min(jstart + B - 1, X)

            # Reinitialise neighborhood buffers if we have skipped a section of the array
            if skippedlastblock
                buffers = initialise_buffers(src, Val{R}(), i, jstart)
                skippedlastblock = false
            end

            # Shuffle new buffer status
            newbs11 = newbs12
            newbs21 = newbs22
            newbs12 = newbs22 = false

            # Loop over the grid COLUMNS inside the block
            for j in jstart:jstop
                # Update buffers unless feshly populated
                buffers = update_buffers(buffers, src, Val{R}(), i, j)

                # Which block column are we in, 1 or 2
                curblockj = (j - jstart) ÷ R + 1

                # Loop over the COLUMN of buffers covering the block
                blocklen = min(Y, i + B - 1) - i + 1
                for b in 1:blocklen
                    # Get the current cell index
                    I = i + b - 1, j
                    # Check the cell isn't masked
                    ismasked(mask, I...) && continue
                    # Set rule buffer
                    bufrule = setbuffer(rule, buffers[b])
                    # Get value/s for the cell
                    readval = readgridsorbuffer(rgrids, buffers[b], bufrule, I...)
                    # Run the rule
                    writeval = applyrule(simdata, bufrule, readval, I)
                    # Write to the grid
                    writegrids!(wgrids, writeval, I...)
                    # Update the status for the current block
                    cs = _cellstatus(opt, wgrids, writeval)
                    curblocki = R == 1 ? b : (b - 1) ÷ R + 1
                    if curblocki == 1
                        curblockj == 1 ? (newbs11 |= cs) : (newbs12 |= cs)
                    else
                        curblockj == 1 ? (newbs21 |= cs) : (newbs22 |= cs)
                    end
                end

                # Combine new block status with deststatus array
                @inbounds dststatus[bi, bj] |= newbs11
                @inbounds dststatus[bi+1, bj] |= newbs21
                @inbounds dststatus[bi, bj+1] |= newbs12
                # Start new block fresh to remove old status
                @inbounds dststatus[bi+1, bj+1] = newbs22
            end
        end
    end
    return nothing
end

@inline _cellstatus(opt::SparseOpt, wgrids::Tuple, writeval) = _cellstatus(opt, writeval[1], writeval)
@inline _cellstatus(opt::SparseOpt, wgrids, writeval) = !can_skip(opt, writeval)


"""
    optmap(f, ::SparseOpt, rdata::GridOrGridTuple, wdata::GridOrGridTuple)

Maps rules over grids with sparse block optimisation. Inactive blocks do not run.
This can lead to order of magnitude performance improvments in sparse
simulations where large areas of the grid are filled with zeros.
"""
function optmap(
    f, ::SparseOpt, rgrids::GridOrGridTuple,
    wgrids::Union{<:GridData{Y,X,R},Tuple{Vararg{<:GridData{Y,X,R}}}}
) where {Y,X,R}
    # Only use SparseOpt for single-grid rules with grid radii > 0
    if R == 0
        optmap(f, NoOpt(), rgrids, wgrids)
        return nothing
    end

    B = 2R
    nblockrows, nblockcols = indtoblock.((Y, X), B)
    status = sourcestatus(rgrids)
    for bj in 1:nblockcols, bi in 1:nblockrows
        @inbounds status[bi, bj] || continue
        # Convert from padded block to init dimensions
        istart = blocktoind(bi, B) - R
        jstart = blocktoind(bj, B) - R
        # Stop at the init row/column size, not the padding or block multiple
        istop = min(istart + B - 1, Y)
        jstop = min(jstart + B - 1, X)
        # Skip the padding
        istart = max(istart, 1)
        jstart = max(jstart, 1)

        for j in jstart:jstop, i in istart:istop
            f(i, j)
        end
    end
    return nothing
end
"""
    optmap(f, ::NoOpt, rgrids::GridOrGridTuple, wgrids::GridOrGridTuple)

Maps rule applicator over the grid with no optimisation
"""
function optmap(f, ::NoOpt, rgrids::GridOrGridTuple,
    wgrids::Union{<:GridData{Y,X,R},Tuple{Vararg{<:GridData{Y,X,R}}}}
) where {Y,X,R}
    for j in 1:X, i in 1:Y
        f(i, j)
    end
end

# Reduces array reads for single grids, when we can just use
# the center of the neighborhood buffer as the cell state
@inline function readgridsorbuffer(rgrids::Tuple, buffer, rule, I...)
    readgrids(keys2vals(readkeys(rule)), rgrids, I...)
end
@inline function readgridsorbuffer(
    rgrids::ReadableGridData{<:Any,<:Any,R}, buffer, rule, I...
) where R
    buffer[R + 1, R + 1]
end

@generated function update_buffers(
    buffers::Tuple, src::AbstractArray{T}, ::Val{R}, i, j
) where {T,R}
    B = 2R; S = 2R + 1; L = S^2
    newvals = Expr[]
    for n in 0:2B-1
        push!(newvals, :(src[i + $n, j + 2R]))
    end
    newbuffers = Expr(:tuple)
    for b in 1:B
        bufvals = Expr(:tuple)
        for n in S+1:L
            push!(bufvals.args, :(buffers[$b][$n]))
        end
        for n in b:b+B
            push!(bufvals.args, newvals[n])
        end
        push!(newbuffers.args, :(SArray{Tuple{$S,$S},$T,2,$L}($bufvals)))
    end
    return quote
        return $newbuffers
    end
end

@generated function initialise_buffers(src::AbstractArray{T}, ::Val{R}, i, j) where {T,R}
    B = 2R; S = 2R + 1; L = S^2
    columns = []
    zerocol = Expr[]
    for r in 1:2B
        push!(zerocol, :(zero(T)))
    end
    push!(columns, zerocol)
    for c in 0:S-2
        newcol = Expr[]
        for r in 0:2B-1
            push!(newcol, :(src[i + $r, j + $c]))
        end
        push!(columns, newcol)
    end
    newbuffers = Expr(:tuple)
    for b in 1:B
        bufvals = Expr(:tuple)
        for c in 1:S, r in b:b+B
            exp = columns[c][r]
            push!(bufvals.args, exp)
        end
        push!(newbuffers.args, :(SArray{Tuple{$S,$S},$T,2,$L}($bufvals)))
    end
    return quote
        return $newbuffers
    end
end



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
        push!(expr.args, :(rgrids[$i][I...]))
    end
    return quote
        keys = map(unwrap, rkeys)
        vals = $expr
        NamedTuple{keys,typeof(vals)}(vals)
    end
end
function readgrids(rkeys::Val, rgrids::ReadableGridData, I...)
    rgrids[I...]
end


"""
    writegrids(rkeys, rgrids, I...)

Write values to grid/s at index `I`. This occurs for every cell for every rule,
so has to be very fast.

Returns a single value or NamedTuple of values.
"""
function writegrids end
@generated function writegrids!(wdata::Tuple, vals::Union{Tuple,NamedTuple}, I...)
    expr = Expr(:block)
    for i in 1:length(wdata.parameters)
        push!(expr.args, :(dest(wdata[$i])[I...] = vals[$i]))
    end
    push!(expr.args, :(nothing))
    return expr
end
function writegrids!(wdata::GridData, val, I...)
    dest(wdata)[I...] = val
    return nothing
end


"""
    getredgrids(context, rule::Rule, simdata::AbstractSimData)

Retrieves `GridData` from a `SimData` object to match the requirements of a `Rule`.

Returns a `Tuple` holding the key or `Tuple` of keys, and grid or `Tuple` of grids.
"""
@generated function getreadgrids(::Rule{R,W}, simdata::AbstractSimData) where {R<:Tuple,W}
    Expr(:tuple,
        Expr(:tuple, (:(Val{$(QuoteNode(key))}()) for key in R.parameters)...),
        Expr(:tuple, (:(simdata[$(QuoteNode(key))]) for key in R.parameters)...),
    )
end
@generated function getreadgrids(::Rule{R,W}, simdata::AbstractSimData) where {R,W}
    :((Val{$(QuoteNode(R))}(), simdata[$(QuoteNode(R))]))
end
@generated function getwritegrids(::Rule{R,W}, simdata::AbstractSimData) where {R,W<:Tuple}
    Expr(:tuple,
        Expr(:tuple, (:(Val{$(QuoteNode(key))}()) for key in W.parameters)...),
        Expr(:tuple, (:(WritableGridData(simdata[$(QuoteNode(key))])) for key in W.parameters)...),
    )
end
@generated function getwritegrids(::Rule{R,W}, simdata::AbstractSimData) where {R,W}
    :((Val{$(QuoteNode(W))}(), WritableGridData(simdata[$(QuoteNode(W))])))
end

"""
    combinegrids(rkey, rgrids, wkey, wgrids)

Combine grids into a new NamedTuple of grids depending
on the read and write keys required by a rule.
"""
@inline function combinegrids(simdata::SimData, rkeys, rgrids, wkeys, wgrids)
    @set simdata.grids = combinegrids(rkeys, rgrids, wkeys, wgrids)
end
@inline function combinegrids(rkey, rgrids, wkey, wgrids)
    combinegrids((rkey,), (rgrids,), (wkey,), (wgrids,))
end
@inline function combinegrids(rkey, rgrids, wkeys::Tuple, wgrids::Tuple)
    combinegrids((rkey,), (rgrids,), wkeys, wgrids)
end
@inline function combinegrids(rkeys::Tuple, rgrids::Tuple, wkey, wgrids)
    combinegrids(rkeys, rgrids, (wkey,), (wgrids,))
end
@generated function combinegrids(rkeys::Tuple{Vararg{<:Val}}, rgrids::Tuple,
                       wkeys::Tuple{Vararg{<:Val}}, wgrids::Tuple)
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

    return quote
        keys = $keysexp
        vals = $dataexp
        NamedTuple{keys,typeof(vals)}(vals)
    end
end

"""
    replacegrids(simdata::AbstractSimData, newkeys, newgrids)

Replace grids in a NamedTuple with new grids where required.
"""
function replacegrids(simdata::AbstractSimData, newkeys, newgrids)
    @set simdata.grids = replacegrids(grids(simdata), newkeys, newgrids)
end
@generated function replacegrids(allgrids::NamedTuple, newkeys::Tuple, newgrids::Tuple)
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

    return quote
        vals = $expr
        NamedTuple{$allkeys,typeof(vals)}(vals)
    end
end
@generated function replacegrids(allgrids::NamedTuple, newkey::Val, newgrid::GridData)
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

    return quote
        vals = $expr
        NamedTuple{$allkeys,typeof(vals)}(vals)
    end
end

_vals2syms(x::Type{<:Tuple}) = map(v -> _vals2syms(v), x.parameters)
_vals2syms(::Type{<:Val{X}}) where X = X
