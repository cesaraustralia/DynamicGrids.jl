"""
A simple array output that stores each step of the simulation in an array of arrays.

Accepts an init matrix and tstop time, or any vector of matrices.
"""
@Ok @Frames struct ArrayOutput{} <: AbstractOutput{T} end

ArrayOutput(frames::AbstractVector, tstop) = begin
    o = ArrayOutput{typeof(frames)}(frames, [false])
    allocate_frames!(o, frames[1], 2:tstop)
    o
end
ArrayOutput(frames::AbstractVector) = ArrayOutput(frames::AbstractVector, length(frames))
