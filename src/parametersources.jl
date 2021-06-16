import ModelParameters.Flatten


"""
    ParameterSource

Abstract supertypes for parameter source wrappers such as `Aux` and `Grid`. 
These allow flexibly in that parameters can be retreived from various data sources.
"""
abstract type ParameterSource end

"""
    get(data::AbstractSimData, key::ParameterSource, I...)
    get(data::AbstractSimData, key::ParameterSource, I::Union{Tuple,CartesianIndex})

Allows parameters to be taken from a single value or a [`ParameterSource`](@ref) 
such as another [`Grid`](@ref), an [`Aux`](@ref) array, or a [`Delay`](@ref).
"""
@propagate_inbounds Base.get(data::AbstractSimData, val, I...) = val
@propagate_inbounds Base.get(data::AbstractSimData, key::ParameterSource, I...) = get(data, key, I)
@propagate_inbounds Base.get(data::AbstractSimData, key::ParameterSource, I::CartesianIndex) = get(data, key, Tuple(I))

"""
    Aux <: ParameterSource

    Aux{K}()
    Aux(K::Symbol)

Use auxilary array with key `K` as a parameter source.

Implemented in rules with:

```julia
get(data, rule.myparam, I)
```

When an `Aux` param is specified at rule construction with:

```julia
rule = SomeRule(; myparam=Aux{:myaux})
output = ArrayOutput(init; aux=(myaux=myauxarray,))
```

If the array is a DimensionalData.jl `DimArray` with a `Ti` (time)
dimension, the correct interval will be selected automatically,
precalculated for each timestep so it has no significant overhead.

Currently this is cycled by default. Note that cycling may be incorrect 
when the simulation timestep (e.g. `Week`) does not fit 
equally into the length of the time dimension (e.g. `Year`).
This will reuire a `Cyclic` index mode in DimensionalData.jl in future 
to correct this problem.
"""
struct Aux{K} <: ParameterSource end
Aux(key::Symbol) = Aux{key}()

_unwrap(::Aux{X}) where X = X
_unwrap(::Type{<:Aux{X}}) where X = X

@propagate_inbounds Base.get(data::AbstractSimData, key::Aux, I::Tuple) = _getaux(data, key, I)

@inline aux(nt::NamedTuple, ::Aux{Key}) where Key = nt[Key]

# If there is no time dimension we return the same data for every timestep
@propagate_inbounds _getaux(data::AbstractSimData, key::Union{Aux,Symbol}, I::Tuple) = _getaux(aux(data, key), data, key, I)
@propagate_inbounds _getaux(A::AbstractMatrix, data::AbstractSimData, key::Union{Aux,Symbol}, I::Tuple) = A[I...]
function _getaux(A::AbstractDimArray{<:Any,3}, data::AbstractSimData, key::Union{Aux,Symbol}, I::Tuple)
    A[I..., auxframe(data, key)]
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
get(data, rule.myparam, I)
```

And specified at rule construction with:

```julia
SomeRule(; myparam=Grid(:somegrid))
```
"""
struct Grid{K} <: ParameterSource end
Grid(key::Symbol) = Grid{key}()

_unwrap(::Grid{X}) where X = X
_unwrap(::Type{<:Grid{X}}) where X = X

@propagate_inbounds Base.get(data::AbstractSimData, key::Grid{K}, I::Tuple) where K = data[K][I...]


"""
    AbstractDelay <: ParameterSource

Abstract supertype for [`ParameterSource`](@ref)s that use data from a grid
with a time delay.
"""
abstract type AbstractDelay{K} <: ParameterSource end

@inline frame(delay::AbstractDelay) = delay.frame

@propagate_inbounds function Base.get(data::AbstractSimData, delay::AbstractDelay{K}, I::Tuple) where K
    _getdelay(frames(data)[frame(delay, data)], delay, I)
end

@propagate_inbounds function _getdelay(frame::NamedTuple, delay::AbstractDelay{K}, I::Tuple) where K
    _getdelay(frame[K], delay, I)
end
@propagate_inbounds function _getdelay(frame::AbstractArray, ::AbstractDelay{K}, I::Tuple) where K
    frame[I...]
end

"""
    Delay <: AbstractDelay

    Delay{K}(steps)

`Delay` allows using a [`Grid`](@ref) from previous timesteps as a parameter source as 
a field in any `Rule` that uses `get` to retrieve it's parameters.

It must be coupled with an output that stores all frames, so that `@assert 
DynamicGrids.isstored(output) == true`.  With [`GraphicOutput`](@ref)s this may be 
acheived by using the keyword argument `store=true` when constructing the output object.

# Type Parameters

- `K::Symbol`: matching the name of a grid in `init`.

# Arguments

- `steps`: As a user supplied parameter, this is a multiple of the step size of the output 
    `tspan`. This is automatically replaced with an integer for each step. Used within the 
    code in a rule, it must be an `Int` number of frames, for performance.

# Example

```julia
SomeRule(;
    someparam=Delay(:grid_a, Month(3))
    otherparam=1.075
)
`` `
"""
struct Delay{K,S} <: AbstractDelay{K}
    steps::S
end
Delay{K}(steps::S) where {K,S} = Delay{K,S}(steps)

ConstructionBase.constructorof(::Delay{K}) where K = Delay{K}
steps(delay::Delay) = delay.steps

# _to_frame
# Replace the delay step size with an integer for fast indexing
# checking that the delay matches the simulation step size.
# Delays at the start just use the init frame, for now.
function _to_frame(delay::Delay{K}, data) where K
    nsteps = steps(delay) / step(tspan(data))
    isteps = trunc(Int, nsteps)
    nsteps == isteps || _delaysteperror(delay, step(tspan(data)))
    frame = max(currentframe(data) - isteps, 1)
    Frame{K}(frame)
end

"""
    Lag <: AbstractDelay

    Lag{K}(frames::Int) 

`Lag` allows using a [`Grid`](@ref) from a specific previous frame from within a rule, 
using `get`. It is similar to [`Delay`](@ref), but an integer amount of steps should be 
used, instead of a quantity related to the simulation `tspan`. Used within rule code,
the lower bound will not be checked. Do this manually, or use [`Frame`](@ref) instead.

# Type Parameter

- `K::Symbol`: matching the name of a grid in `init`.

# Argument

- `frames::Int`: number of frames to lag by, 1 or larger.

# Example

```julia
SomeRule(;
    someparam=Delay(:grid_a, Month(3))
    otherparam=1.075
)
`` `
"""
struct Lag{K} <: AbstractDelay{K}
    nframes::Int
end

function _to_frame(lag::Lag{K}, data) where K
    frame = max(currentframe(data) - lag.nframes, 1)
    Frame{K}(frame)
end

@inline frame(lag::Lag, data) = max(1, currentframe(data) - lag.nframes)

"""
    Frame <: AbstractDelay

    Frame{K}(frame) 

`Frame` allows using a [`Grid`](@ref) from a specific previous timestep from within 
a rule, using `get`. It should only be used within rule code, not as a parameter.

# Type Parameter

- `K::Symbol`: matching the name of a grid in `init`.

# Argument

- `frame::Int`: the exact frame number to use.
"""
struct Frame{K} <: AbstractDelay{K}
    frame::Int
    Frame{K}(frame::Int) where K = new{K}(frame)
end

ConstructionBase.constructorof(::Frame{K}) where K = Frame{K}

@inline frame(delay::Frame) = delay.frame
@inline frame(delay::Frame, data) = frame(delay)


# Delay utils

const DELAY_IGNORE = Union{Function,SArray,AbstractDict,Number}

@inline function hasdelay(rules::Tuple)
    # Check for Delay as parameter or used in rule code
    length(_getdelays(rules)) > 0 || any(map(needsdelay, rules))
end

needsdelay(rule::Rule) = false

# _setdelays
# Update any Delay anywhere in the rules Tuple.
function _setdelays(rules::Tuple, data)
    delays = _getdelays(rules)
    if length(delays) > 0
        newdelays = map(d -> _to_frame(d, data), delays)
        _setdelays(rules, newdelays)
    else
        rules
    end
end

_getdelays(rules::Tuple) = Flatten.flatten(rules, AbstractDelay, DELAY_IGNORE)
_setdelays(rules::Tuple, delays::Tuple) = 
    Flatten.reconstruct(rules, delays, AbstractDelay, DELAY_IGNORE)

_notstorederror() = 
    throw(ArgumentError("Output does not store frames, which is needed for a Delay. Use ArrayOutput or any GraphicOutput with `store=true` keyword"))
_delaysteperror(delay::Delay{K}, simstep) where K = 
    throw(ArgumentError("Delay $K size $(steps(delay)) is not a multiple of simulations step $simstep"))
