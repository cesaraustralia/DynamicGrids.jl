"""
A html output using Interact.jl

Multiple web backends are supported, and will use whichever CSS toolkit you have loaded,
such as InteractBulma.jl

## Example
```julia
using InteractBulma, Blink
BlinkOutput(init)
```

Only available after running `using Blink`
"""
mutable struct BlinkOutput{T, I<:WebInterface{T}} <: AbstractWebOutput{T} 
    interface::I
    window::Blink.AtomShell.Window
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
BlinkOutput(frames::T, model; fps=25, kwargs...) where T <: AbstractVector = begin
    interface = WebInterface(frames, fps, model)
    window = Blink.AtomShell.Window()

    body!(window, interface.page)
    BlinkOutput{T,typeof(interface)}(interface, window)
end

is_ok(o::BlinkOutput) = is_ok(o.interface) && active(o.window)
