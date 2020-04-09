"""
Singleton types for choosing the grid overflow rule used in
[`inbounds`](@ref). These determine what is done when a neighborhood
or jump extends outside of the grid.
"""
abstract type Overflow end

"Wrap cords that overflow boundaries back to the opposite side"
struct WrapOverflow <: Overflow end

"Remove coords that overflow boundaries"
struct RemoveOverflow <: Overflow end

"""
Performance optimisations to use in the simulation.
"""
abstract type PerformanceOpt end

"""
An optimisation that ignores all zero values in the grid.

For low-density simulations performance may improve by
orders of magnitude, as only used cells are run.

This is complicated for optimising neighborhoods - they
must run if they contain just one non-zero cell.
"""
struct SparseOpt <: PerformanceOpt end

"""
Run the simulation without performance optimisations
besides basic high performance programming.

This is still very fast, but not intelligent about the work
that it does.
"""
struct NoOpt <: PerformanceOpt end


abstract type AbstractRuleset end

# Getters
init(rs::AbstractRuleset) = rs.init
mask(rs::AbstractRuleset) = rs.mask
overflow(rs::AbstractRuleset) = rs.overflow
opt(rs::AbstractRuleset) = rs.opt
cellsize(rs::AbstractRuleset) = rs.cellsize
timestep(rs::AbstractRuleset) = rs.timestep
minval(rs::AbstractRuleset) = rs.minval
maxval(rs::AbstractRuleset) = rs.maxval
ruleset(rs::AbstractRuleset) = rs

"""
    Ruleset(rules...; init=nothing, overflow=RemoveOverflow(), cellsize=1, timestep=1)

A container for holding a sequence of `Rule`, an `init`
array and other simulaiton details.
"""
@flattenable @default_kw mutable struct Ruleset{
    R<:Tuple{Vararg{<:Rule}},I,M,O<:Overflow,Op<:PerformanceOpt,C,T
    } <: AbstractRuleset
    rules::R     | ()               | true
    init::I      | nothing          | false
    mask::M      | nothing          | false
    overflow::O  | RemoveOverflow() | false
    opt::Op      | SparseOpt()      | false
    cellsize::C  | 1                | false
    timestep::T  | 1                | false
end
Ruleset(rules::Vararg{<:Rule}; kwargs...) = Ruleset(; rules=rules, kwargs...)

rules(rs::Ruleset) = rs.rules
#
show(io::IO, ruleset::Ruleset) = begin
    printstyled(io, Base.nameof(typeof(ruleset)), " =\n"; color=:blue)
    println(io, "rules:")
    for rule in rules(ruleset)
        println(IOContext(io, :indent => "    "), rule)
    end
    for fn in fieldnames(typeof(ruleset))
        fn == :rules && continue
        println(io, fn, " = ", repr(getfield(ruleset, fn)))
    end
end
