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
sim!(output, ruleset; init=nothing, tstop=length(output), fps=getfps(output)) = begin
    isrunning(output) && return
    setrunning!(output, true)

    # Set the output fps from keyword arg
    setfps!(output, fps)
    # Delete frames output by the previous simulations
    deleteframes!(output)
    # Copy the init array from the ruleset or keyword arg
    init = deepcopy(chooseinit(ruleset.init, init))
    # Write the init array as the first frame
    storeframe!(output, init, 1)
    # Show the first frame
    showframe(output, ruleset, 1)
    # Run the simulation
    runsim!(output, ruleset, init, 2:tstop)
    # Return the output object
    output
end

# Allows attaching an init array to the ruleset, but also passing in an
# alternate array as a keyword arg (which will take preference).
chooseinit(rulesetinit, arginit) = arginit
chooseinit(rulesetinit::Nothing, arginit) = arginit
chooseinit(rulesetinit, arginit::Nothing) = rulesetinit
chooseinit(rulesetinit::Nothing, arginit::Nothing) =
    error("Include an init array: either in the ruleset or with the `init` keyword")

"""
    resume!(output, ruleset; tstop=100)

Restart the simulation where you stopped last time.

### Arguments
See [`sim!`](@ref).
"""
resume!(output, ruleset; tadd=100, fps=getfps(output)) = begin
    isrunning(output) && return
    length(output) > 0 || error("There is no simulation to resume. Run `sim!` first")
    setrunning!(output, true) || return

    # Set the output fps from keyword arg
    setfps!(output, fps)
    cur_t = gettlast(output)
    tspan = cur_t + 1:cur_t + tadd
    # Use the last frame of the existing simulation as the init frame
    init = output[curframe(output, cur_t)]
    runsim!(output, ruleset, init, tspan)
end


"run the simulation either directly or asynchronously."
runsim!(output, args...) =
    if isasync(output)
        @async simloop!(output, args...)
    else
        simloop!(output, args...)
    end

" Loop over the selected timespan, running the ruleset and displaying the output"
simloop!(output, ruleset, init, tspan) = begin
    # Set up the output
    initialize!(output)
    settimestamp!(output, tspan.start)

    # Preallocate data
    data = simdata(ruleset, init)

    # Loop over the simulation
    for t in tspan
        # Update the timestep
        data = updatetime(data, t)
        # Run the ruleset and setup data for the next iteration
        data = sequencerules!(data, ruleset)
        # Save the the current frame
        storeframe!(output, source(data), t)
        # Display the current frame
        isshowable(output, t) && showframe(output, ruleset, t)
        # Let other tasks run (like ui controls) TODO is this needed?
        yield()
        # Stick to the FPS
        delay(output, t)
        # Exit gracefully
        if !isrunning(output) || t == tspan.stop
            showframe(output, ruleset, t)
            setrunning!(output, false)
            # Any finishing touches required by the output
            finalize!(output)
            break
        end
    end
    output
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
sequencerules!(data, ruleset::Ruleset) = sequencerules!(data, ruleset.rules)
sequencerules!(data, rules::Tuple) = begin
    # Run the first rule for the whole frame
    maprule!(data, rules[1])
    # Swap the source and dest arrays
    data = swapsource(data)
    # Run the rest of the rules, recursively
    sequencerules!(data, tail(rules))
end
sequencerules!(data, rules::Tuple{}) = SimData(data)

"""
Apply the rule for each cell in the grid, using optimisations 
allowed for the supertype of the rule.
"""
maprule!(data::AbstractSimData{T,1}, rule) where T = 
    for i = 1:framesize(data)[1]
        ismasked(data, i) && continue
        @inbounds dest(data)[i] = applyrule(rule, data, source(data)[i], (i))
    end
maprule!(data::AbstractSimData{T,2}, rule) where T = 
    for i = 1:framesize(data)[1], j = 1:framesize(data)[2]
        ismasked(data, i, j) && continue
        @inbounds dest(data)[i, j] = applyrule(rule, data, source(data)[i, j], (i, j))
    end
maprule!(data::AbstractSimData{T,3}, rule) where T = 
    for i = 1:framesize(data)[1], j = 1:framesize(data)[2], k = 1:framesize(data)[3]
        ismasked(data, i, j, k) && continue
        @inbounds dest(data)[i, j, k] = applyrule(rule, data, source(data)[i, j, k], (i, j, k))
    end

"Run the rule for all cells, the rule must write to the dest array manually"
maprule!(data::AbstractSimData{T,1}, rule::AbstractPartialRule) where T = begin
    # Initialise the dest array
    data = WritableSimData(data)
    dest(data) .= source(data)
    for i in 1:framesize(data)[1]
        ismasked(data, i) && continue
        @inbounds applyrule!(rule, data, source(data)[i], (i,))
    end
end
maprule!(data::AbstractSimData{T,2}, rule::AbstractPartialRule) where T = begin
    # Initialise the dest array
    data = WritableSimData(data)
    dest(data) .= source(data)
    for i in 1:framesize(data)[1], j in 1:framesize(data)[2]
        ismasked(data, i, j) && continue
        @inbounds applyrule!(rule, data, source(data)[i, j], (i, j))
    end
end
maprule!(data::AbstractSimData{T,3}, rule::AbstractPartialRule) where T = begin
    # Initialise the dest array
    data = WritableSimData(data)
    dest(data) .= source(data)
    for i in 1:framesize(data)[1], j in 1:size(data)[2], k in 1:framesize(data)[2]
        ismasked(data, i, j, k) && continue
        @inbounds applyrule!(rule, data, source(data)[i, j, k], (i, j, k))
    end
end

"""
Run the rule for all cells, writing the result to the dest array
The neighborhood is copied to the rules neighborhood buffer array for performance
# TODO test 1d
"""
maprule!(data::AbstractSimData{T,1}, rule::Union{AbstractNeighborhoodRule, Tuple{AbstractNeighborhoodRule,Vararg}},
          args...)  where T = begin
    # The rule provides the neighborhood buffer
    r = radius(rule)
    sze = hoodsize(r)
    buf = similar(init(data), sze, sze)
    src, dst = source(data), dest(data)
    nrows = framesize(data)

    handleoverflow!(data, r)

    # Setup buffer array between rows
    # Ignore the first column, it wil be copied over in the main loop
    for i in 2:sze
        @inbounds buf[i] = src[i-1-r]
    end
    # Run rule for a row
    @inbounds for i in 1:nrows
        copyto!(buf, 1, buf, 2)
        buf[sze] = src[i+r]
        state = buf[r+1]
        dst[i] = applyrule(rule, data, state, (i,))
    end
end
maprule!(data::AbstractSimData{T,2}, rule::Union{AbstractNeighborhoodRule, Tuple{AbstractNeighborhoodRule,Vararg}},
          args...) where T = begin
    # The rule provides the neighborhood buffer
    r = radius(rule)
    sze = hoodsize(r)
    buf = similar(init(data), sze, sze)
    src, dst = source(data).parent, dest(data).parent
    nrows, ncols = framesize(data)

    handleoverflow!(data, r)

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
                @inbounds buf[x, y] = src[i+x-1, y-1]
            end
        end
        # Run rule for a row
        for j = 1:ncols
            # Move the neighborhood buffer accross one column 
            # copyto! uses linear indexing, so 2d dims are transformed manually
            copyto!(buf, 1, buf, sze + 1, (sze - 1) * sze)
            # Copy a new column to the neighborhood buffer
            for x = 1:sze
                @inbounds buf[x, sze] = src[i+x-1, j+2r]
            end
            ismasked(data, i, j) && continue
            # Run the rule using the buffer
            @inbounds state = buf[r+1, r+1]
            newstate = applyrule(rule, data, state, (i, j), buf)
            @inbounds dst[i+r, j+r] = newstate
        end
    end
end

# maprule!(data::AbstractSimData{T,2}, rule::Union{NR, Tuple{NR,Vararg}},
#          args...) where {T,NR<:AbstractNeighborhoodRule{R}} where R = begin
#     # The rule provides the neighborhood buffer
#     sze = hoodsize(R)
#     src, dst = source(data), dest(data)
#     nrows, ncols = size(data)

#     handleoverflow!(data, overflow(data), R)

#     # Run the rule row by row. When we move along a row by one cell, we access only
#     # a single new column of data same the hight of the nighborhood, and move the existing
#     # data in the neighborhood buffer array accross by one column. This saves on reads
#     # from the main array, and focusses reads and writes in the small buffere array that
#     # should be in fast local memory.
#     for i = 1:nrows
#         # Setup the buffer array for the new row
#         # Run rule for a row
#         for j = 1:ncols
#             # Move the neighborhood buffer accross one column 
#             @inbounds buf = getbuffer(NR, src.parent, i, j)
#             # @inbounds buf = shiftbuffer(buf, src.parent, i, j)
#             ismasked(data, i, j) && continue
#             # Run the rule using the buffer
#             @inbounds state = buf[R+1, R+1]
#             newstate = applyrule(rule, data, state, (i, j), buf)
#             @inbounds dst.parent[i+R, j+R] = state
#         end
#     end
# end

# Base.@propagate_inbounds @generated getbuffer(::Type{<:AbstractNeighborhoodRule{R}}, src, i, j) where {R} = begin
#     expr = Expr(:tuple)
#     X = Y = 2R+1
#     # for x in 1:X
#         # push!(expr.args, zero(eltype(src)))
#     # end
#     for y in 1:Y, x in 1:X 
#         push!(expr.args, :(src[i+$x-1, j+$y-1]))
#     end
#     :(ConstantFixedSizePaddedArray{Tuple{$X,$Y}}($expr))
# end

# Base.@propagate_inbounds @generated shiftbuffer(buf::ConstantFixedSizePaddedArray{Tuple{X,Y}}, src, i, j) where {X,Y}  = begin
#     expr = Expr(:tuple)
#     len = X * Y
#     # Fill the first columns from the existing buffer
#     for n in 1:len - Y
#         push!(expr.args, :(buf.data[$n + Y]))
#     end
#     # Fill the last column from the src array
#     for n in 1:X
#         push!(expr.args, :(src[i + $n - 1, j + $Y - 1]))
#     end
#     :(ConstantFixedSizePaddedArray{Tuple{$X,$Y}}($expr))
# end
# maprule!(data::AbstractSimData{T,2}, rule::Union{AbstractNeighborhoodRule, Tuple{AbstractNeighborhoodRule,Vararg}},
#          args...) where T = begin
#     # TODO handle multiple radii in different rules
    
#     # The rule provides the neighborhood buffer
#     r = radius(rule)
#     src, dst = source(data), dest(data)
#     hsize = hoodsize(r)
#     nrows, ncols = size(data)
#     srcrows, srccols = size(src)
#     initarray = init(data)

#     buffers = typeof(initarray)[zeros(eltype(initarray), hsize, hsize) for i in 1:nrows]
#     dataarray = [setbuffer(data, buf) for buf in buffers]
#     bufcol = zeros(eltype(src), srcrows)

#     handleoverflow!(data, overflow(data), r)

#     # Run rule for a column
#     @inbounds for j in 1:ncols
#         # Get a column of data, bypassing offset arrays getindex
#         for x in 1:srcrows
#             bufcol[x] = src.parent[x, j+2r]
#         end
#         for i in 1:nrows
#             # Get the buffer for this row
#             buf = buffers[i]
#             # Move the neighborhood buffer accross one column 
#             # copyto! uses linear indexing
#             copyto!(buf, 1, buf, hsize + 1, (hsize - 1) * hsize)
#             # Copy a new column to the neighborhood buffer
#             for x in 1:hsize
#                 buf[hsize, x] = bufcol[x+i-1]
#             end
#             if !ismasked(data, i, j)
#                 state = buf[r+1, r+1]
#                 # Run the rule using the data containing this buffer
#                 dst.parent[i+r, j+2r] = applyrule(rule, dataarray[i], state, (i, j))
#             end
#         end
#     end
# end

# maprule!(data::AbstractSimData{T,2}, rule::Union{AbstractNeighborhoodRule, Tuple{AbstractNeighborhoodRule,Vararg}},
#          args...) where T = begin
#     # TODO handle multiple radii in different rules
    
#     # The rule provides the neighborhood buffer
#     r = radius(rule)
#     src, dst = source(data), dest(data)
#     hsize = 2r + 1
#     nrows, ncols = size(data)
#     srcrows, srccols = size(src)
#     initarray = init(data)

#     buf = typeof(initarray)(zeros(hsize, hsize))
#     data = setbuffer(data, buf)
#     bufcols = getcols(src.parent, hsize)

#     handleoverflow!(data, overflow(data), r)
#     newcol = hsize

#     # Run rule for a column
#     @inbounds for j in 1:ncols
#         if j != 1 
#             newcol = rem(newcol-1, hsize) + 1
#             # Get a column of data, bypassing offset arrays getindex
#             for x in 1:srcrows
#                 bufcols[newcol][x] = src.parent[x, j+2r]
#             end
#         end
#         for i in 1:nrows
#             if !ismasked(data, i, j)
#                 # Copy columns to the neighborhood buffer
#                 for y in 1:hsize
#                     bufcol = bufcols[rem(y+newcol, hsize)]
#                     for x in 1:hsize
#                         buf[x, y] = bufcol[x+i-1]
#                     end
#                 end
#                 state = buf[r+1, r+1]
#                 # Run the rule using the data containing this buffer
#                 dst.parent[i+r, j+2r] = applyrule(rule, data, state, (i, j))
#             end
#         end
#     end
# end
# TODO 3d neighborhood

@inline getcols(src, hsize) = begin
    hsize == 0 && return ()
    (getcols(src, hsize-1)..., src[:, hsize])
end

@inline ismasked(data::AbstractSimData, i, j) = ismasked(mask(data), i, j)
@inline ismasked(mask::Nothing, i, j) = false
@inline ismasked(mask::AbstractArray, i, j) = @inbounds return !mask[i, j]

"""
Wrap overflow where required. This optimisation allows us to ignore
bounds checks on neighborhoods and still use a wraparound grid.
"""
handleoverflow!(data::AbstractSimData, r::Integer) = handleoverflow!(data, overflow(data), r)
handleoverflow!(data::AbstractSimData{T,1}, overflow::WrapOverflow, r::Integer) where T = begin
    # Copy two sides
    @inbounds copyto!(source, 1-r:0, source, nrows+1-r:nrows)
    @inbounds copyto!(source, nrows+1:nrows+r, source, 1:r)
end
handleoverflow!(data::AbstractSimData{T,2}, overflow::WrapOverflow, r::Integer) where T = begin
    # TODO optimise this. Its mostly a placeholder so wrapping still works in GOL tests.
    src = source(data)
    nrows, ncols = framesize(data)
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
handleoverflow!(data, overflow::RemoveOverflow, r) = nothing

"""
    applyrule(rules::Tuple, data, state, (i, j))

Subrules. If a tuple of rules is passed to applyrule, run them sequentially for each cell.
This can have much beter performance as no writes occur between rules, and they are 
essentially compiled together into compound rules. This gives correct results only for
AbstractCellRule, or for a single AbstractNeighborhoodRule followed by AbstractCellRule.
"""
@inline applyrule(rules::Tuple, data, state, index, buf) = begin
    state = applyrule(rules[1], data, state, index, buf)
    applyrule(tail(rules), data, state, index)
end
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
    isrunning(output) && return
    setrunning!(output, true)
    initialize!(output)
    for (t, frame) in enumerate(output)
        delay(output, t)
        showframe(output, t)
        isrunning(output) || break
    end
    setrunning!(output, false)
end
