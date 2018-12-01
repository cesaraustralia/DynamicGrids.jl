using Plots

"""
A Plots.jl Output to plot cells as a heatmap in any Plots backend. Some backends
(such as plotly) may be very slow to refresh. Others like gr() should be fine.

Only available after running `using Plots`
"""
@Ok @FPS @Frames mutable struct PlotsOutput{T,P} <: AbstractOutput{T}
    plot::P
end

"""
    PlotsOutput(frames)
Constructor for PlotsOutput.
### Arguments
- `frames::AbstractArray`: vector of matrices

### Keyword arguments
- `aspec_ratio` : passed to the plots heatmap, default is :equal
- `kwargs` : extra keyword args to modify the heatmap
"""
PlotsOutput(frames::AbstractVector; fps=25.0, aspect_ratio=:equal, kwargs...) = begin
    plt = heatmap(; aspect_ratio=aspect_ratio, kwargs...)
    PlotsOutput(frames, fps, 0.0, 0, [false], plt)
end

initialize(output::PlotsOutput, args...) = begin
    display(output.plot)
    output.timestamp = time()
end

show_frame(o::PlotsOutput, frame::AbstractMatrix) = begin
    heatmap!(output.plot, normalize_frame(frame))
    display(output.plot)
end
