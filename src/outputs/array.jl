"""
    ArrayOutput(init; tspan::AbstractRange) 

A simple output that stores each step of the simulation in a vector of arrays.

## Arguments:
- `init`: initialisation `Array` or `NamedTuple` of `Array`

## Keyword Argument:
- `tspan`: `AbstractRange` timespan for the simulation
"""
mutable struct ArrayOutput{T,F<:AbstractVector{T},E} <: Output{T} 
    frames::F
    running::Bool
    extent::E
end

ArrayOutput(; frames, running, extent, kwargs...) = begin
    append!(frames, zerogrids(init(extent), length(tspan(extent))-1))
    ArrayOutput(frames, running, extent)
end
