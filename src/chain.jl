"""
Chains allow chaining rules together to be completed in a single processing step
without intermediate writes, and potentially compiled together into a single function call. 
These can either be all CellRule or NeighborhoodRule followed by CellRule.
"""
struct Chain{T} <: Rule
    val::T
end
Chain(x::Union{NeighborhoodRule,CellRule}) = Chain{typeof(x)}((x,))
Chain(t::Tuple{<:Union{NeighborhoodRule,CellRule},Vararg{<:CellRule}}) = 
    Chain{typeof(t)}(t)
Chain(args...) = Chain(args)


val(chain::Chain) = chain.val

Base.show(io::IO, chain::Chain) = begin
    indent = get(io, :indent, "")
    printstyled(io, indent, "Chain :"; color=:green)
    for rule in val(chain)
        println(io)
        print(IOContext(io, :indent => indent * "    "), rule)
    end
end
Base.tail(chain::Chain) = (ch = tail(val(chain)); Chain{typeof(ch)}(ch))
Base.getindex(chain::Chain, I...) = getindex(val(chain), I...)
Base.size(chain::Chain) = size(val(chain))
