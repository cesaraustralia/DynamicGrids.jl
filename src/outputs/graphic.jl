
"""
    GraphicConfig

    GraphicConfig(; fps=25.0, store=false)

Config and variables for graphic outputs.
"""
mutable struct GraphicConfig{FPS,TS}
    fps::FPS
    store::Bool
    timestamp::TS
    stampframe::Int
    stoppedframe::Int
end
GraphicConfig(; fps=25.0, store=false, kw...) = GraphicConfig(fps, store, 0.0, 1, 1)

fps(gc::GraphicConfig) = gc.fps
store(gc::GraphicConfig) = gc.store
timestamp(gc::GraphicConfig) = gc.timestamp
stampframe(gc::GraphicConfig) = gc.stampframe
stoppedframe(gc::GraphicConfig) = gc.stoppedframe
setfps!(gc::GraphicConfig, x) = gc.fps = x
function settimestamp!(o::GraphicConfig, frame::Int)
    o.timestamp = time()
    o.stampframe = frame
end

setstoppedframe!(gc::GraphicConfig, frame::Int) = gc.stoppedframe = frame

"""
    GraphicOutput <: Output

Abstract supertype for [`Output`](@ref)s that display the simulation frames.

All `GraphicOutputs` must have a [`GraphicConfig`](@ref) object
and define a [`showframe`](@ref) method.

See [`REPLOutput`](@ref) for an example.

## Keywords: 

The default constructor will generate these objects from other keyword arguments 
and pass them to the object constructor, which must accept the following:

- `frames`: a `Vector` of simulation frames (`NamedTuple` or `Array`). 
- `running`: A `Bool`.
- `extent` an [`Extent`](@ref) object.
- `graphicconfig` a [`GraphicConfig`](@ref)object.

"""
abstract type GraphicOutput{T,F} <: Output{T,F} end

# Generic ImageOutput constructor. Converts an init array to vector of arrays.
function (::Type{T})(
    init::Union{NamedTuple,AbstractMatrix}; 
    extent=nothing, graphicconfig=nothing, kw...
) where T <: GraphicOutput
    extent = extent isa Nothing ? Extent(; init=init, kw...) : extent
    graphicconfig = graphicconfig isa Nothing ? GraphicConfig(; kw...) : graphicconfig
    T(; frames=[deepcopy(init)], running=false,
      extent=extent, graphicconfig=graphicconfig, kw...)
end

graphicconfig(o::Output) = GraphicConfig()
graphicconfig(o::GraphicOutput) = o.graphicconfig

# Forwarded getters and setters
fps(o::GraphicOutput) = fps(graphicconfig(o))
timestamp(o::GraphicOutput) = timestamp(graphicconfig(o))
stampframe(o::GraphicOutput) = stampframe(graphicconfig(o))
stoppedframe(o::GraphicOutput) = stoppedframe(graphicconfig(o))
isstored(o::GraphicOutput) = store(o)
store(o::GraphicOutput) = store(graphicconfig(o))

setfps!(o::GraphicOutput, x) = setfps!(graphicconfig(o), x)
settimestamp!(o::GraphicOutput, f) = settimestamp!(graphicconfig(o), f)
setstoppedframe!(o::GraphicOutput, f) = setstoppedframe!(graphicconfig(o), f)

# Delay output to maintain the frame rate
maybesleep(o::GraphicOutput, f) =
    sleep(max(0.0, timestamp(o) + (f - stampframe(o))/fps(o) - time()))
isshowable(o::GraphicOutput, f) = true

function storeframe!(o::GraphicOutput, data)
    f = frameindex(o, data)
    if f > length(o)
        _pushgrid!(eltype(o), o)
    end
    if isstored(o)
        _storeframe!(eltype(o), o, data)
    end
    if isshowable(o, currentframe(data)) 
        showframe(o, data)
    end
    return nothing
end

_pushgrid!(::Type{<:NamedTuple}, o) = push!(o, map(grid -> similar(grid), o[1]))
_pushgrid!(::Type{<:AbstractArray}, o) = push!(o, similar(o[1]))

showframe(o::GraphicOutput, data) = showframe(o, proc(data), data)
showframe(o::GraphicOutput, ::Processor, data) = showframe(map(gridview, grids(data)), o, data)
# Handle NamedTuple for outputs that only accept AbstractArray
showframe(frame::NamedTuple, o::GraphicOutput, data) = showframe(first(frame), o, data)

function initialise!(o::GraphicOutput, data) 
    initalisegraphics(o, data)
end
function finalise!(o::GraphicOutput, data) 
    _storeframe!(eltype(o), o, data)
    finalisegraphics(o, data)
end

initalisegraphics(o::GraphicOutput, data) = nothing
finalisegraphics(o::GraphicOutput, data) = showframe(o, data)
