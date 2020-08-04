
"""
Neighborhoods define the pattern of surrounding cells in the "neighborhood"
of the current cell. The `neighbors` function returns the surrounding
cells as an iterable.

The main kinds of neighborhood are demonstrated below:

![Neighborhoods](https://raw.githubusercontent.com/cesaraustralia/DynamicGrids.jl/media/Neighborhoods.png)

If the allocation of neighborhood buffers during the simulation is costly
(it usually isn't) you can use `allocbuffers` or preallocate them:

```julia
Moore{3}(allocbuffers(3, init))
```

You can also change the length of the buffers tuple to
experiment with cache performance.
"""
abstract type Neighborhood{R,B} end

ConstructionBase.constructorof(::Type{<:T}) where T <: Neighborhood{R} where R =
    T.name.wrapper{R}

radius(hood::Neighborhood{R}) where R = R
buffer(hood::Neighborhood) = hood.buffer

Base.eltype(hood::Neighborhood) = eltype(buffer(hood))
Base.iterate(hood::Neighborhood, args...) = iterate(neighbors(hood), args...)
Base.getindex(hood::Neighborhood, I...) = getindex(buffer(hood), I...)
Base.setindex!(hood::Neighborhood, val, I...) = setindex!(buffer(hood), val, I...)
Base.copyto!(dest::Neighborhood, dof, source::Neighborhood, sof, N) =
    copyto!(buffer(dest), dof, buffer(source), sof, N)


"""
Moore-style square neighborhoods
"""
abstract type AbstractRadialNeighborhood{R,B} <: Neighborhood{R,B} end

"""
    neighbors(hood::AbstractRadialNeighborhoodbuffer)

Returns a generator of the cell neighbors, skipping the central cell.
"""
neighbors(hood::AbstractRadialNeighborhood) = begin
    hoodlen = hoodsize(hood)^2
    centerpoint = hoodlen ÷ 2 + 1
    (buffer(hood)[i] for i in 1:hoodlen if i != centerpoint)
end

"""
    Moore(radius::Int=1)

Moore neighborhoods define the neighborhood as all cells within a horizontal or
vertical distance of the central cell. The central cell is omitted.

The `buffer` argument may be required for performance
optimisation, see [`Neighborhood`](@ref) for details.
"""
struct Moore{R,B} <: AbstractRadialNeighborhood{R,B}
    buffer::B
end
# Buffer is updated later during the simulation.
# but can be passed in now to avoid the allocation.
# This might be bad design. SimData could instead hold a list of
# ruledata for the rule that holds this buffer, with
# the neighborhood. So you can do neighbors(data)
Moore(radius::Int=1, buffer=nothing) =
    Moore{radius}(buffer)
Moore{R}(buffer=nothing) where R =
    Moore{R,typeof(buffer)}(buffer)

# Neighborhood specific `sum` for performance:w
Base.sum(hood::Moore, cell=_centerval(hood)) =
    sum(buffer(hood)) - cell

_centerval(hood) = buffer(hood)[radius(hood) + 1, radius(hood) + 1]

Base.length(hood::Moore{R}) where R = (2R + 1)^2 - 1

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
Neighborhoods are tuples or vectors of custom coordinates tuples
that are specified in relation to the central point of the current cell.
They can be any arbitrary shape or size, but should be listed in column-major
order for performance.
"""
abstract type AbstractPositional{R,B} <: Neighborhood{R,B} end

const CustomCoord = Tuple{Vararg{Int}}
const CustomCoords = Union{AbstractArray{<:CustomCoord},Tuple{Vararg{<:CustomCoord}}}

"""
    Positional(coord::Tuple{Vararg{Int}}...)
    Positional(coords::Tuple{Tuple{Vararg{Int}}}, [buffer=nothing])
    Positional{R}(coords::Tuple, buffer)

Neighborhoods that can take arbitrary shapes by specifying each coordinate,
as `Tuple{Int,Int}` of the row/column distance (positive and negative)
from the central point.

The neighborhood radius is calculated from the most distance coordinate.
For simplicity the buffer read from the main grid is a square with sides
`2r + 1` around the central point, and is not shrunk or offset to match the
coordinates if they are not symmetrical.

The `buffer` argument may be required for performance
optimisation, see [`Neighborhood`] for more details.
"""
@description @flattenable struct Positional{R,C<:CustomCoords,B} <: AbstractPositional{R,B}
    coords::C | false | "A tuple of tuples of Int, containing 2-D coordinates relative to the central point"
    buffer::B
end

Positional(args::CustomCoord...) = Positional(args)
Positional(coords::CustomCoords, buffer=nothing) =
    Positional{absmaxcoord(coords)}(coords, buffer)
Positional{R}(coords::CustomCoords, buffer=nothing) where R =
    Positional{R,typeof(coords),typeof(buffer)}(coords, buffer)

ConstructionBase.constructorof(::Type{Positional{R,C,B}}) where {R,C,B} =
    Positional{R}

coords(hood::Positional) = hood.coords

Base.length(hood::Positional) = length(coords(hood))

# Calculate the maximum absolute value in the coords to use as the radius
absmaxcoord(coords::Union{AbstractArray,Tuple}) = maximum(map(x -> maximum(map(abs, x)), coords))
absmaxcoord(neighborhood::Positional) = absmaxcoord(coords(neighborhood))

"""
    neighbors(hood::Positional)

Returns an iterator over the `Positional` neighborhood cells around the current index.
"""
neighbors(hood::Positional) =
    (buffer(hood)[(coord .+ radius(hood) .+ 1)...] for coord in coords(hood))

@inline mapsetneighbor!(data::WritableGridData, hood::Positional, rule, state, index) = begin
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
    LayeredPositional(layers::Positional...)

Sets of [`Positional`](@ref) neighborhoods that can have separate rules for each set.

`neighbors` for `LayeredPositional` returns a tuple of iterators
for each neighborhood layer.
"""
@description struct LayeredPositional{R,L,B} <: AbstractPositional{R,B}
    layers::L | "A tuple of custom neighborhoods"
    buffer::B | _
end
LayeredPositional(layers::Positional...) =
    LayeredPositional(layers)
LayeredPositional(layers::Tuple{Vararg{<:Positional}}, buffer=nothing) =
    LayeredPositional{maximum(map(radius, layers))}(layers, buffer)
LayeredPositional{R}(layers, buffer) where R = begin
    # Child layers must have the same buffer
    layers = map(l -> (@set l.buffer = buffer), layers)
    LayeredPositional{R,typeof(layers),typeof(buffer)}(layers, buffer)
end


"""
    neighbors(hood::Positional)

Returns a tuple of iterators over each `Positional` neighborhood
layer, for the cells around the current index.
"""
@inline neighbors(hood::LayeredPositional) =
    map(l -> neighbors(l), hood.layers)

@inline Base.sum(hood::LayeredPositional) = map(sum, neighbors(hood))

@inline mapsetneighbor!(data::WritableGridData, hood::LayeredPositional, rule, state, index) =
    map(layer -> mapsetneighbor!(data, layer, rule, state, index), hood.layers)

"""
    VonNeumann(radius=1)

A convenience wrapper to build Von-Neumann neighborhoods as
a [`Positional`](@ref) neighborhood.
"""
VonNeumann(radius=1, buffer=nothing) = begin
    coords = Tuple{Int,Int}[]
    rng = -radius:radius
    for j in rng, i in rng
        distance = abs(i) + abs(j)
        if distance <= radius && distance > 0
            push!(coords, (i, j))
        end
    end
    Positional(coords, buffer)
end

# Find the largest radius present in the passed in rules.
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
spreadbuffers(chain::Chain{R,W}, init::AbstractArray) where {R,W} = begin
    buffers, bufrules = spreadbuffers(rules(chain)[1], init)
    buffers, map(r -> Chain{R,W}((r, tail(rules(chain))...)), bufrules)
end
spreadbuffers(rule::Rule, init::AbstractArray) =
    spreadbuffers(rule, neighborhood(rule), buffer(neighborhood(rule)), init)
spreadbuffers(rule::NeighborhoodRule, hood::Neighborhood, buffers, init::AbstractArray) =
    spreadbuffers(rule::NeighborhoodRule, hood::Neighborhood, allocbuffers(init, hood), init)
spreadbuffers(rule::NeighborhoodRule, hood::Neighborhood, buffers::Tuple, init::AbstractArray) =
    buffers, map(b -> (@set rule.neighborhood.buffer = b), buffers)

"""
    allocbuffers(init::AbstractArray, hood::Neighborhood)
    allocbuffers(init::AbstractArray, radius::Int)

Allocate buffers for the Neighborhood. The `init` array should
be of the same type as the grid the neighborhood runs on.
"""
@inline allocbuffers(init::AbstractArray, hood::Neighborhood{R}) where R = allocbuffers(init, R)
@inline allocbuffers(init::AbstractArray, r::Int) = ntuple(i -> allocbuffer(init, r), 2r)

@inline allocbuffer(init::AbstractArray, hood::Neighborhood{R}) where R = allocbuffer(init, R)
@inline allocbuffer(init::AbstractArray, r::Int) = zeros(eltype(init), 2r+1, 2r+1)

"""
    hoodsize(radius)

Get the size of a neighborhood dimension from its radius,
which is always 2r + 1.
"""
@inline hoodsize(hood::Neighborhood) = hoodsize(radius(hood))
@inline hoodsize(radius::Integer) = 2radius + 1
