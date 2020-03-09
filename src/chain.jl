"""
Chains allow chaining rules together to be completed in a single processing step
without intermediate writes, and potentially compiled together into a single function call.
These can either be all CellRule or NeighborhoodRule followed by CellRule.
"""
struct Chain{R,W,T<:Union{Tuple{},Tuple{<:Union{NeighborhoodRule,CellRule},Vararg{<:CellRule}}}} <: Rule{R,W}
    val::T
end
Chain(args...) = begin
    wkeys = Tuple{union(map(writekeys, args))...}
    rkeys = Tuple{union(map(readkeys, args))...}
    Chain{wkeys,rkeys,typeof(args)}(args)
end

val(chain::Chain) = chain.val
# Only the first rule in a chain can have a radius larger than zero.
radius(chain::Chain) = radius(chain[1])

Base.show(io::IO, chain::Chain) = begin
    indent = get(io, :indent, "")
    printstyled(io, indent, "Chain :"; color=:green)
    for rule in val(chain)
        println(io)
        print(IOContext(io, :indent => indent * "    "), rule)
    end
end
Base.tail(chain::Chain{R,W}) where {R,W} = 
    (ch = tail(val(chain)); Chain{R,W,typeof(ch)}(ch))
Base.tail(chain::Chain{Tuple{}}) = Chain(())
Base.getindex(chain::Chain, I...) = getindex(val(chain), I...)
Base.size(chain::Chain) = size(val(chain))

"""
    applyrule(rules::Chain, data, state, (i, j))

Chained rules. If a `Chain` of rules is passed to applyrule, run them sequentially
for each cell. This can have much beter performance as no writes occur between rules, and
they are essentially compiled together into compound rules. This gives correct results only
for CellRule, or for a single NeighborhoodRule followed by CellRule.
"""
@inline applyrule(chain::Chain{<:Tuple{<:NeighborhoodRule,Vararg}},
                         data, state::NamedTuple, index, buf) = begin
    read = readstate(chain[1], state)
    write = applyrule(chain[1], data, read, index, buf)
    state = updatestate(chain, write, state)
    applyrule(tail(chain), data, updated, index)
end
@inline applyrule(chain::Chain, data, state::NamedTuple, index) = begin
    read = readstate(chain, state)
    write = applyrule(chain[1], data, read, index)
    state = updatestate(chain, write, state)
    applyrule(tail(chain), data, state, index)
end
@inline applyrule(rules::Chain{R,W,Tuple{}}, data, state::NamedTuple, index
                        ) where {R,W} = state

readstate(chain::Chain, state::NamedTuple) = begin
    keys = readkeys(chain[1])
    if keys isa Tuple
        vals = map(k -> state[k], keys)
        NamedTuple{keys,typeof(vals)}(vals)
    else
        state[keys]
    end
end

updatestate(chain::Chain, write, state::NamedTuple) = begin
    chainkeys = map(Val, keys(chain))
    wkeys = writekeys(chain[1])
    wkeys = if wkeys isa Tuple
        map(Val, wkeys)
    else
        Val(wkeys)
    end
    writestate(chainkeys, wkeys, write, state)
end

@inline writestate(chainkeys::Tuple, wkeys::Tuple, write, state) = begin
    state = writestate(chainkeys, wkeys[1], writestate, state)
    writestate(chainkeys, tail(wkeys), writestate, state)
end
@inline writestate(chainkeys::Tuple, writekey::Val, write, state) =
    map(state, NamedTuple{keys(state)}(chainkeys)) do s, ck
        writekey == ck ? write : s 
    end

unwrap(::Val{X}) where X = X
