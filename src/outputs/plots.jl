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
    ok = [true]
    PlotsOutput(frames, fps, time() ok, plt)
end

initialize(output::PlotsOutput) = begin
    set_ok(output, true)
    display(output.plot)
end

"""
    show_frame(output::PlotsOutput, t)
Update plot for every specified interval
"""
function show_frame(output::PlotsOutput, t)
    rem(t, output.interval) == 0 || return true
    heatmap!(output.plot, output[t])
    display(output.plot)
    delay(output)
    is_ok(output)
end
