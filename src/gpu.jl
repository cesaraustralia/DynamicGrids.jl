"""
    GPU <: Processor

Abstract supertype for GPU processors.
"""
abstract type GPU <: Processor end

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

function broadcast_rule!(
    data::AbstractSimData, proc::GPU, opt, ruletype::Val{<:Rule}, rule, rkeys, wkeys
)
    kernel! = ka_rule_kernel!(kernel_setup(proc)...)
    kernel!(data, ruletype, rule, rkeys, wkeys; ndrange=gridsize(data)) |> wait
    return nothing
end

# ka_rule_kernel!
# Runs cell_kernel! on GPU after retrieving the global index
# and setting the neighborhood buffer to a SArray window retrieved 
# from the first (neighborhood) grid
@kernel function ka_rule_kernel!(data, ruletype::Val{<:NeighborhoodRule}, rule, rkeys, wkeys)
    I = @index(Global, NTuple)
    neighborhood_kernel!(data, _firstgrid(data, rkeys), ruletype, rule, rkeys, wkeys, I...)
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
@propagate_inbounds function _setindex!(d::WritableGridData, opt::GPU, x, I...)
    dest(d)[I...] = x
end
