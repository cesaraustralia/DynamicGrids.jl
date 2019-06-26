
@mix @description struct Radius{R}
    radius::R | "The 'radius' of the neighborhood is the distance to the edge from the center cell. "
end


abstract type AbstractRadiusType end

struct Moore <: AbstractRadiusType end

abstract type AbstractVonNeumann <: AbstractRadiusType end
struct VonNeumann <: AbstractVonNeumann end
struct RotVonNeumann <: AbstractVonNeumann end


"""
Neighborhoods define how surrounding cells are related to the current cell.
The `neighbors` function returns the sum of surrounding cells, as defined
by the neighborhood.
"""
abstract type AbstractNeighborhood end

abstract type AbstractRadialNeighborhood{T} <: AbstractNeighborhood end

radius(hood::AbstractNeighborhood) = hood.radius

"""
Radial neighborhoods calculate the surrounding neighborood
from the radius around the central cell, with a number of variants. 
"""
@Radius struct RadialNeighborhood{T} <: AbstractRadialNeighborhood{T} end 
"""
    RadialNeighborhood(;typ = :moore, radius = 1)
The radial neighborhood constructor with defaults.

This neighborhood can be used for one-dimensional, Moore, von Neumann or 
Rotated von Neumann neigborhoods, and may have a radius of any integer size.

### Keyword Arguments
- typ : A Symbol from :moore, :vonneumann or :rotvonneumann. Default: :moore
- radius: Int. Default: 1
"""
RadialNeighborhood(; typ=Moore, radius=1) = RadialNeighborhood{typ, typeof(radius)}(radius)

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
    neighborcoords::N | "A tuple of tuples of Int, containing 2-D coordinates relative to the central point"
end

"""
Sets of custom neighborhoods that can have separate rules for each set.
"""
@Radius struct MultiCustomNeighborhood{N} <: AbstractCustomNeighborhood
    multineighbors::N | "A tuple of tuple of tuples of Int, contains 2-D coordinates relative to the central point. "
end

"""
    neighbors(hood::AbstractRadialNeighborhood, data, state, index, args...)
Sums 2-dimensional radial Von Neumann Nieghborhoods. Shapes are determined by [`inhood`](@ref).
"""
neighbors(hood::RadialNeighborhood{<:AbstractVonNeumann}, model, data, state, index, args...) = begin
    r = radius(hood)
    # Initialise minus the current cell value, as it will be added back in the loop
    buf = buffer(data)
    n = zero(eltype(buf))
    # Sum active cells in the neighborhood
    for x in -r:r, y in -r:r
        inhood(hood, (x, y)) && continue
        x == 0 && y == 0 && continue
        n += buf[x + r + 1, y + r + 1]
    end
    n 
end

"Check cell is inside its neighborhood"
inhood(hood::AbstractRadialNeighborhood{VonNeumann}, index) =
    sum(abs.(index)) <= radius(hood)
inhood(hood::AbstractRadialNeighborhood{RotVonNeumann}, index) =
    sum(abs.(index)) > radius(hood)

"""
    neighbors(hood::RadialNeighborhood{:moore}, data, state, index, args...)

Sums moore nieghborhoods of any dimension. 
"""
neighbors(hood::RadialNeighborhood{Moore}, model, data, state, index, args...) = 
    sum(buffer(data)) - state

"""
    neighbors(hood::AbstractCustomNeighborhood, data, state, index, args...)
Sum a single custom neighborhood.
"""
neighbors(hood::AbstractCustomNeighborhood, model, data, state, index, args...) =
    custom_neighbors(hood.neighborcoords, hood, data)

custom_neighbors(neighborcoords, hood, data) = begin
    r = radius(hood)
    buf = buffer(data)
    # Initialise to empty
    n = zero(eltype(buf))
    # Sum active cells in the neighborhood
    for neighborcoord in neighborcoords
        n += buf[(neighborcoord .+ r .+ 1)...] 
    end
    n
end

"""
    neighbors(hood::MultiCustomNeighborhood, data, state, index, args...)
Sum multiple custom neighborhoods separately.
"""
neighbors(hood::MultiCustomNeighborhood, model, data, state, index, args...) = 
    multi_neighbors(hood.multineighbors, hood, data)

multi_neighbors(multineighbors::Tuple, hood, data) = 
    (custom_neighbors(multineighbors[1], hood, data), 
     multi_neighbors(tail(multineighbors), hood, data)...)
multi_neighbors(multineighbors::Tuple{}, hood, data) = () 
