
# Abstract output type and generic methods
"""
All outputs must inherit from AbstractOutput.

Simulation outputs are decoupled from simulation behaviour and in
many cases can be used interchangeably.
"""
abstract type AbstractOutput{T} <: AbstractVector{T} end

"""
Mixin of basic fields for all outputs
"""
@premix struct Output{T<:AbstractVector}
    frames::T
    running::Bool
end


"Generic ouput constructor. Converts init array to vector of frames."
(::Type{F})(init::T, args...; kwargs...) where F <: AbstractOutput where T <: AbstractMatrix =
    F(T[deepcopy(init)], args...; kwargs...)


# Forward base methods to the frames array
Base.parent(o::AbstractOutput) = frames(o)
Base.length(o::AbstractOutput) = length(frames(o))
Base.size(o::AbstractOutput) = size(frames(o))
Base.firstindex(o::AbstractOutput) = firstindex(frames(o))
Base.lastindex(o::AbstractOutput) = lastindex(frames(o))
Base.@propagate_inbounds Base.getindex(o::AbstractOutput, i) = getindex(frames(o), i)
Base.@propagate_inbounds Base.setindex!(o::AbstractOutput, x, i) = setindex!(frames(o), x, i)
Base.push!(o::AbstractOutput, x) = push!(frames(o), x)
Base.append!(o::AbstractOutput, x) = append!(frames(o), x)


"""
Outputs that display the simulation frames live.
"""
abstract type AbstractGraphicOutput{T} <: AbstractOutput{T} end

"""
Mixin for all graphic outputs
"""
@premix struct Graphic{F,TS,TM}
    fps::F
    showfps::F
    timestamp::TS
    tref::TM
    tlast::TM
    store::Bool
end


"""
Graphic outputs that display RGB24 images.
"""
abstract type AbstractImageOutput{T} <: AbstractGraphicOutput{T} end

"""
Mixin for outputs that output images and can use an image processor.
"""
@premix struct Image{IP,Mi,Ma}
    processor::IP
    minval::Mi
    maxval::Ma
end

processor(o::AbstractImageOutput) = o.processor
minval(o::AbstractImageOutput) = o.minval
maxval(o::AbstractImageOutput) = o.maxval


# Getters and setters
frames(o::AbstractOutput) = o.frames

fps(o::AbstractGraphicOutput) = o.fps
fps(o::AbstractOutput) = nothing
setfps!(o::AbstractGraphicOutput, x) = o.fps = x
setfps!(o::AbstractOutput, x) = nothing

showfps(o::AbstractGraphicOutput) = o.showfps
showfps(o::AbstractOutput) = nothing

gettlast(o::AbstractGraphicOutput) = o.tlast
gettlast(o::AbstractOutput) = lastindex(o)

timestamp(o::AbstractGraphicOutput) = o.timestamp

settimestamp!(o::AbstractGraphicOutput, t) = begin
    o.timestamp = time()
    o.tref = t
end
settimestamp!(o::AbstractOutput, t) = nothing

# Bool getters and setters
isasync(o::AbstractOutput) = false

isrunning(o::AbstractOutput) = o.running
setrunning!(o::AbstractOutput, val) = o.running = val

isstored(o::AbstractOutput) = true
isstored(o::AbstractGraphicOutput) = o.store

isshowable(o::AbstractOutput, t) = false
isshowable(o::AbstractGraphicOutput, t) = true # TODO working max fps. o.timestamp + (t - o.tref)/o.maxfps < time()


# Setup and close output
finalize!(o::AbstractOutput, args...) = nothing

# Delay output to maintain the frame rate
delay(o::AbstractGraphicOutput, t) = sleep(max(0.0, timestamp(o) + (t - o.tref)/fps(o) - time()))
delay(o::AbstractOutput, t) = nothing



# Frame handling
curframe(o::AbstractOutput, t) = isstored(o) ? t : oneunit(t)

storeframe!(o::AbstractGraphicOutput, data, t) = begin
    if o.store
        push!(o, similar(o[1]))
        o[end] .= zero(eltype(o[1]))
        updateframe!(o, data, t)
    else
        o[1] .= zero(eltype(o[1]))
        updateframe!(o, data, 1)
    end
    o.tlast = t
    isshowable(o, t) && showframe(o, data, t)
end
storeframe!(o::AbstractOutput, data, t) = updateframe!(o, data, t)

updateframe!(output, data::AbstractArray, t) = blockrun!(data, output, t)
updateframe!(output, data::AbstractVector{<:SimData}, t) = begin
    for j in 1:size(output[1], 2), i in 1:size(output[1], 1)
        replicatesum = zero(eltype(output[1]))
        for d in data
            replicatesum += d[i, j]
        end
        output[t][i, j] = replicatesum / length(data)
    end
end

@inline blockdo!(data, output::AbstractOutput, index, t) =
    return @inbounds output[t][index...] = data[index...]

allocateframes!(o::AbstractOutput, init, tspan) = begin
    append!(frames(o), [similar(init) for i in tspan])
    nothing
end

"""
Frames are deleted and reallocated during the simulation,
as performance is often display limited, and this allows runs of any length.
"""
initframes!(o::AbstractGraphicOutput, init) = begin
    deleteat!(frames(o), 1:length(o))
    push!(frames(o), deepcopy(init))
end
"""
Frames are preallocated and reused.
"""
initframes!(o::AbstractOutput, init) = begin
    o[1] .= init
    for i = 2:lastindex(o)
        @inbounds o[i] .= zero(eltype(init))
    end
end

"""
    showframe(output::AbstractOutput, [t])
Show the last frame of the output, or the frame at time t.
"""
showframe(o::AbstractOutput, args...) = nothing

showframe(o::AbstractGraphicOutput, data::AbstractSimData) = 
    showframe(o, data, lastindex(o))
showframe(o::AbstractGraphicOutput, data::AbstractSimData, t) = 
    showframe(o[curframe(o, t)], o, data, t)
showframe(o::AbstractGraphicOutput, data::AbstractVector{<:AbstractSimData}, t) = 
    showframe(o, data[1], t)
showframe(frame, o::AbstractGraphicOutput, data::AbstractSimData, t) = 
    showframe(frame, o, t)

showframe(frame, o::AbstractImageOutput, data::AbstractSimData, t) = 
    showframe(frame, o, ruleset(data), t)
showframe(frame, o::AbstractImageOutput, ruleset::AbstractRuleset, t) =
    showframe(frametoimage(o, ruleset, frame, t), o, t)

# Manual showframe without data/ruleset
showframe(frame, o::AbstractImageOutput) = 
    showframe(frame, o::AbstractImageOutput, minimum(frame), maximum(frame))
showframe(frame, o::AbstractImageOutput, min::Number, max::Number) =
    showframe(frame, o, min, max, 1)
showframe(frame, o::AbstractImageOutput, min::Number, max::Number, t::Integer) =
    showframe(frametoimage(o, normaliseframe(frame, min, max), t), o::AbstractOutput, t)


struct HasMinMax end
struct NoMinMax end

hasminmax(output::T) where T = (:minval in fieldnames(T)) ? HasMinMax() : NoMinMax()

normaliseframe(output::AbstractOutput, a::AbstractArray) = 
    normaliseframe(hasminmax(output), output, a)
normaliseframe(::HasMinMax, output, a::AbstractArray) =
    normaliseframe(a, minval(output), maxval(output))
normaliseframe(a::AbstractArray, minval::Number, maxval::Number) = normalise.(a, minval, maxval)
normaliseframe(a::AbstractArray, minval, maxval) = a
normaliseframe(::NoMinMax, output, a::AbstractArray) = a

normalise(x::Number, minval::Number, maxval::Number) = min((x - minval) / (maxval - minval), oneunit(eltype(x)))
