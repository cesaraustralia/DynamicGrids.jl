"""
Simulation outputs are decoupled from simulation behaviour and can be used interchangeably.
These outputs inherit from AbstractOutput.

Types that extend AbstractOutput define their own method for [`show_frame`](@ref).
"""
abstract type AbstractOutput{T} <: AbstractVector{T} end

"Generic ouput constructor. Converts init array to vector of empty frames."
(::Type{T})(init::I, args...; kwargs...) where T <: AbstractOutput where I <: AbstractMatrix =
    T(I[init], args...; kwargs...)

length(o::AbstractOutput) = length(o.frames)
size(o::AbstractOutput) = size(o.frames)
endof(o::AbstractOutput) = endof(o.frames)
getindex(o::AbstractOutput, i) = getindex(o.frames, i)
setindex!(o::AbstractOutput, x, i) = setindex!(o.frames, x, i)
push!(o::AbstractOutput, x) = push!(o.frames, x)
append!(o::AbstractOutput, x) = append!(o.frames, x)


clear(output::AbstractOutput) = deleteat!(output.frames, 1:length(output))
initialize(output::AbstractOutput, args...) = nothing
store_frame(output::AbstractOutput, frame) = push!(output, deepcopy(frame))
is_ok(output) = output.ok[1]
set_ok(output, val) = output.ok[1] = val
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

"""
    replay(output::AbstractOutput) = begin
Show the simulation again. You can also use this to show a sequence 
run with a different output type.

### Example
```julia
replay(REPLOutput(output))
```
"""
replay(output::AbstractOutput) = begin
    initialize(output)
    for (t, frame) in enumerate(output)
        delay(output)
        show_frame(output, t) || break
    end
end

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
end
