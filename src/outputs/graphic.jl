"""
Outputs that display the simulation frames live.
"""
abstract type GraphicOutput{T} <: Output{T} end

(::Type{F})(o::T; kwargs...) where F <: GraphicOutput where T <: GraphicOutput = F(; 
    frames=frames(o), 
    starttime=starttime(o), 
    stoptime=stoptime(o),
    fps=fps(o), 
    showfps=showfps(o), 
    timestamp=timestamp(o), 
    stampframe=stampframe(o), 
    store=store(o),
    kwargs...
)

"""
Mixin for graphic output fields
"""
@premix @default_kw struct Graphic{FPS,SFPS,TS,SF}
    fps::FPS       | 25.0
    showfps::SFPS  | 25.0
    timestamp::TS  | 0.0
    stampframe::SF | 1
    store::Bool    | false
end

# Field getters and setters
fps(o::Output) = nothing
fps(o::GraphicOutput) = o.fps
setfps!(o::Output, x) = nothing
setfps!(o::GraphicOutput, x) = o.fps = x
showfps(o::Output) = nothing
showfps(o::GraphicOutput) = o.showfps
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
