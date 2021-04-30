import ModelParameters.Flatten
          
"""
    Base.get(data::AbstractSimData, key::Union{Symbol,Aux,Grid}, I...)

Allows parameters to be taken from a single value, another grid or an aux array.

If aux arrays are a `DimArray` time sequence (with a `Ti` dim) the currect date will be 
calculated automatically.

Currently this is cycled by default, but will use Cyclic mode in DiensionalData.jl in future.
"""
@propagate_inbounds Base.get(data::AbstractSimData, val, I...) = val


"""
    ParameterSource

Abstract supertypes for parameter source wrappers. These allow
parameters to be retreived from auxilliary data or from other grids.
"""
abstract type ParameterSource end


"""
    Aux <: ParameterSource

    Aux{K}()
    Aux(K::Symbol)

Use auxilary array with key `K` as a parameter source.

Implemented in rules with:

```julia
get(data, rule.myparam, index...)
```

When an `Aux` param is specified at rule construction with:

```julia
rule = SomeRule(; myparam=Aux{:myaux})
output = ArrayOutput(init; aux=(myaux=myauxarray,))
```

If the array is a DimensionalData.jl `DimArray` with a `Ti` (time)
dimension, the correct interval will be selected automatically,
precalculated for each timestep so it has no significant overhead.
"""
struct Aux{K} end
Aux(key::Symbol) = Aux{key}()

_unwrap(::Aux{X}) where X = X
_unwrap(::Type{<:Aux{X}}) where X = X

@propagate_inbounds Base.get(data::AbstractSimData, key::Aux, I...) = _auxval(data, key, I...)

@inline aux(nt::NamedTuple, ::Aux{Key}) where Key = nt[Key]

# If there is no time dimension we return the same data for every timestep
_auxval(data::AbstractSimData, key::Union{Aux,Symbol}, I...) = 
    _auxval(aux(data, key), data, key, I...)
_auxval(A::AbstractMatrix, data::AbstractSimData, key::Union{Aux,Symbol}, y, x) = A[y, x]
# function _auxval(A::AbstractDimArray{<:Any,2}, data::AbstractSimData, key::Union{Aux,Symbol}, y, x)
    # X = DD.basetypeof(dims(A, XDim))
    # Y = DD.basetypeof(dims(A, YDim))
    # A[y, x]
# end
function _auxval(A::AbstractDimArray{<:Any,3}, data::AbstractSimData, key::Union{Aux,Symbol}, y, x)
    # X = DD.basetypeof(dims(A, XDim))
    # Y = DD.basetypeof(dims(A, YDim))
    A[y, x, auxframe(data, key)]
end

function boundscheck_aux(data::AbstractSimData, auxkey::Aux{Key}) where Key
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
    Grid <: ParameterSource

    Grid{K}()
    Grid(K::Symbol)

Use grid with key `K` as a parameter source.

Implemented in rules with:

```julia
get(data, rule.myparam, index...)
```

And specified at rule construction with:

```julia
SomeRule(; myparam=Grid{:somegrid})
```
"""
struct Grid{K} end
Grid(key::Symbol) = Grid{key}()

_unwrap(::Grid{X}) where X = X
_unwrap(::Type{<:Grid{X}}) where X = X

@propagate_inbounds Base.get(data::AbstractSimData, key::Grid{K}, I...) where K = data[K][I...]



"""
    Delay(key::Symbol, length)

`Delay` allows using a [`Grid`](@ref) from previous timesteps as a parameter source as 
a field in any `Rule` that uses `get` to retrieve it's parameters. It must be coupled with 
an output that stores all frames, so that `@assert DynamicGrids.isstored(output) == true`. 

With [`GraphicOutput`](@ref)s this may be acheived by using the keyword argument 
`store=true` when constructing the output object.

# Arguments

- `key::Symbol`: matching the name of a grid in `init`.
- `length`: a multiple of the step size of the output `tspan`.

# Example

```julia
SomeRule(;
    someparam=Delay(:grid_a, Month(3))
    otherparam=1.075
)
`` `
"""
struct Delay{K,S,F,DF}
    steps::S
    frames::F
    delayframe::DF
end
Delay(key::Symbol, step) = Delay{key}(step)
Delay{K}(step::S, frames::F=nothing, delayframe::DF=nothing) where {K,S,F,DF} = 
    Delay{K,S,F,DF}(step, frames, delayframe)

ConstructionBase.constructorof(::Delay{K}) where K = Delay{K}

steps(delay::Delay) = delay.steps
frames(delay::Delay) = delay.frames
delayframe(delay::Delay) = delay.delayframe

@propagate_inbounds function Base.get(data::AbstractSimData, delay::Delay, I...) 
    frames(delay)[delayframe(delay)][I...]
end

# _setdelays
# Update any Delay anywhere in the rules Tuple.
function _setdelays(rules::Tuple, output, data) 
    isstored(output) || _notstorederror()
    Flatten.modify(rules, Delay, Function) do delay
        _setdelay(delay, output, data)
    end
end
# _setdelay
# Replace the delay step size with an integer for fast indexing
# checking that the delay matches the simulation step size.
# Delays at the start just use the init frame, for now.
function _setdelay(delay::Delay{K}, output, data) where K
    nsteps = steps(delay) / step(tspan(data))
    isteps = trunc(Int, nsteps)
    nsteps == isteps || _delaysteperror(delay, step(tspan(data)))
    delayframe = max(currentframe(data) - isteps, 1)
    Delay{K}(isteps, map(f -> f[K], frames(output)), delayframe)
end

_notstorederror() = 
    throw(ArgumentError("Output does not store frames, which is needed for a Delay. Use ArrayOutput or any GraphicOutput with `store=true` keyword"))
_delaysteperror(delay::Delay{K}, simstep) where K = 
    throw(ArgumentError("Delay $K size $(steps(delay)) is not a multiple of simulations step $simstep"))
