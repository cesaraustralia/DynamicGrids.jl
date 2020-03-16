
"""
Neighborhoods define how surrounding cells are related to the current cell.
The `neighbors` function returns the sum of surrounding cells, as defined
by the neighborhood.
"""
abstract type Neighborhood{R} end

radius(hood::Neighborhood{R}) where R = R

"""
A Moore-style neighborhood where a square are with a center radius `(D - 1) / 2`
where D is the diameter.
"""
abstract type AbstractRadialNeighborhood{R} <: Neighborhood{R} end

"""
Radial neighborhoods calculate the surrounding neighborood
from the radius around the central cell. The central cell
is ommitted.
"""
struct RadialNeighborhood{R} <: AbstractRadialNeighborhood{R} end

ConstructionBase.constructorof(::Type{RadialNeighborhood{R}}) where R = RadialNeighborhood{R}()

neighbors(hood::AbstractRadialNeighborhood, buf) = begin
    hoodlen = hoodsize(hood)^2
    centerpoint = hoodlen ÷ 2 + 1
    (buf[i] for i in 1:hoodlen if i != centerpoint)
end

sumneighbors(hood::AbstractRadialNeighborhood, buf, state) = sum(buf) - state

@inline mapsetneighbor!(data::WritableGridData, hood::AbstractRadialNeighborhood, rule, state, index) = begin
    r = radius(hood)
    sum = zero(state)
    # Loop over dispersal kernel grid dimensions
    for x = one(r):2r + one(r)
        xdest = x + index[2] - r - one(r)
        for y = one(r):2r + one(r)
            x == (r + one(r)) && y == (r + one(r)) && continue
            ydest = y + index[1] - r - one(r)
            hood_index = (y, x)
            dest_index = (ydest, xdest)
            sum += setneighbor!(data, hood, rule, state, hood_index, dest_index)
        end
    end
    sum
end

"""
Custom neighborhoods are tuples of custom coordinates (also tuples) specified in relation
to the central point of the current cell. They can be any arbitrary shape or size, but
should be listed in column-major order for performance.
"""
abstract type AbstractCustomNeighborhood{R} <: Neighborhood{R} end

"""
Allows completely arbitrary neighborhood shapes by specifying each coordinate
specifically.
"""
@description @flattenable struct CustomNeighborhood{R,C} <: AbstractCustomNeighborhood{R}
    coords::C | false | "A tuple of tuples of Int, containing 2-D coordinates relative to the central point"
end
CustomNeighborhood{R}(coords) where R = CustomNeighborhood{R,typeof(coords)}(coords)
CustomNeighborhood(args...) = CustomNeighborhood(args)
CustomNeighborhood(coords) = CustomNeighborhood{absmaxcoord(coords),typeof(coords)}(coords)

ConstructionBase.constructorof(::Type{CustomNeighborhood}) where R = CustomNeighborhood{R}

coords(hood::CustomNeighborhood) = hood.coords
# Calculate the maximum absolute value in the coords to use as the radius
absmaxcoord(coords) = maximum((x -> maximum(abs.(x))).(coords))

neighbors(rule::NeighborhoodRule, buf) =
    neighbors(neighborhood(rule), buf)
neighbors(hood::CustomNeighborhood, buf) =
    (buf[(coord .+ radius(hood) .+ 1)...] for coord in coords(hood))

sumneighbors(hood::CustomNeighborhood, buf, state) =
    sum(neighbors(hood, buf))

@inline mapsetneighbor!(data::AbstractSimData, hood::CustomNeighborhood, rule, state, index) = begin
    r = radius(hood); sum = zero(state)
    # Loop over dispersal kernel grid dimensions
    for coord in coords(hood)
        hood_index = coord .+ r
        dest_index = index .+ coord
        sum += setneighbor!(data, hood, rule, state, hood_index, dest_index)
    end
    sum
end

"""
Sets of custom neighborhoods that can have separate rules for each set.
"""
@description struct LayeredCustomNeighborhood{R,C} <: AbstractCustomNeighborhood{R}
    layers::C | "A tuple of tuple of custom neighborhoods"
end
LayeredCustomNeighborhood(l::Tuple) =
    LayeredCustomNeighborhood{maximum(absmaxcoord.(coords.(l))), typeof(l)}(l)

@inline neighbors(hood::LayeredCustomNeighborhood, buf) =
    map(layer -> neighbors(layer, buf), hood.layers)

@inline sumneighbors(hood::LayeredCustomNeighborhood, buf, state) =
    map(layer -> sumneighbors(layer, buf, state), hood.layers)

@inline mapsetneighbor!(data::AbstractSimData, hood::LayeredCustomNeighborhood, rule, state, index) =
    map(layer -> mapsetneighbor!(data, layer, rule, state, index), hood.layers)

"""
A convenience wrapper to build a VonNeumann neighborhoods as a `CustomNeighborhood`.

TODO: variable radius
"""
VonNeumannNeighborhood() = CustomNeighborhood(((0,-1), (-1,0), (1,0), (0,1)))

"""
Find the largest radius present in the passed in rules.
"""
radius(set::Ruleset) = begin
    allkeys = Tuple(union(map(keys, rules(set))...))
    maxradii = Tuple(radius(rules(set), key) for key in allkeys)
    NamedTuple{allkeys}(maxradii)
end
radius(set::Ruleset{Tuple{}}) = NamedTuple{(),Tuple{}}(())
# Get radius of specific key from all rules
radius(rules::Tuple{<:Rule,Vararg}, key) =
    reduce(max, radius(i) for i in rules if key in keys(i); init=0)
radius(rules::Tuple) = mapreduce(radius, max, rules)
radius(rules::Tuple{}, args...) = 0

# TODO radius only for neighborhood grid
radius(rule::NeighborhoodRule, args...) = radius(neighborhood(rule))
radius(rule::PartialNeighborhoodRule, args...) = radius(neighborhood(rule))
radius(rule::Rule, args...) = 0
