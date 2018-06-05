abstract type Neighborhood end
abstract type CustomNeighborhood <: Neighborhood end
abstract type RadialNeighborhood <: Neighborhood end
abstract type RadialNeighborhood2D <: RadialNeighborhood end
abstract type AbstractDispersalNeighborhood <: Neighborhood end

abstract type AbstractOverflow end
struct Wrap <: AbstractOverflow end
struct Skip <: AbstractOverflow end

@mix @with_kw struct Rad{M}
    radius::Int = 1
    overflow::M = Skip()
end

@Rad struct RadialNeighborhood1D{} <: RadialNeighborhood end
@Rad struct MooreNeighborhood{} <: RadialNeighborhood2D end
@Rad struct VonNeumannNeighborhood{} <: RadialNeighborhood2D end
@Rad struct RotVonNeumannNeighborhood{} <: RadialNeighborhood2D end

@with_kw struct SingleCustomNeighborhood{H} <: CustomNeighborhood 
    neighbors::H = ((-1, 0), (1, 0), (0, -1), (0, 1))
end

struct MultiCustomNeighborhood{H} <: CustomNeighborhood 
    multineighbors::H
    cc::Vector{Int8}
end
MultiCustomNeighborhood(mn) = MultiCustomNeighborhood(mn, zeros(Int8, length(mn)))

@with_kw struct DispersalNeighborhood{DK,S} <: AbstractDispersalNeighborhood
    dispkernel::DK = [0.5, 0.25, 0.125]
    overflow::S = Skip()
end

neighbors(h::RadialNeighborhood1D, model, state, col, source, args...) = begin
    width = size(source)
    r = h.radius
    cc = -source[col]
    for p = (col - r):(col + r)
        p = bounded(p, width, n.overflow)
        cc += source[p]
    end
    cc
end

neighbors(h::RadialNeighborhood2D, model, state, ind, source, args...) = begin
    height, width = size(source)
    row, col = ind
    r = h.radius
    cc = -source[row, col]
    for q = (col - r):(col + r)
        for p = (row - r):(row + r)
            inhood(n, p, q, row, col) || continue
            bounded!((p, q), (height, width), n.overflow) || continue
            cc += source[p, q]
        end
    end
    cc
end

@inline inhood(n::RadialNeighborhood2D, p, q, row, col) = true
@inline inhood(n::VonNeumannNeighborhood, p, q, row, col) = 
    (abs(p - row) + abs(q - col)) <= n.radius
@inline inhood(n::RotVonNeumannNeighborhood, p, q, row, col) = 
    (abs(p - row) + abs(q - col)) > n.radius

neighbors(h::DispersalNeighborhood, model, state, ind, source, args...) = begin
    height, width = size(source)
    row, col = ind
    r = length(h.dispkernel)-1
    cc = -source[row, col]
    for b = -r:r
        for a = -r:r
            p = row + b; q = col + a
            bounded!(p, height, h.overflow) || continue
            bounded!(q, width, h.overflow) || continue
            distance = round(Int, sqrt(a^2 + b^2))
            distance == 0 && distance = 1
            printlnt(distance)
            cc += source[p, q] * h.dispkernel[distance] # * model.suitability[ind...] 
            # source[p, q] > 0 && println("Colonize!!!")
        end
    end
    return cc
end

neighbors(h::SingleCustomNeighborhood, model, state, ind, source, args...) =
    custom_neighbors(h.neighborhood, h, ind, source, args...)

neighbors(h::MultiCustomNeighborhood, model, state, ind, source, args...) = begin
    for i = 1:length(h.multineighbors)
        mn.cc[i] = custom_neighbors(h.multineighbors[i], h, ind, source)
    end
    mn.cc
end

custom_neighbors(n::AbstractArray, h, ind, source) = begin
    height, width = size(source)
    row, col = ind
    cc = zero(eltype(source))
    for (p, q) in n
        p += row
        q += col
        bounded!((p, q), (height, width), n.overflow) || continue
        cc += source[p, q]
    end
    cc
end


bounded!(x, max, overflow::Wrap) = begin
    if x < 1 
        x = max + x 
    elseif x > max 
        x = x - max 
    end
    true
end

bounded!(x, max, overflow::Skip) = x > 0 && x < max 

bounded!(xs::Tuple, maxs::Tuple, overflow::Skip) = 
    bounded!(xs[1], maxs[1], n.overflow) && bounded!(xs[2], maxs[1], n.overflow)
