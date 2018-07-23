using Plots

"""
A Plots.jl Output to plot cells as a heatmap in any Plots backend. Some backends
(such as plotly) may be very slow to refresh. Others like gr() should be fine.
`using Plots` must be called for this to be available.
"""
@Ok @Frames struct PlotsOutput{T,P,I} <: AbstractOutput{T}
    plot::P
    interval::I
end

"""
    PlotsOutput(frames)
Constructor for GtkOutput.
### Arguments
- `frames::AbstractArray`: vector of `frames` 

### Keyword arguments
- `aspec_ratio` : passed to the plots heatmap, default is :equal
- `kwargs` : extra keyword args to modify the heatmap
"""
PlotsOutput(frames::AbstractVector; interval=1, aspect_ratio=:equal, kwargs...) = begin
    p = heatmap(; aspect_ratio=aspect_ratio, kwargs...)
    ok = [true]
    PlotsOutput(frames[:], ok, p, interval)
end

initialize(output::PlotsOutput) = begin
    set_ok(output, true)
    display(output.plot)
end

"""
    show_frame(output::PlotsOutput, t; pause=0.1)
Update plot for every specified interval
"""
function show_frame(output::PlotsOutput, t; pause=0.1)
    rem(t, output.interval) == 0 || return true
    heatmap!(output.plot, output[t])
    display(output.plot)
    true
end
