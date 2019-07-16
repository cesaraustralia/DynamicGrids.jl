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
        minval=nothing, maxval=nothing) = 
    Ruleset{typeof.((args, init, mask, overflow, cellsize, timestep, minval))...
           }(args, init, mask, overflow, cellsize, timestep, minval, maxval)

# Getters
rules(ruleset::Ruleset) = ruleset.cellsize
init(ruleset::Ruleset) = ruleset.init
mask(ruleset::Ruleset) = ruleset.mask
overflow(ruleset::Ruleset) = ruleset.overflow
cellsize(ruleset::Ruleset) = ruleset.cellsize
timestep(ruleset::Ruleset) = ruleset.timestep
minval(ruleset::Ruleset) = ruleset.minval
maxval(ruleset::Ruleset) = ruleset.maxval


struct HasMinMax end
struct NoMinMax end

hasminmax(ruleset::T) where T = fieldtype(T, :minval) <: Number ? HasMinMax() : NoMinMax()
