"""
Abstract supertype for [`Ruleset`](@ref) objects and variants.
"""
abstract type AbstractRuleset <: AbstractModel end

# Getters
ruleset(rs::AbstractRuleset) = rs
rules(rs::AbstractRuleset) = rs.rules
boundary(rs::AbstractRuleset) = rs.boundary
proc(rs::AbstractRuleset) = rs.proc
opt(rs::AbstractRuleset) = rs.opt
cellsize(rs::AbstractRuleset) = rs.cellsize
timestep(rs::AbstractRuleset) = rs.timestep
padval(rs::AbstractRuleset) = rs.padval
radius(set::AbstractRuleset) = radius(rules(set))

Base.step(rs::AbstractRuleset) = timestep(rs)
Base.copy(rs::T) where T<:AbstractRuleset = T(rules(rs), boundary(rs), opt(rs), cellsize(rs), timestep(rs))

# ModelParameters interface
Base.parent(rs::AbstractRuleset) = rules(rs)
ModelParameters.setparent!(rs::AbstractRuleset, rules) = rs.rules = rules
ModelParameters.setparent(rs::AbstractRuleset, rules) = @set rs.rules = rules

"""
    Ruleset(rules...; boundary=Remove(), opt=NoOpt(), cellsize=1, timestep=nothing)

A container for holding a sequence of `Rule`s and simulation
details like boundary handing and optimisation.
Rules will be run in the order they are passed, ie. `Ruleset(rule1, rule2, rule3)`.

## Keyword Arguments
- `opt`: a [`PerformanceOpt`](@ref) to specificy optimisations like
  [`SparseOpt`](@ref). Defaults to [`NoOpt`](@ref).
- `boundary`: what to do with boundary of grid edges.
  Options are `Remove()` or `Wrap()`, defaulting to [`Remove`](@ref).
- `cellsize`: size of cells.
- `timestep`: fixed timestep where this is reuired for some rules.
  eg. `Month(1)` or `1u"s"`.
"""
Base.@kwdef mutable struct Ruleset{B<:Boundary,P<:Processor,Op<:PerformanceOpt,C,T,PV} <: AbstractRuleset
    # Rules are intentionally not type stable. This allows `precalc` and Interact.jl
    # updates to change the rule type. Function barriers remove most performance overheads.
    rules::Tuple{Vararg{<:Rule}} = ()
    boundary::B                  = Remove()
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
        rules(rs), boundary(rs), proc(rs), opt(rs), cellsize(rs), timestep(rs), padval(rs)
    )

struct StaticRuleset{R<:Tuple,B<:Boundary,P<:Processor,Op<:PerformanceOpt,C,T,PV} <: AbstractRuleset
    # Rules are intentionally not type stable. This allows `precalc` and Interact.jl
    # updates to change the rule type. Function barriers remove most performance overheads.
    rules::R
    boundary::B
    proc::P
    opt::Op
    cellsize::C
    timestep::T
    padval::PV
end
StaticRuleset(rs::AbstractRuleset) =
    StaticRuleset(
        rules(rs), boundary(rs), proc(rs), opt(rs), cellsize(rs), timestep(rs), padval(rs)
    )
