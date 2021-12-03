using .CUDAKernels, .CUDAKernels.CUDA
import ModelParameters.Flatten

export CuGPU

"""
    CuGPU <: GPU

    CuGPU()
    CuGPU{threads_per_block}()

```julia
ruleset = Ruleset(rule; proc=CuGPU())
# or
output = sim!(output, rule; proc=CuGPU())
```
"""
struct CuGPU{X} <: GPU end
CuGPU() = CuGPU{32}()

# CUDA setup

kernel_setup(::CuGPU{N}) where N = CUDAKernels.CUDADevice(), (N, N)

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
    @set! x.sourcestatus = Adapt.adapt(to, x.sourcestatus)
    @set! x.deststatus = Adapt.adapt(to, x.deststatus)
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

# _proc_setup
# Convert all arrays in SimData to CuArrays
@noinline function _proc_setup(::CuGPU, simdata::AbstractSimData) 
    Adapt.adapt(CuArray, simdata)
end

_copyto_output!(outgrid, grid::GridData, proc::GPU) = copyto!(outgrid, gridview(grid))


# Thread-safe CUDA atomic ops

for (f, op) in atomic_ops
    atomic_f = Symbol(:atomic_, f)
    @eval begin
        function ($f)(d::WritableGridData{<:Any,R}, ::CuGPU, x, I...) where R
            A = parent(dest(d))
            i = Base._to_linear_index(A, (I .+ R)...)
            (CUDA.$atomic_f)(pointer(A, i), x)
        end
    end
end
