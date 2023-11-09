module DynamicGridsCUDAExt

using CUDA, DynamicGrids, ModelParameters

# CUDA setup

DynamicGrids.kernel_setup(::CuGPU{N}) where N = CUDA.CUDAKernels.CUDABackend(), (N, N)

# _proc_setup
# Convert all arrays in SimData to CuArrays
@noinline function DynamicGrids._proc_setup(::CuGPU, simdata::AbstractSimData) 
    Adapt.adapt(CuArray, simdata)
end

# Thread-safe CUDA atomic ops
for (f, op) in DynamicGrids.ATOMIC_OPS
    atomic_f = Symbol(:atomic_, f)
    @eval begin
        function ($f)(d::GridData{<:WriteMode,<:Any,R}, ::CuGPU, x, I...) where R
            A = parent(dest(d))
            i = Base._to_linear_index(A, (I .+ R)...)
            (CUDA.$atomic_f)(pointer(A, i), x)
        end
    end
end

end
