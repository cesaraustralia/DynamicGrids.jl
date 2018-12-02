"""
A simple array output that stores each step of the simulation in an array of arrays.
"""
@Ok @Frames struct ArrayOutput{} <: AbstractOutput{T} end
ArrayOutput(frames::AbstractVector) = ArrayOutput{typeof(frames)}(frames, [false])

is_async(o::ArrayOutput) = false

allocate!(o::ArrayOutput, init, tspan) = begin
    append!(o.frames, [similar(init) for i in tspan])
    nothing
end

store_frame!(::NoFPS, o::ArrayOutput, frame, t) = o[t] .= frame
