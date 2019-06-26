""" 
    distances(a::AbstactMatrix)

Calculate the distances between all cells in a matrix
"""
distances(a) = broadcast(calc_distance, (a,), broadcastable_indices(a))

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
