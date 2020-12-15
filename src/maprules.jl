# Internal traits for sharing methodsbst
const GridOrGridTuple = Union{<:GridData,Tuple{Vararg{<:GridData}}}

"""
    maprule!(simdata::SimData, rule::Rule)

Map a rule over the grids it reads from and updating the grids it writes to.

This is broken into a setup method and an application method
to introduce a function barrier, for type stability.
"""
function maprule!(data::SimData, rule::Rule)
    #= keys and grids are separated instead of in a NamedTuple as `rgrids` or `wgrids`
    may be a single grid, not a Tuple. But we still need to know what its key is.
    The structure of rgrids and wgrids determines the values that are sent to the rule
    are in a NamedTuple or single value, and wether a tuple of single return value
    is expected. There may be a cleaner way of doing this. =#
    rkeys, rgrids = _getreadgrids(rule, data)
    wkeys, wgrids = _getwritegrids(rule, data)
    # Copy the source to dest for grids we are writing to, if needed
    _maybeupdatedest!(wgrids, rule)
    # Copy or zero out overflow where needed
    _handleoverflow!(wgrids)
    # Combine read and write grids to a temporary simdata object.
    # This means that grids not specified to write to are read-only.
    allkeys = map(Val, keys(data)) 
    allgrids = values(data)
    tempdata = _combinegrids(data, allkeys, allgrids, wkeys, wgrids)
    # Run the rule loop
    maprule!(wgrids, tempdata, proc(data), opt(data), rule, rkeys, rgrids, wkeys)
    # Mask writes to dest if a mask isprovided, except for 
    # CellRule which doesn't move values into masked areas
    rule isa CellRule || _maybemask!(wgrids)
    # Copy the dest status to source status if it is in use
    _maybecopystatus!(wgrids)
    # Swap the dest/source of grids that were written to
    readonly_wgrids = _swapsource(wgrids) |> _to_readonly
    # Combine the written grids with the original simdata
    _replacegrids(data, wkeys, readonly_wgrids)
end
function maprule!(simdata::SimData, rule::SetGridRule)
    rkeys, rgrids = _getreadgrids(rule, simdata)
    wkeys, wgrids = _getwritegrids(rule, simdata)
    tempsimdata = _combinegrids(simdata, rkeys, rgrids, wkeys, wgrids)
    # Run the rule loop
    applyrule!(tempsimdata, rule)
    # Combine the written grids with the original simdata
    _replacegrids(simdata, wkeys, _to_readonly(wgrids))
end

_maybeupdatedest!(ds::Tuple, rule) = map(d -> _maybeupdatedest!(d, rule), ds)
_maybeupdatedest!(d::WritableGridData, rule::Rule) = nothing
function _maybeupdatedest!(d::WritableGridData, rule::SetCellRule)
    copyto!(parent(dest(d)), parent(source(d)))
end

_maybemask!(wgrids::Tuple) = map(_maybemask!, wgrids)
_maybemask!(wgrid::WritableGridData) = _maybemask!(wgrid, proc(wgrid), mask(wgrid))
_maybemask!(wgrid::WritableGridData, proc, mask::Nothing) = nothing
function _maybemask!(wgrid::WritableGridData{Y,X}, proc, mask::AbstractArray) where {Y,X}
    procmap(proc, 1:X) do j
        for i in 1:Y
            dest(wgrid)[i, j] *= mask[i, j]
        end
    end
end

_maybecopystatus!(grids::Tuple{Vararg{<:GridData}}) = map(_maybecopystatus!, grids)
_maybecopystatus!(grid::GridData) = _maybecopystatus!(sourcestatus(grid), deststatus(grid))
_maybecopystatus!(srcstatus, deststatus) = nothing
function _maybecopystatus!(srcstatus::AbstractArray, deststatus::AbstractArray)
    copyto!(srcstatus, deststatus)
end

_to_readonly(data::Tuple) = map(ReadableGridData, data)
_to_readonly(data::WritableGridData) = ReadableGridData(data)

_hassparseopt(wgrids::Tuple) = any(o -> o isa SparseOpt, map(opt, wgrids))
_hassparseopt(wgrid) = opt(wgrid) isa SparseOpt

const NeedsBuffer = Union{NeighborhoodRule,Chain{<:Any,<:Any,<:Tuple{<:NeighborhoodRule,Vararg}}}

function maprule!(
    wgrids::Union{<:GridData{Y,X,R},Tuple{<:GridData{Y,X,R},Vararg}},
    simdata, proc::CPU, opt, rule, rkeys, rgrids, wkeys
) where {Y,X,R}
    let simdata=simdata, proc=proc, opt=opt, rule=rule, 
        rkeys=rkeys, rgrids=rgrids, wkeys=wkeys, wgrids=wgrids
        optmap(proc, opt, rgrids, Tuple{Y,X,R}) do i, j
            rule_kernel!(wgrids, simdata, rule, rkeys, rgrids, wkeys, i, j)
        end
    end
end
function maprule!(
    wgrids::Union{<:GridData{Y,X,R},Tuple{<:GridData{Y,X,R},Vararg}},
    simdata, proc::CPU, opt, rule::NeedsBuffer, args...
) where {Y,X,R}
    grid = simdata[neighborhoodkey(rule)]
    _maybecopystatus!(grid, opt)
    mapneighborhoodrule!(wgrids, simdata, grid, proc, opt, rule, args...)
    return nothing
end

### Rules that don't need a neighborhood buffer ####################

# Run kernels with SparseOpt
@inline function optmap(f, proc, ::SparseOpt, rgrids, ::Type{Tuple{Y,X,R}}) where {Y,X,R}
    # Only use SparseOpt for single-grid rules with grid radii > 0
    if R == 0
        optmap(f, proc, NoOpt(), rgrids, Tuple{Y,X,R})
        return nothing
    end
    B = 2R
    grid = rgrids isa Tuple ? first(rgrids) : rgrids
    let f=f, proc=proc, grid=grid
        procmap(proc, 1:_indtoblock(X, B)) do bj
            for  bi in 1:_indtoblock(Y, B)
                @inbounds sourcestatus(grid)[bi, bj] || return nothing
                # Convert from padded block to init dimensionn
                istart, jstart = _blocktoind(bi, B) - R, _blocktoind(bj, B) - R
                # Stop at the init row/column size, not the padding or block multiple
                istop, jstop = min(istart + B - 1, Y), min(jstart + B - 1, X)
                # Skip the padding
                istart, jstart  = max(istart, 1), max(jstart, 1)
                for j in jstart:jstop, i in istart:istop
                    f(i, j)
                end
                return nothing
            end
        end
    end
    return nothing
end
# Run kernel over the whole grid, cell by cell
@inline optmap(f, proc, ::NoOpt, g, ::Type{Tuple{Y,X,R}}) where {Y,X,R} = 
    procmap(proc, 1:X) do j
        for i in 1:Y
            f(i, j)
        end
    end

# Looping over cells or blocks on CPU
@inline procmap(f, proc::SingleCPU, range) =
    for n in range
        f(n)
    end
@inline procmap(f, proc::ThreadedCPU, range) =
    Threads.@threads for n in range 
        f(n)
    end

@inline function rule_kernel!(wgrids, simdata, rule::Rule, rkeys, rgrids, wkeys, i, j)
    readval = _readgrids(rkeys, rgrids, i, j)
    writeval = applyrule(simdata, rule, readval, (i, j))
    _writegrids!(wgrids, writeval, i, j)
    nothing
end
@inline function rule_kernel!(wgrids, simdata, rule::SetCellRule, rkeys, rgrids, wkeys, i, j)
    readval = _readgrids(rkeys, rgrids, i, j)
    applyrule!(simdata, rule, readval, (i, j))
    nothing
end



## Rules that need a Neighorhood buffer #############################################

@inline function mapneighborhoodrule!(
    wgrids, simdata, grid::GridData{Y,X,R}, proc::CPU, args...
) where {Y,X,R}
    let wgrids=wgrids, simdata=simdata, grid=grid, proc=proc, args=args
        procmap(proc, 1:_indtoblock(Y, 2R)) do bi
            row_kernel!(wgrids, simdata, grid, args..., bi)
        end
    end
    return nothing
end

@inline function _maybecopystatus!(grid, opt::SparseOpt)
    # Copy src to dst - we don't run every block so this is necessary
    src, dst = parent(source(grid)), parent(dest(grid))
    srcstatus, dststatus = parent(source(grid)), parent(dest(grid))
    dst .= src
    dststatus .= srcstatus
    return nothing
end 
@inline _maybecopystatus!(grid, opt::NoOpt) = nothing


#= Run the rule row by row. When we move along a row by one cell, we access only
a single new column of data with the height of 4R, and move the existing
data in the neighborhood buffers array across by one column. This saves on reads
from the main array. =#
@inline function row_kernel!(
    wgrids, simdata::SimData, grid::GridData{Y,X,R}, opt::NoOpt, rule, 
    rkeys, rgrids, wkeys, bi
) where {Y,X,R}
    B = 2R
    i = _blocktoind(bi, B)
    # Loop along the block ROW. 
    src = parent(source(grid))
    buffers = _initialise_buffers(src, Val{R}(), i, 1)
    blocklen = min(Y, i + B - 1) - i + 1
    for j = 1:X
        buffers = _update_buffers(buffers, src, Val{R}(), i, j)
        # Loop over the COLUMN of buffers covering the block
        for b in 1:blocklen
            @inbounds bufrule = _setbuffer(rule, buffers[b])
            I = i + b - 1, j
            # Run the rule using buffer b
            @inbounds readval = _readgridsorbuffer(rgrids, buffers[b], bufrule, I...)
            writeval = applyrule(simdata, bufrule, readval, I)
            _writegrids!(wgrids, writeval, I...)
        end
    end
end
@inline function row_kernel!(
    wgrids, simdata::SimData, grid::GridData{Y,X,R}, opt::SparseOpt, rule, 
    rkeys, rgrids, wkeys, bi
) where {Y,X,R}
    B = 2R
    S = 2R + 1
    nblockcols = _indtoblock(X, B)
    src = parent(source(grid))
    srcstatus, dststatus = sourcestatus(grid), deststatus(grid)

    # Blocks ignore padding! the first block contains padding.
    i = _blocktoind(bi, B)
    # Get current block
    skippedlastblock = true

    # Initialise block status for the start of the row
    # The first column always runs, it's buggy otherwise.
    @inbounds bs11, bs12 = true, true
    @inbounds bs21, bs22 = true, true
    # New block status
    newbs12 = false
    newbs22 = false
    buffers = _initialise_buffers(src, Val{R}(), i, 1)
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
                jstart = _blocktoind(bj, B)
                jstop = min(jstart + B - 1, X)
                for j in jstart:jstop
                    # Loop over the grid ROWS inside the block
                    blocklen = min(Y, i + B - 1) - i + 1
                    for b in 1:blocklen
                        I = i + b - 1, j
                        readval = _readgrids(rkeys, rgrids, I...)
                        writeval = applyrule(simdata, tail(rule), readval, I)
                        _writegrids!(wgrids, writeval, I...)
                    end
                end
            end
            continue
        end # Define area to loop over with the block.
        # It's variable because the last block may be partial
        jstart = _blocktoind(bj, B)
        jstop = min(jstart + B - 1, X)

        # Reinitialise neighborhood buffers if we have skipped a section of the array
        if skippedlastblock
            buffers = _initialise_buffers(src, Val{R}(), i, jstart)
            skippedlastblock = false
        end

        # Shuffle new buffer status
        newbs11 = newbs12
        newbs21 = newbs22
        newbs12 = newbs22 = false

        # Loop over the grid COLUMNS inside the block
        for j in jstart:jstop
            # Update buffers unless feshly populated
            buffers = _update_buffers(buffers, src, Val{R}(), i, j)

            # Which block column are we in, 1 or 2
            curblockj = (j - jstart) ÷ R + 1

            # Loop over the COLUMN of buffers covering the block
            blocklen = min(Y, i + B - 1) - i + 1
            for b in 1:blocklen
                # Get the current cell index
                I = i + b - 1, j
                # Set rule buffer
                bufrule = _setbuffer(rule, buffers[b])
                # Get value/s for the cell
                readval = _readgridsorbuffer(rgrids, buffers[b], bufrule, I...)
                # Run the rule
                writeval = applyrule(simdata, bufrule, readval, I)
                # Write to the grid
                _writegrids!(wgrids, writeval, I...)
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
    return nothing
end

@inline _cellstatus(opt::SparseOpt, wgrids::Tuple, writeval) = _cellstatus(opt, writeval[1], writeval)
@inline _cellstatus(opt::SparseOpt, wgrids, writeval) = !can_skip(opt, writeval)



## Low-level generated functiond for working with grids ######################

# Reduces array reads for single grids, when we can just use
# the center of the neighborhood buffer as the cell state
@inline function _readgridsorbuffer(rgrids::Tuple, buffer, rule, I...)
    _readgrids(_keys2vals(_readkeys(rule)), rgrids, I...)
end
@inline function _readgridsorbuffer(
    rgrids::ReadableGridData{<:Any,<:Any,R}, buffer, rule, I...
) where R
    @inbounds buffer[R + 1, R + 1]
end

# Generate an SArray from the main array and the last SArray
@generated function _update_buffers(
    buffers::Tuple, src::AbstractArray{T}, ::Val{R}, i, j
) where {T,R}
    B = 2R; S = 2R + 1; L = S^2
    newvals = Expr[]
    for n in 0:2B-1
        push!(newvals, :(@inbounds src[i + $n, j + 2R]))
    end
    newbuffers = Expr(:tuple)
    for b in 1:B
        bufvals = Expr(:tuple)
        for n in S+1:L
            push!(bufvals.args, :(@inbounds buffers[$b][$n]))
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

# Generate an SArray from the main array
@generated function _initialise_buffers(src::AbstractArray{T}, ::Val{R}, i, j) where {T,R}
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
            push!(newcol, :(@inbounds src[i + $r, j + $c]))
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
    _readgrids(rkeys, rgrids, I...)

Read values from grid/s at index `I`. This occurs for every cell for every rule,
so has to be very fast.

Returns a single value or NamedTuple of values.
"""
function _readgrids end
@generated function _readgrids(rkeys::Tuple, rgrids::Tuple, I...)
    expr = Expr(:tuple)
    for i in 1:length(rgrids.parameters)
        push!(expr.args, :(@inbounds rgrids[$i][I...]))
    end
    return quote
        keys = map(_unwrap, rkeys)
        vals = $expr
        NamedTuple{keys,typeof(vals)}(vals)
    end
end
function _readgrids(rkeys::Val, rgrids::ReadableGridData, I...)
    @inbounds rgrids[I...]
end

"""
    _writegrids(rkeys, rgrids, I...)

Write values to grid/s at index `I`. This occurs for every cell for every rule,
so has to be very fast.

Returns a single value or NamedTuple of values.
"""
function _writegrids end
@generated function _writegrids!(wdata::Tuple, vals::Union{Tuple,NamedTuple}, I...)
    expr = Expr(:block)
    for i in 1:length(wdata.parameters)
        push!(expr.args, :(@inbounds dest(wdata[$i])[I...] = vals[$i]))
    end
    push!(expr.args, :(nothing))
    return expr
end
function _writegrids!(wdata::GridData, val, I...)
    @inbounds dest(wdata)[I...] = val
    return nothing
end

"""
    getredgrids(context, rule::Rule, simdata::AbstractSimData)

Retrieves `GridData` from a `SimData` object to match the requirements of a `Rule`.

Returns a `Tuple` holding the key or `Tuple` of keys, and grid or `Tuple` of grids.
"""
@generated function _getreadgrids(::Rule{R,W}, simdata::AbstractSimData) where {R<:Tuple,W}
    Expr(:tuple,
        Expr(:tuple, (:(Val{$(QuoteNode(key))}()) for key in R.parameters)...),
        Expr(:tuple, (:(simdata[$(QuoteNode(key))]) for key in R.parameters)...),
    )
end
@generated function _getreadgrids(::Rule{R,W}, simdata::AbstractSimData) where {R,W}
    :((Val{$(QuoteNode(R))}(), simdata[$(QuoteNode(R))]))
end
@generated function _getwritegrids(::Rule{R,W}, simdata::AbstractSimData) where {R,W<:Tuple}
    Expr(:tuple,
        Expr(:tuple, (:(Val{$(QuoteNode(key))}()) for key in W.parameters)...),
        Expr(:tuple, (:(WritableGridData(simdata[$(QuoteNode(key))])) for key in W.parameters)...),
    )
end
@generated function _getwritegrids(::Rule{R,W}, simdata::AbstractSimData) where {R,W}
    :((Val{$(QuoteNode(W))}(), WritableGridData(simdata[$(QuoteNode(W))])))
end

"""
    _combinegrids(rkey, rgrids, wkey, wgrids)

Combine grids into a new NamedTuple of grids depending
on the read and write keys required by a rule.
"""
@inline function _combinegrids(simdata::SimData, rkeys, rgrids, wkeys, wgrids)
    @set simdata.grids = _combinegrids(rkeys, rgrids, wkeys, wgrids)
end
@inline function _combinegrids(rkey, rgrids, wkey, wgrids)
    _combinegrids((rkey,), (rgrids,), (wkey,), (wgrids,))
end
@inline function _combinegrids(rkey, rgrids, wkeys::Tuple, wgrids::Tuple)
    _combinegrids((rkey,), (rgrids,), wkeys, wgrids)
end
@inline function _combinegrids(rkeys::Tuple, rgrids::Tuple, wkey, wgrids)
    _combinegrids(rkeys, rgrids, (wkey,), (wgrids,))
end
@generated function _combinegrids(rkeys::Tuple, rgrids::Tuple, wkeys::Tuple, wgrids::Tuple)
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
    _replacegrids(simdata::AbstractSimData, newkeys, newgrids)

Replace grids in a NamedTuple with new grids where required.
"""
function _replacegrids(simdata::AbstractSimData, newkeys, newgrids)
    @set simdata.grids = _replacegrids(grids(simdata), newkeys, newgrids)
end
@generated function _replacegrids(allgrids::NamedTuple, newkeys::Tuple, newgrids::Tuple)
    newkeys = map(_unwrap, newkeys.parameters)
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
@generated function _replacegrids(allgrids::NamedTuple, newkey::Val, newgrid::GridData)
    newkey = _unwrap(newkey)
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
