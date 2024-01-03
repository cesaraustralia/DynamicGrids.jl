"""
    ArrayOutput <: Output

    ArrayOutput(init; tspan::AbstractRange, [aux, mask, padval]) 

A simple output that stores each step of the simulation in a vector of arrays.

# Arguments

- `init`: initialisation `AbstractArrayArray` or `NamedTuple` of `AbstractArrayArray`.

# Keywords (passed to [`Extent`](@ref))

$EXTENT_KEYWORDS

An `Extent` object can be also passed to the `extent` keyword, and other keywords will be ignored.
"""
mutable struct ArrayOutput{T,F<:AbstractVector{T},E} <: Output{T,F} 
    frames::F
    running::Bool
    extent::E
end
function ArrayOutput(; frames, running, extent, kw...)
    append!(frames, _zerogrids(init(extent), length(tspan(extent))-1))
    ArrayOutput(frames, running, extent)
end

"""
    ResultOutput <: Output

    ResultOutput(init; tspan::AbstractRange, kw...) 

A simple output that only stores the final result, not intermediate frames.

# Arguments

- `init`: initialisation `Array` or `NamedTuple` of `Array`

# Keywords (passed to [`Extent`](@ref))

$EXTENT_KEYWORDS

An `Extent` object can be also passed to the `extent` keyword, and other keywords will be ignored.
"""
mutable struct ResultOutput{T,F<:AbstractVector{T},E} <: Output{T,F} 
    frames::F
    running::Bool
    extent::E
end
ResultOutput(; frames, running, extent, kw...) = ResultOutput(frames, running, extent)

isstored(o::ResultOutput) = false
storeframe!(o::ResultOutput, data::AbstractSimData) = nothing

function finalise!(o::ResultOutput, data::AbstractSimData) 
    # Only store after the last frame
    _storeframe!(o, eltype(o), data)
end
