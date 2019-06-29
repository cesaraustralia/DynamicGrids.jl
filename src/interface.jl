"""
    function rule(model, state, t, source, dest, args...)

Rules alter cell values based on their current state and other cells, often
[`neighbors`](@ref).

### Arguments:
- `model` : [`AbstractRule`](@ref)
- `data` : [`FrameData`](@ref)
- `state`: the value of the current cell
- `index`: a (row, column) tuple of Int for the current cell coordinates - `t`: the current time step
- `args`: additional arguments passed through from user input to [`sim!`](@ref)

Returns a value to be written to the current cell.

$METHODLIST
"""
function applyrule end


"""
    function rule!(model, data, state, args...)
A rule that manually writes to the dest array, used in models inheriting
from [`AbstractPartialRule`](@ref).

### Arguments:
see [`rule`](@ref)

$METHODLIST
"""
function applyrule! end


"""
    neighbors(hood::AbstractNeighborhood, state, indices, t, source, args...)

Checks all cells in neighborhood and combines them according
to the particular neighborhood type.
$METHODLIST
"""
function neighbors end


"""
Return the radius of a model if it has one, otherwise zero.
"""
function radius end
