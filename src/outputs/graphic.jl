"""
Outputs that display the simulation frames live.
"""
abstract type GraphicOutput{T} <: Output{T} end

(::Type{F})(o::T; kwargs...) where F <: GraphicOutput where T <: GraphicOutput =
    F(; frames=frames(o), starttime=starttime(o), endtime=endtime(o),
      fps=fps(o), showfps=showfps(o), timestamp=timestamp(o), stampframe=stampframe(o), store=store(o),
      kwargs...)

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
fps(o::GraphicOutput) = o.fps
setfps!(o::GraphicOutput, x) = o.fps = x
showfps(o::GraphicOutput) = o.showfps
timestamp(o::GraphicOutput) = o.timestamp
stampframe(o::GraphicOutput) = o.stampframe
isstored(o::GraphicOutput) = o.store

settimestamp!(o::GraphicOutput, f) = begin
    o.timestamp = time()
    o.stampframe = f
end

# Output interface
# Delay output to maintain the frame rate
delay(o::GraphicOutput, f) =
    sleep(max(0.0, timestamp(o) + (f - stampframe(o))/fps(o) - time()))
isshowable(o::GraphicOutput, f) = true # TODO working max fps. o.timestamp + (t - tlast(o))/o.maxfps < time()


"""
Grids are deleted and reallocated during the simulation,
which this allows runs of any length.
"""
initframes!(o::GraphicOutput, init) = begin
    deleteat!(frames(o), 1:length(o))
    push!(frames(o), deepcopy(init))
end
initframes!(o::GraphicOutput, init::NamedTuple) = begin
    deleteat!(frames(o), 1:length(o))
    push!(frames(o), deepcopy(init))
end


storegrid!(o::GraphicOutput, data) = begin
    f = currentframe(data)
    if isstored(o)
        push!(o, fill!(similar(o[1]), zero(eltype(o[1]))))
        storegrid!(o, data, f)
    else
        fill!(o[1], zero(eltype(o[1])))
        storegrid!(o, data, 1)
    end
    isshowable(o, f) && showgrid(o, data, f, currenttime(data))
end
storegrid!(o::GraphicOutput, data::AbstractSimData) =
    storegrid!(eltype(o), o, data)
storegrid!(::Type{<:NamedTuple}, o::GraphicOutput, data::AbstractSimData) = begin
    f = currentframe(data) 
    if isstored(o)
        push!(o, map(grid -> fill!(similar(grid), zero(eltype(grid))), o[1]))
        storegrid!(o, data, f)
    else
        map(grid -> fill!(grid, zero(eltype(grid))), o[1])
        storegrid!(o, data, 1)
    end
    isshowable(o, f) && showgrid(o, data, f, currenttime(data))
end
storegrid!(::Type{<:AbstractArray}, o::GraphicOutput, data::AbstractSimData) = begin
    f = currentframe(data) 
    if isstored(o)
        push!(o, fill!(similar(o[1]), zero(eltype(o[1]))))
        storegrid!(o, data, f)
    else
        fill!(o[1], zero(eltype(o[1])))
        storegrid!(o, data, 1)
    end
    isshowable(o, f) && showgrid(o, data, f, currenttime(data))
end


# Show frame given only the output
showgrid(o::GraphicOutput, f=lastindex(o), t=stoptime(o)) =
    showgrid(o[f], o, f, t)
# Get frame f from output and call showgrid again
showgrid(o::GraphicOutput, data::AbstractSimData, f, t) =
    showgrid(o[frameindex(o, f)], o, data, f, t)
# Handle a vector of SimData from replicate sims
showgrid(o::GraphicOutput, data::AbstractVector{<:AbstractSimData}, f, t) =
    showgrid(o, data[1], f, t)
# Get frame swap SimData for Ruleset and call showgrid again
# This allows passing in the Ruleset when you don't have SimData
showgrid(frame, o::GraphicOutput, data::AbstractSimData, f, t) =
    showgrid(frame, o, ruleset(data), f, t)
# Default behaviour: pass the frame to an output without modifications for Ruleset/Simdata
showgrid(frame, o::GraphicOutput, ruleset::AbstractRuleset, f, t) =
    showgrid(frame, o, f, t)

# For interactive use
# Show frame given data object
showgrid(o::GraphicOutput, data::Union{AbstractSimData,Ruleset}) =
    showgrid(o, data, lastindex(o), stoptime(o))
