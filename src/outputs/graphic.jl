
mutable struct GraphicConfig{FPS,TS,SF}
    fps::FPS
    timestamp::TS
    stampframe::SF
    store::Bool
end
GraphicConfig(; fps=25.0, store=false, kwargs...) =
    GraphicConfig(fps, 0.0, 1, store)


fps(gc::GraphicConfig) = gc.fps
timestamp(gc::GraphicConfig) = gc.timestamp
stampframe(gc::GraphicConfig) = gc.stampframe
store(gc::GraphicConfig) = gc.store
setfps!(gc::GraphicConfig, x) = gc.fps = x
settimestamp!(o::GraphicConfig, f) = begin
    o.timestamp = time()
    o.stampframe = f
end

"""
Outputs that display the simulation frames live.
"""
abstract type GraphicOutput{T} <: Output{T} end

# Generic ImageOutput constructor. Converts an init array to vector of arrays.
(::Type{T})(init::Union{NamedTuple,AbstractMatrix}; extent=nothing, graphicconfig=nothing, 
            kwargs...) where T <: GraphicOutput = begin
    extent = extent isa Nothing ? Extent(; init=init, kwargs...) : extent
    graphicconfig = graphicconfig isa Nothing ? GraphicConfig(; kwargs...) : graphicconfig
    T(; frames=[deepcopy(init)], running=false, 
      extent=extent, graphicconfig=graphicconfig, kwargs...)
end

graphicconfig(o::Output) = GraphicConfig()
graphicconfig(o::GraphicOutput) = o.graphicconfig

# Field getters and setters
fps(o::GraphicOutput) = fps(graphicconfig(o))
timestamp(o::GraphicOutput) = timestamp(graphicconfig(o))
stampframe(o::GraphicOutput) = stampframe(graphicconfig(o))
store(o::GraphicOutput) = store(graphicconfig(o))
isstored(o::GraphicOutput) = store(o)

setfps!(o::Output, x) = nothing
setfps!(o::GraphicOutput, x) = setfps!(graphicconfig(o), x)

settimestamp!(o::Output, f) = nothing
settimestamp!(o::GraphicOutput, f) = settimestamp!(graphicconfig(o), f)

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
