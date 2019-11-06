
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

"""
    neighbors(hood::AbstractRadialNeighborhood, buf, state)

Sums radial Moore nieghborhoods of any dimension.
"""
neighbors(hood::AbstractRadialNeighborhood, model, buf, state) = sum(buf) - state

@inline mapreduceneighbors(f, data, hood::AbstractRadialNeighborhood, rule, state, index) = begin
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
            sum += f(data, hood, rule, state, hood_index, dest_index)
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
@description struct CustomNeighborhood{R,C} <: AbstractCustomNeighborhood{R}
    coords::C | "A tuple of tuples of Int, containing 2-D coordinates relative to the central point"
end
CustomNeighborhood(args...) = CustomNeighborhood(args)
CustomNeighborhood(coords) = CustomNeighborhood{absmaxcoord(coords), typeof(coords)}(coords)

coords(hood::CustomNeighborhood) = hood.coords
# Calculate the maximum absolute value in the coords to use as the radius
absmaxcoord(coords) = maximum((x -> maximum(abs.(x))).(coords))

neighbors(hood::CustomNeighborhood, rule, buf, state) = begin
    r = radius(hood); sum = zero(state)
    for coord in coords(hood)
        sum += buf[(coord .+ r .+ 1)...]
    end
    sum
end

@inline mapreduceneighbors(f, data, hood::CustomNeighborhood, rule, state, index) = begin
    r = radius(hood); sum = zero(state)
    # Loop over dispersal kernel grid dimensions
    for coord in coords(hood)
        hood_index = coord .+ r
        dest_index = index .+ coord
        sum += f(data, hood, rule, state, hood_index, dest_index)
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

@inline neighbors(hood::LayeredCustomNeighborhood, rule, buf, state) = 
    map(layer -> neighbors(layer, rule, buf, state), hood.layers)

@inline mapreduceneighbors(f, data, hood::LayeredCustomNeighborhood, rule, state, index) = 
    map(layer -> mapreduceneighbors(f, data, layer, rule, state, index), hood.layers)

"""
A convenience wrapper to build a VonNeumann neighborhoods as a `CustomNeighborhood`.

# TODO: variable radius
"""
VonNeumannNeighborhood() = CustomNeighborhood(((0,-1), (-1,0), (1,0), (0,1)))


"""
Find the largest radius present in the passed in rules.
"""
radius(set::Ruleset) = max(radius(rules(ruleset)))
radius(set::MultiRuleset) = begin
    ruleradius = map(radius, map(rules, ruleset(set)))
    intradius = map(key -> radius(interactions(set), key), map(Val, keys(set)))
    map(max, Tuple(ruleradius), Tuple(intradius))
end
radius(ruleset::Ruleset) = radius(rules(ruleset))
radius(rules::Tuple) = mapreduce(radius, max, rules)
radius(rules::Tuple, key) = mapreduce(rule -> radius(rule, key), max, rules)
radius(rules::Tuple{}, args...) = 0

radius(rule::NeighborhoodRule) = radius(neighborhood(rule))
radius(rule::PartialNeighborhoodRule) = radius(neighborhood(rule))
radius(rule::Rule, args...) = 0
# Only the first rule in a chain can have a radius larger than zero.
radius(chain::Chain) = radius(chain[1])
