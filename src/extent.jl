abstract type AbstractExtent{I,M,A} end

init(e::AbstractExtent) = e.init
mask(e::AbstractExtent) = e.mask
aux(e::AbstractExtent) = e.aux
@inline aux(e::AbstractExtent, key) = aux(aux(e), key)
@inline aux(nt::NamedTuple, ::Aux{Key}) where Key = nt[Key] # Fast compile-time version
@noinline aux(::Nothing, key) = 
    throw(ArgumentError("No aux data available. Pass a NamedTuple to the `aux=` keyword of the Output"))
tspan(e::AbstractExtent) = e.tspan # Never type-stable, only access in `precalc` methods
gridsize(extent::AbstractExtent) = gridsize(init(extent))

"""
    Extent(init::Union{AbstractArray,NamedTuple}, 
           mask::Union{AbstractArray,Nothing}, 
           aux::Union{NamedTuple,Nothing}, 
           tspan::AbstractRange)
    Extent(; init, mask=nothing, aux=nothing, tspan, kwargs...)

Container for extensive variables: spatial and timeseries data.
These are kept separate from rules to allow application
of rules to alternate spatial and temporal contexts.

Extent is not usually constructed directly by users, but it can be passed
to `Output` constructors instead of `init`, `mask`, `aux` and `tspan`.

- `init`: initialisation `Array`/`NamedTuple` for grid/s.
- `mask`: `BitArray` for defining cells that will/will not be run.
- `aux`: NamedTuple of arbitrary input data. Use `aux(data, Aux(:key))` to access from 
  a `Rule` in a type-stable way.
- `tspan`: Time span range. Never type-stable, only access this in `precalc` methods
"""
mutable struct Extent{I<:Union{AbstractArray,NamedTuple},
                      M<:Union{AbstractArray,Nothing},
                      A<:Union{NamedTuple,Nothing}} <: AbstractExtent{I,M,A}
    init::I
    mask::M
    aux::A
    tspan::AbstractRange
    function Extent(init::I, mask::M, aux::A, tspan::T) where {I,M,A,T}
        # Check grid sizes match
        gridsize = if init isa NamedTuple
            size_ = size(first(init))
            if !all(map(i -> size(i) == size_, init))
                throw(ArgumentError("`init` grid sizes do not match"))
            end
        else
            size_ = size(init)
        end
        if (mask !== nothing) && (size(mask) != size_) 
            throw(ArgumentError("`mask` size do not match `init`"))
        end
        new{I,M,A}(init, mask, aux, tspan)
    end
end
Extent(; init, mask=nothing, aux=nothing, tspan, kw...) = Extent(init, mask, aux, tspan)

settspan!(e::Extent, tspan) = e.tspan = tspan

struct StaticExtent{I<:Union{AbstractArray,NamedTuple},
                    M<:Union{AbstractArray,Nothing},
                    A<:Union{NamedTuple,Nothing},
                    T} <: AbstractExtent{I,M,A}
    init::I
    mask::M
    aux::A
    tspan::T
end
StaticExtent(e::Extent) = StaticExtent(init(e), mask(e), aux(e), tspan(e)) 
