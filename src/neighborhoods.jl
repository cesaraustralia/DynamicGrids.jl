"Abstract type to extend to a neighborhood"
abstract type AbstractNeighborhood end

"Abstract type to extend [`RadialNeighborhoods`](@ref)"
abstract type AbstractRadialNeighborhood{T} <: AbstractNeighborhood end

@mix struct Overflow{O}
    "[`AbstractOverflow`](@ref). Determines how co-ordinates outside of the grid are handled"
    overflow::O
end

"""
Radial neighborhoods calculate the surrounding neighborood
from the radius around the central cell, with a number of variants. 

They can be constructed with: `RadialNeighborhood{:moore,Skip}(1,Skip())` but the keyword 
constructor should be preferable.
"""
@Overflow struct RadialNeighborhood{T} <: AbstractRadialNeighborhood{T}
    """
    The 'radius' of the neighborhood is the distance to the edge
    from the center cell. A neighborhood with radius 1 is 3 cells wide.
    """
    radius::Int32
end 
"""
    RadialNeighborhood(;typ = :moore, radius = 1, overflow = Skip)
The radial neighborhood constructor with defaults.

This neighborhood can be used for one-dimensional, Moore, von Neumann or 
Rotated von Neumann neigborhoods, and may have a radius of any integer size.

### Keyword Arguments
- typ : A Symbol from :onedim, :moore, :vonneumann or :rotvonneumann. Default: :moore
- radius: Int. Default: 1
- overflow: [`AbstractOverflow`](@ref). Default: Skip()
"""
RadialNeighborhood(; typ=:moore, radius=Int32(1), overflow=Skip()) =
    RadialNeighborhood{typ, typeof(overflow)}(radius, overflow)

""" Custom neighborhoods are tuples of custom coordinates in relation to the central point
of the current cell. They can be any arbitrary shape or size.
"""
abstract type AbstractCustomNeighborhood <: AbstractNeighborhood end

"""
Allows completely arbitrary neighborhood shapes by specifying each coordinate
specifically.
"""
@Overflow struct CustomNeighborhood{H} <: AbstractCustomNeighborhood
    """
    A tuple of tuples of Int (or an array of arrays of Int, etc),
    contains 2-D coordinates relative to the central point
    """
    neighbors::H
end

"""
Sets of custom neighborhoods that can have separate rules for each set.
"""
@Overflow struct MultiCustomNeighborhood{H, C} <: AbstractCustomNeighborhood
    """
    A tuple of tuple of tuples of Int (or an array of arrays of arrays of Int, etc),
    contains 2-D coordinates relative to the central point.
    """
    multineighbors::H
    "A vector the length of the base multineighbors tuple, for intermediate storage"
    cc::C
end
MultiCustomNeighborhood(;multi=(), overflow=Wrap(), init=Int32[0]) = 
    MultiCustomNeighborhood(multi, typeof(init)(zeros(eltype(init), length(multi))), overflow)


"""
    neighbors(hood::AbstractNeighborhood, state, row, col, t, source, args...)
Checks all cells in neighborhood and combines them according
to the particular neighborhood type.
"""
function neighbors() end

"""
    neighbors(hood::AbstractRadialNeighborhood{:onedim}, state, row, col, t, source, args...)
Sums single dimension radial neighborhoods. Commonly used by Wolfram.
"""
neighbors(hood::AbstractRadialNeighborhood{:onedim}, model, state, row, col, t, source, args...) = begin
    width = size(source)
    r = hood.radius
    # Initialise minus the current cell value, as it will be added back in the loop
    cc = -source[row, col]
    # Sum active cells in the neighborhood
    for p = (row, col - r):(row, col + r)
        p = bounded(p, width, hood.overflow)
        cc += source[p]
    end
    cc
end

"""
    neighbors(hood::AbstractRadialNeighborhood, state, row, col, t, source, args...)
Sums 2-dimensional radial Nieghborhoods. Specific shapes like Moore and Von Neumann
are determined by [`inhood`](@ref), as this method is general.
"""
neighbors(hood::AbstractRadialNeighborhood, model, state, row, col, t, source, args...) = begin
    height, width = size(source)
    r = hood.radius
    # Initialise minus the current cell value, as it will be added back in the loop
    cc = zero(state) 
    # Sum active cells in the neighborhood
    for p = (row - r):(row + r), q = (col - r):(col + r) 
        if ((p, q) == (row, col)) 
            # println((p, q), (row, col))
            continue
        end
        # println((p, q))
        p, q, is_inbounds = inbounds((p, q), (height, width), hood.overflow)
        is_inbounds && inhood(hood, p, q, row, col) || continue
        # println((p, q))
        cc += source[p, q]
    end
    # println(cc)
    cc
end

"""
    neighbors(hood::AbstractCustomNeighborhood, state, row, col, t, source, args...)
Sum a single custom neighborhood.
"""
neighbors(hood::AbstractCustomNeighborhood, model, state, row, col, t, source, args...) =
    custom_neighbors(hood.neighbors, hood, row, col, t, source, args...)

"""
    neighbors(hood::MultiCustomNeighborhood, state, row, col, t, source, args...)
Sum multiple custom neighborhoods separately.
"""
neighbors(hood::MultiCustomNeighborhood, model, state, row, col, t, source, args...) = begin
    for i = 1:length(hood.multineighbors)
        hood.cc[i] = custom_neighbors(hood.multineighbors[i], hood, row, col, t, source)
    end
    hood.cc
end

custom_neighbors(n, hood, row, col, t, source) = begin
    height, width = size(source)
    # Initialise to empty
    cc = zero(eltype(source))
    # Sum active cells in the neighborhood
    for (a, b) in n
        p, q, is_inbounds = inbounds((a + row, b + col), (height, width), hood.overflow)
        is_inbounds || continue
        cc += source[p, q]
    end
    cc
end


"""
    inhood(n::AbstractRadialNeighborhood{:moore}, p, q, row, col)
Check cell is inside a Moore neighborhood. Always returns `true`.
"""
inhood(n::AbstractRadialNeighborhood{:moore}, p, q, row, col) = true
"""
    inhood(n::AbstractRadialNeighborhood{:vonneumann}, p, q, row, col)
Check cell is inside a Vonn-Neumann neighborhood, returning a boolean.
"""
inhood(n::AbstractRadialNeighborhood{:vonneumann}, p, q, row, col) =
    (abs(p - row) + abs(q - col)) <= n.radius
"""
    inhood(n::AbstractRadialNeighborhood{:rotvonneumann}, p, q, row, col)
Check cell is inside a Rotated Von-Neumann neighborhood, returning a boolean.
"""
inhood(n::AbstractRadialNeighborhood{:rotvonneumann}, p, q, row, col) =
    (abs(p - row) + abs(q - col)) > n.radius
