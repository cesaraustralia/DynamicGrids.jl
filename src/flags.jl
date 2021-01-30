"""
Abstract supertype for performance optimisation flags.
"""
abstract type PerformanceOpt end

"""
    SparseOpt()

An optimisation flag that ignores all zero values in the grid.

For low-density simulations performance may improve by
orders of magnitude, as only used cells are run.

This is complicated for optimising neighborhoods - they
must run if they contain just one non-zero cell.

Specifiy with:

```julia
ruleset = Ruleset(rule; opt=SparseOpt())
# or
output = sim!(output, rule; opt=SparseOpt())
```

`SparseOpt` is best demonstrated with this simulation, where the grey areas do not
run except where the neighborhood partially hangs over an area that is not grey:

![SparseOpt demonstration](https://raw.githubusercontent.com/cesaraustralia/DynamicGrids.jl/media/complexlife_spareseopt.gif)
"""
struct SparseOpt{F<:Function} <: PerformanceOpt
    f::F
end
SparseOpt() = SparseOpt(==(0))

@inline can_skip(opt::SparseOpt{<:Function}, val) = opt.f(val)

"""
    NoOpt()

Flag to run a simulation without performance optimisations besides basic high performance
programming. Still fast, but not intelligent about the work that it does: all cells are run
for all rules.

`NoOpt` is the default `opt` method.
"""
struct NoOpt <: PerformanceOpt end

"""
Abstract supertype for selecting a hardware processor, such as ia CPU or GPU.
"""
abstract type Processor end

"""
Abstract supertype for CPU processors.
"""
abstract type CPU <: Processor end

"""
    SingleCPU()

[`Processor`](@ref) flag that specifies to use a single thread on a single CPU.

Specifiy with:

```julia
ruleset = Ruleset(rule; proc=SingleCPU())
# or
output = sim!(output, rule; proc=SingleCPU())
```
"""
struct SingleCPU <: CPU end


"""
    ThreadedCPU()

[`Processor`](@ref) flag that specifies to use a `Threads.nthreads()` CPUs.

Specifiy with:

```julia
ruleset = Ruleset(rule; proc=ThreadedCPU())
# or
output = sim!(output, rule; proc=ThreadedCPU())
```
"""
struct ThreadedCPU{L} <: CPU
    spinlock::L
end
ThreadedCPU() = ThreadedCPU(Base.Threads.SpinLock())
Base.Threads.lock(opt::ThreadedCPU) = lock(opt.spinlock)
Base.Threads.unlock(opt::ThreadedCPU) = unlock(opt.spinlock)

"""
Abstract supertype for GPU processors.
"""
abstract type GPU <: Processor end

"""
Abstract supertype for flags that specify the boundary conditions used in the simulation,
used in [`inbounds`](@ref) and to update [`NeighborhoodRule`](@ref) grid padding.
These determine what happens when a neighborhood or jump extends outside of the grid.
"""
abstract type Boundary end

"""
    Wrap()

[`Boundary`](@ref) flag to wrap cordinates that boundary boundaries back to the
opposite side of the grid.

Specifiy with:

```julia
ruleset = Ruleset(rule; boundary=Wrap())
# or
output = sim!(output, rule; boundary=Wrap())
```
"""
struct Wrap <: Boundary end

"""
    Remove()

[`Boundary`](@ref) flag that specifies to assign `padval` to cells that overflow grid
boundaries. `padval` defaults to `zero(eltype(grid))` but can be assigned as a keyword
argument to an [`Output`](@ref).

Specifiy with:

```julia
ruleset = Ruleset(rule; boundary=Remove())
# or
output = sim!(output, rule; boundary=Remove())
```
"""
struct Remove <: Boundary end

"""
    Aux{K}()
    Aux(K::Symbol)

Use auxilary array with key `K` as a parameter source.

Implemented in rules with:

```julia
get(data, rule.myparam, index...)
```

When an `Aux` param is specified at rule construction with:

```julia
rule = SomeRule(; myparam=Aux{:myaux})
output = ArrayOutput(init; aux=(myaux=myauxarray,))
```

If the array is a DimensionalData.jl `DimArray` with a `Ti` (time)
dimension, the correct interval will be selected automatically,
precalculated for each timestep so it has no significant overhead.
"""
struct Aux{K} end
Aux(key::Symbol) = Aux{key}()

_unwrap(::Aux{X}) where X = X
_unwrap(::Type{<:Aux{X}}) where X = X

"""
    Grid{K}()
    Grid(K::Symbol)

Use grid with key `K` as a parameter source.

Implemented in rules with:

```julia
get(data, rule.myparam, index...)
```

And specified at rule construction with:

```julia
SomeRule(; myparam=Grid{:somegrid})
```
"""
struct Grid{K} end
Grid(key::Symbol) = Grid{key}()

_unwrap(::Grid{X}) where X = X
_unwrap(::Type{<:Grid{X}}) where X = X
