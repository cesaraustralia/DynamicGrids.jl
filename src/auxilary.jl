# If there is no time dimension we return the same data for every timestep
_auxval(data::AbstractSimData, key::Union{Aux,Symbol}, I...) = 
    _auxval(aux(data, key), data, key, I...)
_auxval(A::AbstractMatrix, data::SimData, key::Union{Aux,Symbol}, y, x) = A[y, x]
# function _auxval(A::AbstractDimArray{<:Any,2}, data::SimData, key::Union{Aux,Symbol}, y, x)
    # X = DD.basetypeof(dims(A, XDim))
    # Y = DD.basetypeof(dims(A, YDim))
    # A[y, x]
# end
function _auxval(A::AbstractDimArray{<:Any,3}, data::SimData, key::Union{Aux,Symbol}, y, x)
    # X = DD.basetypeof(dims(A, XDim))
    # Y = DD.basetypeof(dims(A, YDim))
    A[y, x, auxframe(data, key)]
end

function boundscheck_aux(data::SimData, auxkey::Aux{Key}) where Key
    a = aux(data)
    (a isa NamedTuple && haskey(a, Key)) || _auxmissingerror(Key, a)
    gsize = gridsize(data)
    asize = size(a[Key], 1), size(a[Key], 2)
    if asize != gsize
        _auxsizeerror(Key, asize, gsize)
    end
    return true
end

@noinline _auxmissingerror(key, aux) = error("Aux data $key is not present in aux")
@noinline _auxsizeerror(key, asize, gsize) =
    error("Aux data $key is size $asize does not match grid size $gsize")

_calc_auxframe(data) = _calc_auxframe(aux(data), data)
_calc_auxframe(aux::NamedTuple, data) = map(A -> _calc_auxframe(A, data), aux)
function _calc_auxframe(A::AbstractDimArray, data)
    hasdim(A, Ti) || return nothing
    curtime = currenttime(data)
    firstauxtime = first(dims(A, TimeDim))
    auxstep = step(dims(A, TimeDim))
    # Use julias range objects to calculate the distance between the 
    # current time and the start of the aux 
    i = if curtime >= firstauxtime
        length(firstauxtime:auxstep:curtime)
    else
        1 - length(firstauxtime-timestep(data):-auxstep:curtime)
    end
    _cyclic_index(i, size(A, 3))
end
_calc_auxframe(aux, data) = nothing

function _cyclic_index(i::Integer, len::Integer)
    return if i > len
        rem(i + len - 1, len) + 1
    elseif i <= 0
        i + (i ÷ len -1) * -len
    else
        i
    end
end


"""
    CopyTo{W}(from)
    CopyTo{W}(; from)

A simple rule that copies aux array slices to a grid over time.
This can be used for comparing simulation dynamics to aux data dynamics.
"""
struct CopyTo{W,F} <: Rule{Tuple{},W}
    "An Aux or Grid key for data source or a single value"
    from::F
end
CopyTo(from) = CopyTo{:_default_}(from)
CopyTo(; from) = CopyTo{:_default_}(from)
CopyTo{W}(from) where W = CopyTo{W,typeof(from)}(from)
CopyTo{W}(; from) where W = CopyTo{W,typeof(from)}(from)

ConstructionBase.constructorof(::Type{<:CopyTo{W}}) where W = CopyTo{W}

DynamicGrids.applyrule(data, rule::CopyTo, state, I) = get(data, rule.from, I...)
DynamicGrids.applyrule(data, rule::CopyTo{W}, state, I) where W <: Tuple =
    ntuple(i -> get(data, rule.from, I...), length(_asiterable(W)))
