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
    set_running(output, true) || return
    clear(output)
    allocate(output, init, 1:tstop)
    store_frame(output, init, 1)
    show_frame(output, 1)
    run_sim!(output, models, init, 2:tstop, args...)
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
    set_running(output, true) || return
    tspan = 1 + lastindex(output):lastindex(output) + tadd
    run_sim!(output, models, output[end], tspan, args...)
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
frameloop(output, models, init, tspan, args...) = begin
    h, w = size(init)
    indices = broadcastable_indices(init)

    initialize(output, args...)
    modeldata = prepare(models, init)

    source = deepcopy(init)
    dest = deepcopy(init)

    set_timestamp(output, tspan.start)

    for t in tspan
        # Run the automation on the source array, writing to the dest array and
        # setting the source and dest arrays for the next iteration.
        data = FrameData(source, dest, models.cellsize, t, modeldata)
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
        if !is_running(output) || t == tspan.stop
            show_frame(output, t)
            set_running(output, false)
            finalize(output)
            break
        end
    end
end

prepare(modelwrapper::Models, init) = prepare(modelwrapper.models, init)
prepare(models::Tuple{T,Vararg}, init) where T =
    (prepare(models[1], init), prepare(Base.tail(models), init)...)
prepare(models::Tuple{}, init) = ()
prepare(model::AbstractModel, init) = ()
prepare(model::AbstractNeighborhoodModel, init) = begin
    extended = zeros(eltype(init), (size(init) .+ 2model.neighborhood.radius)...)
    loc = zeros(eltype(init), size(model.neighborhood.kernel)...)
    NieghborhoodMem(extended, loc)
end

"""
    run_models!(models::Tuple{T,Vararg}, source, dest, args...)
per
Iterate over all models recursively, swapping source and dest arrays.

Returns a tuple containing the source and dest arrays for the next iteration.
"""
run_models!(models::Tuple, data, args...) = begin
    broadcast_rule!(models[1], data, args...)
    data = FrameData(data.dest, data.source, data.cellsize, data.t, Base.tail(data.modeldata))
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
broadcast_rule!(model::AbstractNeighborhoodModel, data, indices, args...) = begin
    r = model.neighborhood.radius
    s = size(data.source)
    lge = data.modeldata[1].extended
    sml = data.modeldata[1].loc
    for j in 1:s[2]
        @simd for i in 1:s[1] 
            @inbounds lge[i+r, j+r] = data.source[i,j]
        end
    end

    h, w = size(model.neighborhood.kernel)
    for i = 1:s[1]
        for b = 1:1+2r
            @simd for a = 1:1+2r
                @inbounds sml[a, b] = zero(eltype(sml)) 
            end
        end
        for b = r+1:2r
            @simd for a = 1:1+2r
                @inbounds sml[a, b] = lge[i+a-1, b+r]
            end
        end
        for j = 1:s[2]
            @inbounds copyto!(sml, 1, sml, h + 1, (w - 1) * h)
            @simd for a = 1:1+2r
                @inbounds sml[a, w] = lge[i+a-1, j+2r]
            end
            @inbounds data.dest[i, j] = rule(model, data, sml[r+1, r+1], (i, j), args...)
        end
    end
end

"""
    function rule(model, state, indices, t, source, dest, args...)

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
