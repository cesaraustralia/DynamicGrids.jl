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
sim!(output, model, args...; init=nothing, tstop=100, fps=get_fps(output)) = begin
    is_running(output) && return
    set_running!(output, true)

    # Set the output fps from keyword arg
    set_fps!(output, fps)
    # Delete frames output by the previous simulations
    delete_frames!(output)
    # Copy the init array from the model or keyword arg
    init = deepcopy(chooseinit(model.init, init))
    # Write the init array as the first frame
    store_frame!(output, init, 1)
    # Show the first frame
    show_frame(output, 1)
    # Run the simulation
    run_sim!(output, model, init, 2:tstop, args...)
    # Return the output object
    output
end

# Allows attaching an init array to the model, but also passing in an
# alternate array as a keyword arg (which will take preference).
chooseinit(modelinit, arginit) = arginit
chooseinit(modelinit::Nothing, arginit) = arginit
chooseinit(modelinit, arginit::Nothing) = modelinit
chooseinit(modelinit::Nothing, arginit::Nothing) =
    error("Include an init array: either with the model or the init keyword")

"""
    resume!(output, model, args...; tstop=100)

Restart the simulation where you stopped last time.

### Arguments
See [`sim!`](@ref).
"""
resume!(output, model, args...; tadd=100, fps=get_fps(output)) = begin
    is_running(output) && return
    length(output) > 0 || error("There is no simulation to resume. Run `sim!` first")
    set_running!(output, true) || return

    # Set the output fps from keyword arg
    set_fps!(output, fps)
    1:tadd .+ get_tlast(output) 
    # Use the last frame of the existing simulation as the init frame
    init = output[curframe(output, cur_t)]
    run_sim!(output, model, init, tspan, args...)
    output
end



"run the simulation either directly or asynchronously."
run_sim!(output, args...) =
    if is_async(output)
        @async simloop!(output, args...)
    else
        simloop!(output, args...)
    end

" Loop over the selected timespan, running model and displaying output "
simloop!(output, model, init, tspan, args...) = begin
    sze = size(init)

    # Set up the output
    initialize!(output, args...)

    # Preallocate arrays. These may be larger than init.
    source, dest = allocate_storage(model, init)

    set_timestamp!(output, tspan.start)

    for t in tspan
        # Collect the data elements for this frame
        data = simdata(model, source, dest, sze, t)
        # Run the automation on the source array, writing to the dest array and
        # setting the source and dest arrays for the next iteration.
        source, dest = run_model!(data, model.models, args...)
        # Save the the current frame
        store_frame!(output, source, t)
        # Display the current frame
        is_showable(output, t) && show_frame(output, t)
        # Let other tasks run (like ui controls)
        yield()
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
    allocate_storage(model, init)

Define the `source` and `dest` arrays for the model, possibly larger than the `init` array.
This is an optimisation to avoid the need for bounds checking in `rule`. Their size and
offset depend on the maximum model radius in the list of passed-in model.
"""

allocate_storage(model, init::AbstractArray) = allocate_storage(maxradius(model), init)
allocate_storage(r::Integer, init::AbstractArray) = begin
    # Find the maximum radius required by all models
    sze = size(init)
    newsize = sze .+ 2r
    # Add a margin around the original init array, offset into the negative
    # So that the first real cell is still 1, 1
    newindices = -r + 1:sze[1] + r, -r + 1:sze[2] + r
    source = OffsetArray(zeros(eltype(init), newsize...), newindices...)

    # Copy the init array to the middle section of the source array
    for j in 1:sze[2], i in 1:sze[1]
        source[i, j] = init[i,j]
    end
    # The dest array is the same as the source array
    dest = deepcopy(source)
    source, dest
end

"""
Find the largest radius present in the passed in models.
"""
maxradius(modelwrapper::Models) = maxradius(modelwrapper.models)
maxradius(models::Tuple{T,Vararg}) where T =
    max(maxradius(models[1]), maxradius(tail(models))...)
maxradius(models::Tuple{}) = 0
maxradius(model::AbstractModel) = radius(model)

radius(model::AbstractNeighborhoodModel) = radius(model.neighborhood)
radius(model::AbstractPartialNeighborhoodModel) = radius(model.neighborhood)
radius(model::AbstractModel) = 0
# For submodel tuples. Only the first submodel can have a radius.
radius(models::Tuple) = radius(models[1])


run_model!(data, models::Tuple, args...) = begin
    # Run the first model
    run_rule!(data, models[1], args...)
    # Swap the source and dest arrays
    tail_data = swapsource(data)
    # Run the rest of the models, recursively
    run_model!(tail_data, tail(models), args...)
end
run_model!(data, models::Tuple{}, args...) = source(data), dest(data)

" Run the rule for all cells, writing the result to the dest array"
run_rule!(data::AbstractSimData{T,1}, model::AbstractModel, args...) where T = 
    for i = 1:size(data)[1]
        @inbounds dest(data)[i] = rule(model, data, source(data)[i], (i), args...)
    end
run_rule!(data::AbstractSimData{T,2}, model::AbstractModel, args...) where T = 
    for i = 1:size(data)[1], j = 1:size(data)[2]
        @inbounds dest(data)[i, j] = rule(model, data, source(data)[i, j], (i, j), args...)
    end
run_rule!(data::AbstractSimData{T,3}, model::AbstractModel, args...) where T = 
    for i = 1:size(data)[1], j = 1:size(data)[2], k = 1:size(data)[3]
        @inbounds dest(data)[i, j, k] = rule(model, data, source(data)[i, j, k], (i, j, k), args...)
    end

"Run the rule for all cells, the rule must write to the dest array manually"
run_rule!(data::AbstractSimData{T,1}, model::AbstractPartialModel, args...) where T = begin
    # Initialise the dest array
    dest(data) .= source(data)
    for i in 1:size(data)[1]
        @inbounds rule!(model, data, source(data)[i], (i,), args...)
    end
end
run_rule!(data::AbstractSimData{T,2}, model::AbstractPartialModel, args...) where T = begin
    # Initialise the dest array
    dest(data) .= source(data)
    for i in 1:size(data)[1], j in 1:size(data)[2]
        @inbounds rule!(model, data, source(data)[i, j], (i, j), args...)
    end
end
run_rule!(data::AbstractSimData{T,3}, model::AbstractPartialModel, args...) where T = begin
    # Initialise the dest array
    dest(data) .= source(data)
    for i in 1:size(data)[1], j in 1:size(data)[2], k in 1:size(data)[2]
        @inbounds rule!(model, data, source(data)[i, j, k], (i, j, k), args...)
    end
end

"""
Run the rule for all cells, writing the result to the dest array
The neighborhood is copied to the models neighborhood buffer array for performance
"""
run_rule!(data::AbstractSimData{T,1}, model::Union{AbstractNeighborhoodModel, Tuple{AbstractNeighborhoodModel,Vararg}},
          args...)  where T = begin
    # The model provides the neighborhood buffer
    r = radius(model)
    sze = hoodsize(r)
    buf = similar(init(data), sze, sze)
    src, dst = source(data), dest(data)
    nrows = size(data)

    handle_overflow!(data, overflow(data), r)

    # Setup buffer array between rows
    # Ignore the first column, it wil be copied over in the main loop
    for i in 2:sze
        @inbounds buf[i] = src[i-1-r]
    end
    # Run rule for a row
    for i in 1:nrows
        @inbounds copyto!(buf, 1, buf, 2)
        @inbounds buf[sze] = src[i+r]
        @inbounds dst[i] = rule(model, data, buf[r+1], (i,), args...)
    end
end
run_rule!(data::AbstractSimData{T,2}, model::Union{AbstractNeighborhoodModel, Tuple{AbstractNeighborhoodModel,Vararg}},
          args...) where T = begin
    # The model provides the neighborhood buffer
    r = radius(model)
    sze = hoodsize(r)
    buf = similar(init(data), sze, sze)
    data = newbuffer(data, buf)
    src, dst = source(data), dest(data)
    nrows, ncols = size(data)

    handle_overflow!(data, overflow(data), r)

    # Run the model row by row. When we move along a row by one cell, we access only
    # a single new column of data same the hight of the nighborhood, and move the existing
    # data in the neighborhood buffer array accross by one column. This saves on reads
    # from the main array, and focusses reads and writes in the small buffere array that
    # should be in fast local memory.
    for i = 1:nrows
        # Setup the buffer array for the new row
        # Ignore the first column, it wil be copied over in the main loop
        for y = 2:sze
            for x = 1:sze
                @inbounds buf[x, y] = src[i+x-1-r, y-1-r]
            end
        end
        # Run rule for a row
        for j = 1:ncols
            # Move the neighborhood buffer accross one column 
            # copyto! uses linear indexing, so 2d dims are transformed manually
            @inbounds copyto!(buf, 1, buf, sze + 1, (sze - 1) * sze)
            # Copy a new column to the neighborhood buffer
            for x = 1:sze
                @inbounds buf[x, sze] = src[i+x-1-r, j+r]
            end
            # Run the rule using the buffer
            @inbounds dst[i, j] = 
            rule(model, data, buf[r+1, r+1], (i, j), args...)
        end
    end
end
# TODO 3d neighborhood


"""
Wrap overflow where required. This optimisation allows us to ignore
bounds checks on neighborhoods and still use a wraparound grid.
"""
handle_overflow!(data::AbstractSimData{T,1}, overflow::WrapOverflow, r) where T = begin
    # Copy two sides
    @inbounds copyto!(source, 1-r:0, source, nrows+1-r:nrows)
    @inbounds copyto!(source, nrows+1:nrows+r, source, 1:r)
end
handle_overflow!(data::AbstractSimData{T,2}, overflow::WrapOverflow, r) where T = begin
    nrows, ncols = size(data)
    src = source(data)
    # Left
    @inbounds copyto!(src, CartesianIndices((1:nrows, 1-r:0)),
                      src, CartesianIndices((1:nrows, ncols+1-r:ncols)))
    # Right
    @inbounds copyto!(src, CartesianIndices((1:nrows, ncols+1:ncols+r)),
                      src, CartesianIndices((1:nrows, 1:r)))
    # Top
    @inbounds copyto!(src, CartesianIndices((1-r:0, 1:ncols)),
                      src, CartesianIndices((ncols+1-r:ncols, 1:ncols)))
    # Bottom
    @inbounds copyto!(src, CartesianIndices((ncols+1:ncols+r, 1:ncols)),
                      src, CartesianIndices((1:r, 1:ncols)))

    # Copy four corners
    @inbounds copyto!(src, CartesianIndices((1-r:0, 1-r:0)),
                      src, CartesianIndices((nrows+1-r:nrows, ncols+1-r:ncols)))
    @inbounds copyto!(src, CartesianIndices((1-r:0, ncols+1:ncols+r)),
                      src, CartesianIndices((nrows+1-r:nrows, 1:r)))
    @inbounds copyto!(src, CartesianIndices((nrows+1:nrows+r, ncols+1:ncols+r)),
                      src, CartesianIndices((1:r, 1:r)))
    @inbounds copyto!(src, CartesianIndices((nrows+1:nrows+r, 1-r:0)),
                      src, CartesianIndices((1:r, ncols+1-r:ncols)))
end
handle_overflow!(data, overflow::RemoveOverflow, r) = nothing

"""
    rule(submodels::Tuple, data, state, (i, j), args...)

Submodel rule. If a tuple of models is passed in, run them all sequentially for each cell.
This can have much beter performance as no writes occur between models, and they are 
essentially compiled together into compound rules. This gives correct results only for
AbstractCellModel, or for a single AbstractNeighborhoodModel followed by AbstractCellModel.
"""
@inline rule(submodels::Tuple, data, state, index, args...) = begin
    state = rule(submodels[1], data, state, index, args...)
    rule(tail(submodels), data, state, index, args...)
end
@inline rule(submodels::Tuple{}, data, state, index, args...) = state


"""
    replay(output::AbstractOutput)
Show a stored simulation again. You can also use this to show a simulation
in different output type.

If you ran a simulation with `store=false` there won't be much to replay.

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

abstract type MyAbstractType{T <: AbstractFloat} end
struct MyConcreteType1{T} <: MyAbstractType{T} end
struct MyConcreteType2{T} <: MyAbstractType{T} end

function fun(x::MyAbstractType{U}, y::MyAbstractType{V}) where {U<:AbstractFloat, V<:AbstractFloat}
    println(typeof(x) )
    println(typeof(y) )
end
