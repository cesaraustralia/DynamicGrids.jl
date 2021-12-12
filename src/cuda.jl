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
