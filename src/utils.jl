"""
    inbounds(x, max, overflow)

Check grid boundaries for a single coordinate and max value or a tuple
of coorinates and max values.

Returns a tuple containing the coordinate(s) followed by a boolean `true`
if the cell is in bounds, `false` if not.

Overflow of type [`Skip`](@ref) returns the coordinate and `false` to skip
coordinates that overflow outside of the grid.
[`Wrap`](@ref) returns a tuple with the current position or it's
wrapped equivalent, and `true` as it is allways in-bounds.
"""
inbounds(xs::Tuple, maxs::Tuple, overflow) = begin
    a, inbounds_a = inbounds(xs[1], maxs[1], overflow)
    b, inbounds_b = inbounds(xs[2], maxs[2], overflow)
    (a, b), inbounds_a && inbounds_b
end
inbounds(x::Number, max::Number, overflow::Skip) = x, x > zero(x) && x <= max
inbounds(x::Number, max::Number, overflow::Wrap) =
    if x < oneunit(x)
        max + rem(x, max), true
    elseif x > max
        rem(x, max), true
    else
        x, true
    end

""" 
    distances(a::AbstactMatrix)

Calculate the distances between all cells in a matrix
"""
distances(a::AbstractMatrix) = broadcast(matrix_calc_distance, broadcastable_indices(a)...)

matrix_calc_distance(row, col) = calc_distance(row - 1, col - 1)

calc_distance(y, x) = sqrt(y^2 + x^2)

broadcastable_indices(a) = broadcastable_indices(Int, a)
broadcastable_indices(T::Type, a) = begin
    h, w = size(a)
    rows = typeof(similar(a, T))(collect(row for row in 1:h, col in 1:w))
    cols = typeof(similar(a, T))(collect(col for row in 1:h, col in 1:w))
    rows, cols
end
