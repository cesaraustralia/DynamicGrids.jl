
"""
All outputs must inherit from Output.

Simulation outputs are decoupled from simulation behaviour and in
many cases can be used interchangeably.
"""
abstract type Output{T} <: AbstractVector{T} end

# Generic ouput constructor. Converts an init array to vector of arrays.
(::Type{F})(init::AbstractMatrix; kwargs...) where F <: Output =
    F(; frames=[deepcopy(init)], kwargs...)
(::Type{F})(init::NamedTuple; kwargs...) where F <: Output =
    F(; frames=[deepcopy(init)], kwargs...)

(::Type{F})(o::T; kwargs...) where F <: Output where T <: Output =
    F(; frames=frames(o), starttime=starttime(o), stoptime=stoptime(o), kwargs...)

# Forward base methods to the frames array
Base.parent(o::Output) = frames(o)
Base.length(o::Output) = length(frames(o))
Base.size(o::Output) = size(frames(o))
Base.firstindex(o::Output) = firstindex(frames(o))
Base.lastindex(o::Output) = lastindex(frames(o))
Base.@propagate_inbounds Base.getindex(o::Output, i) =
    getindex(frames(o), i)
Base.@propagate_inbounds Base.setindex!(o::Output, x, i) = setindex!(frames(o), x, i)
Base.push!(o::Output, x) = push!(frames(o), x)
Base.append!(o::Output, x) = append!(frames(o), x)


"""
Mixin of basic fields for all outputs
"""
@premix @default_kw struct Output{T<:AbstractVector}
    frames::T      | []
    running::Bool  | false
    starttime::Any | 1
    stoptime::Any  | 1
end

# Getters and setters
frames(o::Output) = o.frames
starttime(o::Output) = o.starttime
stoptime(o::Output) = o.stoptime
tspan(o::Output) = (stoptime(o), starttime(o))
isrunning(o::Output) = o.running
setrunning!(o::Output, val) = o.running = val
setstarttime!(output, x) = output.starttime = x
setstoptime!(output, x) = output.stoptime = x

# Placeholder methods for graphic functions that are
# ignored in simple outputs
settimestamp!(o::Output, f) = nothing
fps(o::Output) = nothing
setfps!(o::Output, x) = nothing
showfps(o::Output) = nothing
isasync(o::Output) = false
isstored(o::Output) = true
isshowable(o::Output, f) = false
finalize!(o::Output, args...) = nothing
delay(o::Output, f) = nothing
showgrid(o::Output, args...) = nothing


# Grid strorage and updating
gridindex(o::Output, data::AbstractSimData) = gridindex(o, currentframe(data))
# Every frame is frame 1 if the simulation isn't stored
gridindex(o::Output, f) = isstored(o) ? f : oneunit(f)

zerogrids(init::AbstractArray, nframes) = [zero(init) for f in 1:nframes]
zerogrids(init::NamedTuple, nframes) =
    [map(layer -> zero(layer), init) for f in 1:nframes]


@inline blockdo!(data::SimData, frame::AbstractArray, index, f) =
    return @inbounds frame[index...] = data[index...]

storegrid!(output, data) = storegrid!(output, data, gridindex(output, data))
storegrid!(output, data::SimData, f) = begin
    checkbounds(output, f)
    blockrun!(data, output[f], f)
end
storegrid!(output, multidata::MultiSimData, f) = begin
    checkbounds(output, f)
    for key in keys(multidata)
        # TODO use blocks for MutiSimData?
        # blockrun!(data(multidata)[key], output[f][key], f)
        source = data(multidata)[key]
        target = output[f][key]
        for i in CartesianIndices(output[f][key])
            target[i] = source[i]
        end
    end
end
# Replicated frames
storegrid!(output, data::AbstractVector{<:SimData}, f) = begin
    for j in 1:size(output[1], 2), i in 1:size(output[1], 1)
        replicatesum = zero(eltype(output[1]))
        for d in data
            replicatesum += d[i, j]
        end
        output[f][i, j] = replicatesum / length(data)
    end
end

allocategrids!(o::Output, init, framerange) = begin
    append!(frames(o), [similar(init) for f in framerange])
    o
end

"""
Grids are preallocated and reused.
"""
initgrids!(o::Output, init) = begin
    first(o) .= init
    for f = (firstindex(o) + 1):lastindex(o)
        @inbounds o[f] .= zero(eltype(init))
    end
    o
end
initgrids!(o::Output, init::NamedTuple) = begin
    for key in keys(init)
        first(o)[key] .= init[key]
    end
    for f = (firstindex(o) + 1):lastindex(o)
        for key in keys(init)
            @inbounds o[f][key] .= zero(eltype(init[key]))
        end
    end
    o
end
