
# Mixins

@premix struct Frames{T<:AbstractVector}
    "An array that holds each frame of the simulation"
    frames::T
end

@premix struct Ok
    running::Bool
end

@premix struct FPS{F,TS,TM}
    fps::F
    showmax_fps::F
    timestamp::TS
    tref::TM
    tlast::TM
    store::Bool
end

@premix struct MinMax{MM}
    min::MM
    max::MM
end

@premix struct ImageProc{IP}
    processor::IP
end


# Traits

struct HasFPS end
struct NoFPS end

has_fps(o::O) where O = :fps in fieldnames(O) ? HasFPS() : NoFPS()

struct HasMinMax end
struct NoMinMax end

has_minmax(m) = begin
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
@Frames struct NullOutput{} <: AbstractOutput{T} end

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
is_async(o::AbstractOutput) = false

is_showable(o::AbstractOutput, t) = is_showable(has_fps(o), o, t)
is_showable(::HasFPS, o, t) = true # TODO working max fps. o.timestamp + (t - o.tref)/o.showmax_fps < time()
is_showable(::NoFPS, o, t) = false 

is_running(o::AbstractOutput) = o.running

set_running!(o::AbstractOutput, val) = o.running = val

# Getters and setters
get_tlast(o::AbstractOutput) = get_tlast(has_fps(o), o)
get_tlast(::HasFPS, o::AbstractOutput) = o.tlast
get_tlast(::NoFPS, o::AbstractOutput) = lastindex(o)

get_fps(o) = get_fps(has_fps(o), o) 
get_fps(::HasFPS, o) = o.fps
get_fps(::NoFPS, o) = 0.0

set_fps!(o, x) = set_fps!(has_fps(o), o, x) 
set_fps!(::HasFPS, o, x) = o.fps = x
set_fps!(::NoFPS, o, x) = nothing

set_timestamp!(o, t) = set_timestamp!(has_fps(o), o, t)
set_timestamp!(::HasFPS, o, t) = begin
    o.timestamp = time()
    o.tref = t
end
set_timestamp!(::NoFPS, o, t) = nothing


# Frame handling
store_frame!(o::AbstractOutput, frame, t) = store_frame!(has_fps(o), o, frame, t)
store_frame!(::HasFPS, o, frame, t) = begin
    if length(o) == 0
        push!(o, frame)
    elseif o.store
        push!(o, similar(o[1]))
        update_frame!(o, frame, t)
    else
        update_frame!(o, frame, 1)
    end
    o.tlast = t
end
store_frame!(::NoFPS, o, frame, t) = update_frame!(o, frame, t)

update_frame!(o, frame::AbstractArray{T,1}, t) where T = begin
    sze = size(o[1])
    for i in 1:sze[1]
        @inbounds o[t][i] = frame[i]
    end
end
update_frame!(o, frame::AbstractArray{T,2}, t) where T = begin
    sze = size(o[1])
    for j in 1:sze[2], i in 1:sze[1]
        @inbounds o[t][i, j] = frame[i, j]
    end
end
update_frame!(o, frame::AbstractArray{T,3}, t) where T = begin
    sze = size(o[1])
    for i in 1:sze[1], j in 1:sze[2], k in 1:sze[3]
        @inbounds o[t][i, j, k] = frame[i, j, k]
    end
end


allocate_frames!(o::AbstractOutput, init, tspan) = begin
    append!(o.frames, [similar(init) for i in tspan])
    nothing
end

delete_frames!(o::AbstractOutput) = delete_frames!(has_fps(o), o::AbstractOutput)
delete_frames!(::HasFPS, o::AbstractOutput) = deleteat!(o.frames, 1:length(o))
delete_frames!(::NoFPS, o::AbstractOutput) = nothing

"""
    show_frame(output::AbstractOutput, [t])
Show the last frame of the output, or the frame at time t.
"""
show_frame(o::AbstractOutput) = show_frame(o, lastindex(o))
show_frame(o::AbstractOutput, t) = show_frame(o, o[curframe(o, t)], t)
show_frame(o::AbstractOutput, frame::AbstractMatrix) = show_frame(o, frame, 0)
show_frame(o::AbstractOutput, frame, t) = nothing

curframe(o::AbstractOutput, t) = curframe(has_fps(o), o, t)
curframe(::HasFPS, o, t) = o.store ? t : oneunit(t)
curframe(::NoFPS, o, t) = t


# Setup and close output
initialize!(o::AbstractOutput, args...) = initialize!(has_fps(o), o, args...)
initialize!(::HasFPS, args...) = nothing
initialize!(::NoFPS, args...) = nothing

finalize!(o::AbstractOutput, args...) = nothing

# Delay output to maintain the frame rate
delay(o, t) = delay(has_fps(o), o, t)
delay(::HasFPS, o, t) = sleep(max(0.0, o.timestamp + (t - o.tref)/get_fps(o) - time()))
delay(::NoFPS, o, t) = nothing
