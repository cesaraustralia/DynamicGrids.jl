"""
Simulation outputs are decoupled from simulation behaviour and can be used interchangeably.
These outputs inherit from AbstractOutput.

Types that extend AbstractOutput define their own method for [`show_frame`](@ref).
"""
abstract type AbstractOutput{T} <: AbstractVector{T} end

@premix struct Frames{T<:AbstractVector}
    "An array that holds each frame of the simulation"
    frames::T
end

@premix struct Ok
    running::Array{Bool}
end

@premix struct FPS{F,TS,TR}
    fps::F
    showmax_fps::F
    timestamp::TS
    tref::TR
    store::Bool
end

struct HasFPS end
struct NoFPS end

"Generic ouput constructor. Converts init array to vector of frames."
(::Type{F})(init::T, args...; kwargs...) where F <: AbstractOutput where T <: AbstractMatrix =
    F(T[init], args...; kwargs...)


# Base methods
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

set_running(o::AbstractOutput, val) = o.running[1] = val

is_async(o::AbstractOutput) = false

clear(o::AbstractOutput) = deleteat!(o.frames, 1:length(o))

process_image(o, frame) = Images.Gray.(frame)


has_fps(o::O) where O = all(fn -> fn in fieldnames(O), (:fps, :timestamp)) ? HasFPS() : NoFPS()
fps(o) = o.fps

store_frame(o::AbstractOutput, frame, t) = store_frame(has_fps(o), o, frame, t)
store_frame(::HasFPS, o, frame, t) = 
    if o.store || length(o) == 0
        push!(o, deepcopy(frame))
    else
        o[1] .= frame
    end
store_frame(::NoFPS, o, frame, t) = push!(o, deepcopy(frame))

curframe(o::AbstractOutput, t) = curframe(has_fps(o), o, t)
curframe(::HasFPS, o, t) = o.store ? t : 1
curframe(::NoFPS, o, t) = t

is_showable(o::AbstractOutput, t) = is_showable(has_fps(o), o, t)
is_showable(::HasFPS, o, t) = t % (o.fps ÷ o.showmax_fps + 1) == 0
is_showable(::NoFPS, o, t) = false

finalize(o::AbstractOutput, args...) = nothing

initialize(o::AbstractOutput, args...) = initialize(has_fps(o), o, args...)
initialize(::HasFPS, o, args...) = nothing 
initialize(::NoFPS, o, args...) = nothing 

delay(o, t) = delay(has_fps(o), o, t) 
delay(::HasFPS, o, t) = sleep(max(0.0, o.timestamp + (t - o.tref)/fps(o) - time()))
delay(::NoFPS, o, t) = nothing

set_timestamp(o, t) = set_timestamp(has_fps(o), o, t) 
set_timestamp(::HasFPS, o, t) = begin
    o.timestamp = time()
    o.tref = t
end
set_timestamp(::NoFPS, o, t) = nothing

""" 
    savegif(filename::String, output::AbstractOutput)
Write the output array to a gif. 
Saving very large gifs may trigger a bug in imagemagick.
"""
savegif(filename::String, output::AbstractOutput) = 
    FileIO.save(filename, Gray.(cat(3, output...)))

""" 
    show_frame(output::AbstractOutput, [t])
Show the last frame of the output, or the frame at time t. 
"""
show_frame(o::AbstractOutput) = showframe(o, lastindex(o))
show_frame(o::AbstractOutput, t) = nothing

