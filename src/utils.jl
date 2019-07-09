"""
    inbounds(x, max, overflow)

Check grid boundaries for a single coordinate and max value or a tuple
of coorinates and max values.

Returns a tuple containing the coordinate(s) followed by a boolean `true`
if the cell is in bounds, `false` if not.

Overflow of type [`RemoveOverflow`](@ref) returns the coordinate and `false` to skip
coordinates that overflow outside of the grid.
[`WrapOverflow`](@ref) returns a tuple with the current position or it's
wrapped equivalent, and `true` as it is allways in-bounds.
"""
@inline inbounds(xs::Tuple, maxs::Tuple, overflow) = begin
    a, inbounds_a = inbounds(xs[1], maxs[1], overflow)
    b, inbounds_b = inbounds(xs[2], maxs[2], overflow)
    (a, b), inbounds_a & inbounds_b
end
@inline inbounds(x::Number, max::Number, overflow::RemoveOverflow) = x, x > zero(x) && x <= max
@inline inbounds(x::Number, max::Number, overflow::WrapOverflow) =
    if x < oneunit(x)
        max + rem(x, max), true
    elseif x > max
        rem(x, max), true
    else
        x, true
    end

""" 
    distances(a::AbstactMatrix)

Calculate the matrix of distances (in units of cells) between all cells in a matrix
"""
distances(a) = broadcast(calc_distance, Ref(a), broadcastable_indices(a))

calc_distance(::AbstractMatrix, index) = calc_distance(index .- 1)
calc_distance((y, x)) = sqrt(y^2 + x^2)

broadcastable_indices(a) = broadcastable_indices(Int, a)
broadcastable_indices(T::Type, a) = begin
    h, w = size(a)
    typeof(similar(a, Tuple{T,T}))(collect((row, col) for row in 1:h, col in 1:w))
end


"""
    sizefromradius(radius)

Get the size of a neighborhood dimension from its radius, 
which is always 2r + 1.
"""
hoodsize(radius::Integer) = 2radius + 1
