"""
    AbstractExtent

Abstract supertype for `Extent` objects, that hold all variables related
to space and time in a simulation. Usually the field of an output.
"""
abstract type AbstractExtent{I,M,A,PV} end

init(e::AbstractExtent) = e.init
mask(e::AbstractExtent) = e.mask
aux(e::AbstractExtent) = e.aux
@inline aux(e::AbstractExtent, key) = aux(aux(e), key)
@noinline aux(::Nothing, key) =
    throw(ArgumentError("No aux data available. Pass a NamedTuple to the `aux=` keyword of the Output"))
padval(e::AbstractExtent) = e.padval
tspan(e::AbstractExtent) = e.tspan # Never type-stable, only access in `modifyrule` methods
gridsize(extent::AbstractExtent) = gridsize(init(extent))

Base.ndims(e::AbstractExtent{<:AbstractArray}) = ndims(init(e))
Base.ndims(e::AbstractExtent{<:NamedTuple}) = ndims(first(init(e)))
Base.size(e::AbstractExtent{<:AbstractArray}) = size(init(e))
Base.size(e::AbstractExtent{<:NamedTuple}) = size(first(init(e)))

(::Type{T})(e::AbstractExtent) where T<:AbstractExtent = T(init(e), mask(e), aux(e), padval(e), tspan(e))

const EXTENT_KEYWORDS = """
- `init`: initialisation `Array`/`NamedTuple` for grid/s.
- `mask`: `BitArray` for defining cells that will/will not be run.
- `aux`: NamedTuple of arbitrary input data. Use `aux(data, Aux(:key))` to access from
    a `Rule` in a type-stable way.
- `padval`: padding value for grids with stencil rules. The default is 
    `zero(eltype(init))`.
- `tspan`: Time span range. Never type-stable, only access this in `modifyrule` methods
"""

"""
    Extent <: AbstractExtent

    Extent(init, mask, aux, padval, tspan)
    Extent(; init, tspan, mask=nothing, aux=nothing, padval=zero(eltype(init)), kw...)

Container for extensive variables: spatial and timeseries data.
These are kept separate from rules to allow application
of rules to alternate spatial and temporal contexts.

Extent is not usually constructed directly by users, but it can be passed
to `Output` constructors instead of `init`, `mask`, `aux` and `tspan`.

# Arguments/Keywords

$EXTENT_KEYWORDS
"""
mutable struct Extent{I<:Union{AbstractArray,NamedTuple},
                      M<:Union{AbstractArray,Nothing},
                      A<:Union{NamedTuple,Nothing},
                      PV} <: AbstractExtent{I,M,A,PV}
    init::I
    mask::M
    aux::A
    padval::PV
    tspan::AbstractRange
    function Extent(init::I, mask::M, aux::A, padval::PV, tspan::T) where {I,M,A,PV,T}
        # Check grid sizes match
        if init isa NamedTuple
            gridsize = size(first(init))
            if !all(map(i -> size(i) == gridsize, init))
                throw(ArgumentError("`init` grid sizes do not match"))
            end
            init1 = first(init)
            if first(init) isa AbstractDimArray
                DimensionalData.comparedims(init...; val=true)
            end
            # Use the same padval for everthing if there is only one
            if !(padval isa NamedTuple)
                padval = map(_ -> padval, init)
            end
        else
            gridsize = size(init)
        end
        if (mask !== nothing) && (size(mask) != gridsize)
            throw(ArgumentError("`mask` size do not match `init`"))
        end
        new{I,M,A,typeof(padval)}(init, mask, aux, padval, tspan)
    end
end
Extent(; init, mask=nothing, aux=nothing, padval=_padval(init), tspan, kw...) =
    Extent(init, mask, aux, padval, tspan)
Extent(init::Union{AbstractArray,NamedTuple}; kw...) = Extent(; init, kw...)

settspan!(e::Extent, tspan) = e.tspan = tspan

_padval(init::NamedTuple) = map(_padval, init)
_padval(init::AbstractArray{T}) where T = zero(T)

# An immutable `Extent` object, for internal use.
struct StaticExtent{I<:Union{AbstractArray,NamedTuple},
                    M<:Union{AbstractArray,Nothing},
                    A<:Union{NamedTuple,Nothing},
                    PV,T} <: AbstractExtent{I,M,A,PV}
    init::I
    mask::M
    aux::A
    padval::PV
    tspan::T
end
StaticExtent(; init, mask=nothing, aux=nothing, padval=_padval(init), tspan, kw...) =
    StaticExtent(init, mask, aux, padval, tspan)
StaticExtent(init::Union{AbstractArray,NamedTuple}; kw...) = StaticExtent(; init, kw...)
