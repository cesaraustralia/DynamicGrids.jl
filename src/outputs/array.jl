abstract type AbstractArrayOutput{T} <: AbstractOutput{T} end

"""
A simple output that stores each step of the simulation in a vector of arrays.

### Arguments:
- `frames`: Single init array or vector of arrays
- `tstop`: The length of the output.
"""
@Output mutable struct ArrayOutput{} <: AbstractArrayOutput{T} end

ArrayOutput(frames::AbstractVector, tstop) = begin
    o = ArrayOutput{typeof(frames)}(frames, false)
    allocateframes!(o, frames[1], 2:tstop)
    o
end
ArrayOutput(frames::AbstractVector) = ArrayOutput(frames::AbstractVector, length(frames))
