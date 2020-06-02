
"""
    Extent(init, mask, tspan, aux) 
    Extent(; init, mask=nothing, tspan, aux=nothing, kwargs...) 

Container for extensive variables: spatial and timeseries data.
These are kept separate from rules to allow application
of rules to alternate spatial and temporal contexts.

Not usually constructed directly by users, but it can be passed to outputs
instead of `init`, `mask`, `tspan` and `aux`.
"""
mutable struct Extent{I,M,A}
    init::I
    mask::M
    tspan::AbstractRange
    aux::A
end
Extent(; init, mask=nothing, tspan, aux=nothing, kwargs...) = 
    Extent(init, mask, tspan, aux) 

init(e::Extent) = e.init
mask(e::Extent) = e.mask
tspan(e::Extent) = e.tspan
aux(e::Extent) = e.aux

settspan!(e::Extent, tspan) = e.tspan = tspan
setstarttime!(e::Extent, start) =
    e.tspan = start:step(tspan(e)):last(tspan(e))
setstoptime!(e::Extent, stop) =
    e.tspan = first(tspan(e)):step(tspan(e)):stop
