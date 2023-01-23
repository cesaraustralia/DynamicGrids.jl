# Adapt.jl method for DynamicGrids objects
# These move objects tp GPU

function Adapt.adapt_structure(to, x::AbstractSimData)
    return ConstructionBase.setproperties(x, ( 
        grids = map(g -> Adapt.adapt(to, g), x.grids),
        extent = Adapt.adapt(to, x.extent),
    ))
end
function Adapt.adapt_structure(to, x::GridData)
    return ConstructionBase.setproperties(x, ( 
        source = Adapt.adapt(to, x.source),
        dest = Adapt.adapt(to, x.dest),
        mask = Adapt.adapt(to, x.mask),
        optdata = Adapt.adapt(to, x.optdata),
    ))
end
function Adapt.adapt_structure(to, x::AbstractExtent)
    return ConstructionBase.setproperties(x, ( 
        init = _adapt_x(to, x.init),
        mask = _adapt_x(to, x.mask),
        aux = _adapt_x(to, x.aux),
    ))
end
# Adapt output frames to GPU
# TODO: this may be incorrect use of Adapt.jl, as the Output
# object is not entirely adopted for GPU use, the CuArray
# frames are still held in a regular Array. But for out purposes
# only the inner frames are used on the GPU.
function Adapt.adapt_structure(to, o::Output)
    frames = map(o.frames) do f
        _adapt_x(to, f)
    end
    @set! o.extent = adapt(to, o.extent)
    @set! o.frames = frames
    return o
end

_adapt_x(to, A::AbstractArray) = Adapt.adapt(to, A)
_adapt_x(to, nt::NamedTuple) = map(A -> Adapt.adapt(to, A), nt)
_adapt_x(to, nt::Nothing) = nothing
