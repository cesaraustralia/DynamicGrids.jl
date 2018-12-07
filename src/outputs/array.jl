"""
A simple array output that stores each step of the simulation in an array of arrays.
"""
abstract type AbstractArrayOutput{T} <: AbstractOutput{T} end

@Ok @Frames struct ArrayOutput{} <: AbstractArrayOutput{T} end
ArrayOutput(frames::AbstractVector, tstop) = begin
    o = ArrayOutput{typeof(frames)}(frames, [false])
    allocate!(o, frames[1], 2:tstop)
    o
end
ArrayOutput(frames::AbstractVector) = ArrayOutput(frames::AbstractVector, length(frames))

is_async(o::AbstractArrayOutput) = false

allocate!(o::AbstractArrayOutput, init, tspan) = begin
    append!(o.frames, [similar(init) for i in tspan])
    nothing
end

clear!(output::AbstractArrayOutput) = nothing
