"""
Simulation outputs are decoupled from simulation behaviour and can be used interchangeably.
These outputs inherit from AbstractOutput.

Types that extend AbstractOutput define their own method for [`show_frame`](@ref).
"""
abstract type AbstractOutput{T} <: AbstractVector{T} end

"Generic ouput constructor. Converts init array to vector of empty frames."
(::Type{F})(init::T, args...; kwargs...) where F <: AbstractOutput where T <: AbstractMatrix =
    F(T[init], args...; kwargs...)

length(o::AbstractOutput) = length(o.frames)
size(o::AbstractOutput) = size(o.frames)
endof(o::AbstractOutput) = endof(o.frames)
getindex(o::AbstractOutput, i) = getindex(o.frames, i)
setindex!(o::AbstractOutput, x, i) = setindex!(o.frames, x, i)
push!(o::AbstractOutput, x) = push!(o.frames, x)
append!(o::AbstractOutput, x) = append!(o.frames, x)

clear(o::AbstractOutput) = deleteat!(o.frames, 1:length(o))
initialize(o::AbstractOutput, args...) = nothing
finalize(o::AbstractOutput, args...) = nothing
store_frame(o::AbstractOutput, frame) = push!(o, deepcopy(frame))
is_ok(o::AbstractOutput) = o.ok[1]
set_ok(o::AbstractOutput, val) = o.ok[1] = val
is_running(o::AbstractOutput) = o.running[1]
set_running(o::AbstractOutput, val) = o.running[1] = val
# process_image(output, frame) = convert(Array{UInt32, 2}, frame) .* 0x00ffffff
process_image(output, frame) = Images.Gray.(frame)

struct HasFPS end
struct NoFPS end

delay(output) = :fps in fieldnames(output) ? delay(HasFPS(), output) : delay(NoFPS(), output) 
delay(::HasFPS, output) = begin
    sleep(max(0.0, output.timestamp + 1/output.fps - time()))
    output.timestamp = time()
end
delay(::NoFPS, output) = sleep(0.0)

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

@premix struct Frames{T<:AbstractVector}
    "An array that holds each frame of the simulation"
    frames::T
end

@premix struct FPS{F,TS}
    fps::F
    timestamp::TS
end

@premix struct Ok
    ok::Array{Bool}
    running::Array{Bool}
end
