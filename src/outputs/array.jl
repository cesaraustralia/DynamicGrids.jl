"""
    ArrayOutput(init; tspan::AbstractRange) 

A simple output that stores each step of the simulation in a vector of arrays.

## Arguments:
- `init`: initialisation `Array` or `NamedTuple` of `Array`

## Keyword Argument:
- `tspan`: `AbstractRange` timespan for the simulation
"""
@Output mutable struct ArrayOutput{T} <: Output{T} end

ArrayOutput(init; mask=nothing, tspan, kwargs...) = begin
    frames = zerogrids(init, length(tspan))
    frames[1] = deepcopy(init)
    running = false
    if length(kwargs) > 1
        @warn "additional keyword arguments not use: $kwargs"
    end
    ArrayOutput(frames, init, mask, running, tspan)
end

zerogrids(initgrid::AbstractArray, nframes) = 
    [zero(initgrid) for f in 1:nframes]
zerogrids(initgrids::NamedTuple, nframes) =
    [map(grid -> zero(grid), initgrids) for f in 1:nframes]
