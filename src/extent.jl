
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
- `aux`: NamedTuple of arbitrary input data. Use `aux(data, Vale{:key})` to access from 
  a `Rule` in a type-stable way.
- `tspan`: Time span range. Never type-stable, only access this in `precalc` methods
"""
mutable struct Extent{I<:Union{AbstractArray,NamedTuple},
                      M<:Union{AbstractArray,Nothing},
                      A<:Union{NamedTuple,Nothing}}
    init::I
    mask::M
    aux::A
    tspan::AbstractRange
end
Extent(init::I, mask::M, aux::A, tspan::T) where {I,M,A,T} = begin
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
    Extent{I,M,A,T}(init, mask, aux, tspan)
end
Extent(; init, mask=nothing, aux=nothing, tspan, kwargs...) =
    Extent(init, mask, aux, tspan)

init(e::Extent) = e.init
mask(e::Extent) = e.mask
aux(e::Extent) = e.aux
@inline aux(e::Extent, key::Symbol) = aux(e)[key] # Should not be used in rules
@inline aux(e::Extent, ::Val{Key}) where Key = aux(e)[Key] # Fast compile-time version
tspan(e::Extent) = e.tspan # Never type-stable, only access in `precalc` methods

settspan!(e::Extent, tspan) = e.tspan = tspan

gridsize(extent::Extent) = gridsize(init(extent))
