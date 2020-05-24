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
ruleset(rs::AbstractRuleset) = rs

Base.step(rs::AbstractRuleset) = timestep(rs)

"""
    Ruleset(rules...; init=nothing, mask=nothing, overflow=RemoveOverflow(), opt=SparseeOpt(), cellsize=1, timestep=1)

A container for holding a sequence of `Rule`, an `init`
array and other simulaiton details. Rules will be run in the
order they are passed, ie. `Ruleset(rule1, rule2, rule3)`.

## Keyword Arguments
- `init`: init grid(s) to use if none are supplied to `sim!`.
  An `AbstractArray`, a `NamedTuple` of `AbsractactArray`, or `nothing`.
- `mask`: An array of Bool matching the size of `init`. Cells that are `false` will not run.
- `overflow`: determine what to do with overflow of grid edges.
  Options are `RemoveOverflow()` or `WrapOverflow()`.
  Available from `applyrule` with `overflow(data)`
- `cellsize`: Size of cells.
  Available from `applyrule` with `timestep(data)`
- `timestep`: timestep size for all rules. eg. `Month(1)` or `1u"s"`.
  Available from `applyrule` with `timestep(data)`
"""
@default_kw @flattenable mutable struct Ruleset{I,M,O<:Overflow,Op<:PerformanceOpt,C,T
    } <: AbstractRuleset
    # Rules are intentionally not type stable. This allows `precalc` and Interact.jl 
    # updates to change the rule type. Function barriers remove any performance overheads.
    rules::Tuple{Vararg{<:Rule}} | ()               | true
    init::I                      | nothing          | false
    mask::M                      | nothing          | false
    overflow::O                  | RemoveOverflow() | false
    opt::Op                      | SparseOpt()      | false
    cellsize::C                  | 1                | false
    timestep::T                  | 1                | false
end
Ruleset(rules::Vararg{<:Rule}; kwargs...) = Ruleset(; rules=rules, kwargs...)

rules(rs::Ruleset) = rs.rules
