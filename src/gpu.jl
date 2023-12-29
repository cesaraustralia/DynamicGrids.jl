"""
    GPU <: Processor

Abstract supertype for GPU processors.
"""
abstract type GPU <: Processor end

function _copyto_output!(outgrid, grid::GridData, proc::GPU)
    # copyto!(outgrid, view(grid, axes(outgrid)...))
    outgrid .= view(grid, axes(outgrid)...)
end

"""
    CPUGPU <: GPU

    CPUGPU()

Uses the CUDA GPU code on CPU using KernelAbstractions, to test it.
"""
struct CPUGPU{L} <: GPU 
    spinlock::L
end
CPUGPU() = CPUGPU(Base.Threads.SpinLock())
Base.Threads.lock(opt::CPUGPU) = lock(opt.spinlock)
Base.Threads.unlock(opt::CPUGPU) = unlock(opt.spinlock)

kernel_setup(::CPUGPU) = KernelAbstractions.CPU(), 1

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

function maprule!(
    data::AbstractSimData, proc::GPU, opt, ruletype::Val{<:Rule}, rule, rkeys, wkeys
)
    backend = KernelAbstractions.get_backend(first(grids(data)))
    kernel! = ka_rule_kernel!(kernel_setup(proc)...)
    kernel!(data, ruletype, rule, rkeys, wkeys; ndrange=gridsize(data))
    KernelAbstractions.synchronize(backend)
    return nothing
end

kernel_setup(proc::CuGPU) = _cuda_kernel_setup(proc)
_cuda_kernel_setup(proc) = error("Run `using CUDA` to use CuGPU")

# ka_rule_kernel!
# Runs cell_kernel! on GPU after retrieving the global index
# and setting the stencil buffer to a SArray window retrieved 
# from the first (stencil) grid
@kernel function ka_rule_kernel!(data, ruletype::Val{<:NeighborhoodRule}, rule, rkeys, wkeys)
    I = @index(Global, NTuple)
    stencil_kernel!(data, _firstgrid(data, rkeys), ruletype, rule, rkeys, wkeys, I...)
    nothing
end
@kernel function ka_rule_kernel!(data, ruletype::Val, rule, rkeys, wkeys)
    I = @index(Global, NTuple)
    cell_kernel!(data, ruletype, rule, rkeys, wkeys, I...)
    nothing
end

### Indexing. UNSAFE / LOCKS required

# This is not safe for general use. 
# It can be used where only identical transformations of a cell 
# can happen from any other cell, such as setting all 1s to 2.
@propagate_inbounds function _setindex!(d::GridData{<:WriteMode}, opt::GPU, x, I...)
    Stencils.unsafe_setindex_with_padding(source(d), padding(d), x, I...)
end
@propagate_inbounds function _setindex!(d::GridData{<:SwitchMode}, opt::GPU, x, I...)
    Stencils.unsafe_setindex_with_padding(dest(d), padding(d), x, I...)
end

function _maybemask!(
    wgrid::GridData{<:GridMode,<:Tuple{Y,X}}, proc::GPU, mask::AbstractArray
) where {Y,X}
    pv = padval(wgrid)
    kernel! = ka_mask_kernel!(kernel_setup(proc)...)
    kernel!(source(wgrid), mask, pv; ndrange=size(wgrid)) 
    return nothing
end

@kernel function ka_mask_kernel!(grid, mask, padval)
    I = @index(Global, NTuple)
    mask[I...] ? grid[I...] : padval
end
@kernel function ka_mask_kernel!(grid, mask, padval::Nothing)
    I = @index(Global, NTuple)
    mask[I...] * grid[I...]
end
