
"""
    sim!(output, [ruleset::Ruleset=ruleset(output)];
         init=init(output),
         mask=mask(output),
         tstpan=tspan(output),
         aux=aux(output),
         fps=fps(output),
         simdata=nothing,
         nreplicates=nothing)

Runs the simulation, passing the destination aray to
the passed in output for each time-step.

### Arguments
- `output`: An [`Output`](@ref) to store grids or display them on the screen.
- `ruleset`: A [`Ruleset`](@ref) containing one or more [`Rule`](@ref)s. If the output
  has a `Ruleset` attached, it will be used.

### Keyword Arguments

Theses are the taken from the output argument by default.

- `init`: optional array or NamedTuple of arrays.
- `mask`: a `Bool` array matching the init array size. `false` cells do not run.
- `aux`: a `NamedTuple` of auxilary data to be used by rules.
- `tspan`: a tuple holding the start and end of the timespan the simulaiton will run for.
- `fps`: the frames per second to display. Will be taken from the output if not passed in.
- `nreplicates`: the number of replicates to combine in stochastic simulations
- `simdata`: a [`SimData`](@ref) object. Keeping it between simulations can reduce memory
  allocation when that is important.
"""
sim!(output::Output, ruleset=ruleset(output);
     init=init(output),
     mask=mask(output),
     tspan=tspan(output),
     aux=aux(output),
     fps=fps(output),
     nreplicates=nothing,
     simdata=nothing, kwargs...) = begin

    gridsize(init) == gridsize(DG.init(output)) || throw(ArgumentError("init size does not match output init"))
    # Some rules are only valid for a set time-step size.
    step(ruleset) !== nothing && step(ruleset) != step(tspan) &&
        throw(ArgumentError("tspan step $(step(tspan)) must equal rule step $(step(ruleset))"))

    # Rebuild Extent to allow kwarg alterations
    extent = Extent(; init=asnamedtuple(init), mask=mask, aux=aux, tspan=tspan)
    # Set up output
    initialise(output)
    isrunning(output) && error("A simulation is already running in this output")
    setrunning!(output, true) || error("Could not start the simulation with this output")
    settspan!(output, tspan)
    # Create or update the combined data object for the simulation
    simdata = initdata!(simdata, extent, ruleset, nreplicates)
    # Delete grids output by the previous simulations
    initgrids!(output, init)
    # Set run speed for GraphicOutputs
    setfps!(output, fps)
    # Show the first grid
    showframe(output, simdata, 1, first(tspan))
    # Let the init grid be displayed as long as a normal grid
    delay(output, 1)
    # Run the simulation over simdata and a unitrange
    runsim!(output, simdata, 1:lastindex(tspan))
end

"""
    sim!(output, rules::Rule...; kwargs...)

Run a simulation passing in rules without defining a `Ruleset`.
"""
sim!(output::Output, rules::Tuple; kwargs...) = sim!(output::Output, rules...; kwargs...)
sim!(output::Output, rules::Rule...; tspan=tspan(output), kwargs...) = begin
    ruleset = Ruleset(rules...; timestep=step(tspan), kwargs...)
    sim!(output::Output, ruleset; tspan=tspan, kwargs...)
end

"""
    resume!(output::GraphicOutput, ruleset::Ruleset=ruleset(output);
            tstop=last(tspan(output)),
            fps=fps(output),
            simdata=nothing,
            nreplicates=nothing)

Restart the simulation from where you stopped last time. For arguments see [`sim!`](@ref).
The keyword arg `tstop` can be used to extend the length of the simulation.

### Arguments
- `output`: An [`Output`](@ref) to store grids or display them on the screen.
- `ruleset`: A [`Ruleset`](@ref) containing one ore more [`Rule`](@ref)s.
  These will each be run in sequence.

### Keyword Arguments (optional
- `init`: an optional initialisation array
- `tstop`: the new stop time for the simulation. Taken from the output length by default.
- `fps`: the frames per second to display. Taken from the output by default.
- `nreplicates`: the number of replicates to combine in stochastic simulations
- `simdata`: a [`SimData`](@ref) object. Keeping it between simulations can improve performance
  when that is important
"""
function resume!(output::GraphicOutput, ruleset::Ruleset=ruleset(output);
        tstop=last(tspan(output)),
        fps=fps(output),
        simdata=nothing,
        nreplicates=nothing)
    initialise(output)
    # Check status and arguments
    isrunning(output) && error("A simulation is already running in this output")
    setrunning!(output, true) || error("Could not start the simulation with this output")

    # Calculate new timespan
    new_tspan = first(tspan(output)):step(tspan(output)):tstop
    stoppedframe_ = stoppedframe(output)
    fspan = stoppedframe_:lastindex(new_tspan)
    settspan!(output, new_tspan)

    # Use the last frame of the existing simulation as the init frame
    if stoppedframe_ <= length(output)
        init = output[stoppedframe_]
    else
        init = output[1]
    end

    setfps!(output, fps)
    extent = Extent(; init=asnamedtuple(init), mask=mask(output), aux=aux(output), tspan=new_tspan)
    simdata = initdata!(simdata, extent, ruleset, nreplicates)
    runsim!(output, simdata, fspan)
end

"""
    runsim!(output::Output, args...)

Simulation runner. Runs a simulation synchonously or asynchonously
depending on the return value of `isasync(output)` - which may be a 
fixed trait or a field value depending on the output type.

This allows interfaces with interactive components to update during
the simulations.
"""
runsim!(output, simdata, fspan) = 
    if isasync(output)
        @async simloop!(output, simdata, fspan)
    else
        simloop!(output, simdata, fspan)
    end

"""
    simloop!(output::Output, simdata::SimData, fspan::UnitRange)

Loop over the frames in `fspan`, running the ruleset and displaying the output.

Operations on outputs and rulesets are allways mutable and in-place.

Operations on [`Rule`](@ref)s and [`SimData`](@ref) objects are in a 
functional style, as they are used in inner loops where immutability improves 
performance.
"""
function simloop!(output::Output, simdata, fspan)
    # Set the frame timestamp for fps calculation
    settimestamp!(output, first(fspan))
    # Initialise types etc
    simdata = updatetime(simdata, 1)
    # Loop over the simulation
    for f in fspan[2:end]
        # Get a data object with updated timestep and precalculate rules
        simdata = updatetime(simdata, f)
        precalcrules!(simdata)
        # Run the ruleset and setup data for the next iteration
        simdata = sequencerules!(simdata)
        # Save/do something with the the current grid
        storeframe!(output, simdata)
        # Let interface things happen
        isasync(output) && yield()
        # Stick to the FPS
        delay(output, f)
        # Exit gracefully
        if !isrunning(output) || f == last(fspan)
            showframe(output, simdata, f, currenttime(simdata))
            setstoppedframe!(output, f)
            finalise(output)
            break
        end
    end
    setrunning!(output, false)
    output
end
