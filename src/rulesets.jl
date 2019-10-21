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

Ruleset(args...; init=nothing, mask=nothing, overflow=RemoveOverflow(), cellsize=1, timestep=1, 
        minval=0, maxval=1) = 
    Ruleset{typeof.((args, init, mask, overflow, cellsize, timestep, minval))...
           }(args, init, mask, overflow, cellsize, timestep, minval, maxval)
rules(rs::Ruleset) = rs.rules

# Getters
rules(rs::Ruleset) = rs.rules
init(rs::Ruleset) = rs.init
mask(rs::Ruleset) = rs.mask
overflow(rs::Ruleset) = rs.overflow
cellsize(rs::Ruleset) = rs.cellsize
timestep(rs::Ruleset) = rs.timestep
ruleset(rs::Ruleset) = rs

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


abstract type RuleMode{T} end

struct Independent{T} <: RuleMode{T} val::T end
struct Interactive{Keys,T} <: RuleMode{T} 
    val::T 
end
Interactive{Keys}(t) where Keys = Interactive{Keys,typeof(t)}(t)

# Provide a constructor for generic rule reconstruction
ConstructionBase.constructorof(::Type{Interactive{Keys}}) where Keys = Interactive{Keys} 


val(rm::RuleMode) = rm.val
maxradius(rm::RuleMode) = maxradius(val(rm))


struct HasMinMax end
struct NoMinMax end

hasminmax(ruleset::T) where T = fieldtype(T, :minval) <: Number ? HasMinMax() : NoMinMax()
