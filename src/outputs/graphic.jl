
"""
    GraphicConfig(; fps=25.0, store=false, kwargs...) =
    GraphicConfig(fps, timestamp, stampframe, store)

Config and variables for graphic outputs.
"""
mutable struct GraphicConfig{FPS,TS}
    fps::FPS
    timestamp::TS
    stampframe::Int
    stoppedframe::Int
    store::Bool
end
GraphicConfig(; fps=25.0, store=false, kwargs...) =
    GraphicConfig(fps, 0.0, 1, 1, store)

fps(gc::GraphicConfig) = gc.fps
timestamp(gc::GraphicConfig) = gc.timestamp
stampframe(gc::GraphicConfig) = gc.stampframe
stoppedframe(gc::GraphicConfig) = gc.stoppedframe
store(gc::GraphicConfig) = gc.store
setfps!(gc::GraphicConfig, x) = gc.fps = x
settimestamp!(o::GraphicConfig, f) = begin
    o.timestamp = time()
    o.stampframe = f
end

setstoppedframe!(gc::GraphicConfig, f) = gc.stoppedframe = f

"""
Outputs that display the simulation frames live.

All `GraphicOutputs` have a [`GraphicConfig`](@ref) object 
and provide a [`showframe`](@ref) method.

See [`REPLOutput`](@ref) for an example.
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
stoppedframe(o::GraphicOutput) = stoppedframe(graphicconfig(o))
store(o::GraphicOutput) = store(graphicconfig(o))
isstored(o::GraphicOutput) = store(o)

setfps!(o::GraphicOutput, x) = setfps!(graphicconfig(o), x)
settimestamp!(o::GraphicOutput, f) = settimestamp!(graphicconfig(o), f)
setstoppedframe!(o::GraphicOutput, f) = setstoppedframe!(graphicconfig(o), f)

# Output interface
# Delay output to maintain the frame rate
delay(o::GraphicOutput, f) =
    sleep(max(0.0, timestamp(o) + (f - stampframe(o))/fps(o) - time()))
isshowable(o::GraphicOutput, f) = true # TODO working max fps. o.timestamp + (t - tlast(o))/o.maxfps < time()

storeframe!(o::GraphicOutput, data::AbstractSimData) = begin
    f = frameindex(o, data)
    if f > length(o)
        _pushgrid!(eltype(o), o)
    end
    storeframe!(eltype(o), o, data, f)
    isshowable(o, currentframe(data)) && showframe(o, data, currentframe(data), currenttime(data))
end

_pushgrid!(::Type{<:NamedTuple}, o::GraphicOutput) =
    push!(o, map(grid -> similar(grid), o[1]))
_pushgrid!(::Type{<:AbstractArray}, o::GraphicOutput) =
    push!(o, similar(o[1]))

# Get frame f from output and call showframe again
#showframe(o::GraphicOutput, f, t) = showframe(o, Ruleset(), f, t)
showframe(o::GraphicOutput, data::SimData, f, t) =
    showframe(o[frameindex(o, f)], o, data, f, t)
