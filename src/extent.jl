
"""
    Extent(init, mask, aux, tspan, tstopped)
    Extent(; init, mask=nothing, aux=nothing, tspan, kwargs...)

Container for extensive variables: spatial and timeseries data.
These are kept separate from rules to allow application
of rules to alternate spatial and temporal contexts.

Extent is not usually constructed directly by users, but it can be passed
to `Output` constructors instead of `init`, `mask`, `aux` and `tspan`.
"""
mutable struct Extent{I,M,A}
    init::I
    mask::M
    aux::A
    tspan::AbstractRange
end
Extent(init::I, mask::M, aux::A, tspan::T) where {I,M,A,T} = begin
    # Check grid sizes match
    gridsize = if init isa NamedTuple
        size_ = size(first(init_))
        all(map(i -> size(i) == size_, init)) || throw(ArgumentError("`init` grid sizes do not match"))
    else
        size_ = size(init_)
    end
    (mask !== nothing) && (size(mask) != size_) && throw(ArgumentError("`mask` size do not match `init`"))
    Extent{I,M,A,T}(init, mask, aux, tspan)
end
Extent(; init, mask=nothing, aux=nothing, tspan, kwargs...) =
    Extent(init, mask, aux, tspan)

init(e::Extent) = e.init
mask(e::Extent) = e.mask
aux(e::Extent) = e.aux
tspan(e::Extent) = e.tspan

settspan!(e::Extent, tspan) = e.tspan = tspan

gridsize(extent::Extent) = gridsize(init(extent))
