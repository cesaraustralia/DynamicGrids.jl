
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
abstract type Neighborhood{R} end

ConstructionBase.constructorof(::Type{<:T}) where T <: Neighborhood{R} where R =
    T.name.wrapper{R}

radius(hood::Neighborhood{R}) where R = R
buffer(hood::Neighborhood) = hood.buffer
@inline positions(hood::Neighborhood, I) = (I .+ o for o in offsets(hood))

Base.eltype(hood::Neighborhood) = eltype(buffer(hood))
Base.iterate(hood::Neighborhood, args...) = iterate(neighbors(hood), args...)
Base.getindex(hood::Neighborhood, I...) = getindex(buffer(hood), I...)
Base.setindex!(hood::Neighborhood, val, I...) = setindex!(buffer(hood), val, I...)
Base.copyto!(dest::Neighborhood, dof, source::Neighborhood, sof, N) =
    copyto!(buffer(dest), dof, buffer(source), sof, N)

"""
Moore-style square neighborhoods
"""
abstract type RadialNeighborhood{R} <: Neighborhood{R} end

"""
    Moore(radius::Int=1)

Moore neighborhoods define the neighborhood as all cells within a horizontal or
vertical distance of the central cell. The central cell is omitted.

The `buffer` argument may be required for performance
optimisation, see [`Neighborhood`](@ref) for details.
"""
struct Moore{R,B} <: RadialNeighborhood{R}
    buffer::B
end
# Buffer is updated later during the simulation.
# but can be passed in now to avoid the allocation.
# This might be bad design. SimData could instead hold a list of
# ruledata for the rule that holds this buffer, with
# the neighborhood. So you can do neighbors(data)
Moore(radius::Int=1, buffer=nothing) = Moore{radius}(buffer)
Moore{R}(buffer=nothing) where R = Moore{R,typeof(buffer)}(buffer)

@inline function neighbors(hood::Moore{R}) where R
    # Use linear indexing
    buflen = (2R + 1)^2
    centerpoint = buflen ÷ 2 + 1
    return (buffer(hood)[i] for i in 1:buflen if i != centerpoint)
end
@inline function offsets(hood::Moore{R}) where R
    ((i, j) for j in -R:R, i in -R:R if i != (0, 0))
end
@inline setbuffer(n::Moore{R}, buf::B2) where {R,B2} = Moore{R,B2}(buf)

Base.length(hood::Moore{R}) where R = (2R + 1)^2 - 1
# Neighborhood specific `sum` for performance:w
Base.sum(hood::Moore) = _sum(hood, _centerval(hood))

_centerval(hood::Neighborhood{R}) where R = buffer(hood)[R + 1, R + 1]
_sum(hood::Neighborhood, cell) = sum(buffer(hood)) - cell


"""
Abstract supertype for kernel neighborhoods.

These inlude the central cell.
"""
abstract type AbstractKernel{R} <: RadialNeighborhood{R} end

kernel(hood::AbstractKernel) = hood.kernel

Base.length(hood::AbstractKernel{R}) where R = (2R + 1)^2
Base.sum(hood::AbstractKernel) = sum(buffer(hood))
neighbors(hood::AbstractKernel) = buffer(hood)

LinearAlgebra.dot(hood::AbstractKernel) = kernel(hood) ⋅ buffer(hood)
# The central cell is included
@inline offsets(hood::AbstractKernel{R}) where R = ((i, j) for j in -R:R, i in -R:R)

"""
    Kernel{R}(kernel, buffer=nothing)

"""
struct Kernel{R,K,B} <: AbstractKernel{R}
    "Kernal matrix"
    kernel::K
    "Neighborhood buffer"
    buffer::B
end
@inline Kernel{R}(kernel, buffer=nothing) where R = 
    Kernel{R,typeof(kernel),typeof(buffer)}(kernel, buffer)
@inline Kernel(kernel::AbstractMatrix, buffer=nothing) = 
    Kernel{(size(kernel, 1) - 1) ÷ 2}(kernel, buffer)
@inline Kernel{R}() where R = Kernel{R}(nothing, nothing)
@inline Kernel(R::Int) = Kernel{R}(nothing, nothing)
@inline ConstructionBase.constructorof(::Type{Kernel{R,K,B}}) where {R,K,B} = Kernel{R}

@inline setbuffer(n::Kernel{R,K}, buf::B2) where {R,K,B2} = Kernel{R,K,B2}(n.kernel, buf)


# Depreciated 

@inline function mapsetneighbor!(
    data::WritableGridData, hood::Neighborhood, rule, state, index
)
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
    return sum
end

@inline function mapsetneighbor!(
    f, data::WritableGridData, hood, state, index
)
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
    return sum
end

"""
Neighborhoods are tuples or vectors of custom coordinates tuples
that are specified in relation to the central point of the current cell.
They can be any arbitrary shape or size, but should be listed in column-major
order for performance.
"""
abstract type AbstractPositional{R} <: Neighborhood{R} end

const CustomOffset = Tuple{Vararg{Int}}
const CustomOffsets = Union{AbstractArray{<:CustomOffset},Tuple{Vararg{<:CustomOffset}}}

"""
    Positional(coord::Tuple{Vararg{Int}}...)
    Positional(offsets::Tuple{Tuple{Vararg{Int}}}, [buffer=nothing])
    Positional{R}(offsets::Tuple, buffer)

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
struct Positional{R,O<:CustomOffsets,B} <: AbstractPositional{R}
    "A tuple of tuples of Int, containing 2-D coordinates relative to the central point"
    offsets::O
    buffer::B
end
Positional(args::CustomOffset...) = Positional(args)
Positional(offsets::CustomOffsets, buffer=nothing) =
    Positional{_absmaxcoord(offsets)}(offsets, buffer)
Positional{R}(offsets::CustomOffsets, buffer=nothing) where R =
    Positional{R,typeof(offsets),typeof(buffer)}(offsets, buffer)

# Calculate the maximum absolute value in the offsets to use as the radius
_absmaxcoord(offsets::Union{AbstractArray,Tuple}) = maximum(map(x -> maximum(map(abs, x)), offsets))
_absmaxcoord(neighborhood::Positional) = absmaxcoord(offsets(neighborhood))

ConstructionBase.constructorof(::Type{Positional{R,C,B}}) where {R,C,B} = Positional{R}

Base.length(hood::Positional) = length(offsets(hood))

offsets(hood::Positional) = hood.offsets
@inline neighbors(hood::Positional) =
    (buffer(hood)[(offset .+ radius(hood) .+ 1)...] for offset in offsets(hood))
@inline setbuffer(n::Positional{R,O}, buf::B2) where {R,O,B2} = Positional{R,O,B2}(offsets(n), buf)

@inline function mapsetneighbor!(
    data::WritableGridData, hood::Positional, rule, state, index
)
    r = radius(hood); sum = zero(state)
    # Loop over dispersal kernel grid dimensions
    for offset in offsets(hood)
        hood_index = offset .+ r
        dest_index = index .+ offset
        sum += setneighbor!(data, hood, rule, state, hood_index, dest_index)
    end
    return sum
end

"""
    LayeredPositional(layers::Positional...)

Sets of [`Positional`](@ref) neighborhoods that can have separate rules for each set.

`neighbors` for `LayeredPositional` returns a tuple of iterators
for each neighborhood layer.
"""
struct LayeredPositional{R,L,B} <: AbstractPositional{R}
    "A tuple of custom neighborhoods"
    layers::L
    buffer::B
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
@inline neighbors(hood::LayeredPositional) = map(l -> neighbors(l), hood.layers)
@inline offsets(hood::LayeredPositional) = map(l -> offsets(l), hood.layers)
@inline positions(hood::LayeredPositional, args...) = map(l -> positions(l, args...), hood.layers)
@inline setbuffer(n::LayeredPositional{R,L}, buf::B2) where {R,L,B2} = 
    LayeredPositional{R,L,B2}(n.layers, buf)

@inline Base.sum(hood::LayeredPositional) = map(sum, neighbors(hood))

@inline mapsetneighbor!(data::WritableGridData, hood::LayeredPositional, rule, state, index) =
    map(layer -> mapsetneighbor!(data, layer, rule, state, index), hood.layers)

"""
    VonNeumann(radius=1)

A convenience wrapper to build Von-Neumann neighborhoods as
a [`Positional`](@ref) neighborhood.
"""
function VonNeumann(radius=1, buffer=nothing)
    offsets = Tuple{Int,Int}[]
    rng = -radius:radius
    for j in rng, i in rng
        distance = abs(i) + abs(j)
        if distance <= radius && distance > 0
            push!(offsets, (i, j))
        end
    end
    return Positional(Tuple(offsets), buffer)
end


# Find the largest radius present in the passed in rules.
radius(set::Ruleset) = radius(rules(set))
function radius(rules::Tuple{Vararg{<:Rule}})
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

"""
    hoodsize(radius)

Get the size of a neighborhood dimension from its radius,
which is always 2r + 1.
"""
@inline hoodsize(hood::Neighborhood) = hoodsize(radius(hood))
@inline hoodsize(radius::Integer) = 2radius + 1
