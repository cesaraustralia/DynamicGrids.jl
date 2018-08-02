"""
A html output using Interact.jl

Multiple web backends are supported, and will use whichever CSS toolkit you have loaded,
such as [InteractBulma.jl](.

## Example
```julia
using InteractBulma, Blink
WebOutput(init)
```

Only available after running `using InteractBulma`
"""
@Ok @FPS @Frames mutable struct WebOutput{W,Ti} <: AbstractOutput{T}
    window::W
    t::Ti
end

"""
    WebOutput(frames)
Constructor for WebOutput.
### Arguments
- `frames::AbstractArray`: vector of matrices. 

### Keyword arguments
- `aspec_ratio` : passed to the plots heatmap, default is :equal
- `kwargs` : extra keyword args to modify the heatmap
"""
WebOutput(frames::AbstractVector{F}; fps=25, aspect_ratio=:equal, kwargs...) where F = begin
    window = Blink.Window()
    ok = [true]
    image = Observable{Any}(dom"div"([Images.Gray.(frames[1])]))
    obs_t = Observable{Int}(1)
    output = WebOutput(frames, fps, time(), ok, window, obs_t)

    stop = button("stop")
    on(x -> ok[1] = false, observe(stop))
    replay = button("replay")
    on(observe(replay)) do x
        # ok[1] = false
        # do this in a safer way: we need to make sure the other process stops.
        # sleep(0.3)
        ok[1] = true
        replay(output)
    end
    map!(t -> dom"div"([Images.Gray.(frames[t])]), image, obs_t)
    Blink.body!(window, dom"div"(vbox(image, hbox(stop, replay))))

    output
end

initialize(output::WebOutput) = set_ok(output, true)
is_ok(output::WebOutput) = output.ok[1] && active(output.window)

"""
    show_frame(output::WebOutput, t; fps=25.0)
Update plot for every specified interval
"""
function show_frame(output::WebOutput, t; fps=0.1)
    output.t[] = t
    delay(output)
    is_ok(output)
end
