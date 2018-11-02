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
    set_running(output, true) || return
    clear(output)
    store_frame(output, init, 1)
    show_frame(output, 1) 
    run_sim!(output, models, init, 2:time, args...)
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
    set_running(output, true) || return
    timespan = 1 + lastindex(output):lastindex(output) + time
    run_sim!(output, models, output[end], timespan, args...)
    output
end

run_sim!(output, args...) = 
    if is_async(output) 
        f() = frameloop(output, args...)
        schedule(Task(f))
    else
        frameloop(output, args...)
    end

" Loop over the selected timespan, running models and displaying output "
frameloop(output, models, init, time, args...) = begin
    h, w = size(init)
    indices = broadcastable_indices(init)

    initialize(output)
    set_timestamp(output, time.start)

    source = deepcopy(init)
    dest = deepcopy(init)

    for t in time
        # Run the automation on the source array, writing to the dest array and
        # setting the source and dest arrays for the next iteration.
        data = ModelData(models.cellsize, source, dest, t)
        source, dest = run_models!(models.models, data, indices, args...)
        # Save the the current frame
        store_frame(output, source, t)
        # Display the current frame
        is_showable(output, t) && show_frame(output, t)
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
    run_models!(models::Tuple{T,Vararg}, source, dest, args...)

Iterate over all models recursively, swapping source and dest arrays. 

Returns a tuple containing the source and dest arrays for the next iteration.
"""
run_models!(models::Tuple, data, args...) = begin
    broadcast_rule!(models[1], data, args...)
    data = ModelData(data.cellsize, data.dest, data.source, data.t)
    run_models!(Base.tail(models), data, args...)
end
run_models!(models::Tuple{}, data, args...) = data.source, data.dest 


"""
    broadcast_rules!(models, data, indices, args...)

Runs the rule(s) for each cell in the grid, dependin on the model(s) passed in.
For [`AbstractModel`] the returned values are written to the `dest` grid,
while for [`AbstractPartialModel`](@ref) the grid is
pre-initialised to zero and rules manually populate the dest grid.
"""
broadcast_rule!(model::AbstractModel, data, indices, args...) = begin
    broadcast!(rule, data.dest, Ref(model), Ref(data), data.source, indices, tuple.(args)...)
end
broadcast_rule!(model::AbstractPartialModel, data, indices, args...) = begin
    # Initialise the dest array
    data.dest .= data.source
    broadcast(rule!, Ref(model), Ref(data), data.source, indices, tuple.(args)...)
end


"""
    function rule(model, state, indices, t, source, dest, args...)

Rules alter cell values based on their current state and other cells, often
[`neighbors`](@ref). 

### Arguments:
- `model` : [`AbstractModel`](@ref)
- `data` : [`ModelData`](@ref)
- `state`: the value of the current cell
- `index`: a (row, column) tuple of Int for the current cell coordinates - `t`: the current time step
- `args`: additional arguments passed through from user input to [`sim!`](@ref)

Returns a value to be written to the current cell.
"""
function rule(model::Nothing, data, state, index, args...) end

"""
    function rule!(model, data, state, indices, args...)
A rule that manually writes to the dest array, used in models inheriting 
from [`AbstractPartialModel`](@ref).

### Arguments:
see [`rule`](@ref) 
"""
function rule!(model::Nothing, data, state, index, args...) end

"""
    replay(output::AbstractOutput)
Show the stored simulation again. You can also use this to show a sequence 
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
