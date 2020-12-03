"""
Abstract supertype for [`Ruleset`](@ref) objects and variants.
"""
abstract type AbstractRuleset <: AbstractModel end

# Getters
ruleset(rs::AbstractRuleset) = rs
rules(rs::AbstractRuleset) = rs.rules
overflow(rs::AbstractRuleset) = rs.overflow
proc(rs::AbstractRuleset) = rs.proc
opt(rs::AbstractRuleset) = rs.opt
cellsize(rs::AbstractRuleset) = rs.cellsize
timestep(rs::AbstractRuleset) = rs.timestep
padval(rs::AbstractRuleset) = rs.padval
radius(set::AbstractRuleset) = radius(rules(set))

Base.step(rs::AbstractRuleset) = timestep(rs)
Base.copy(rs::T) where T<:AbstractRuleset = T(rules(rs), overflow(rs), opt(rs), cellsize(rs), timestep(rs))

# ModelParameters interface
Base.parent(rs::AbstractRuleset) = rules(rs)
ModelParameters.setparent!(rs::AbstractRuleset, rules) = rs.rules = rules
ModelParameters.setparent(rs::AbstractRuleset, rules) = @set rs.rules = rules

"""
    Ruleset(rules...; overflow=RemoveOverflow(), opt=NoOpt(), cellsize=1, timestep=nothing)

A container for holding a sequence of `Rule`s and simulation
details like overflow handing and optimisation.
Rules will be run in the order they are passed, ie. `Ruleset(rule1, rule2, rule3)`.

## Keyword Arguments
- `opt`: a [`PerformanceOpt`](@ref) to specificy optimisations like
  [`SparseOpt`](@ref). Defaults to [`NoOpt`](@ref).
- `overflow`: what to do with overflow of grid edges.
  Options are `RemoveOverflow()` or `WrapOverflow()`, defaulting to [`RemoveOverflow`](@ref).
- `cellsize`: size of cells.
- `timestep`: fixed timestep where this is reuired for some rules.
  eg. `Month(1)` or `1u"s"`.
"""
Base.@kwdef mutable struct Ruleset{O<:Overflow,P<:Processor,Op<:PerformanceOpt,C,T,PV} <: AbstractRuleset
    # Rules are intentionally not type stable. This allows `precalc` and Interact.jl
    # updates to change the rule type. Function barriers remove most performance overheads.
    rules::Tuple{Vararg{<:Rule}} = ()
    overflow::O                  = RemoveOverflow()
    proc::P                      = SingleCPU()
    opt::Op                      = NoOpt()
    cellsize::C                  = 1
    timestep::T                  = nothing
    padval::PV                   = 0
end
Ruleset(rules::Vararg{<:Rule}; kwargs...) = Ruleset(; rules=rules, kwargs...)
Ruleset(rules::Tuple; kwargs...) = Ruleset(; rules=rules, kwargs...)
Ruleset(rs::AbstractRuleset) =
    Ruleset(
        rules(rs), overflow(rs), proc(rs), opt(rs), cellsize(rs), timestep(rs), padval(rs)
    )

struct StaticRuleset{R<:Tuple,O<:Overflow,P<:Processor,Op<:PerformanceOpt,C,T,PV} <: AbstractRuleset
    # Rules are intentionally not type stable. This allows `precalc` and Interact.jl
    # updates to change the rule type. Function barriers remove most performance overheads.
    rules::R
    overflow::O
    proc::P
    opt::Op
    cellsize::C
    timestep::T
    padval::PV
end
StaticRuleset(rs::AbstractRuleset) =
    StaticRuleset(
        rules(rs), overflow(rs), proc(rs), opt(rs), cellsize(rs), timestep(rs), padval(rs)
    )
