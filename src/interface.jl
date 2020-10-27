"""
    applyrule(data, rule::Rule, state, index)

Apply a rule to the cell state and return values to write to the grid/s.

This is called in `maprule!` methods during the simulation, 
not by the user. Custom `Rule` implementations must define this method.

### Arguments:
- `data` : [`SimData`](@ref)
- `rule` : [`Rule`](@ref)
- `state`: the value(s) of the current cell
- `index`: a (row, column) tuple of Int for the current cell coordinates

Returns the values) to be written to the current cell(s).
"""
function applyrule end


"""
    applyrule!(data, rule::ManualRule, state, index)

Apply a rule to the cell state and manually write to the grid data array. 
Used in all rules inheriting from [`ManualRule`](@ref).

This is called in internal `maprule!` methods during the simulation, 
not by the user. Custom `ManualRule` implementations must define this method.

### Arguments:
see [`applyrule`](@ref)
"""
function applyrule! end

"""
    neighbors(x::Union{Neighborhood,NeighborhoodRule}})

Returns an iteraterable generator over all cells in the neighborhood.

Custom `Neighborhood`s must define this method.
"""
function neighbors end

"""
    sumneighbors(hood::Neighborhood, state)

Sums all cells in the neighborhood. This is identical to running 
`sum(neighbors(hood))` but it can be more efficient than as
it may use matrix algra libraries for `sum`, instead of regular sum over 
an iterator.
"""
function sumneighbors end

"""
    mapsetneighbor!(data, neighborhood, rule, state, index)

Run `setneighbor!` over all cells in the neighborhood and sums its return values. 

This is used only in [`ManualNeighborhoodRule`](@ref).
"""
function mapsetneighbor! end

"""
    setneighbor!(data, neighborhood, rule, state, hood_index, dest_index)

Set value of a cell in the neighborhood. Called in `mapsetneighbor!`.
"""
function setneighbor! end

"""
    radius(rule, [key])

Return the radius of a rule or ruleset if it has one, otherwise zero.
"""
function radius end

"""
    aux(obj)

Retrieve auxilary data `NamedTuple` from an [`Output`](@ref), 
[`Extent`](@ref) or [`SimData`](@ref) object.
"""
function aux end

"""
    tspan(obj)

Retrieve the time-span `AbstractRange` from an [`Output`](@ref), 
[`Extent`](@ref) or [`SimData`](@ref) object.
"""
function tspan end

"""
    timestep(obj)

Retrieve the timestep size from an [`Output`](@ref), 
[`Extent`](@ref), [`Ruleset`](@ref) or [`SimData`](@ref) object.
"""
function timestep end

"""
    currenttimestep(simdata::SimData)

Retrieve the current timestep from a [`SimData`](@ref) object.

This may be different from the `timestep`. If the simulation is in `Month`, 
`currenttimestep` will return `Seconds` for the length of the specific month.
"""
function currenttimestep end

"""
    currentframe(simdata::SimData)

Retrieve the current simulation frame as an integer from a [`SimData`](@ref) object.
"""
function currentframe end

"""
    currenttime(simdata::SimData)

Retrieve the current simulation time from a [`SimData`](@ref) object.

This will be in whatever type/units you specify in `tspan`.
"""
function currenttime end
