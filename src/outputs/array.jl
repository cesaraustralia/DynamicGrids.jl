"""
    ArrayOutput(init; tspan::Range) 
    ArrayOutput(init, length::Integer)

A simple output that stores each step of the simulation in a vector of arrays.

### Arguments:
- `frames`: Single init array or vector of arrays
- `length`: The length of the output.
"""
@Output mutable struct ArrayOutput{T} <: Output{T} end

ArrayOutput(init, length::Integer; kwargs...) = begin
    frames = [deepcopy(init)]
    append!(frames, zerogrids(init, length-1))
    ArrayOutput(; frames=frames, kwargs...)
end

zerogrids(initgrid::AbstractArray, nframes) = [zero(initgrid) for f in 1:nframes]
zerogrids(initgrids::NamedTuple, nframes) =
    [map(grid -> zero(grid), initgrids) for f in 1:nframes]
