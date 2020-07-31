"""
    applyrule(data, rule::Rule, state, index)

Updates cell values based on their current state and the 
state of other cells as defined in the Rule.

### Arguments:
- `data` : [`SimData`](@ref)
- `rule` : [`Rule`](@ref)
- `state`: the value(s) of the current cell
- `index`: a (row, column) tuple of Int for the current cell coordinates - `t`: the current time step

Returns the values) to be written to the current cell(s).
"""
function applyrule end


"""
    applyrule!(data, rule::ManualRule, state, index)

A rule that manually writes to the grid data array, 
used in all rules inheriting from [`ManualRule`](@ref).

### Arguments:
see [`applyrule`](@ref)
"""
function applyrule! end

"""
Returns an iteraterable generator over all cells in the neighborhood.
"""
function neighbors end

"""
sumneighbors(hood::Neighborhood, buffer, state)

Sums all cells in the neighborhood. This is identical to running 
`sum(neighbors(hood, buffer))` but it can be more efficient than as
it may use matrix algra libraries for `sum`, instead of regular sum over 
an iterator.
"""
function sumneighbors end

"""
    mapsetneighbor!(data, hood, rule, state, index)

Run `setneighbor!` over all cells in the neighborhood and sums its return values. 
"""
function mapsetneighbor! end

"""
Set value of a cell in the neighborhood. Called in `mapsetneighbor`.
"""
function setneighbor! end

"""
    radius(rule, [key])

Return the radius of a rule or ruleset if it has one, otherwise zero.
"""
function radius end

"""
    aux(obj)

Retreive auxilary data `NamedTuple` from an [`Output`](@ref), 
[`Extent`](@ref) or [`SimdData`](@ref) object.
"""
function aux end

"""
    tspan(obj)

Retreive the timespan `AbstractRange` from an [`Output`](@ref), 
[`Extent`](@ref) or [`SimdData`](@ref) object.
"""
function tspan end

"""
    timestep(obj)

Retreive the timestep size from an [`Output`](@ref), 
[`Extent`](@ref), [`Ruleset`](@ref) or [`SimdData`](@ref) object.
"""
function timestep end

"""
    currenttimestep(simdata::SimdData)

Retreive the current timestep from a [`SimdData`](@ref) object.

This may be different from the `timestep`. If the simulation is in `Month`, 
`currenttimestep` will return `Seconds` for the length of the specific month.
"""
function currenttimestep end

"""
    currentframe(simdata::SimdData)

Retreive the current simulation frame as an integer from a [`SimdData`](@ref) object.
"""
function currentframe end

"""
    currenttime(simdata::SimdData)

Retreive the current simulation time as an integer from a [`SimdData`](@ref) object.

This will be in whatever type/units you specify in `tspan`.
"""
function currenttime end
