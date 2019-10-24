"""
sim!(output, ruleset; init=nothing, tstpan=(1, length(output)),
     fps=fps(output), data=nothing, nreplicates=nothing)

Runs the whole simulation, passing the destination aray to
the passed in output for each time-step.

### Arguments
- `output`: An [AbstractOutput](@ref) to store frames or display them on the screen.
- `ruleset`: A Rule() containing one ore more [`AbstractRule`](@ref). These will each be run in sequence.

### Keyword Arguments
- `init`: the initialisation array. If `nothing`, the Ruleset must contain an `init` array.
- `tspan`: the timespan simulaiton will run for.
- `fps`: the frames per second to display. Will be taken from the output if not passed in.
- `nreplicates`: the number of replicates to combine in stochastic simulations
- `data`: a SimData object. Can reduce allocations when that is important.
"""
sim!(output, ruleset; init=nothing, tspan=(1, length(output)), fps=fps(output),
     nreplicates=nothing, data=nothing) = begin
    isrunning(output) && error("A simulation is already running in this output")
    setrunning!(output, true) || error("Could not start the simulation with this output")
    starttime = first(tspan)
    fspan = tspan2fspan(tspan, timestep(ruleset))
    setstarttime!(output, starttime)
    # Copy the init array from the ruleset or keyword arg
    init = chooseinit(DynamicGrids.init(ruleset), init)
    data = initdata!(data, ruleset, init, starttime, nreplicates)
    # Delete frames output by the previous simulations
    initframes!(output, init)
    setfps!(output, fps)
    # Show the first frame
    showframe(output, data, 1)
    # Let the init frame be displayed as long as a normal frame
    delay(output, 1)
    # Run the simulation
    runsim!(output, data, fspan)
end

tspan2fspan(tspan, tstep) = 1:lastindex(first(tspan):tstep:last(tspan))

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
resume!(output, ruleset; tstop=stoptime(output), fps=fps(output), data=nothing,
        nreplicates=nothing) = begin
    length(output) > 0 || error("There is no simulation to resume. Run `sim!` first")
    isrunning(output) && error("A simulation is already running in this output")
    setrunning!(output, true) || error("Could not start the simulation with this output")
    tstart = starttime(output)
    lastframe = lastindex(tstart:timestep(ruleset):stoptime(output))
    stopframe = lastindex(tstart:timestep(ruleset):tstop)
    fspan = lastframe:stopframe
    # Use the last frame of the existing simulation as the init frame
    init = output[lastindex(output)]
    data = initdata!(data, ruleset, init, tstart, nreplicates)
    setfps!(output, fps)
    runsim!(output, data, fspan)
end

"run the simulation either directly or asynchronously."
runsim!(output, args...) =
    if isasync(output)
        @async simloop!(output, args...)
    else
        simloop!(output, args...)
    end

"""
Loop over the selected timespan, running the ruleset and displaying the output

Operations on outputs and rulesets are allways mutable and in-place.
Operations on rules and data objects are functional as they are used in inner loops
where immutability improves performance.
"""
simloop!(output, data, fspan) = begin
    settimestamp!(output, first(fspan))
    # Initialise types etc
    data = updatetime(data, 1)# |> precalcrules
    # Loop over the simulation
    for f in fspan[2:end]
        # Get a data object with updated timestep and precalculated rules
        data = updatetime(data, f) |> precalcrules
        # Run the ruleset and setup data for the next iteration
        data = sequencerules!(data)
        # Save/do something with the the current frame
        storeframe!(output, data)
        isasync(output) && yield()
        # Stick to the FPS
        delay(output, f)
        # Exit gracefully
        if !isrunning(output) || f == last(fspan)
            showframe(output, data, f)
            setrunning!(output, false)
            setstoptime!(output, currenttime(data))
            finalize!(output)
            break
        end
    end
    output
end


"""
    precalcrules(rule, data) = rule

Rule precalculation. This is a functional approach rebuilding rules recursively.
@set from Setfield.jl helps in specific rule implementations.

The default is to return the existing rule
"""
precalcrules(rule, data) = rule

precalcrules(data::SimData) = @set data.ruleset.rules = precalcrules(rules(data), data)
precalcrules(data::MultiSimData) = @set data.data = map(precalcrules, data.data)
precalcrules(rules::Tuple, data) =
    (precalcrules(rules[1], data), precalcrules(tail(rules), data)...)
precalcrules(rules::Tuple{}, data) = ()
precalcrules(chain::Chain, data) = Chain(precalcrules(val(chain), data))
