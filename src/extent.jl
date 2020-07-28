
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
Extent(; init, mask=nothing, aux=nothing, tspan, kwargs...) =
    Extent(init, mask, aux, tspan)

init(e::Extent) = e.init
mask(e::Extent) = e.mask
aux(e::Extent) = e.aux
tspan(e::Extent) = e.tspan

settspan!(e::Extent, tspan) = e.tspan = tspan

gridsize(extent::Extent) = gridsize(init(extent))
gridsize(A::AbstractArray) = size(A)
gridsize(nt::NamedTuple) = size(first(nt))
