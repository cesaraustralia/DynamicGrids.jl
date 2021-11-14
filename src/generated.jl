
# Low-level generated functions for working with grids

# _update_buffers => NTuple{N,SMatrix}
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

# _initialise_buffers => NTuple{N,SMatrix}
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

# _getwindow => SMatrix
# Get a single window square from an array, as an SMatrix.
# We use this on GPUs to get a neighborhood window from the main 
# grid, which is 10x or more faster than using a view. 
# We could possible just use this instead of _update_buffers
# for the sake of simplicity, with some performance loss.
# @generated function _getwindow(tile::AbstractArray{T,2}, ::Neighborhood{R}, i, j) where {T,R}
#     S = 2R+1
#     L = S^2
#     vals = Expr(:tuple)
#     for jj in 1:S, ii in 1:S 
#         push!(vals.args, :(@inbounds tile[$ii + i - 1, $jj + j - 1]))
#     end
#     return :(SMatrix{$S,$S,$T,$L}($vals))
# end
@generated function _getwindow(tile::AbstractArray{T,N}, ::Neighborhood{R}, I...) where {T,R,N}
    S = 2R+1
    L = S^N
    vals = Expr(:tuple)
    nh = CartesianIndices(nuple(_ -> OneTo(S), N))
    for i in 1:L 
        nhI = map((i1, i2) -> i1 + i2 - 1, I, Tuple(nh[i]))
        push!(vals.args, :(@inbounds tile[$cI...]))
    end
    return :(SMatrix{$S,$S,$T,$L}($vals))
end

# _readcell
# Returns a single value or NamedTuple of values.
# This occurs for every cell for every rule, so has to be very fast.
@generated function _readcell(data, ::K, I...) where K<:Tuple
    expr = Expr(:tuple)
    keys = map(_unwrap, Tuple(K.parameters))
    for (i, k) in enumerate(keys)
        push!(expr.args, :(@inbounds source(data[$(QuoteNode(k))])[I...]))
    end
    return quote
        keys = $keys
        vals = $expr
        NamedTuple{keys,typeof(vals)}(vals)
    end
end
@inline function _readcell(data::AbstractSimData, ::Val{K}, I...) where K
    @inbounds source(data[K])[I...]
end

# _writecell! => nothing
# Write values to grid/s at index `I`. 
# This occurs for every cell for every rule, so has to be very fast.
@generated function _writecell!(data, ::Val{<:CellRule}, wkeys::K, vals::Union{Tuple,NamedTuple}, I...) where K<:Tuple
    expr = Expr(:block)
    keys = map(_unwrap, Tuple(K.parameters))
    for (i, k) in enumerate(keys) 
        # MUST write to source(grid) - CellRule doesn't switch grids
        push!(expr.args, :(@inbounds source(data[$(QuoteNode(k))])[I...] = vals[$i]))
    end
    push!(expr.args, :(nothing))
    return expr
end
@inline function _writecell!(data, ::Val{<:CellRule}, wkeys::Val{K}, val, I...) where K
    # MUST write to source(grid) - CellRule doesn't switch grids
    @inbounds source(data[K])[I...] = val
    return nothing
end
@generated function _writecell!(data, ::Val, wkeys::K, vals::Union{Tuple,NamedTuple}, I...) where K<:Tuple
    expr = Expr(:block)
    keys = map(_unwrap, Tuple(K.parameters))
    for (i, k) in enumerate(keys) 
        # MUST write to dest(grid) here, not grid K
        # setindex! has overrides for the grid
        push!(expr.args, :(@inbounds dest(data[$(QuoteNode(k))])[I...] = vals[$i]))
    end
    push!(expr.args, :(nothing))
    return expr
end
@inline function _writecell!(data, ::Val, wkeys::Val{K}, val, I...) where K
    # MUST write to dest(grid) here, not grid K
    # setindex! has overrides for the grid
    @inbounds dest(data[K])[I...] = val
    return nothing
end

# _getreadgrids => Union{ReadableGridData,Tuple{ReadableGridData,Vararg}}
# Retrieves `GridData` from a `SimData` object to match the requirements of a `Rule`.
# Returns a `Tuple` holding the key or `Tuple` of keys, and grid or `Tuple` of grids.
@generated function _getreadgrids(::Rule{R,W}, data::AbstractSimData) where {R<:Tuple,W}
    Expr(:tuple,
        Expr(:tuple, (:(Val{$(QuoteNode(key))}()) for key in R.parameters)...),
        Expr(:tuple, (:(data[$(QuoteNode(key))]) for key in R.parameters)...),
    )
end
@generated function _getreadgrids(::Rule{R,W}, data::AbstractSimData) where {R,W}
    :((Val{$(QuoteNode(R))}(), data[$(QuoteNode(R))]))
end

# _getwritegrids => Union{WritableGridData,Tuple{WritableGridData,Vararg}}
# Retrieves `GridData` from a `SimData` object to match the requirements of a `Rule`.
# Returns a `Tuple` holding the key or `Tuple` of keys, and grid or `Tuple` of grids.
@generated function _getwritegrids(::Rule{R,W}, data::AbstractSimData) where {R,W<:Tuple}
    Expr(:tuple,
        Expr(:tuple, (:(Val{$(QuoteNode(key))}()) for key in W.parameters)...),
        Expr(:tuple, (:(WritableGridData(data[$(QuoteNode(key))])) for key in W.parameters)...),
    )
end
@generated function _getwritegrids(::Rule{R,W}, data::AbstractSimData) where {R,W}
    :((Val{$(QuoteNode(W))}(), WritableGridData(data[$(QuoteNode(W))])))
end

# _combinegrids => AbstractSimData
# Combine grids into a new NamedTuple of grids depending
# on the read and write keys required by a rule.
@inline function _combinegrids(data::AbstractSimData, wkeys, wgrids)
    allkeys = map(Val, keys(data))
    allgrids = values(data)
    _combinegrids(data, allkeys, allgrids, wkeys, wgrids)
end
@inline function _combinegrids(data::AbstractSimData, rkeys, rgrids, wkeys, wgrids)
    @set data.grids = _combinegrids(rkeys, rgrids, wkeys, wgrids)
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

# _replacegrids => AbstractSimData
# Replace grids in a NamedTuple with new grids where required.
function _replacegrids(data::AbstractSimData, newkeys, newgrids)
    @set data.grids = _replacegrids(grids(data), newkeys, newgrids)
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

# _vals2syms => Union{Symbol,Tuple}
# Get symbols from a Val or Tuple type
@inline _vals2syms(x::Type{<:Tuple}) = map(v -> _vals2syms(v), x.parameters)
@inline _vals2syms(::Type{<:Val{X}}) where X = X
