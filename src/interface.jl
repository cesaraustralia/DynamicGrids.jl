"""
    applyrule(rule::Rule, data, state, index)

Updates cell values based on their current state and the state of other cells
as defined in the Rule.

### Arguments:
- `rule` : [`Rule`](@ref)
- `data` : [`FrameData`](@ref)
- `state`: the value of the current cell
- `index`: a (row, column) tuple of Int for the current cell coordinates - `t`: the current time step

Returns a value to be written to the current cell.
"""
function applyrule end


"""
    applyrule!(rule::PartialRule, data, state, index)

A rule that manually writes to the dest array, used in rules inheriting
from [`PartialRule`](@ref).

### Arguments:
see [`applyrule`](@ref)
"""
function applyrule! end

"""
    applyinteraction(interacttion::PartialRule, data, state, index)

Applay an interation that returns a tuple of values.
### Arguments:
see [`applyrule`](@ref)
"""
function applyinteraction end

"""
    applyinteraction!(interacttion::PartialRule, data, state, index)

Applay an interation that manually writes to the passed in dest arrays.
### Arguments:
see [`applyrule`](@ref)
"""
function applyinteraction! end

"""
    precalcrule!(rule, data)

Run any precalculations needed to run a rule for a particular frame.

It may be better to do this in a functional way with an external precalc object
passed into a rule via the `data` object, but it's done statefully for now for simplicity.
"""
function precalcrule! end


"""
    neighbors(hood::Neighborhood, state, indices, t, source, args...)

Checks all cells in neighborhood and combines them according
to the particular neighborhood type.
"""
function neighbors end

"""
    mapreduceneighbors(f, data, neighborhood, rule, state, index)

Run `f` over all cells in the neighborhood and sums its return values. 
`f` is a function or functor with the form:
`f(data, neighborhood, rule, state, hood_index, dest_index)`. 
"""
function mapreduceneighbors end

"""
Set value of a cell in the neighborhood.
Usually called in `mapreduceneighbors`.
"""
function setneighbor! end

"""
Return the radius of a rule or ruleset if it has one, otherwise zero.
"""
function radius end
