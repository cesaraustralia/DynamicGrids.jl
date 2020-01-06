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


abstract type AbstractRuleset end

# Getters
init(rs::AbstractRuleset) = rs.init
mask(rs::AbstractRuleset) = rs.mask
overflow(rs::AbstractRuleset) = rs.overflow
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
@flattenable @default_kw mutable struct Ruleset{R<:Tuple,I,M,O<:Overflow,C,T} <: AbstractRuleset
    rules::R     | ()               | true
    init::I      | nothing          | false
    mask::M      | nothing          | false
    overflow::O  | RemoveOverflow() | false
    cellsize::C  | 1                | false
    timestep::T  | 1                | false
end
Ruleset(rules::Vararg{<:Rule}; kwargs...) = Ruleset(; rules=rules, kwargs...)

Ruleset(args...; kwargs...) = Ruleset(; rules=args, kwargs...)
rules(rs::Ruleset) = rs.rules

# Getters

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


@flattenable struct MultiRuleset{R<:Tuple{<:NamedTuple,<:Tuple},I,M,O,C,T} <: AbstractRuleset
    rules::R     | true
    init::I      | false
    mask::M      | false
    overflow::O  | false
    cellsize::C  | false
    timestep::T  | false
end
MultiRuleset(; rulesets=(), interactions=(), init=map(init, rulesets), 
             mask=nothing, overflow=RemoveOverflow(), cellsize=1, timestep=1) = begin
    rulesets = map(r -> standardise_ruleset(r, mask, overflow, cellsize, timestep), rulesets)
    MultiRuleset((rulesets, interactions), init, mask, overflow, cellsize, timestep)
end

rules(rs::MultiRuleset) = rs.rules
ruleset(mrs::MultiRuleset) = mrs.rules[1]
interactions(mrs::MultiRuleset) = mrs.rules[2]

Base.getindex(mrs::MultiRuleset, key) = getindex(ruleset(mrs), key)
Base.keys(mrs::MultiRuleset) = keys(ruleset(mrs))

standardise_ruleset(ruleset, mask, overflow, cellsize, timestep) = begin
    @set! ruleset.mask = mask 
    @set! ruleset.overflow = overflow 
    @set! ruleset.cellsize = cellsize 
    @set! ruleset.timestep = timestep 
    ruleset
end



# struct HasMinMax end
# struct NoMinMax end

# hasminmax(ruleset::T) where T = fieldtype(T, :minval) <: Number ? HasMinMax() : NoMinMax()
