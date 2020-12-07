
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
GraphicConfig(; fps=25.0, store=false, kwargs...) = GraphicConfig(fps, 0.0, 1, 1, store)

fps(gc::GraphicConfig) = gc.fps
timestamp(gc::GraphicConfig) = gc.timestamp
stampframe(gc::GraphicConfig) = gc.stampframe
stoppedframe(gc::GraphicConfig) = gc.stoppedframe
store(gc::GraphicConfig) = gc.store
setfps!(gc::GraphicConfig, x) = gc.fps = x
function settimestamp!(o::GraphicConfig, frame::Int)
    o.timestamp = time()
    o.stampframe = frame
end

setstoppedframe!(gc::GraphicConfig, frame::Int) = gc.stoppedframe = frame

"""
Outputs that display the simulation frames live.

All `GraphicOutputs` have a [`GraphicConfig`](@ref) object
and provide a [`showframe`](@ref) method.

## Interface Methods

- `extent(output) => Extent`
- `graphicconfig(output) => GraphicConfig`
- `isasync(output) => Bool`: does the output need to run asynchronously, 
  in a separate thread.
- `showframe(grid::Union{Array,NamedTuple}, o::ThisOutput, data::SimData)` :
  in which the output generally show the frame graphically in some way.

See [`REPLOutput`](@ref) for an example.

## Constructor Keyword Arguments: 

The default constructor will generate these objects from keyword arguments and pass 
them to the object constructor, which must accept the following

- `frames`: a Vector of simulation frames (`NamedTuple` or `Array`). 
- `running`: A Bool.
- `extent` an [`Extent`](@ref) object.
- `graphicconfig` a [`GraphicConfig`](@ref)object.

"""
abstract type GraphicOutput{T,F} <: Output{T,F} end

# Generic ImageOutput constructor. Converts an init array to vector of arrays.
function (::Type{T})(
    init::Union{NamedTuple,AbstractMatrix}; 
    extent=nothing, graphicconfig=nothing, kwargs...
) where T <: GraphicOutput
    extent = extent isa Nothing ? Extent(; init=init, kwargs...) : extent
    graphicconfig = graphicconfig isa Nothing ? GraphicConfig(; kwargs...) : graphicconfig
    T(; frames=[deepcopy(init)], running=false,
      extent=extent, graphicconfig=graphicconfig, kwargs...)
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
delay(o::GraphicOutput, f::Int) =
    sleep(max(0.0, timestamp(o) + (f - stampframe(o))/fps(o) - time()))
isshowable(o::GraphicOutput, f) = true

function storeframe!(o::GraphicOutput, data::AbstractSimData)
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

function showframe(o::GraphicOutput, data::AbstractSimData)
    # Take a view over each grid, as it may be padded
    frame = map(grids(data)) do grid
        view(grid, Base.OneTo.(gridsize(grid))...) 
    end
    showframe(frame, o, data)
end
showframe(frame::NamedTuple, o::GraphicOutput, data::AbstractSimData) =
    showframe(first(frame), o, data)
@noinline showframe(frame::AbstractArray, o::GraphicOutput, data::AbstractSimData) =
    error("showframe not defined for $(nameof(typeof(o)))")

function initialise!(output::GraphicOutput, data::AbstractSimData) 
    initalisegraphics(o, data)
end
function finalise!(output::GraphicOutput, data::AbstractSimData) 
    _storeframe!(eltype(output), output, data)
    finalisegraphics(o, data)
end

initalisegraphics(o::GraphicOutput, data::AbstractSimData) = nothing
finalisegraphics(o::GraphicOutput, data::AbstractSimData) = showframe(o, data)
