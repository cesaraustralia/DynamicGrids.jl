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
sim!(output, ruleset; init=nothing, tstop=length(output), fps=fps(output), data=nothing, nreplicates=nothing) = begin
    isrunning(output) && error("A simulation is already running in this output")
    setrunning!(output, true) || error("Could not start the simulation with this output")

    # Copy the init array from the ruleset or keyword arg
    init = chooseinit(ruleset.init, init)
    data = initdata!(data, ruleset, init, nreplicates)
    # Delete frames output by the previous simulations
    initframes!(output, init)
    setfps!(output, fps)
    # Show the first frame
    showframe(output, data, 1)
    # Let the init frame show as long as a normal frame
    delay(output, 1)
    # Run the simulation
    runsim!(output, ruleset, data, 2:tstop)
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
resume!(output, ruleset; tadd=100, fps=fps(output), data=nothing, nreplicates=nothing) = begin
    length(output) > 0 || error("There is no simulation to resume. Run `sim!` first")
    isrunning(output) && error("A simulation is already running in this output")
    setrunning!(output, true) || error("Could not start the simulation with this output")

    # Set the output fps from keyword arg
    cur_t = gettlast(output)
    tspan = cur_t + 1:cur_t + tadd
    # Use the last frame of the existing simulation as the init frame
    init = output[curframe(output, cur_t)]
    data = initdata!(data, ruleset, init, nreplicates)
    setfps!(output, fps)
    runsim!(output, ruleset, data, tspan)
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
# replay(output::AbstractOutput, ruleset) = begin
#     isrunning(output) && return
#     setrunning!(output, true)
#     for (t, frame) in enumerate(output)
#         delay(output, t)
#         showframe(output, ruleset, t)
#         isrunning(output) || break
#     end
#     setrunning!(output, false)
# end

"run the simulation either directly or asynchronously."
runsim!(output, args...) =
    if isasync(output)
        @async simloop!(output, args...)
    else
        simloop!(output, args...)
    end

" Loop over the selected timespan, running the ruleset and displaying the output"
simloop!(output, ruleset, data, tspan) = begin
    settimestamp!(output, tspan.start)
    # Loop over the simulation
    for t in tspan
        # Update the timestep
        data = updatetime(data, t)
        # Run the ruleset and setup data for the next iteration
        data = sequencerules!(data, ruleset)
        # Save/do something with the the current frame
        storeframe!(output, data, t)
        isasync(output) && yield()
        # Stick to the FPS
        delay(output, t)
        # Exit gracefully
        if !isrunning(output) || t == tspan.stop
            showframe(output, data, t)
            setrunning!(output, false)
            finalize!(output)
            break
        end
    end
    output
end


"""
Iterate over all rules recursively, swapping source and dest arrays.
Returns the data object with source and dest arrays ready for the next iteration.
"""
sequencerules!(data::SimData, ruleset::Ruleset) = sequencerules!(data, ruleset.rules)
sequencerules!(data::SimData, rules::Tuple) = begin
    # Run the first rule for the whole frame
    maprule!(data, rules[1])
    # Swap the source and dest arrays
    data = swapsource(data)
    # Run the rest of the rules, recursively
    sequencerules!(data, tail(rules))
end
sequencerules!(data::SimData, rules::Tuple{}) = data
"""
Threaded replicate simulations. If nreplicates is set the data object
will be a vector of replicate data, so we loop over it with threads.
"""
sequencerules!(data::AbstractVector{<:SimData}, rules) = begin
    Threads.@threads for i in 1:length(data)
        sequencerules!(data[i], rules)
    end
    data
end
