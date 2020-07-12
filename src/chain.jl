"""
`Chain`s allow chaining rules together to be completed in a single processing step
without intermediate reads or writes from grids. They are potentially compiled
together into a single function call, especially if you use `@inline` on all
`applyrule`. methods. `Chain` can hold either all [`CellRule`](@ref) or
[`NeighborhoodRule`](@ref) followed by [CellRule`](@ref).
"""
struct Chain{R,W,T<:Union{Tuple{},Tuple{Union{<:NeighborhoodRule,<:CellRule},Vararg{<:CellRule}}}} <: Rule{R,W}
    rules::T
end
Chain(args...) = begin
    rkeys = Tuple{union(map(k -> asiterable(readkeys(k)), args)...)...}
    wkeys = Tuple{union(map(k -> asiterable(writekeys(k)), args)...)...}
    Chain{rkeys,wkeys,typeof(args)}(args)
end

rules(chain::Chain) = chain.rules
# Only the first rule in a chain can have a radius larger than zero.
radius(chain::Chain) = radius(chain[1])
neighborhoodkey(chain::Chain) = neighborhoodkey(chain[1])
neighborhood(chain::Chain) = neighborhood(chain[1])

Base.tail(chain::Chain{R,W}) where {R,W} = begin
    ch = tail(rules(chain))
    Chain{R,W,typeof(ch)}(ch)
end
Base.getindex(chain::Chain, i) = getindex(rules(chain), i)
Base.iterate(chain::Chain) = iterate(rules(chain))
Base.length(chain::Chain) = length(rules(chain))
Base.firstindex(chain::Chain) = firstindex(rules(chain))
Base.lastindex(chain::Chain) = lastindex(rules(chain))

"""
    applyrule(data, rules::Chain, state, (i, j))

Chained rules. If a [`Chain`](@ref) of rules is passed to `applyrule`, run them
sequentially for each cell. This can have much beter performance as no writes
occur between rules, and they are essentially compiled together into compound
rules. This gives correct results only for [`CellRule`](@ref), or for a single
[`NeighborhoodRule`](@ref) followed by [`CellRule`](@ref).
"""
@inline applyrule(data::SimData, chain::Chain, state, index) =
    chainrule(data, chain::Chain, chain[1], state, index)
@inline applyrule(data::SimData, chain::Chain{R,W,Tuple{}}, state, index) where {R,W} =
    chainstate(chain, map(Val, writekeys(chain)), state)

@inline chainrule(data::SimData, chain::Chain, rule::Rule{RR,RW}, state, index
                  ) where {RR,RW} = begin
    # Get the state needed by this rule
    read = chainstate(chain, Val{RR}, state)
    # Run the rule
    write = applyrule(data, rule, read, index)
    # Create new state with the result and state from other rules
    newstate = update_chainstate(chain, rule, state, write)
    # Run applyrule on the rest of the chain
    applyrule(data, tail(chain), newstate, index)
end
@inline chainrule(data::SimData, chain::Chain, rule::Rule{RR,RW}, state, index, args...
                  ) where {RR<:Tuple,RW} = begin
    read = chainstate(chain, (map(Val, readkeys(rule))...,), state)
    write = applyrule(data, rule, read, index)
    newstate = update_chainstate(chain, rule, state, write)
    applyrule(data, tail(chain), newstate, index)
end

# Get state as a NamedTuple or single value
@inline chainstate(chain::Chain, keys::Tuple, state) = begin
    keys = map(unwrap, keys)
    vals = map(k -> state[k], keys)
    NamedTuple{keys,typeof(vals)}(vals)
end
@inline chainstate(chain::Chain, key::Type{<:Val}, state) =
    state[unwrap(key)]

# Merge new state with previous state 
# Returning a new NamedTuple with all keys having the most recent state
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
