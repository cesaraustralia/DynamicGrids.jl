"""
    sim!(output, model, init, args...; tstop=1000)

Runs the whole simulation, passing the destination aray to
the passed in output for each time-step.

### Arguments
- `output`: An [AbstractOutput](@ref) to store frames or display them on the screen.
- `model`: A Model() containing one ore more [`AbstractModel`](@ref). These will each be run in sequence.
- `init`: The initialisation array.
- `args`: additional args are passed through to [`rule`](@ref) and
  [`neighbors`](@ref) methods.

### Keyword Arguments
- `tstop`: Any Number. Default: 100
"""
sim!(output, models, init, args...; tstop=100) = begin
    is_running(output) && return
    set_running!(output, true) || return
    clear!(output)
    store_frame!(output, init, 1)
    show_frame(output, 1)
    @sync run_sim!(output, models, init, 2:tstop, args...)
    output
end

"""
    resume!(output, models, args...; tstop=100)

Restart the simulation where you stopped last time.

### Arguments
See [`sim!`](@ref).
"""
resume!(output, models, args...; tadd=100) = begin
    is_running(output) && return
    length(output) > 0 || error("run sim! first")
    set_running!(output, true) || return

    cur = lastindex(output)
    tspan = cur + 1:cur + tadd
    @sync run_sim!(output, models, output[cur], tspan, args...)
    output
end

"run the simulation either directly or asynchronously."
run_sim!(output, args...) =
    if is_async(output)
        f() = frameloop(output, args...)
        schedule(Task(f))
    else
        frameloop!(output, args...)
    end

" Loop over the selected timespan, running models and displaying output "
frameloop!(output, models, init, tspan, args...) = begin
    sze = size(init)

    # Set up the output
    initialize!(output, args...)

    # Define storage arrays. These  may be larger than init!
    source, dest = define_storage(models, init)

    set_timestamp!(output, tspan.start)

    for t in tspan
        # Collect the data elements for this frame
        data = FrameData(source, dest, sze, models.cellsize, models.timestep, t)
        # Run the automation on the source array, writing to the dest array and
        # setting the source and dest arrays for the next iteration.
        source, dest = run_model!(models.models, data, args...)
        # Save the the current frame
        store_frame!(output, source, t)
        # Display the current frame
        is_showable(output, t) && show_frame(output, t)
        # Let other tasks run (like ui controls)
        is_async(output) && yield()
        # Stick to the FPS
        delay(output, t)
        # Exit gracefully
        if !is_running(output) || t == tspan.stop
            show_frame(output, t)
            set_running!(output, false)
            # Any finishing touches required by the output
            finalize!(output)
            break
        end
    end
end

"""
    define_storage(models, init)

Define the source and dest arrays for the model. Their size and offset depend on the maximum
model radius in the list of passed-in models
"""
define_storage(models, init) = begin
    r = max_radius(models, init)
    sze = size(init)
    dims = sze .+ 2r
    source = OffsetArray(zeros(eltype(init), dims...), -r + 1:sze[1] + r, -r + 1:sze[2] + r)
    source .= 0.0

    for j in 1:sze[2], i in 1:sze[1]
        @inbounds source[i, j] = init[i,j]
    end
    dest = deepcopy(source)
    source, dest
end

"""
Find the largest radius present in the passed in models.
"""
max_radius(model::AbstractModel, init) = radius(model)
max_radius(modelwrapper::Models, init) = max_radius(modelwrapper.models, init)
max_radius(models::Tuple{T,Vararg}, init) where T =
    max(max_radius(models[1], init), max_radius(tail(models), init)...)
max_radius(models::Tuple{}, init) = 0

"""
Return the radius of a model if it has one, otherwise zero.
"""
function radius end
radius(model::AbstractNeighborhoodModel) = radius(model.neighborhood)
radius(model::AbstractPartialNeighborhoodModel) = radius(model.neighborhood)
radius(model::AbstractModel) = 0
radius(models::Tuple) = radius(models[1])

"""
AbstractNeighborhoodModel requires a temp array. `temp_neighborhood()` must be defined to return it.
"""
function temp_neighborhood end
temp_neighborhood(model::T) where T =
    error("Add a temp_neighborhood(model::$T) method that returns the array location for your model")
temp_neighborhood(models::Tuple) = temp_neighborhood(models[1])

"""
    run_model!(models::Tuple{T,Vararg}, source, dest, args...)
per
Iterate over all models recursively, swapping source and dest arrays.

Returns a tuple containing the source and dest arrays for the next iteration.
"""
function run_model! end
run_model!(models::Tuple, data, args...) = begin
    # Run the first model
    run_rule!(models[1], data, args...)
    # Swap the source and dest arrays
    tail_data = FrameData(data.dest, data.source, data.dims, data.cellsize, data.timestep, data.t)
    # Run the rest of the models, recursively 
    run_model!(tail(models), tail_data, args...)
end
run_model!(models::Tuple{}, data, args...) = data.source, data.dest

"""
    run_rule!(models, data, indices, args...)

Runs the rule(s) for each cell in the grid, dependin on the model(s) passed in.
For [`AbstractModel`] the returned values are written to the `dest` grid,
while for [`AbstractPartialModel`](@ref) the grid is
pre-initialised to zero and rules manually populate the dest grid.
"""
function run_rule! end
run_rule!(model::AbstractModel, data, args...) = begin
    # Run the rule for all cells, writing the result to the dest array
    for i = 1:data.dims[1]
        for j = 1:data.dims[2]
            @inbounds data.dest[i, j] = rule(model, data, data.source[i, j], (i, j), args...)
        end
    end
end
run_rule!(model::AbstractPartialModel, data, args...) = begin
    # Initialise the dest array
    data.dest .= data.source
    # Run the rule for all cells, the rule must write to the dest array manually
    for i = 1:data.dims[1]
        for j = 1:data.dims[2]
            @inbounds rule!(model, data, data.source[i, j], (i, j), args...)
        end
    end
end
run_rule!(model::Union{AbstractNeighborhoodModel, Tuple{AbstractNeighborhoodModel,Vararg}},
                       data, args...) = begin
    temp = temp_neighborhood(model)
    r = radius(model)
    h, w = size(temp)

    # Run the rule for all cells, writing the result to the dest array
    # The neighborhood is copied to the models temp neighborhood array for performance
    for i = 1:data.dims[1]
        # Setup temp array between rows
        for b = 1:r+1
            for a = 1:h
                @inbounds temp[a, b] = zero(eltype(temp))
            end
        end
        for b = r+2:w
            for a = 1:h
                @inbounds temp[a, b] = data.source[i+a-1-r, b-1-r]
            end
        end
        # Run rule for a row
        for j = 1:data.dims[2]
            @inbounds copyto!(temp, 1, temp, h + 1, (w - 1) * h)
            for a = 1:h
                @inbounds temp[a, w] = data.source[i+a-1-r, j+r]
            end
            @inbounds data.dest[i, j] = rule(model, data, data.source[i, j], (i, j), args...)
        end
    end
end

"""
    function rule(model, state, t, source, dest, args...)

Rules alter cell values based on their current state and other cells, often
[`neighbors`](@ref).

### Arguments:
- `model` : [`AbstractModel`](@ref)
- `data` : [`FrameData`](@ref)
- `state`: the value of the current cell
- `index`: a (row, column) tuple of Int for the current cell coordinates - `t`: the current time step
- `args`: additional arguments passed through from user input to [`sim!`](@ref)

Returns a value to be written to the current cell.
"""
function rule(model::Nothing, data, state, index, args...) end

"""
    rule(submodels::Tuple, data, state, (i, j), args...)

Submodel rule. If a tuple of models is passed in, run the all sequentially for each cell.

This gives correct results only for AbstractCellModel or for a single AbstractNeighborhoodModel
followed by AbstractCellModel.
"""
@inline rule(submodels::Tuple, data, state, index, args...) = begin
    state = rule(submodels[1], data, state, index, args...)
    rule(tail(submodels), data, state, index, args...)
end
@inline rule(submodels::Tuple{}, data, state, index, args...) = state

"""
    function rule!(model, data, state, args...)
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
    set_running!(output, true)
    initialize!(output)
    for (t, frame) in enumerate(output)
        delay(output, t)
        show_frame(output, t)
        is_running(output) || break
    end
    set_running!(output, false)
end
