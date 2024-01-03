# Adapt method for DynamicGrids objects
function Adapt.adapt_structure(to, x::AbstractSimData)
    @set! x.grids = map(g -> Adapt.adapt(to, g), x.grids)
    @set! x.extent = Adapt.adapt(to, x.extent)
    return x
end

function Adapt.adapt_structure(to, x::GridData)
    @set! x.source = Adapt.adapt(to, x.source)
    @set! x.source = Adapt.adapt(to, x.source)
    @set! x.mask = Adapt.adapt(to, x.mask)
    @set! x.dest = Adapt.adapt(to, x.dest)
    @set! x.optdata = Adapt.adapt(to, x.optdata)
    return x
end

function Adapt.adapt_structure(to, x::AbstractExtent)
    @set! x.init = _adapt_x(to, init(x))
    @set! x.mask = _adapt_x(to, mask(x))
    @set! x.aux = _adapt_x(to, aux(x))
    return x
end

_adapt_x(to, A::AbstractArray) = Adapt.adapt(to, A)
_adapt_x(to, nt::NamedTuple) = map(A -> Adapt.adapt(to, A), nt)
_adapt_x(to, nt::Nothing) = nothing

# Adapt output frames to GPU
# TODO: this may be incorrect use of Adapt.jl, as the Output
# object is not entirely adopted for GPU use, the CuArray
# frames are still held in a regular Array.
function Adapt.adapt_structure(to, o::Output)
    frames = map(o.frames) do f
        _adapt_x(to, f)
    end
    @set! o.extent = adapt(to, o.extent)
    @set! o.frames = frames
    return o
end
