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
    rkeys = Tuple{union(map(k -> asiterable(readkeys(k)), args)...)...}
    wkeys = Tuple{union(map(k -> asiterable(writekeys(k)), args)...)...}
    Chain{rkeys,wkeys,typeof(args)}(args)
end

val(chain::Chain) = chain.val
# Only the first rule in a chain can have a radius larger than zero.
radius(chain::Chain) = radius(chain[1])
neighborhoodkey(chain::Chain) = neighborhoodkey(chain[1])

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
@inline applyrule(chain::Chain, data, state, index, args...) = begin
    newstate = applyrule(chain::Chain, chain[1], data, state, index, args...)
end
@inline applyrule(chain::Chain{R,W,Tuple{}}, data, state, index, args...
                 ) where {R,W} = 
    chainstate(chain, map(Val, writekeys(chain)), state)

@inline applyrule(chain::Chain, rule::Rule{RR,RW}, data, state, index, args...
                  ) where {RR,RW} = begin
    read = chainstate(chain, Val{RR}, state)
    write = applyrule(rule, data, read, index, args...)
    newstate = update_chainstate(chain, rule, state, write)
    applyrule(tail(chain), data, newstate, index)
end
@inline applyrule(chain::Chain, rule::Rule{RR,RW}, data, state, index, args...
                  ) where {RR<:Tuple,RW} = begin
    read = chainstate(chain, (map(Val, readkeys(rule))...,), state)
    write = applyrule(rule, data, read, index, args...)
    newstate = update_chainstate(chain, rule, state, write)
    applyrule(tail(chain), data, newstate, index)
end

@inline chainstate(chain::Chain, keys::Tuple, state) = begin
    keys = map(unwrap, keys)
    vals = map(k -> state[k], keys)
    NamedTuple{keys,typeof(vals)}(vals)
end
@inline chainstate(chain::Chain, key::Type{<:Val}, state) = 
    state[unwrap(key)]

@generated update_chainstate(chain::Chain{CR,CW}, rule::Rule{RR,RW}, state::NamedTuple{K,V}, writestate::Tuple
                            ) where {CR,CW,RR,RW,K,V} = begin
    expr = Expr(:tuple)
    wkeys = RW.parameters
    keys = (union(K, RW.parameters)...,)
    for (i, k) in enumerate(keys)
        if k in wkeys
            for (j, wkey) in enumerate(wkeys)
                if k == wkey
                    push!(expr.args, :(writestate[$j]))
                end
            end
        else
            push!(expr.args, :(state[$i]))
        end
    end
    quote
        newstate = $expr
        NamedTuple{$keys}(newstate)
    end
end

@generated update_chainstate(chain::Chain{CR,CW}, rule::Rule{RR,RW}, state::NamedTuple{K,V}, writestate
                            ) where {CR,CW,RR,RW,K,V} = begin
    expr = Expr(:tuple)
    keys = (union(K, (RW,))...,)
    for (i, k) in enumerate(keys)
        if k == RW
            push!(expr.args, :(writestate))
        else
            push!(expr.args, :(state[$i]))
        end
    end
    quote
        newstate = $expr
        NamedTuple{$keys}(newstate)
    end
end
