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
mutable struct Ruleset{R,I,Ma,O<:AbstractOverflow,C<:Number,T<:Number,M} <: AbstractRuleset
    rules::R
    init::I
    mask::Ma
    overflow::O
    cellsize::C
    timestep::T
    minval::M
    maxval::M
end
Ruleset(args...; init=nothing, mask=nothing, overflow=RemoveOverflow(), cellsize=1, timestep=1, 
        minval=0, maxval=1) = 
    Ruleset{typeof.((args, init, mask, overflow, cellsize, timestep, minval))...
           }(args, init, mask, overflow, cellsize, timestep, minval, maxval)
rules(rs::Ruleset) = rs.rules


abstract type RuleMode{T} end

struct Shared{T} <: RuleMode{T} val::T end
struct Combined{T} <: RuleMode{T} val::T end
struct Parallel{T} <: RuleMode{T} val::T end
struct Specific{X,T} <: RuleMode{T} val::T end
Specific{X}(t) where X = Specific{X,typeof(t)}(t)


val(rm::RuleMode) = rm.val
maxradius(rm::RuleMode) = maxradius(val(rm))


struct HasMinMax end
struct NoMinMax end

hasminmax(ruleset::T) where T = fieldtype(T, :minval) <: Number ? HasMinMax() : NoMinMax()
