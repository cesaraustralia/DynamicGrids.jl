"""
    applyrule(rule::AbstractRule, data, state, index)

Updates cell values based on their current state and the state of other cells
as defined in the Rule.

### Arguments:
- `rule` : [`AbstractRule`](@ref)
- `data` : [`FrameData`](@ref)
- `state`: the value of the current cell
- `index`: a (row, column) tuple of Int for the current cell coordinates - `t`: the current time step
- `args`: additional arguments passed through from user input to [`sim!`](@ref)

Returns a value to be written to the current cell.
"""
function applyrule end


"""
    applyrule!(rule::AbstractPartialRule, data, state, index)
A rule that manually writes to the dest array, used in rules inheriting
from [`AbstractPartialRule`](@ref).

### Arguments:
see [`applyrule`](@ref)
"""
function applyrule! end


"""
    neighbors(hood::AbstractNeighborhood, state, indices, t, source, args...)

Checks all cells in neighborhood and combines them according
to the particular neighborhood type.
"""
function neighbors end


"""
Return the radius of a rule or ruleset if it has one, otherwise zero.
"""
function radius end
