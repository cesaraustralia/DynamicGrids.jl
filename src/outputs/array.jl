abstract type AbstractArrayOutput{T} <: AbstractOutput{T} end

"""
A simple output that stores each step of the simulation in a vector of arrays.

### Arguments:
- `frames`: Single init array or vector of arrays
- `length`: The length of the output.
"""
@Output mutable struct ArrayOutput{} <: AbstractArrayOutput{T} end

ArrayOutput(init::AbstractMatrix, length; kwargs...) = begin
    frames = [copy(init)]
    append!(frames, [zero(init) for f in 2:length])
    ArrayOutput(; frames=frames, kwargs...)
end
