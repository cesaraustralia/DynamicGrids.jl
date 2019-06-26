
@mix @description struct Radius{R}
    radius::R | "The 'radius' of the neighborhood is the distance to the edge from the center cell. "
end


"""
Neighborhoods define how surrounding cells are related to the current cell.
The `neighbors` function returns the sum of surrounding cells, as defined
by the neighborhood.
"""
abstract type AbstractNeighborhood end

radius(hood::AbstractNeighborhood) = hood.radius


"""
Radial neighborhoods calculate the surrounding neighborood
from the radius around the central cell. The central cell
is ommitted.
"""
@Radius struct RadialNeighborhood{} <: AbstractNeighborhood end 

""" 
Custom neighborhoods are tuples of custom coordinates in relation to the central point
of the current cell. They can be any arbitrary shape or size.
"""
abstract type AbstractCustomNeighborhood <: AbstractNeighborhood end

"""
Allows completely arbitrary neighborhood shapes by specifying each coordinate
specifically.
"""
@Radius struct CustomNeighborhood{N} <: AbstractCustomNeighborhood
    coords::N | "A tuple of tuples of Int, containing 2-D coordinates relative to the central point"
end
CustomNeighborhood(coords) = CustomNeighborhood(coords, absmaxcoord(coords))

# Calculate the maximum absolute value in the coords to use as the radius
absmaxcoord(coords) = maximum((x -> maximum(abs.(x))).(coords))



"""
Sets of custom neighborhoods that can have separate rules for each set.
"""
@Radius struct LayeredCustomNeighborhood{N} <: AbstractCustomNeighborhood
    layeredcoords::N | "A tuple of tuple of tuples of Int, contains 2-D coordinates relative to the central point. "
end
LayeredCustomNeighborhood(layeredcoords) = 
    LayeredCustomNeighborhood(layeredcoords, maximum(absmaxcoord.(layeredcoords)))


VonNeumannNeighborhood() = CustomNeighborhood(((0,-1), (-1,0), (1,0), (0,1)))

"""
    neighbors(hood::RadialNeighborhood{:moore}, data, state, index, args...)

Sums moore nieghborhoods of any dimension. 
"""
neighbors(hood::RadialNeighborhood, model, data, state, args...) = 
    sum(buffer(data)) - state

"""
    neighbors(hood::AbstractCustomNeighborhood, data, state, index, args...)
Sum a single custom neighborhood.
"""
neighbors(hood::AbstractCustomNeighborhood, model, data, state, index, args...) =
    custom_neighbors(hood.coords, hood, data)

custom_neighbors(coords, hood, data) = begin
    r = radius(hood)
    buf = buffer(data)
    # Initialise to empty
    n = zero(eltype(buf))
    # Sum active cells in the neighborhood
    for coord in coords
        n += buf[(coord .+ r .+ 1)...] 
    end
    n
end

"""
    neighbors(hood::LayeredCustomNeighborhood, data, state, index, args...)
Sum multiple custom neighborhoods separately.
"""
neighbors(hood::LayeredCustomNeighborhood, model, data, state, index, args...) = 
    multi_neighbors(hood.layeredcoords, hood, data)

multi_neighbors(layeredcoords::Tuple, hood, data) = 
    (custom_neighbors(layeredcoords[1], hood, data), 
     multi_neighbors(tail(layeredcoords), hood, data)...)
multi_neighbors(layeredcoords::Tuple{}, hood, data) = () 
