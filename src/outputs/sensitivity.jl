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
    if length(o) < 
        push!(o, deepcopy(frame))
    else
        o[t] .+= frame
    end

finalize(o::SensitivityOutput, args...) = begin

end


"Output constructor to convert a `SensitivityOutput()` to something you can view using replay()"
(::Type{F})(init::SensitivityOutput, args...; kwargs...) where F <: AbstractOutput = begin
    F(T[init], args...; kwargs...)
end
