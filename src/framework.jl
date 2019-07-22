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

    # Copy the init array from the ruleset or keyword arg
    init = deepcopy(chooseinit(ruleset.init, init))
    # Delete frames output by the previous simulations
    initframes!(output, init)
    # Set the output fps from keyword arg
    setfps!(output, fps)
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
        # isshowable(output, t) && showframe(output, ruleset, output[end], t, data)
        # Let other tasks run (like ui controls) TODO is this needed?
        #yield()
        # Stick to the FPS
        delay(output, t)
        # Exit gracefully
        if !isrunning(output) || t == tspan.stop
            showframe(output, ruleset, t)
            # showframe(output, ruleset, output[end], t, data)
            setrunning!(output, false)
            # Any finithing touches required by the output
            finalize!(output)
            break
        end
    end
    output
end


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
