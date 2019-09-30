
"""
Neighborhoods define how surrounding cells are related to the current cell.
The `neighbors` function returns the sum of surrounding cells, as defined
by the neighborhood.
"""
abstract type AbstractNeighborhood{R} end

radius(hood::AbstractNeighborhood{R}) where R = R


"""
Radial neighborhoods calculate the surrounding neighborood
from the radius around the central cell. The central cell
is ommitted.
"""
struct RadialNeighborhood{R} <: AbstractNeighborhood{R} end 

""" 
Custom neighborhoods are tuples of custom coordinates in relation to the central point
of the current cell. They can be any arbitrary shape or size.
"""
abstract type AbstractCustomNeighborhood{R} <: AbstractNeighborhood{R} end

"""
Allows completely arbitrary neighborhood shapes by specifying each coordinate
specifically.
"""
@description struct CustomNeighborhood{R,C} <: AbstractCustomNeighborhood{R}
    coords::C | "A tuple of tuples of Int, containing 2-D coordinates relative to the central point"
end
CustomNeighborhood(coords) = CustomNeighborhood{absmaxcoord(coords), typeof(coords)}(coords)

# Calculate the maximum absolute value in the coords to use as the radius
absmaxcoord(coords) = maximum((x -> maximum(abs.(x))).(coords))



"""
Sets of custom neighborhoods that can have separate rules for each set.
"""
@description struct LayeredCustomNeighborhood{R,C} <: AbstractCustomNeighborhood{R}
    layeredcoords::C | "A tuple of tuple of tuples of Int, contains 2-D coordinates relative to the central point. "
end
LayeredCustomNeighborhood(layeredcoords) = 
    LayeredCustomNeighborhood{maximum(absmaxcoord.(layeredcoords)), typeof(layeredcoords)}(layeredcoords)


VonNeumannNeighborhood() = CustomNeighborhood(((0,-1), (-1,0), (1,0), (0,1)))

"""
    neighbors(hood::RadialNeighborhood, buf, state)

Sums moore nieghborhoods of any dimension. 
"""
neighbors(hood::RadialNeighborhood, model, buf, state) = sum(buf) - state

"""
    neighbors(hood::AbstractCustomNeighborhood, buf, state)
Sum a single custom neighborhood.
"""
neighbors(hood::AbstractCustomNeighborhood, model, buf, state) =
    custom_neighbors(hood.coords, hood, buf)

custom_neighbors(coords, hood, buf) = begin
    r = radius(hood)
    # Initialise to empty
    n = zero(eltype(buf))
    # Sum active cells in the neighborhood
    for coord in coords
        n += buf[(coord .+ r .+ 1)...] 
    end
    n
end

"""
neighbors(hood::LayeredCustomNeighborhood, buf, state)
Sum multiple custom neighborhoods separately.
"""
neighbors(hood::LayeredCustomNeighborhood, model, buf, state) = 
    multi_neighbors(hood.layeredcoords, hood, buf)

multi_neighbors(layeredcoords::Tuple, hood, buf) = 
    (custom_neighbors(layeredcoords[1], hood, buf), 
     multi_neighbors(tail(layeredcoords), hood, buf)...)
multi_neighbors(layeredcoords::Tuple{}, hood, buf) = () 



"""
Find the largest radius present in the passed in rules.
"""
maxradius(ruleset::Ruleset) = maxradius(rules(ruleset))
maxradius(rules::Tuple{T,Vararg}) where T =
    max(radius(rules[1]), maxradius(tail(rules))...)
maxradius(rules::Tuple{}) = 0

radius(rule::AbstractNeighborhoodRule) = radius(neighborhood(rule))
radius(rule::AbstractPartialNeighborhoodRule) = radius(neighborhood(rule))
radius(rule::AbstractRule) = 0
# Only the first rule in a chain can have a radius.
radius(chain::Chain) = radius(chain[1])
