
# Mixins

@premix struct Output{T<:AbstractVector}
    frames::T
    running::Bool
end

"""
Mixin for all outputs that display frames live.
"""
@premix struct FPS{F,TS,TM}
    fps::F
    maxfps::F
    timestamp::TS
    tref::TM
    tlast::TM
    store::Bool
end

@premix struct MinMax{MM}
    min::MM
    max::MM
end

"""
Mixin for outputs that output real images and can use an image processor.
"""
@premix struct ImageProc{IP}
    processor::IP
end


# Traits

struct HasFPS end
struct NoFPS end

hasfps(o::O) where O = :fps in fieldnames(O) ? HasFPS() : NoFPS()

struct HasMinMax end
struct NoMinMax end

hasminmax(m) = begin
    fns = fieldnames(typeof(m))
    :min in fns && :max in fns ? HasMinMax() : NoMinMax()
end


# Abstract output type and generic methods

"""
Output additions that summarise the current frame. 
This could be a plot or graphic.
"""
abstract type AbstractSummary end

"""
All outputs must inherit from AbstractOutput.

Simulation outputs are decoupled from simulation behaviour and in
many cases can be used interchangeably.
"""
abstract type AbstractOutput{T} <: AbstractVector{T} end

"Generic ouput constructor. Converts init array to vector of frames."
(::Type{F})(init::T, args...; kwargs...) where F <: AbstractOutput where T <: AbstractMatrix = 
    F(T[deepcopy(init)], args...; kwargs...)


" A generic Null output that does nothing "
@Output struct NullOutput{} <: AbstractOutput{T} end

NullOutput(args...) = NullOutput{typeof([])}([])


# Forward base methods to the frames array
length(o::AbstractOutput) = length(o.frames)
size(o::AbstractOutput) = size(o.frames)
firstindex(o::AbstractOutput) = firstindex(o.frames)
lastindex(o::AbstractOutput) = lastindex(o.frames)
getindex(o::AbstractOutput, i) = getindex(o.frames, i)
setindex!(o::AbstractOutput, x, i) = setindex!(o.frames, x, i)
push!(o::AbstractOutput, x) = push!(o.frames, x)
append!(o::AbstractOutput, x) = append!(o.frames, x)


# Bool getters and setters
isasync(o::AbstractOutput) = false

isshowable(o::AbstractOutput, t) = isshowable(hasfps(o), o, t)
isshowable(::HasFPS, o, t) = true # TODO working max fps. o.timestamp + (t - o.tref)/o.maxfps < time()
isshowable(::NoFPS, o, t) = false 

isrunning(o::AbstractOutput) = o.running

setrunning!(o::AbstractOutput, val) = o.running = val

# Getters and setters
gettlast(o::AbstractOutput) = gettlast(hasfps(o), o)
gettlast(::HasFPS, o::AbstractOutput) = o.tlast
gettlast(::NoFPS, o::AbstractOutput) = lastindex(o)

getfps(o) = getfps(hasfps(o), o) 
getfps(::HasFPS, o) = o.fps
getfps(::NoFPS, o) = 0.0

setfps!(o, x) = setfps!(hasfps(o), o, x) 
setfps!(::HasFPS, o, x) = o.fps = x
setfps!(::NoFPS, o, x) = nothing

settimestamp!(o, t) = settimestamp!(hasfps(o), o, t)
settimestamp!(::HasFPS, o, t) = begin
    o.timestamp = time()
    o.tref = t
end
settimestamp!(::NoFPS, o, t) = nothing


# Frame handling
storeframe!(o::AbstractOutput, frame, t) = storeframe!(hasfps(o), o, frame, t)
storeframe!(::HasFPS, o, frame, t) = begin
    if length(o) == 0
        push!(o, frame)
    elseif o.store
        push!(o, similar(o[1]))
        updateframe!(o, frame, t)
    else
        updateframe!(o, frame, 1)
    end
    o.tlast = t
end
storeframe!(::NoFPS, o, frame, t) = updateframe!(o, frame, t)

updateframe!(o, frame::AbstractArray{T,1}, t) where T = begin
    sze = size(o[1])
    for i in 1:sze[1]
        @inbounds o[t][i] = frame[i]
    end
end
updateframe!(o, frame::AbstractArray{T,2}, t) where T = begin
    sze = size(o[1])
    for j in 1:sze[2], i in 1:sze[1]
        @inbounds o[t][i, j] = frame[i, j]
    end
end
updateframe!(o, frame::AbstractArray{T,3}, t) where T = begin
    sze = size(o[1])
    for i in 1:sze[1], j in 1:sze[2], k in 1:sze[3]
        @inbounds o[t][i, j, k] = frame[i, j, k]
    end
end


allocateframes!(o::AbstractOutput, init, tspan) = begin
    append!(o.frames, [similar(init) for i in tspan])
    nothing
end

deleteframes!(o::AbstractOutput) = deleteframes!(hasfps(o), o::AbstractOutput)
deleteframes!(::HasFPS, o::AbstractOutput) = deleteat!(o.frames, 1:length(o))
deleteframes!(::NoFPS, o::AbstractOutput) = nothing

"""
    showframe(output::AbstractOutput, [t])
Show the last frame of the output, or the frame at time t.
"""
showframe(o::AbstractOutput) = showframe(o, lastindex(o))
showframe(o::AbstractOutput, t) = showframe(o, o[curframe(o, t)], t)
showframe(o::AbstractOutput, frame::AbstractMatrix) = showframe(o, frame, 0)
showframe(o::AbstractOutput, frame, t) = nothing

curframe(o::AbstractOutput, t) = curframe(hasfps(o), o, t)
curframe(::HasFPS, o, t) = o.store ? t : oneunit(t)
curframe(::NoFPS, o, t) = t


# Setup and close output
initialize!(o::AbstractOutput, args...) = initialize!(hasfps(o), o, args...)
initialize!(::HasFPS, args...) = nothing
initialize!(::NoFPS, args...) = nothing

finalize!(o::AbstractOutput, args...) = nothing

# Delay output to maintain the frame rate
delay(o, t) = delay(hasfps(o), o, t)
delay(::HasFPS, o, t) = sleep(max(0.0, o.timestamp + (t - o.tref)/getfps(o) - time()))
delay(::NoFPS, o, t) = nothing
