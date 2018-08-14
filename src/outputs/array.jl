"""
A simple array output that stores each step of the simulation in an array of arrays.
"""
@Frames struct ArrayOutput{} <: AbstractOutput{T} end
ArrayOutput(frames::AbstractVector) = ArrayOutput{typeof(frames)}(frames)

is_ok(o::ArrayOutput) = true
set_ok(o::ArrayOutput, val) = nothing
is_running(o::ArrayOutput) = false
set_running(o::ArrayOutput, val) = nothing
is_async(o::ArrayOutput) = false
