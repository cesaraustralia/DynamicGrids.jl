"""
    PerformanceOpt

Abstract supertype for performance optimisation flags.
"""
abstract type PerformanceOpt end

"""
    NoOpt <: PerformanceOpt

    NoOpt()

Flag to run a simulation without performance optimisations besides basic high performance
programming. Still fast, but not intelligent about the work that it does: all cells are run
for all rules.

`NoOpt` is the default `opt` method.
"""
struct NoOpt <: PerformanceOpt end

"""
    Processor

Abstract supertype for selecting a hardware processor, such as ia CPU or GPU.
"""
abstract type Processor end

"""
    CPU <: Processor

Abstract supertype for CPU processors.
"""
abstract type CPU <: Processor end

"""
    SingleCPU <: CPU

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
    ThreadedCPU <: CPU

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
