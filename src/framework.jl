"""
sim!(output, ruleset; init=nothing, tstop=length(output), 
     fps=fps(output), data=nothing, nreplicates=nothing)

Runs the whole simulation, passing the destination aray to
the passed in output for each time-step.

### Arguments
- `output`: An [AbstractOutput](@ref) to store frames or display them on the screen.
- `ruleset`: A Rule() containing one ore more [`AbstractRule`](@ref). These will each be run in sequence.

### Keyword Arguments
- `init`: the initialisation array. If `nothing`, the Ruleset must contain an `init` array.
- `tstop`: the number of the frame the simulaiton will run to.
- `fps`: the frames per second to display. Will be taken from the output if not passed in.
- `nreplicates`: the number of replicates to combine in stochastic simulations
- `data`: a SimData object. Can reduce allocations when that is important.
"""
sim!(output, ruleset; init=nothing, tstop=length(output), fps=fps(output), nreplicates=nothing, data=nothing) = begin
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
    resume!(output, ruleset; tadd=100, kwargs...)

Restart the simulation where you stopped last time. For arguments see [`sim!`](@ref).
The keyword arg `tadd` indicates the number of frames to add, and of course an init
array will not be accepted.
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
        # Do any precalculations the rules need for this frame
        precalcrule!(ruleset, data)
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
sequencerules!(data::SimData, ruleset::Ruleset) = sequencerules!(data, rules(ruleset))
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

precalcrule!(ruleset::Ruleset, data) = precalcrule!(rules(ruleset), data) 
precalcrule!(rules::Tuple, data) = begin
    precalcrule!(rules[1], data)
    precalcrule!(tail(rules), data)
end
precalcrule!(rules::Tuple{}, data) = nothing
precalcrule!(chain::Chain, data) = precalcrule!(val(chain), data)
precalcrule!(rule, data) = nothing
