using Blink,
      WebSockets

"""
A html output using Interact.jl and an Electron window through Blink.jl

## Example
```julia
using Blink
BlinkOutput(init)
```
"""
@flattenable mutable struct BlinkOutput{T, I<:WebInterface{T}} <: AbstractWebOutput{T} 
    interface::I                   | true
    window::Blink.AtomShell.Window | false
end

"""
    BlinkOutput(frames, model, args...)
Constructor for BlinkOutput.

### Arguments
- `frames::AbstractArray`: vector of matrices.
- `model::Models`: tuple of models wrapped in Models().
- `args`: any additional arguments to be passed to the model rule

### Keyword arguments
- `fps`: frames per second
- `showmax_fps`: maximum displayed frames per second
- `store::Bool`: save frames or not
"""
BlinkOutput(frames::T, model, args...; kwargs...) where T <: AbstractVector = begin
    interface = WebInterface(frames, model, args...; kwargs...)
    window = Blink.AtomShell.Window()
    body!(window, interface.page)

    BlinkOutput{T,typeof(interface)}(interface, window)
end

# Forward output methods to WebInterface. BlinkOutput is just a wrapper.
length(o::BlinkOutput) = length(o.interface)
size(o::BlinkOutput) = size(o.interface)
endof(o::BlinkOutput) = endof(o.interface)
firstindex(o::BlinkOutput) = firstidex(o.interface)
lastindex(o::BlinkOutput) = lastindex(o.interface)
getindex(o::BlinkOutput, i) = getindex(o.interface, i)
setindex!(o::BlinkOutput, x, i) = setindex!(o.interface, x, i)
push!(o::BlinkOutput, x) = push!(o.interface, x)
append!(o::BlinkOutput, x) = append!(o.interface, x)


clear!(o::BlinkOutput) = clear!(o.interface)
store_frame!(o::BlinkOutput, frame, t) = store_frame!(o.interface, frame, t)
update_frame!(o::BlinkOutput, frame, t) = update_frame!(o.interface, frame, t)
set_time!(o::BlinkOutput, t) = set_time!(o.interface, t)
set_timestamp!(o::BlinkOutput, t) = set_timestamp!(o.interface, t)
set_running!(o::BlinkOutput, x) = set_running!(o.interface, x) 
show_frame(o::BlinkOutput, t::Number) = show_frame(o.interface, t)
delay(o::BlinkOutput, t::Number) = delay(o.interface, t)

is_showable(o::BlinkOutput, t) = is_showable(o.interface, t)
is_async(o::BlinkOutput) = is_async(o.interface)
is_running(o::BlinkOutput) = is_alive(o) && is_running(o.interface)
is_alive(o::BlinkOutput) = o.window.content.sock.state == WebSockets.ReadyState(1)

last_t(o::BlinkOutput) = last_t(o.interface)
fps(o::BlinkOutput) = fps(o.interface)
curframe(o::BlinkOutput, t) = curframe(o.interface, t)

normalize_frame(o::BlinkOutput, a::AbstractArray) = normalize_frame(o.interface, a)
show_frame(o::BlinkOutput, args...) = show_frame(o, args...)
process_image(o::BlinkOutput, frame) = process_image(o, frame)

has_fps(o::BlinkOutput) = has_fps(o.interface)
has_minmax(o::BlinkOutput) = has_minmax(o.interface)
