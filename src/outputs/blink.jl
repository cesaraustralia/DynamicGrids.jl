using Blink

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
@flattenable mutable struct BlinkOutput{T, I<:WebInterface{T}} <: AbstractWebOutput{T} 
    interface::I                   | Include()
    window::Blink.AtomShell.Window | Exclude()
end

"""
    BlinkOutput(frames)
Constructor for BlinkOutput.
### Arguments
- `frames::AbstractArray`: vector of matrices.
- `model::Models`: tuple of models wrapped in Models().
- `args`: any additional arguments to be passed to `sim!` and `resume!`

### Keyword arguments
- `aspec_ratio` : passed to the plots heatmap, default is :equal
- `kwargs` : extra keyword args to modify the heatmap
"""
BlinkOutput(frames::T, model, args...; fps=25, kwargs...) where T <: AbstractVector = begin
    interface = WebInterface(frames, fps, deepcopy(model), args...)
    window = Blink.AtomShell.Window()

    body!(window, interface.page)
    BlinkOutput{T,typeof(interface)}(interface, window)
end

# Forward output methods to WebInterface. BlinkOutput is just a wrapper.
length(o::BlinkOutput) = length(o.interface)
size(o::BlinkOutput) = size(o.interface)
endof(o::BlinkOutput) = endof(o.interface)
getindex(o::BlinkOutput, i) = getindex(o.interface, i)
setindex!(o::BlinkOutput, x, i) = setindex!(o.interface, x, i)
push!(o::BlinkOutput, x) = push!(o.interface, x)
append!(o::BlinkOutput, x) = append!(o.interface, x)
clear(o::BlinkOutput) = clear(o.interface)
store_frame(o::BlinkOutput, frame) = store_frame(o.interface, frame)
show_frame(o::BlinkOutput, frame) = show_frame(o.interface, frame)

is_running(o::BlinkOutput) = is_running(o.interface)
set_running(o::BlinkOutput, x) = set_running(o.interface, x) 
