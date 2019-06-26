"""
    function rule(model, state, t, source, dest, args...)

Rules alter cell values based on their current state and other cells, often
[`neighbors`](@ref).

### Arguments:
- `model` : [`AbstractModel`](@ref)
- `data` : [`FrameData`](@ref)
- `state`: the value of the current cell
- `index`: a (row, column) tuple of Int for the current cell coordinates - `t`: the current time step
- `args`: additional arguments passed through from user input to [`sim!`](@ref)

Returns a value to be written to the current cell.

$METHODLIST
"""
function rule end


"""
    function rule!(model, data, state, args...)
A rule that manually writes to the dest array, used in models inheriting
from [`AbstractPartialModel`](@ref).

### Arguments:
see [`rule`](@ref)

$METHODLIST
"""
function rule! end


"""
    run_model!(models::Tuple, source, dest, args...)

Iterate over all models recursively, swapping source and dest arrays.

Returns a tuple containing the source and dest arrays for the next iteration.

$METHODLIST
"""
function run_model! end


"""
    run_rule!(models, data, indices, args...)

Runs the rule(s) for each cell in the grid, following rules defined by the supertype of each
model(s) passed in.

$METHODLIST
"""
function run_rule! end


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

"""
AbstractNeighborhoodModel requires a temp array. `neighborhood_buffer()` must be defined to return it.
"""
function neighborhood_buffer end
