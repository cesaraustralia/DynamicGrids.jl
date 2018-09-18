"""
A model contains all the information required to run a rule in a cellular
simulation, given an initialised array. Models can be chained together in any order.

The output of the rule for an AbstractModel is written to the current cell in the grid.
"""
abstract type AbstractModel end

"""
An abstract type for models that do not write to every cell of the grid, for efficiency.

There are two main differences with `AbstractModel`. AbstractPartialModel requires
initialisation of the destination array before each timestep, and the output of
the rule is not written to the grid but done manually.
"""
abstract type AbstractPartialModel end


"""
Singleton types for choosing the grid overflow rule used in
[`inbounds`](@ref). These determine what is done when a neighborhood
or jump extends outside of the grid.
"""
abstract type AbstractOverflow end
"Wrap cords that overflow to the opposite side"
struct Wrap <: AbstractOverflow end
"Skip coords that overflow boundaries"
struct Skip <: AbstractOverflow end

" A mutable container for models. 
This allows updating of immutable values for live control, such as with 
BlinkOutput, while keeping the core model immutable for GPU compatability."
mutable struct Models{M} models::M
    Models(args...) = new{typeof(args)}(args)
end



"""
    sim!(output, model, init, args...; time=1000)
Runs the whole simulation, passing the destination aray to
the passed in output for each time-step.

### Arguments
- `output`: An [AbstractOutput](@ref) to store frames or display them on the screen.
- `model`: A Model() containing one ore more [`AbstractModel`](@ref). These will each be run in sequence.
- `init`: The initialisation array.
- `args`: additional args are passed through to [`rule`](@ref) and
  [`neighbors`](@ref) methods.

### Keyword Arguments
- `time`: Any Number. Default: 100
"""
sim!(output, models, init, args...; time=100) = begin
    is_running(output) && return
    set_running(output, true)
    clear(output)
    store_frame(output, init, 1)
    show_frame(output, 1) 
    run!(output, models, init, 2:time, args...)
    output
end

"""
    resume!(output, models, args...; time=100)
Restart the simulation where you stopped last time.

### Arguments
See [`sim!`](@ref). 
"""
resume!(output, models, args...; time=100) = begin
    is_running(output) && return
    set_running(output, true)
    timespan = 1 + lastindex(output):lastindex(output) + time
    run!(output, models, output[end], timespan, args...)
    output
end

run!(output, args...) = 
    if is_async(output) 
        f() = frameloop(output, args...)
        schedule(Task(f))
    else
        frameloop(output, args...)
    end

# Loop over the selected timespan
frameloop(output, model, init, time, args...) = begin
    # Define the index coordinates. There might be a better way than this?
    h, w = size(init)
    rows = typeof(similar(init, Int))(collect(row for row in 1:h, col in 1:w))
    cols = typeof(similar(init, Int))(collect(col for row in 1:h, col in 1:w))

    initialize(output)
    source = deepcopy(init)
    dest = deepcopy(init)
    set_timestamp(output, time.start)

    for t in time
        t = t
        # Run the automation on the source array, writing to the dest array and
        # setting the source and dest arrays for the next iteration.
        source, dest = broadcast_rules!(model.models, source, dest, rows, cols, t, args...)
        # Save the the current frame
        store_frame(output, source, t)
        # Display the current frame
        use_frame(output, t) && show_frame(output, t)
        # Let other tasks run (like ui controls)
        is_async(output) && yield()
        # Stick to the FPS
        delay(output, t)
        # Exit gracefully
        if !is_running(output) || t == time.stop 
            show_frame(output, t)
            set_running(output, false)
            finalize(output)
            break
        end
    end
end

"""
    broadcast_rules!(models, source, dest, rows, cols, t, args...)
Internal method that runs the rule(s) for each cell in the grid, dependin on the model(s) passed in.
For [`AbstractModel`] the returned values are written to the `dest` grid,
while for [`AbstractPartialModel`](@ref) the grid is
pre-initialised to zero and rules manually populate the dest grid.

Returns a tuple containing the source and dest arrays for the next iteration.
"""
broadcast_rules!(models::Tuple{T,Vararg}, source, dest, rows, cols, t, args...
                ) where {T<:AbstractModel} = begin
    # Write rule outputs to every cell of the dest array
    broadcast!(rule, dest, Ref(models[1]), source, rows, cols, t, (source,), (dest,), tuple.(args)...)
    # Swap source and dest for the next rule/iteration
    broadcast_rules!(Base.tail(models), dest, source, rows, cols, t, args...)
end
broadcast_rules!(models::Tuple{T,Vararg}, source, dest, rows, cols, t, args...
                ) where {T<:AbstractPartialModel} = begin
    # Initialise the dest array
    dest .= source
    # The rule writes to the dest array manually where required
    broadcast(rule!, Ref(models[1]), source, rows, cols, t, (source,), (dest,), tuple.(args)...)
    # Swap source and dest for the next rule/iteration
    broadcast_rules!(Base.tail(models), dest, source, rows, cols, t, args...)
end
broadcast_rules!(models::Tuple{}, source, dest, rows, cols, t, args...) = source, dest


"""
    function rule(model, state, rows, cols, t, source, dest, args...)
Rules alter cell values based on their current state and other cells, often
[`neighbors`](@ref). Most rules return a value to be written to the current cell,
except rules for models inheriting from [`AbstractPartialModel`](@ref).
These must write to the `dest` array directly.

### Arguments:
- `model` : [`AbstractModel`](@ref)
- `state`: the value of the current cell
- `index`: a (row, column) tuple of Int for the current cell coordinates - `t`: the current time step
- `source`: the whole source array. Not to be written to
- `dest`: the whole destination array. To be written to for AbstractPartialModel.
- `args`: additional arguments passed through from user input to [`sim!`](@ref)
"""
function rule(model::Nothing, state, row, col, t, source, dest, args...) end

"""
    function rule!(model, state, rows, cols, t, source, dest, args...)
A rule that writes to the dest array, used in partial models. 

### Arguments:
see [`rule`](@ref) 
"""
function rule!(model::Nothing, state, row, col, t, source, dest, args...) end

"""
    inbounds(x, max, overflow)
Check grid boundaries for a single coordinate and max value or a tuple
of coorinates and max values.

Returns a tuple containing the coordinate(s) followed by a boolean `true`
if the cell is in bounds, `false` if not.

Overflow of type [`Skip`](@ref) returns the coordinate and `false` to skip
coordinates that overflow outside of the grid.
[`Wrap`](@ref) returns a tuple with the current position or it's
wrapped equivalent, and `true` as it is allways in-bounds.
"""
inbounds(xs::Tuple, maxs::Tuple, overflow) = begin
    a, inbounds_a = inbounds(xs[1], maxs[1], overflow)
    b, inbounds_b = inbounds(xs[2], maxs[2], overflow)
    a, b, inbounds_a && inbounds_b
end
inbounds(x::Number, max::Number, overflow::Skip) = x, x > zero(x) && x <= max
inbounds(x::Number, max::Number, overflow::Wrap) =
    if x < oneunit(x)
        max + rem(x, max), true
    elseif x > max
        rem(x, max), true
    else
        x, true
    end

"""
    replay(output::AbstractOutput) = begin
Show the simulation again. You can also use this to show a sequence 
run with a different output type.

### Example
```julia
replay(REPLOutput(output))
```
"""
replay(output::AbstractOutput) = begin
    is_running(output) && return
    set_running(output, true)
    initialize(output)
    for (t, frame) in enumerate(output)
        delay(output, t)
        show_frame(output, t)
        is_running(output) || break
    end
    set_running(output, false)
end
