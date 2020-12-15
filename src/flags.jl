"""
Performance optimisations to use in the simulation.
"""
abstract type PerformanceOpt end

"""
    SparseOpt()

An optimisation that ignores all zero values in the grid.

For low-density simulations performance may improve by
orders of magnitude, as only used cells are run.

This is complicated for optimising neighborhoods - they
must run if they contain just one non-zero cell.

This is best demonstrated with this simulation, where the grey areas do not
run except where the neighborhood partially hangs over an area that is not grey.

![SparseOpt demonstration](https://raw.githubusercontent.com/cesaraustralia/DynamicGrids.jl/media/complexlife_spareseopt.gif)
"""
struct SparseOpt{F<:Function} <: PerformanceOpt
    f::F
end
SparseOpt() = SparseOpt(==(0))

@inline can_skip(opt::SparseOpt{<:Function}, val) = opt.f(val)

"""
    NoOpt()

Run the simulation without performance optimisations
besides basic high performance programming.

This is still very fast, but not intelligent about the work
that it does.
"""
struct NoOpt <: PerformanceOpt end


abstract type Processor end

abstract type CPU <: Processor end

struct SingleCPU <: CPU end

struct ThreadedCPU{L} <: CPU 
    spinlock::L
end
ThreadedCPU() = ThreadedCPU(Base.Threads.SpinLock())
Base.Threads.lock(opt::ThreadedCPU) = lock(opt.spinlock)
Base.Threads.unlock(opt::ThreadedCPU) = unlock(opt.spinlock)



"""
Singleton types for choosing the grid boundary rule used in
[`inbounds`](@ref) and [`NeighborhoodRule`](@ref) buffers.
These determine what is done when a neighborhood or jump extends outside of the grid.
"""
abstract type Boundary end

"""
    Wrap()

Wrap cordinates that boundary boundaries back to the opposite side of the grid.
"""
struct Wrap <: Boundary end

"""
    Remove()

Remove coordinates that boundary grid boundaries.
"""
struct Remove <: Boundary end


struct Aux{K} end
Aux(key::Symbol) = Aux{key}()

struct Grid{K} end
Grid(key::Symbol) = Grid{key}()
