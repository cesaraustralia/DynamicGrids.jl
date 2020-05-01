"""
    applyrule(rule::Rule, data, state, index, [buffer])

Updates cell values based on their current state and the 
state of other cells as defined in the Rule.

### Arguments:
- `rule` : [`Rule`](@ref)
- `data` : [`SimData`](@ref)
- `state`: the value(s) of the current cell
- `index`: a (row, column) tuple of Int for the current cell coordinates - `t`: the current time step
- `buffer`: a neighborhood burrer array passed to [`NeighborhoodRule`].

Returns the values) to be written to the current cell(s).
"""
function applyrule end


"""
    applyrule!(rule::PartialRule, data, state, index)

A rule that manually writes to the grid data array, 
used in all rules inheriting from [`PartialRule`](@ref).

### Arguments:
see [`applyrule`](@ref)
"""
function applyrule! end

"""
    precalcrules(rule, data)

Run any precalculations needed to run a rule for a particular frame,
returning new rule objects containing the updates.

This is a functional approach, rebuilding rules recursively.
`@set` from Setfield.jl can help updating immutable rules.

The default action is to return the existing rule without change.
"""
function precalcrules end

"""
neighbors(hood::Neighborhood, buffer)

Returns an iteraterable over all cells in the neighborhood.
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


# TODO: docuent SimData methods
function starttime end
function currenttime end
function currentframe end
function gridsize end
function mask end
function overflow end
function timestep end
