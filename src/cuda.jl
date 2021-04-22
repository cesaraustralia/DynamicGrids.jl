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
kernel_setup(::CuGPU{N}) where N = CUDAKernels.CUDADevice(), (N, N)

function Adapt.adapt_structure(to, x::Union{AbstractSimData,GridData,Rule})
    Flatten.modify(A -> adapt(to, A), x, Union{CuArray,Array,AbstractDimArray}, Union{SArray,Function})
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
    Flatten.modify(CuArray, obj, Union{Array,BitArray}, Union{CuArray,SArray,Dict,Function})
end

_copyto_output!(outgrid, grid::GridData, proc::GPU) = copyto!(outgrid, gridview(grid))

function maprule!(
    simdata::AbstractSimData{Y,X}, proc::GPU, opt, ruletype::Val{<:Rule}, rule, rkeys, wkeys
) where {Y,X}
    kernel! = cu_cell_kernel!(kernel_setup(proc)...)
    kernel!(simdata, ruletype, rule, rkeys, wkeys; ndrange=gridsize(simdata)) |> wait
end
function maprule!(
    simdata::AbstractSimData{Y,X}, proc::GPU, opt, ruletype::Val{<:NeighborhoodRule}, rule, rkeys, wkeys
) where {Y,X}
    grid = simdata[neighborhoodkey(rule)]
    kernel! = cu_neighborhood_kernel!(kernel_setup(proc)...)
    n = gridsize(simdata)
    kernel!(simdata, opt, ruletype, rule, rkeys, wkeys, ndrange=n) |> wait
    return nothing
end

@kernel function cu_neighborhood_kernel!(
    simdata, opt, ruletype::Val{<:NeighborhoodRule}, rule, rkeys, wkeys
)
    I, J = @index(Global, NTuple)
    src = parent(_firstgrid(simdata, rkeys))
    buf = _getwindow(src, neighborhood(rule), I, J)
    bufrule = _setbuffer(rule, buf)
    cell_kernel!(simdata, ruletype, bufrule, rkeys, wkeys, I, J)
    nothing
end

@generated function _getwindow(tile::AbstractArray{T}, ::Neighborhood{R}, i, j) where {T,R}
    S = 2R+1
    L = S^2
    vals = Expr(:tuple)
    for jj in 1:S, ii in 1:S 
        push!(vals.args, :(@inbounds tile[$ii + i - 1, $jj + j - 1]))
    end
    return :(SMatrix{$S,$S,$T,$L}($vals))
end

@kernel function cu_cell_kernel!(simdata, ruletype::Val, rule, rkeys, wkeys)
    i, j = @index(Global, NTuple)
    cell_kernel!(simdata, ruletype, rule, rkeys, wkeys, i, j)
    nothing
end


### UNSAFE / LOCKS required

# This is not safe for general use. 
# Can be used only where only one value can be set within a rule
@propagate_inbounds function _setindex!(d::WritableGridData, opt::CuGPU, x, I...)
    dest(d)[I...] = x
end

# Thread-safe atomic ops
for (f, op) in atomic_ops
    atomic_f = Symbol(:atomic_, f)
    @eval begin
        @propagate_inbounds function ($f)(d::WritableGridData{Y,X,R}, ::CuGPU, x, I...) where {Y,X,R}
            A = parent(dest(d))
            i = Base._to_linear_index(A, (I .+ R)...)
            ($f)(A, x, i)
        end
        @propagate_inbounds function ($f)(A::CUDA.CuDeviceArray, x, i) where {Y,X,R}
            (CUDA.$atomic_f)(pointer(A, i), x)
        end
    end
end
