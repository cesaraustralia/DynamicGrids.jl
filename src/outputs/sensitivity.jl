"""
A simple array output that stores each step of the simulation in an array of arrays.
"""
@Ok @Frames struct SensitivityOutput{} <: AbstractOutput{T} 
    passes::Int
end
SensitivityOutput(frames::AbstractVector, passes=10) = 
    SensitivityOutput{typeof(frames)}(frames, [false], passes)

is_async(o::SensitivityOutput) = false

run!(o::SensitivityOutput, args...) = 
    for p in 1:o.passes
        frameloop(output, args...)
    end

store_frame(::NoFPS, o::SensitivityOutput, frame, t) = 
    if length(o) < t
        push!(o, deepcopy(frame))
    else
        o[t] .+= frame
    end

"Output constructor to convert a `SensitivityOutput()` to something you can view using replay()"
(::Type{F})(output::SensitivityOutput{T}, args...; kwargs...) where {T, F <: AbstractOutput} = begin
    # Scale between 0.0 and 1.0
    for frame in output
        frame ./= output.passes 
    end
    F(T[ouput[:]], args...; kwargs...)
end
