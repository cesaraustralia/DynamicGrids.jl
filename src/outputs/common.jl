
# Mixins

@premix struct Frames{T<:AbstractVector}
    "An array that holds each frame of the simulation"
    frames::T
end

@premix struct Ok
    running::Array{Bool}
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

struct HasProcessor end
struct NoProcessor end

has_processor(o::O) where O = :processor in fieldnames(O) ? HasProcessor() : NoProcessor()



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


# Forward base methods to the frames array

length(o::AbstractOutput) = length(o.frames)
size(o::AbstractOutput) = size(o.frames)
firstindex(o::AbstractOutput) = firstindex(o.frames)
lastindex(o::AbstractOutput) = lastindex(o.frames)
getindex(o::AbstractOutput, i) = getindex(o.frames, i)
setindex!(o::AbstractOutput, x, i) = setindex!(o.frames, x, i)
push!(o::AbstractOutput, x) = push!(o.frames, x)
append!(o::AbstractOutput, x) = append!(o.frames, x)



# Custom methods

is_running(o::AbstractOutput) = o.running[1]

set_running!(o::AbstractOutput, val) = o.running[1] = val

is_async(o::AbstractOutput) = false

fps(o) = o.fps

allocate_frames!(o::AbstractOutput, init, tspan) = begin
    append!(o.frames, [similar(init) for i in tspan])
    nothing
end

clear!(o::AbstractOutput) = clear!(has_fps(o), o::AbstractOutput)
clear!(::HasFPS, o::AbstractOutput) = deleteat!(o.frames, 1:length(o))
clear!(::NoFPS, o::AbstractOutput) = nothing

last_t(o::AbstractOutput) = last_t(has_fps(o), o)
last_t(::HasFPS, o::AbstractOutput) = o.tlast
last_t(::NoFPS, o::AbstractOutput) = lastindex(o)

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

update_frame!(o, frame, t) = begin
    sze = size(o[1])
    for j in 1:sze[2], i in 1:sze[1]
        @inbounds o[t][i, j] = frame[i, j]
    end
end

curframe(o::AbstractOutput, t) = curframe(has_fps(o), o, t)
curframe(::HasFPS, o, t) = o.store ? t : oneunit(t)
curframe(::NoFPS, o, t) = t

isshowable(o::AbstractOutput, t) = isshowable(has_fps(o), o, t)
isshowable(::HasFPS, o, t) = true # TODO working max fps. o.timestamp + (t - o.tref)/o.showmax_fps < time()
isshowable(::NoFPS, o, t) = false 

finalize!(o::AbstractOutput, args...) = nothing

initialize!(o::AbstractOutput, args...) = initialize!(has_fps(o), o, args...)
initialize!(::HasFPS, args...) = nothing
initialize!(::NoFPS, args...) = nothing

delay(o, t) = delay(has_fps(o), o, t)
delay(::HasFPS, o, t) = sleep(max(0.0, o.timestamp + (t - o.tref)/fps(o) - time()))
delay(::NoFPS, o, t) = nothing

set_timestamp!(o, t) = set_timestamp!(has_fps(o), o, t)
set_timestamp!(::HasFPS, o, t) = begin
    o.timestamp = time()
    o.tref = t
end
set_timestamp!(::NoFPS, o, t) = nothing

"""
    show_frame(output::AbstractOutput, [t])
Show the last frame of the output, or the frame at time t.
"""
show_frame(o::AbstractOutput) = show_frame(o, lastindex(o))
show_frame(o::AbstractOutput, t::Number) = show_frame(o, o[curframe(o, t)], t)
show_frame(o::AbstractOutput, frame::AbstractMatrix) = show_frame(o, frame, 0)
show_frame(o::AbstractOutput, frame, t) = nothing



" A generic Null output that does nothing "
@Frames struct NullOutput{} <: AbstractOutput{T} end

NullOutput(args...) = NullOutput{typeof([])}([])

