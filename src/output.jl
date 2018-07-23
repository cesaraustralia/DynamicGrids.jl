"""
Simulation outputs are decoupled from simulation behaviour and can be used interchangeably.
These outputs inherit from AbstractOutput.

Types that extend AbstractOutput define their own method for [`show_frame`](@ref).
"""
abstract type AbstractOutput{T} <: AbstractVector{T} end

"Generic ouput constructor. Converts init array to vector of empty frames."
(::Type{T})(init::I, args...; kwargs...) where T <: AbstractOutput where I <: AbstractMatrix =
    T(I[], args...; kwargs...)

length(o::AbstractOutput) = length(o.frames)
size(o::AbstractOutput) = size(o.frames)
endof(o::AbstractOutput) = endof(o.frames)
getindex(o::AbstractOutput, i) = getindex(o.frames, i)
setindex!(o::AbstractOutput, x, i) = setindex!(o.frames, x, i)
push!(o::AbstractOutput, x) = push!(o.frames, x)
append!(o::AbstractOutput, x) = append!(o.frames, x)


clear(output::AbstractOutput) = deleteat!(output.frames, 1:length(output))
initialize(output::AbstractOutput) = nothing
store_frame(output::AbstractOutput, frame) = push!(output, deepcopy(frame))
show_frame(output::AbstractOutput, t; pause=0.1) = true
is_ok(output) = output.ok[1]
set_ok(output, val) = output.ok[1] = val
process_image(output, frame) = convert(Array{UInt32, 2}, frame) .* 0x00ffffff

""" 
    savegif(filename::String, output::AbstractOutput; fps=30)
Write the output array to a gif. 
Saving very large gifs may trigger a bug in imagemagick.
"""
savegif(filename::String, output::AbstractOutput; fps=30) = 
    FileIO.save(filename, Gray.(cat(3, output...)); fps=fps)

"""
    replay(output::AbstractOutput; pause=0.1) = begin
Show the simulation again. You can also use this to show a sequence 
run with a different output type.

### Example
```julia
replay(REPLOutput(output); pause=0.1)
```
"""
replay(output::AbstractOutput; pause=0.1) = begin
    initialize(output)
    for (t, frame) in enumerate(output)
        show_frame(output, t; pause=pause)
    end
end

@premix struct Frames{T}
    "An array that holds each frame of the simulation"
    frames::Vector{T}
end

@premix struct Ok
    ok::Array{Bool}
end

"""
A simple array output that stores each step of the simulation in an array of arrays.
"""
@Frames struct ArrayOutput{} <: AbstractOutput{T} end
ArrayOutput(frames::AbstractVector) = ArrayOutput(frames[:])
