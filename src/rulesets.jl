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
end
Ruleset(args...; init=nothing, mask=nothing, overflow=RemoveOverflow(), cellsize=1, timestep=1, 
        minval=0, maxval=1) = 
    Ruleset{typeof.((args, init, mask, overflow, cellsize, timestep, minval))...
           }(args, init, mask, overflow, cellsize, timestep, minval, maxval)

show(io::IO, ruleset::Ruleset) = begin
    printstyled(io, Base.nameof(typeof(ruleset)), " :"; color=:blue)
    println(io)
    println(IOContext(io, :indent => "    "), "rules:\n", ruleset.rules)
    for fn in fieldnames(typeof(ruleset))
        fn == :rules && continue
        println(io, fn, " = ", repr(getfield(ruleset, fn)))
    end
end

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

struct Chain{T}
    val::T
    Chain{T}(t::Tuple) where T = begin
        if !(t[1] <: Union{AbstractNeighborhoodRule, AbstractCellRule})
            throw(ArgumentError("Only `AbstractNeighborhoodRule` or `AbstractCellRule` allowed as first rule in a `Chain`. $(Base.nameof(typeof(r))) found"))
        end
        map(tail(t)) do r
            if !(r <: AbstractCellRule)
                throw(ArgumentError("Only `AbstractCellRule` allowed in a `Chain`. $(Base.nameof(typeof(r))) found"))
            end
        end
        new{T}(t)
    end
end
Chain(xs::Tuple) = Chain{typeof(xs)}(xs)
Chain(x) = Chain{typeof((x,))}((x,))
Chain(args...) = Chain{typeof(args)}(args)

val(chain::Chain) = chain.val
Base.tail(chain::Chain) = Chain(tail(val(chain)))
Base.getindex(chain::Chain, I...) = getindex(val(chain), I...)
Base.size(chain::Chain) = size(val(chain))
