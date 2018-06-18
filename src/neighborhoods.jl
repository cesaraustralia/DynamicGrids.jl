"""
$(TYPEDEF)
Neighborhoods define the behaviour towards the cells surrounding the current cell.
"""
abstract type AbstractNeighborhood end

"""
$(TYPEDEF)
Radial neighborhoods calculate the neighborood in a loop from simple rules
base of the radius of cells around the central cell.
"""
abstract type AbstractRadialNeighborhood{T} <: AbstractNeighborhood end

"""
$(TYPEDEF)
$(FIELDS)
"""
struct RadialNeighborhood{T,O} <: AbstractRadialNeighborhood{T} 
    radius::Int
    overflow::O
end

"""
    RadialNeighborhood(;typ = :moore, radius = 1, overflow = Skip)
Radial neighborhood constructor with defaults.

typ may be :onedim, :moore, :vonneumann or :rotvonneumann
radius is an Int, and overflop is [`Skip`](@ref) or [`Wrap`](@ref).
"""
RadialNeighborhood(; typ=:moore, radius=1, overflow=Skip()) =
    RadialNeighborhood{typ, typeof(overflow)}(radius, overflow)

"""
Custom neighborhoods are tuples of custom coordinates in relation to the central point
of the current cell. They can be any arbitrary shape or size.

$(TYPEDEF)
$(FIELDS)
"""
abstract type AbstractCustomNeighborhood <: AbstractNeighborhood end

"""
$(TYPEDEF)
$(FIELDS)
"""
struct CustomNeighborhood{H,O} <: AbstractCustomNeighborhood 
    neighbors::H
    overflow::O
end

"""
Multi custom neighborhoods are sets of custom neighborhoods that can have
separate rules for each set. cc is a vector used to store the output of these rules.

$(TYPEDEF)
$(FIELDS)
"""
struct MultiCustomNeighborhood{H,O} <: AbstractCustomNeighborhood 
    multineighbors::H
    cc::Vector{Int8}
    overflow::O
end
MultiCustomNeighborhood(mn) = MultiCustomNeighborhood(mn, zeros(Int8, length(mn)))


"""
    neighbors(h::AbstractNeighborhood, state, index, t, source, args...) = begin
Checks all cells in neighborhood and combines them according
to the particular neighborhood rule.
$(METHODLIST)
"""
function neighbors(h, state, index, t, source, args) end

neighbors(h::AbstractRadialNeighborhood{:onedim}, state, index, t, source, args...) = begin
    width = size(source)
    r = h.radius
    cc = -source[index]
    for p = (index - r):(index + r)
        p = bounded(p, width, h.overflow)
        cc += source[p]
    end
    cc
end

neighbors(h::AbstractRadialNeighborhood, state, index, t, source, args...) = begin
    height, width = size(source)
    row, col = index
    r = h.radius
    cc = -source[row, col]
    for q = (col - r):(col + r)
        for p = (row - r):(row + r)
            inhood(h, p, q, row, col) || continue
            p, q, inb = inbounds((p, q), (height, width), h.overflow) 
            inb || continue
            cc += source[p, q]
        end
    end
    cc
end

neighbors(h::AbstractCustomNeighborhood, state, index, t, source, args...) =
    custom_neighbors(h.neighborhood, h, index, t, source, args...)

neighbors(h::MultiCustomNeighborhood, state, index, t, source, args...) = begin
    for i = 1:length(h.multineighbors)
        mn.cc[i] = custom_neighbors(h.multineighbors[i], h, index, t, source)
    end
    mn.cc
end

custom_neighbors(n, h, index, t, source) = begin
    height, width = size(source)
    row, col = index
    cc = zero(eltype(source))
    for (a, b) in n
        p, q = inbounds((a + row, b + col), (height, width), h.overflow) || continue
        cc += source[p, q]
    end
    cc
end

""" 
    inhood(n::AbstractRadialNeighborhood{T}, p, q, row, col)
Check cell is inside a radial neighborhood, returning a boolean.
"""
inhood(n::AbstractRadialNeighborhood{:moore}, p, q, row, col) = true
inhood(n::AbstractRadialNeighborhood{:vonneumann}, p, q, row, col) = 
    (abs(p - row) + abs(q - col)) <= n.radius
inhood(n::AbstractRadialNeighborhood{:rotvonneumann}, p, q, row, col) = 
    (abs(p - row) + abs(q - col)) > n.radius

""" 
    inbounds(xs::Tuple, maxs::Tuple, overflow)
Check grid boundaries for two coordinates. 

Returns a 3-tuple of coords and a boolean. True means the cell is in bounds,
false it is not.
"""
inbounds(xs::Tuple, maxs::Tuple, overflow) = begin
    a, inbounds_a = inbounds(xs[1], maxs[1], overflow)
    b, inbounds_b = inbounds(xs[2], maxs[2], overflow)
    a, b, inbounds_a && inbounds_b
end

""" 
    inbounds(x::Number, max::Number, overflow::Skip)
Skip coordinates that overflow outside of the grid.
"""
inbounds(x::Number, max::Number, overflow::Skip) = x, x > 0 && x < max

""" 
    inbounds(x::Number, max::Number, overflow::Skip)
Swap overflowing coordinates to the other side.
"""
inbounds(x::Number, max::Number, overflow::Wrap) = begin
    if x < 1 
        x = max + x 
    elseif x > max 
        x = x - max 
    end
    x, true
end
