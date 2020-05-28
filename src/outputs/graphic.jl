"""
Outputs that display the simulation frames live.
"""
abstract type GraphicOutput{T} <: Output{T} end

"""
Mixin for graphic output fields
"""
@premix struct Graphic{FPS,TS,SF,S}
    fps::FPS
    timestamp::TS
    stampframe::SF
    store::S
end

# Generic GraphicOutput constructor. Converts an init array to vector of arrays.
(::Type{T})(init::Union{NamedTuple,AbstractMatrix}; mask=nothing, fps=25.0, store=false, kwargs...
           ) where T <: GraphicOutput =
    T(; frames=[deepcopy(init)], init=init, mask=mask, running=false, fps=fps, timestamp=0.0, 
      stampframe=1, store=store, kwargs...)

# Field getters and setters
fps(o::Output) = nothing
fps(o::GraphicOutput) = o.fps
setfps!(o::Output, x) = nothing
setfps!(o::GraphicOutput, x) = o.fps = x
timestamp(o::GraphicOutput) = o.timestamp
stampframe(o::GraphicOutput) = o.stampframe
store(o::GraphicOutput) = o.store
isstored(o::GraphicOutput) = store(o)

settimestamp!(o::Output, f) = nothing
settimestamp!(o::GraphicOutput, f) = begin
    o.timestamp = time()
    o.stampframe = f
end

# Output interface
# Delay output to maintain the frame rate
delay(o::GraphicOutput, f) =
    sleep(max(0.0, timestamp(o) + (f - stampframe(o))/fps(o) - time()))
isshowable(o::GraphicOutput, f) = true # TODO working max fps. o.timestamp + (t - tlast(o))/o.maxfps < time()

storegrid!(o::GraphicOutput, data::AbstractSimData) = begin
    f = gridindex(o, data)
    if isstored(o)
        _pushgrid!(eltype(o), o)
    end
    storegrid!(eltype(o), o, data, f)
    isshowable(o, currentframe(data)) && showgrid(o, data, currentframe(data), currenttime(data))
end

_pushgrid!(::Type{<:NamedTuple}, o::GraphicOutput) =
    push!(o, map(grid -> similar(grid), o[1]))
_pushgrid!(::Type{<:AbstractArray}, o::GraphicOutput) =
    push!(o, similar(o[1]))

# Get frame f from output and call showgrid again
showgrid(o::GraphicOutput, data::AbstractSimData, f, t) =
    showgrid(o[gridindex(o, f)], o, data, f, t)
