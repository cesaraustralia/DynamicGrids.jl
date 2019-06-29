"""
    sim!(output, ruleset, init; tstop=1000)

Runs the whole simulation, passing the destination aray to
the passed in output for each time-step.

### Arguments
- `output`: An [AbstractOutput](@ref) to store frames or display them on the screen.
- `ruleset`: A Rule() containing one ore more [`AbstractRule`](@ref). These will each be run in sequence.
- `init`: The initialisation array.
- `args`: additional args are passed through to [`rule`](@ref) and
  [`neighbors`](@ref) methods.

### Keyword Arguments
- `tstop`: Any Number. Default: 100
"""
sim!(output, ruleset; init=nothing, tstop=100, fps=get_fps(output)) = begin
    is_running(output) && return
    set_running!(output, true)

    # Set the output fps from keyword arg
    set_fps!(output, fps)
    # Delete frames output by the previous simulations
    delete_frames!(output)
    # Copy the init array from the ruleset or keyword arg
    init = deepcopy(chooseinit(ruleset.init, init))
    # Write the init array as the first frame
    store_frame!(output, init, 1)
    # Show the first frame
    show_frame(output, 1)
    # Run the simulation
    run_sim!(output, ruleset, init, 2:tstop)
    # Return the output object
    output
end

# Allows attaching an init array to the ruleset, but also passing in an
# alternate array as a keyword arg (which will take preference).
chooseinit(rulesetinit, arginit) = arginit
chooseinit(rulesetinit::Nothing, arginit) = arginit
chooseinit(rulesetinit, arginit::Nothing) = rulesetinit
chooseinit(rulesetinit::Nothing, arginit::Nothing) =
    error("Include an init array: either with the ruleset or the init keyword")

"""
    resume!(output, ruleset; tstop=100)

Restart the simulation where you stopped last time.

### Arguments
See [`sim!`](@ref).
"""
resume!(output, ruleset; tadd=100, fps=get_fps(output)) = begin
    is_running(output) && return
    length(output) > 0 || error("There is no simulation to resume. Run `sim!` first")
    set_running!(output, true) || return

    # Set the output fps from keyword arg
    set_fps!(output, fps)
    cur_t = get_tlast(output)
    tspan = cur_t + 1:cur_t + tadd
    # Use the last frame of the existing simulation as the init frame
    init = output[curframe(output, cur_t)]
    run_sim!(output, ruleset, init, tspan)
    output
end



"run the simulation either directly or asynchronously."
run_sim!(output, args...) =
    if is_async(output)
        @async simloop!(output, args...)
    else
        simloop!(output, args...)
    end

" Loop over the selected timespan, running the ruleset and displaying the output"
simloop!(output, ruleset, init, tspan) = begin
    sze = size(init)

    # Set up the output
    initialize!(output)

    # Preallocate arrays. These may be larger than init.
    source, dest = allocate_storage(ruleset, init)

    set_timestamp!(output, tspan.start)

    for t in tspan
        # Collect the data elements for this frame
        data = simdata(ruleset, source, dest, sze, t)
        # Run the ruleset on the source array, writing to the dest array and
        # setting the source and dest arrays for the next iteration.
        source, dest = sequencerules!(data, ruleset)
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
    allocate_storage(ruleset, init)

Define the `source` and `dest` arrays for the ruleset, possibly larger than the `init` array.
This is an optimisation to avoid the need for bounds checking in `rule`. Their size and
offset depend on the maximum rule radius in the list of passed-in rules.
"""

allocate_storage(ruleset, init::AbstractArray) = allocate_storage(maxradius(ruleset), init)
allocate_storage(r::Integer, init::AbstractArray) = begin
    # Find the maximum radius required by all rules
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
Find the largest radius present in the passed in rules.
"""
maxradius(ruleset::Ruleset) = maxradius(ruleset.rules)
maxradius(rules::Tuple{T,Vararg}) where T =
    max(maxradius(rules[1]), maxradius(tail(rules))...)
maxradius(rules::Tuple{}) = 0
maxradius(rule::AbstractRule) = radius(rule)

radius(rule::AbstractNeighborhoodRule) = radius(rule.neighborhood)
radius(rule::AbstractPartialNeighborhoodRule) = radius(rule.neighborhood)
radius(rule::AbstractRule) = 0
# For rule chain tuples. Only the first rule can have a radius.
radius(rules::Tuple) = radius(rules[1])


"""
Iterate over all rules recursively, swapping source and dest arrays.
Returns a tuple containing the source and dest arrays for the next iteration.
"""
sequencerules!(data, ruleset::Ruleset) = 
    sequencerules!(data, ruleset.rules)
sequencerules!(data, rules::Tuple) = begin
    # Run the first rule for the whole frame
    map_rule!(data, rules[1])
    # Swap the source and dest arrays
    tail_data = swapsource(data)
    # Run the rest of the rules, recursively
    sequencerules!(tail_data, tail(rules))
end
sequencerules!(data, rules::Tuple{}) = source(data), dest(data)

"""
Apply the rule for each cell in the grid, using optimisations 
allowed for the supertype of the rule.
"""
map_rule!(data::AbstractSimData{T,1}, rule::AbstractRule) where T = 
    for i = 1:size(data)[1]
        @inbounds dest(data)[i] = applyrule(rule, data, source(data)[i], (i))
    end
map_rule!(data::AbstractSimData{T,2}, rule::AbstractRule) where T = 
    for i = 1:size(data)[1], j = 1:size(data)[2]
        @inbounds dest(data)[i, j] = applyrule(rule, data, source(data)[i, j], (i, j))
    end
map_rule!(data::AbstractSimData{T,3}, rule::AbstractRule) where T = 
    for i = 1:size(data)[1], j = 1:size(data)[2], k = 1:size(data)[3]
        @inbounds dest(data)[i, j, k] = applyrule(rule, data, source(data)[i, j, k], (i, j, k))
    end

"Run the rule for all cells, the rule must write to the dest array manually"
map_rule!(data::AbstractSimData{T,1}, rule::AbstractPartialRule) where T = begin
    # Initialise the dest array
    dest(data) .= source(data)
    for i in 1:size(data)[1]
        @inbounds applyrule!(rule, data, source(data)[i], (i,))
    end
end
map_rule!(data::AbstractSimData{T,2}, rule::AbstractPartialRule) where T = begin
    # Initialise the dest array
    dest(data) .= source(data)
    for i in 1:size(data)[1], j in 1:size(data)[2]
        @inbounds applyrule!(rule, data, source(data)[i, j], (i, j))
    end
end
map_rule!(data::AbstractSimData{T,3}, rule::AbstractPartialRule) where T = begin
    # Initialise the dest array
    dest(data) .= source(data)
    for i in 1:size(data)[1], j in 1:size(data)[2], k in 1:size(data)[2]
        @inbounds applyrule!(rule, data, source(data)[i, j, k], (i, j, k))
    end
end

"""
Run the rule for all cells, writing the result to the dest array
The neighborhood is copied to the rules neighborhood buffer array for performance
"""
map_rule!(data::AbstractSimData{T,1}, rule::Union{AbstractNeighborhoodRule, Tuple{AbstractNeighborhoodRule,Vararg}},
          args...)  where T = begin
    # The rule provides the neighborhood buffer
    r = radius(rule)
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
        @inbounds state = buf[r+1]
        newstate = applyrule(rule, data, state, (i,))
        @inbounds dst[i] = newstate
    end
end
map_rule!(data::AbstractSimData{T,2}, rule::Union{AbstractNeighborhoodRule, Tuple{AbstractNeighborhoodRule,Vararg}},
          args...) where T = begin
    # The rule provides the neighborhood buffer
    r = radius(rule)
    sze = hoodsize(r)
    buf = similar(init(data), sze, sze)
    data = newbuffer(data, buf)
    src, dst = source(data), dest(data)
    nrows, ncols = size(data)

    handle_overflow!(data, overflow(data), r)

    # Run the rule row by row. When we move along a row by one cell, we access only
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
                @inbounds buf[x, sze] = src.parent[i+x-1, j+2r]
            end
            # Run the rule using the buffer
            @inbounds state = buf[r+1, r+1]
            newstate = applyrule(rule, data, state, (i, j))
            @inbounds dst.parent[i+r, j+r] = newstate
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
    applyrule(rules::Tuple, data, state, (i, j))

Subrules. If a tuple of rules is passed to applyrule, run them sequentially for each cell.
This can have much beter performance as no writes occur between rules, and they are 
essentially compiled together into compound rules. This gives correct results only for
AbstractCellRule, or for a single AbstractNeighborhoodRule followed by AbstractCellRule.
"""
@inline applyrule(rules::Tuple, data, state, index) = begin
    state = applyrule(rules[1], data, state, index)
    applyrule(tail(rules), data, state, index)
end
@inline applyrule(rules::Tuple{}, data, state, index) = state


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
