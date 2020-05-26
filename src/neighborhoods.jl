
"""
Neighborhoods define how surrounding cells are related to the current cell.
The `neighbors` function returns the sum of surrounding cells, as defined
by the neighborhood.

Neighborhoods are iterable, so 

for n in hood
    if n > 3 
end   

If the allocation of neighborhood buffers during the simulation is costly 
(it usually isn't) you can use `allocbuffers` or preallocate them:

```julia
RadialNeighborhood{3}(allocbuffers(3, init))
```

You can also change the length of the buffers tuple to 
experiment with cache performance.
"""
abstract type Neighborhood{R,B} end

ConstructionBase.constructorof(::Type{<:T}) where T <: Neighborhood{R} where R = 
    T.name.wrapper{R}

radius(hood::Neighborhood{R}) where R = R
buffer(hood::Neighborhood{<:Any,<:Tuple}) = first(hood.buffer)
buffer(hood::Neighborhood{<:Any,<:AbstractArray}) = hood.buffer

Base.eltype(hood::Neighborhood) = eltype(buffer(hood))
Base.iterate(hood::Neighborhood, args...) = iterate(neighbors(hood), args...)
Base.getindex(hood::Neighborhood, I...) = getindex(buffer(hood), I...)
Base.setindex!(hood::Neighborhood, val, I...) = setindex!(buffer(hood), val, I...)
Base.copyto!(dest::Neighborhood, dof, source::Neighborhood, sof, N) =
    copyto!(buffer(dest), dof, buffer(source), sof, N)


"""
A Moore-style neighborhood where a square are with a center radius `(D - 1) / 2`
where D is the diameter.
"""
abstract type AbstractRadialNeighborhood{R,B} <: Neighborhood{R,B} end

"""
    neighbors(hood::AbstractRadialNeighborhood, buffer)

Returns a generator of the cell neighbors, skipping the central cell.
"""
neighbors(hood::AbstractRadialNeighborhood) = begin
    hoodlen = hoodsize(hood)^2
    centerpoint = hoodlen ÷ 2 + 1
    (buffer(hood)[i] for i in 1:hoodlen if i != centerpoint)
end

"""
    RadialNeighborhood{R}([buffer])

Radial neighborhoods calculate the surrounding neighborhood
from the radius around the central cell. The central cell
is omitted.

The `buffer` argument may be required for performance 
optimisation, see [`Neighborhood`] for details.
"""
struct RadialNeighborhood{R,B} <: AbstractRadialNeighborhood{R,B} 
    buffer::B
end
RadialNeighborhood{R}(buffer=nothing) where R =
    RadialNeighborhood{R,typeof(buffer)}(buffer)

# Custom `sum` for performance:w
Base.sum(hood::RadialNeighborhood, cell=_centerval(hood)) = 
    sum(buffer(hood)) - cell 

_centerval(hood) = buffer(hood)[radius(hood) + 1, radius(hood) + 1]

Base.length(hood::RadialNeighborhood{R}) where R = (2R + 1)^2 - 1

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
abstract type AbstractCustomNeighborhood{R,B} <: Neighborhood{R,B} end

const CustomCoord = Tuple{Vararg{Int}}
const CustomCoords = Tuple{Vararg{<:CustomCoord}}

"""
    CustomNeighborhood(coord::Tuple{Vararg{Int}}...)
    CustomNeighborhood(coords::Tuple{Tuple{Vararg{Int}}}, [buffer=nothing])
    CustomNeighborhood{R}(coords::Tuple, buffer)

Allows arbitrary neighborhood shapes by specifying each coord, which are simply 
`Tuple`s of `Int` distance (positive and negative) from the central point. 

The neighborhood radius is calculated from the most distance coordinate. 
For simplicity the buffer read from the main grid is a square with sides
`2R + 1` around the central point, and is not shrunk or offset to match the 
coordinates if they are not symmetrical.

The `buffer` argument may be required for performance 
optimisation, see [`Neighborhood`] for more details.
"""
@description @flattenable struct CustomNeighborhood{R,C<:CustomCoords,B} <: AbstractCustomNeighborhood{R,B}
    coords::C | false | "A tuple of tuples of Int, containing 2-D coordinates relative to the central point"
    buffer::B
end

CustomNeighborhood(args::CustomCoord...) = CustomNeighborhood(args)
CustomNeighborhood(coords::CustomCoords, buffer=nothing) =
    CustomNeighborhood{absmaxcoord(coords)}(coords, buffer)
CustomNeighborhood{R}(coords::CustomCoords, buffer) where R =
    CustomNeighborhood{R,typeof(coords),typeof(buffer)}(coords, buffer)

ConstructionBase.constructorof(::Type{CustomNeighborhood{R,C,B}}) where {R,C,B} = 
    CustomNeighborhood{R}

coords(hood::CustomNeighborhood) = hood.coords

Base.length(hood::CustomNeighborhood) = length(coords(hood))

# Calculate the maximum absolute value in the coords to use as the radius
absmaxcoord(coords::Tuple) = maximum(map(x -> maximum(map(abs, x)), coords))
absmaxcoord(neighborhood::CustomNeighborhood) = absmaxcoord(coords(neighborhood))

neighbors(hood::CustomNeighborhood) =
    (buffer(hood)[(coord .+ radius(hood) .+ 1)...] for coord in coords(hood))


@inline mapsetneighbor!(data::WritableGridData, hood::CustomNeighborhood, rule, state, index) = begin
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
@description struct LayeredCustomNeighborhood{R,L,B} <: AbstractCustomNeighborhood{R,B}
    layers::L  | "A tuple of custom neighborhoods"
    buffer::B | _
end
LayeredCustomNeighborhood(layers::Tuple{Vararg{<:CustomNeighborhood}}, buffer) =
    LayeredCustomNeighborhood{maximum(absmaxcoord.(layers))}(layers, buffer)
LayeredCustomNeighborhood{R}(layers, buffer) where R = begin
    # Child layers must have the same buffer
    layers = map(l -> (@set l.buffer = buffer), layers)
    LayeredCustomNeighborhood{R,typeof(layers),typeof(buffer)}(layers, buffer)
end


@inline neighbors(hood::LayeredCustomNeighborhood) =
    map(l -> neighbors(l), hood.layers)

@inline Base.sum(hood::LayeredCustomNeighborhood) = map(sum, neighbors(hood))

@inline mapsetneighbor!(data::WritableGridData, hood::LayeredCustomNeighborhood, rule, state, index) =
    map(layer -> mapsetneighbor!(data, layer, rule, state, index), hood.layers)

"""
A convenience wrapper to build a VonNeumann neighborhoods as a `CustomNeighborhood`.

TODO: variable radius
"""
VonNeumannNeighborhood(buffer=nothing) = 
    CustomNeighborhood(((0,-1), (-1,0), (1,0), (0,1)), buffer)

"""
Find the largest radius present in the passed in rules.
"""
radius(set::Ruleset) = radius(rules(set))
radius(rules::Tuple{Vararg{<:Rule}}) = begin
    allkeys = Tuple(union(map(keys, rules)...))
    maxradii = Tuple(radius(rules, key) for key in allkeys)
    return NamedTuple{allkeys}(maxradii)
end
radius(rules::Tuple{}) = NamedTuple{(),Tuple{}}(())
# Get radius of specific key from all rules
radius(rules::Tuple{Vararg{<:Rule}}, key::Symbol) =
    reduce(max, radius(i) for i in rules if key in keys(i); init=0)

# TODO radius only for neighborhood grid
radius(rule::NeighborhoodRule, args...) = radius(neighborhood(rule))
radius(rule::ManualNeighborhoodRule, args...) = radius(neighborhood(rule))
radius(rule::Rule, args...) = 0


# Build rules and neighborhoods for each buffer, so they
# don't have to be constructed in the loop
spreadbuffers(chain::Chain, grid) = 
    map(r -> Chain(r, tail(rules(chain))...), spreadbuffers(rules(chain)[1], grid))
spreadbuffers(rule::Rule, grid) = spreadbuffers(rule, neighborhood(rule), buffer(neighborhood(rule)), grid)
spreadbuffers(rule::NeighborhoodRule, hood::Neighborhood, buffers, grid) = 
    spreadbuffers(rule, hood, allocbuffers(grid, hood), grid)
spreadbuffers(rule::NeighborhoodRule, hood::Neighborhood, buffers::Tuple, grid) = 
    map(b -> (@set rule.neighborhood.buffer = b), buffers)

"""
    hoodsize(radius)

Get the size of a neighborhood dimension from its radius,
which is always 2r + 1.
"""
@inline hoodsize(hood::Neighborhood) = hoodsize(radius(hood))
@inline hoodsize(radius::Integer) = 2radius + 1

