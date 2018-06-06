abstract type Neighborhood end
abstract type CustomNeighborhood <: Neighborhood end
abstract type RadialNeighborhood <: Neighborhood end
abstract type RadialNeighborhood2D <: RadialNeighborhood end
abstract type AbstractDispersalNeighborhood <: Neighborhood end

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

struct DispersalNeighborhood{K,S} <: AbstractDispersalNeighborhood
    dispkernel::K
    overflow::S
end


abstract type AbstractOverflow end

" Wrap cords that overflow to the opposite side "
struct Wrap <: AbstractOverflow end
" Skip coords that overflow boundaries "
struct Skip <: AbstractOverflow end


abstract type AbstractShortDispersal end

@with_kw struct ShortDispersal{N,Float64} <: AbstractShortDispersal
    neighborhood::N = DispersalNeighborhood()
    prob::Float64 = 0.9
end


abstract type AbstractLongDispersal end

@with_kw struct LongDispersal <: AbstractLongDispersal
    prob::Float64 = 0.01
    spotrange::Int = 30
end


abstract type AbstractLayers end

struct SuitabilityLayer{S} <: AbstractLayers
    suitability::S
end

struct PopSuitLayers{S,P} <: AbstractLayers
    suitability::S
    population::P
end


abstract type AbstractCellular end
abstract type AbstractLife <: AbstractCellular end
abstract type AbstractDispersal <: AbstractCellular end

@with_kw struct Dispersal{A,B,C} <: AbstractDispersal
    short::A = ShortDispersal()
    long::B = LongDispersal()
    layers::C
end

@with_kw struct Life{N} <: AbstractLife
    neighborhood::N = MooreNeighborhood(overflow=Wrap())
    B::Array{Int,1} = [3]
    S::Array{Int,1} = [2,3]
end
