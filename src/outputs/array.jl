"""
A simple array output that stores each step of the simulation in an array of arrays.
"""
@Frames struct ArrayOutput{} <: AbstractOutput{T} end
ArrayOutput(frames::AbstractVector) = ArrayOutput{typeof(frames)}(frames)
