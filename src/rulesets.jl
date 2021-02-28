"""
    AbstractRuleset <: ModelParameters.AbstractModel

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
radius(set::AbstractRuleset) = radius(rules(set))

Base.step(rs::AbstractRuleset) = timestep(rs)

# ModelParameters interface
Base.parent(rs::AbstractRuleset) = rules(rs)
ModelParameters.setparent!(rs::AbstractRuleset, rules) = rs.rules = rules
ModelParameters.setparent(rs::AbstractRuleset, rules) = @set rs.rules = rules

"""
    Rulseset <: AbstractRuleset

    Ruleset(rules...; kw...)

A container for holding a sequence of `Rule`s and simulation
details like boundary handing and optimisation.
Rules will be run in the order they are passed, ie. `Ruleset(rule1, rule2, rule3)`.

# Keywords

- `proc`: a [`Processor`](@ref) to specificy the hardware to run simulations on, 
    like [`SingleCPU`](@ref), [`ThreadedCPU`](@ref) or [`CuGPU`](@ref) when 
    KernelAbstractions.jl and a CUDA gpu is available. 
- `opt`: a [`PerformanceOpt`](@ref) to specificy optimisations like
    [`SparseOpt`](@ref). Defaults to [`NoOpt`](@ref).
- `boundary`: what to do with boundary of grid edges.
    Options are `Remove()` or `Wrap()`, defaulting to [`Remove`](@ref).
- `cellsize`: size of cells.
- `timestep`: fixed timestep where this is required for some rules. 
    eg. `Month(1)` or `1u"s"`.
"""
Base.@kwdef mutable struct Ruleset{B<:BoundaryCondition,P<:Processor,Op<:PerformanceOpt,C,T} <: AbstractRuleset
    # Rules in Ruleset are intentionally not type-stable.
    # But they are when rebuilt in a StaticRuleset later
    rules::Tuple{Vararg{<:Rule}} = ()
    boundary::B                  = Remove()
    proc::P                      = SingleCPU()
    opt::Op                      = NoOpt()
    cellsize::C                  = 1
    timestep::T                  = nothing
end
Ruleset(rules::Rule...; kw...) = Ruleset(; rules=rules, kw...)
Ruleset(rules::Tuple; kw...) = Ruleset(; rules=rules, kw...)
function Ruleset(rs::AbstractRuleset)
    Ruleset(
        rules(rs), boundary(rs), proc(rs), opt(rs), cellsize(rs), timestep(rs),
    )
end

struct StaticRuleset{R<:Tuple,B<:BoundaryCondition,P<:Processor,Op<:PerformanceOpt,C,T} <: AbstractRuleset
    rules::R
    boundary::B
    proc::P
    opt::Op
    cellsize::C
    timestep::T
end
function StaticRuleset(rs::AbstractRuleset)
    StaticRuleset(
        rules(rs), boundary(rs), proc(rs), opt(rs), cellsize(rs), timestep(rs),
    )
end
