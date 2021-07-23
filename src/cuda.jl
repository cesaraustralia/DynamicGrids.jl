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
function Adapt.adapt_structure(to, x::Union{AbstractSimData,GridData,Rule})
    Flatten.modify(A -> adapt(to, A), x, Union{CuArray,Array,AbstractDimArray}, Union{SArray,Function})
end

# Adapt output frames to GPU
# TODO: this may be incorrect use of Adapt.jl, as the Output
# object is not entirely adopted for GPU use, the CuArray
# frames are still held in a regular Array.
function Adapt.adapt_structure(to, o::Output)
    frames = map(o.frames) do f
        if f isa NamedTuple
            a = map(g -> adapt(to, g), f)
        else
            adapt(to, f)
        end
    end
    @set o.extent = adapt(to, o.extent)
    @set o.frames = frames
end

# _proc_setup
# Convert all arrays in SimData to CuArrays
@noinline function _proc_setup(::CuGPU, simdata::AbstractSimData) 
    Flatten.modify(CuArray, simdata, Union{Array,BitArray}, Union{CuArray,SArray,Dict,Function})
end

_copyto_output!(outgrid, grid::GridData, proc::GPU) = copyto!(outgrid, gridview(grid))


# Thread-safe CUDA atomic ops

for (f, op) in atomic_ops
    atomic_f = Symbol(:atomic_, f)
    @eval begin
        @propagate_inbounds function ($f)(d::WritableGridData{<:Any,R}, ::CuGPU, x, I...) where R
            A = parent(dest(d))
            i = Base._to_linear_index(A, (I .+ R)...)
            (CUDA.$atomic_f)(pointer(A, i), x)
        end
    end
end
