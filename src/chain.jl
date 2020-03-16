"""
`Chain`s allow chaining rules together to be completed in a single processing step
without intermediate reads or writes from grids. They are potentially compiled
together into a single function call, especially if you use `@inline` on all
`applyrule`. methods. `Chain` can hold either all [`CellRule`](@ref) or
[`NeighborhoodRule`](@ref) followed by [CellRule`](@ref).
"""
struct Chain{R,W,T<:Union{Tuple{},Tuple{Union{<:NeighborhoodRule,<:CellRule},Vararg{<:CellRule}}}} <: Rule{R,W}
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

Base.show(io::IO, chain::Chain{R,W}) where {R,W} = begin
    indent = get(io, :indent, "")
    printstyled(io, indent, string("Chain {", W, ",", R, "} :"); color=:green)
    for rule in val(chain)
        println(io)
        print(IOContext(io, :indent => indent * "    "), rule)
    end
end
Base.tail(chain::Chain{R,W}) where {R,W} = begin
    ch = tail(val(chain))
    Chain{R,W,typeof(ch)}(ch)
end
Base.tail(chain::Chain{R,W,Tuple{}}) where {R,W} = Chain{R,W}(())
Base.getindex(chain::Chain, I...) = getindex(val(chain), I...)
Base.length(chain::Chain) = length(val(chain))

"""
    applyrule(rules::Chain, data, state, (i, j))

Chained rules. If a [`Chain`](@ref) of rules is passed to `applyrule`, run them
sequentially for each cell. This can have much beter performance as no writes
occur between rules, and they are essentially compiled together into compound
rules. This gives correct results only for [`CellRule`](@ref), or for a single
[`NeighborhoodRule`](@ref) followed by [`CellRule`](@ref).
"""
@inline applyrule(chain::Chain, data, state::NamedTuple, index, args...) = begin
    read = readstate(chain, state)
    write = applyrule(chain[1], data, read, index, args...)
    updated = updatestate(chain, write, state)
    applyrule(tail(chain), data, updated, index)
end
@inline applyrule(rules::Chain{R,W,Tuple{}}, data, state::NamedTuple, index, args...
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

neighborhoodkey(chain::Chain) = neighborhoodkey(chain[1])
