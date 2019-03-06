using Blink, WebSockets

abstract type AbstractBlinkOutput{T} <: AbstractWebOutput{T} end

"""
A html output using Interact.jl and an Electron window through Blink.jl
BlinkOutput automatically generates sliders to control simulations
in realtime. args and kwargs are passed to [`WebInterface`]

## Example
```julia
using Blink
BlinkOutput(init, model)
```

### Arguments
- `frames::AbstractArray`: vector of matrices.
- `model::Models`: tuple of models wrapped in Models().
- `args`: any additional arguments to be passed to the model rule

### Optional keyword arguments
- `fps = 25`: frames per second.
- `showmax_fps = fps`: maximum displayed frames per second
- `store::Bool = false`: save frames or not.
- `processor = Greyscale()`
- `theme` A css theme.
"""
@flattenable mutable struct BlinkOutput{T, I<:WebInterface{T}} <: AbstractBlinkOutput{T}
    interface::I                   | true
    window::Blink.AtomShell.Window | false
end

BlinkOutput(frames::T, model, args...; kwargs...) where T <: AbstractVector = begin
    interface = WebInterface(frames, model, args...; kwargs...)
    window = Blink.AtomShell.Window()
    body!(window, interface.page)

    BlinkOutput{T,typeof(interface)}(interface, window)
end

# Forward output methods to WebInterface: BlinkOutput is just a wrapper.
@forward AbstractBlinkOutput.interface length, size, endof, firstindex, lastindex, getindex, 
    setindex!, push!, append!,
    delete_frames!, store_frame!, update_frame!, 
    show_frame, delay, normalize_frame, process_frame, web_image,
    set_time!, set_timestamp!, set_running!, set_fps!, 
    get_fps, get_tlast, is_showable, is_async, curframe, 
    has_fps, has_minmax, has_processor

# Running checks depend on the blink window still being open
is_running(o::AbstractBlinkOutput) = is_alive(o) && is_running(o.interface)
is_alive(o::AbstractBlinkOutput) = o.window.content.sock.state == WebSockets.ReadyState(1)
