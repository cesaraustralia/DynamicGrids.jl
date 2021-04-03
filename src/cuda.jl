using KernelAbstractions, .CUDAKernels, .CUDAKernels.CUDA
import ModelParameters.Flatten

"""
    GPU <: Processor

Abstract supertype for GPU processors.
"""
abstract type GPU <: Processor end

export GPU, CuGPU, CPUGPU

"""
    CPUGPU <: GPU

    CPUGPU()

Uses the CUDA GPU code on CPU using KernelAbstractions, to test it.
"""
struct CPUGPU <: GPU end

"""
    CuGPU <: GPU

    CuGPU()
    CuGPU{threads_per_block}()

```julia
ruleset = Ruleset(rule; proc=ThreadedCPU())
# or
output = sim!(output, rule; proc=ThreadedCPU())
```
"""
struct CuGPU{X} <: GPU end
CuGPU() = CuGPU{32}()

kernel_setup(::CPUGPU) = KernelAbstractions.CPU(), 1
kernel_setup(::CuGPU{N}) where N = CUDAKernels.CUDADevice(), N

function Adapt.adapt_structure(to, x::Union{AbstractSimData,GridData,Rule})
    Flatten.modify(A -> adapt(to, A), x, Union{CuArray,Array,AbstractDimArray}, SArray)
end

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

@noinline function _proc_setup(::CuGPU, obj) 
    Flatten.modify(CuArray, obj, Union{Array,BitArray}, Union{CuArray,SArray,Dict})
end

_copyto_output!(outgrid, grid::GridData, proc::GPU) = copyto!(outgrid, gridview(grid))

function maprule!(
    wgrids::Union{<:GridData{Y,X,R},Tuple{<:GridData{Y,X,R},Vararg}},
    simdata, proc::GPU, opt, ruletype::Val{<:Rule}, rule, args...
) where {Y,X,R}
    kernel! = cu_cell_kernel!(kernel_setup(proc)...)
    kernel!(wgrids, simdata, ruletype, rule, args...; ndrange=gridsize(simdata)) |> wait
end
function maprule!(
    wgrids::Union{<:GridData{Y,X,R},Tuple{<:GridData{Y,X,R},Vararg}},
    simdata, proc::GPU, opt, ruletype::Val{<:NeighborhoodRule}, rule, args...
) where {Y,X,R}
    grid = simdata[neighborhoodkey(rule)]
    kernel! = cu_neighborhood_kernel!(kernel_setup(proc)...)
    # n = _indtoblock.(gridsize(simdata), 8) .- 1
    n = gridsize(simdata)
    kernel!(wgrids, simdata, grid, opt, ruletype, rule, args..., ndrange=n) |> wait
    return nothing
end

@kernel function cu_neighborhood_kernel!(
    wgrids, data, grid::GridData{Y,X,R}, opt, ruletype::Val{<:NeighborhoodRule}, rule, args...
) where {Y,X,R}
    I, J = @index(Global, NTuple)
    src = parent(source(grid))
    @inbounds buf = view(src, I:I+2R, J:J+2R)
    bufrule = _setbuffer(rule, buf)
    cell_kernel!(wgrids, data, ruletype, bufrule, args..., I, J)
    nothing
end

@kernel function cu_cell_kernel!(wgrids, simdata, ruletype::Val, rule, rkeys, rgrids, wkeys)
    i, j = @index(Global, NTuple)
    cell_kernel!(wgrids, simdata, ruletype, rule, rkeys, rgrids, wkeys, i, j)
    nothing
end

# @kernel function cu_cell_kernel!(
#     simdata::SimData, grid::GridData{Y,X,1}, rule::NeighborhoodRule,
#     rkeys, rgrids, wkeys, wgrids
# ) where {Y,X}
#     gi, gj = @index(Group, NTuple)
#     i, j = @index(Local,  NTuple)
#     N = @uniform groupsize()[1]
#     M = @uniform groupsize()[2]
#     # +1 to avoid bank conflicts on shared memory
#     tile = @localmem eltype(src) 8, 8
#     for n in 1:4 
#         b = ((i - 1) & 1)
#         k = 4b + n
#         l = 2j + b - 1
#         @inbounds tile[k, l] = src[(gi-1) * N + k, (gi-1) * N + l]
#     end
#     @synchronize
#     # Manually calculate global indexes
#     I = (gi-1) * N + i
#     J = (gj-1) * M + j
#     @inbounds buf = view(tile, i:i+2, j:j+2)
#     bufrule = setbuffer(rule, buf)
#     readval = _readgrids(rkeys, rgrids, I, J)
#     writeval = applyrule(simdata, bufrule, readval, (I, J))
#     _writegrids!(wgrids, writeval, I, J)
#     nothing
# end

for (f, op) in atomic_ops
    atomic_f = Symbol(:atomic_, f)
    @eval begin
        @propagate_inbounds function ($f)(::CuGPU, d::WritableGridData{Y,X,R}, x, I...) where {Y,X,R}
            A = parent(dest(d))
            i = Base._to_linear_index(A, (I .+ R)...)
            ($f)(A, x, i)
        end
        @propagate_inbounds function ($f)(A::CUDA.CuDeviceArray, x, i) where {Y,X,R}
            (CUDA.$atomic_f)(pointer(A, i), x)
        end
    end
end
