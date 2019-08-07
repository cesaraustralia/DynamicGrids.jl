abstract type AbstractRuleset end

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

# Getters
rules(rs::Ruleset) = rs.cellsize
init(rs::Ruleset) = rs.init
mask(rs::Ruleset) = rs.mask
overflow(rs::Ruleset) = rs.overflow
cellsize(rs::Ruleset) = rs.cellsize
timestep(rs::Ruleset) = rs.timestep
minval(rs::Ruleset) = rs.minval
maxval(rs::Ruleset) = rs.maxval
ruleset(rs::Ruleset) = rs


struct HasMinMax end
struct NoMinMax end

hasminmax(ruleset::T) where T = fieldtype(T, :minval) <: Number ? HasMinMax() : NoMinMax()
