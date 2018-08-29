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

@premix struct FPS{F,TS}
    fps::F
    timestamp::TS
end

struct HasFPS end
struct NoFPS end

"Generic ouput constructor. Converts init array to vector of empty frames."
(::Type{F})(init::T, args...; kwargs...) where F <: AbstractOutput where T <: AbstractMatrix =
    F(T[init], args...; kwargs...)

length(o::AbstractOutput) = length(o.frames)
size(o::AbstractOutput) = size(o.frames)
lastindex(o::AbstractOutput) = lastindex(o.frames)
getindex(o::AbstractOutput, i) = getindex(o.frames, i)
setindex!(o::AbstractOutput, x, i) = setindex!(o.frames, x, i)
push!(o::AbstractOutput, x) = push!(o.frames, x)
append!(o::AbstractOutput, x) = append!(o.frames, x)

clear(o::AbstractOutput) = deleteat!(o.frames, 1:length(o))
finalize(o::AbstractOutput, args...) = nothing
store_frame(o::AbstractOutput, frame) = push!(o, deepcopy(frame))
is_running(o::AbstractOutput) = o.running[1]
set_running(o::AbstractOutput, val) = o.running[1] = val
is_async(o::AbstractOutput) = false
# process_image(output, frame) = convert(Array{UInt32, 2}, frame) .* 0x00ffffff
process_image(output, frame) = Images.Gray.(frame)

has_fps(output) = :fps in fieldnames(typeof(output)) ? HasFPS() : NoFPS()

initialize(o::AbstractOutput, args...) =  initialize(has_fps(o), o, args...)
initialize(::HasFPS, o::AbstractOutput, args...) = o.timestamp = time() 
initialize(::NoFPS, o::AbstractOutput, args...) = nothing 

delay(o, t) = delay(has_fps(o), o, t) 
delay(::HasFPS, o, t) = sleep(max(0.0, o.timestamp + t/o.fps - time()))
delay(::NoFPS, o, t) = nothing

"""
    show_frame(output::AbstractOutput, t)
Show a specific frame of the output.
"""
show_frame(output::AbstractOutput, t) = true

""" 
    savegif(filename::String, output::AbstractOutput)
Write the output array to a gif. 
Saving very large gifs may trigger a bug in imagemagick.
"""
savegif(filename::String, output::AbstractOutput) = 
    FileIO.save(filename, Gray.(cat(3, output...)))
