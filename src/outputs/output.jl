
"""
All outputs must inherit from AbstractOutput.

Simulation outputs are decoupled from simulation behaviour and in
many cases can be used interchangeably.
"""
abstract type AbstractOutput{T} <: AbstractVector{T} end

"Generic ouput constructor. Converts init array to vector of frames."
(::Type{F})(init::T; kwargs...) where F <: AbstractOutput where T <: AbstractMatrix =
    F(; frames=T[deepcopy(init)], kwargs...)

(::Type{F})(o::T; kwargs...) where F <: AbstractOutput where T <: AbstractOutput =
    F(; frames=frames(o), starttime=starttime(o), stoptime=stoptime(o), kwargs...)

# Forward base methods to the frames array
Base.parent(o::AbstractOutput) = frames(o)
Base.length(o::AbstractOutput) = length(frames(o))
Base.size(o::AbstractOutput) = size(frames(o))
Base.firstindex(o::AbstractOutput) = firstindex(frames(o))
Base.lastindex(o::AbstractOutput) = lastindex(frames(o))
Base.@propagate_inbounds Base.getindex(o::AbstractOutput, i) = 
    getindex(frames(o), i)
Base.@propagate_inbounds Base.setindex!(o::AbstractOutput, x, i) = setindex!(frames(o), x, i)
Base.push!(o::AbstractOutput, x) = push!(frames(o), x)
Base.append!(o::AbstractOutput, x) = append!(frames(o), x)


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
frames(o::AbstractOutput) = o.frames
starttime(o::AbstractOutput) = o.starttime
stoptime(o::AbstractOutput) = o.stoptime
tspan(o::AbstractOutput) = (stoptime(o), starttime(o))
isrunning(o::AbstractOutput) = o.running
setrunning!(o::AbstractOutput, val) = o.running = val
setstarttime!(output, x) = output.starttime = x
setstoptime!(output, x) = output.stoptime = x

# Placeholder methods for graphic functions that are
# ignored in simple outputs
settimestamp!(o::AbstractOutput, f) = nothing
fps(o::AbstractOutput) = nothing
setfps!(o::AbstractOutput, x) = nothing
showfps(o::AbstractOutput) = nothing
isasync(o::AbstractOutput) = false
isstored(o::AbstractOutput) = true
isshowable(o::AbstractOutput, f) = false
finalize!(o::AbstractOutput, args...) = nothing
delay(o::AbstractOutput, f) = nothing
showframe(o::AbstractOutput, args...) = nothing


# Frame strorage and updating
frameindex(o::AbstractOutput, data::AbstractSimData) = frameindex(o, currentframe(data))
frameindex(o::AbstractOutput, f) = isstored(o) ? f : oneunit(f)

@inline blockdo!(data, output::AbstractOutput, index, f) =
    return @inbounds output[f][index...] = data[index...]

storeframe!(output, data) = storeframe!(output, data, frameindex(output, data))
storeframe!(output, data::AbstractArray, f) = begin
    checkbounds(output, f)
    blockrun!(data, output, f)
end
# Replicated frames
storeframe!(output, data::AbstractVector{<:SimData}, f) = begin
    for j in 1:size(output[1], 2), i in 1:size(output[1], 1)
        replicatesum = zero(eltype(output[1]))
        for d in data
            replicatesum += d[i, j]
        end
        output[f][i, j] = replicatesum / length(data)
    end
end

allocateframes!(o::AbstractOutput, init, framerange) = begin
    append!(frames(o), [similar(init) for f in framerange])
    o
end

"""
Frames are preallocated and reused.
"""
initframes!(o::AbstractOutput, init) = begin
    first(o) .= init
    for f = (firstindex(o) + 1):lastindex(o)
        @inbounds o[f] .= zero(eltype(init))
    end
    o
end
