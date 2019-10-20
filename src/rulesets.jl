"""
Singleton types for choosing the grid overflow rule used in
[`inbounds`](@ref). These determine what is done when a neighborhood
or jump extends outside of the grid.
"""
abstract type AbstractOverflow end

"Wrap cords that overflow boundaries back to the opposite side"
struct WrapOverflow <: AbstractOverflow end

"Remove coords that overflow boundaries"
struct RemoveOverflow <: AbstractOverflow end


abstract type AbstractRuleset end

"""
    Ruleset(rules...; init=nothing, overflow=RemoveOverflow(), cellsize=1, timestep=1)

A container for holding a sequence of AbstractRule, an init
array and other simulaiton details.
"""
@default_kw mutable struct Ruleset{R<:Tuple{AbstractRule,Vararg},I,M,O<:AbstractOverflow,C,T} <: AbstractRuleset
    rules::R     | nothing
    init::I      | nothing
    mask::M      | nothing
    overflow::O  | RemoveOverflow()
    cellsize::C  | 1
    timestep::T  | 1
end
Ruleset(rules::Vararg{<:AbstractRule}; kwargs...) = Ruleset(; rules=rules, kwargs...)

show(io::IO, ruleset::Ruleset) = begin
    printstyled(io, Base.nameof(typeof(ruleset)), " =\n"; color=:blue)
    println(io, "rules:")
    for rule in ruleset.rules
        println(IOContext(io, :indent => "    "), rule)
    end
    for fn in fieldnames(typeof(ruleset))
        fn == :rules && continue
        println(io, fn, " = ", repr(getfield(ruleset, fn)))
    end
end

# Getters
rules(rs::Ruleset) = rs.rules
init(rs::Ruleset) = rs.init
mask(rs::Ruleset) = rs.mask
overflow(rs::Ruleset) = rs.overflow
cellsize(rs::Ruleset) = rs.cellsize
timestep(rs::Ruleset) = rs.timestep
ruleset(rs::Ruleset) = rs
