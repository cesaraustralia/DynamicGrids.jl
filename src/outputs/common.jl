
# Mixins

@premix struct Output{T<:AbstractVector}
    frames::T
    running::Bool
end

"""
Mixin for all outputs that display frames live.
"""
@premix struct Graphic{F,TS,TM}
    fps::F
    maxfps::F
    timestamp::TS
    tref::TM
    tlast::TM
    store::Bool
end

"""
Mixin for outputs that output real images and can use an image processor.
"""
@premix struct ImageProc{IP}
    processor::IP
end


# Abstract output type and generic methods
"""
All outputs must inherit from AbstractOutput.

Simulation outputs are decoupled from simulation behaviour and in
many cases can be used interchangeably.
"""
abstract type AbstractOutput{T} <: AbstractVector{T} end

"Generic ouput constructor. Converts init array to vector of frames."
(::Type{F})(init::T, args...; kwargs...) where F <: AbstractOutput where T <: AbstractMatrix =
    F(T[deepcopy(init)], args...; kwargs...)

abstract type AbstractGraphicOutput{T} <: AbstractOutput{T} end



" A generic Null output that does nothing "
@Output struct NullOutput{} <: AbstractOutput{T} end

NullOutput(args...) = NullOutput{typeof([])}([])


# Forward base methods to the frames array
Base.length(o::AbstractOutput) = length(frames(o))
Base.size(o::AbstractOutput) = size(frames(o))
Base.firstindex(o::AbstractOutput) = firstindex(frames(o))
Base.lastindex(o::AbstractOutput) = lastindex(frames(o))
Base.@propagate_inbounds Base.getindex(o::AbstractOutput, i) = getindex(frames(o), i)
Base.@propagate_inbounds Base.setindex!(o::AbstractOutput, x, i) = setindex!(frames(o), x, i)
Base.push!(o::AbstractOutput, x) = push!(frames(o), x)
Base.append!(o::AbstractOutput, x) = append!(frames(o), x)

frames(o::AbstractOutput) = o.frames
timestamp(o::AbstractGraphicOutput) = o.timestamp

isasync(o::AbstractOutput) = false

# Bool getters and setters
isasync(o::AbstractOutput) = false

isstored(o::AbstractOutput) = true
isstored(o::AbstractGraphicOutput) = o.store

isshowable(o::AbstractOutput, t) = false
isshowable(o::AbstractGraphicOutput, t) = true # TODO working max fps. o.timestamp + (t - o.tref)/o.maxfps < time()

isrunning(o::AbstractOutput) = o.running

setrunning!(o::AbstractOutput, val) = o.running = val

# Getters and setters
gettlast(o::AbstractGraphicOutput) = o.tlast
gettlast(o::AbstractOutput) = lastindex(o)

getfps(o::AbstractGraphicOutput) = o.fps
getfps(o::AbstractOutput) = nothing

setfps!(o::AbstractGraphicOutput, x) = o.fps = x
setfps!(o::AbstractOutput, x) = nothing

settimestamp!(o::AbstractGraphicOutput, t) = begin
    o.timestamp = time()
    o.tref = t
end
settimestamp!(o::AbstractOutput, t) = nothing


# Frame handling
storeframe!(o::AbstractGraphicOutput, frame, t) = begin
    if o.store
        push!(o, similar(o[1]))
        updateframe!(o, frame, t)
    else
        updateframe!(o, frame, 1)
    end
    o.tlast = t
end
storeframe!(o::AbstractOutput, frame, t) = updateframe!(o, frame, t)

updateframe!(o, frame::AbstractArray{T,2}, t) where T =
    for j in 1:size(o[1], 2), i in 1:size(o[1], 1)
        @inbounds o[t][i, j] = frame[i, j]
    end


allocateframes!(o::AbstractOutput, init, tspan) = begin
    append!(frames(o), [similar(init) for i in tspan])
    nothing
end

initframes!(o::AbstractGraphicOutput, init) = begin
    deleteat!(frames(o), 1:length(o))
    push!(frames(o), init)
end
initframes!(o::AbstractOutput, init) = o[1] .= init

"""
    showframe(output::AbstractOutput, [t])
Show the last frame of the output, or the frame at time t.
"""
showframe(o::AbstractOutput) = showframe(o, lastindex(o))
showframe(o::AbstractOutput, t) = showframe(o, o[curframe(o, t)], t)
showframe(o::AbstractOutput, frame::AbstractArray) = showframe(o, frame, 0)
showframe(o::AbstractOutput, frame::AbstractArray, t) = nothing
showframe(o::AbstractOutput, ruleset::AbstractRuleset, t) =
    showframe(o, ruleset, o[curframe(o, t)], t)
showframe(o::AbstractOutput, ruleset::AbstractRuleset, frame::AbstractArray, t) =
    showframe(o::AbstractOutput, normaliseframe(ruleset, frame), t)

curframe(o::AbstractOutput, t) = isstored(o) ? t : oneunit(t)

normaliseframe(ruleset, a::AbstractArray) = normaliseframe(hasminmax(ruleset), ruleset, a)
normaliseframe(::HasMinMax, ruleset, a::AbstractArray) =
    normaliseframe(a, minval(ruleset), maxval(ruleset))
normaliseframe(a::AbstractArray, minval::Number, maxval::Number) =
    min.((a .- minval) ./ (maxval - minval), one(eltype(a)))
normaliseframe(::NoMinMax, ruleset, a::AbstractArray) = a


# Setup and close output
initialize!(o::AbstractOutput) = nothing
finalize!(o::AbstractOutput, args...) = nothing

# Delay output to maintain the frame rate
delay(o::AbstractGraphicOutput, t) = sleep(max(0.0, timestamp(o) + (t - o.tref)/getfps(o) - time()))
delay(o::AbstractOutput, t) = nothing
