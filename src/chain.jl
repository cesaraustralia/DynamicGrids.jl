"""
    Chain(rules...)

`Chain`s allow chaining rules together to be completed in a single processing step,
without intermediate reads or writes from grids. 

They are potentially compiled together into a single function call, especially if you 
use `@inline` on all `applyrule` methods. `Chain` can hold either all [`CellRule`](@ref) 
or [`NeighborhoodRule`](@ref) followed by [`CellRule`](@ref).

[`ManualRule`](@ref) can't be used in `Chain`, as it doesn't have a return value.

![Chain rule diagram](https://raw.githubusercontent.com/cesaraustralia/DynamicGrids.jl/media/Chain.png)
"""
struct Chain{R,W,T<:Union{Tuple{},Tuple{Union{<:NeighborhoodRule,<:CellRule},Vararg{<:CellRule}}}} <: Rule{R,W}
    rules::T
end
Chain(rules...) = Chain(rules) 
Chain(rules::Tuple) = begin
    rkeys = Tuple{union(map(k -> asiterable(readkeys(k)), rules)...)...}
    wkeys = Tuple{union(map(k -> asiterable(writekeys(k)), rules)...)...}
    Chain{rkeys,wkeys,typeof(rules)}(rules)
end

rules(chain::Chain) = chain.rules
# Only the first rule in a chain can be a NeighborhoodRule
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

Chained rules. 

If a [`Chain`](@ref) of rules is passed to `applyrule`, run them
sequentially for each cell. This can have much beter performance as no writes
occur between rules, and they are essentially compiled together into compound
rules. This gives correct results only for [`CellRule`](@ref), or for a single
[`NeighborhoodRule`](@ref) followed by [`CellRule`](@ref).
"""
@generated applyrule(data::SimData, chain::Chain{R,W,T}, state, index) where {R,W,T} = begin
    expr = Expr(:block)
    for i in 1:length(T.parameters)
        rule_expr = quote
            rule = chain[$i]
            # Get the state needed by this rule
            read = readstate(rule, state)
            # Run the rule
            write = applyrule(data, rule, read, index)
            # Create new state with the result and state from other rules
            state = update_chainstate(rule, state, write)
        end
        push!(expr.args, rule_expr)
    end
    push!(expr.args, :(writestate(chain, state)))
    expr
end

# Get state as a NamedTuple or single value
@generated readstate(::Rule{R,W}, state::NamedTuple) where {R<:Tuple,W} = begin 
    expr = Expr(:tuple)
    keys = Tuple(R.parameters)
    for k in keys
        push!(expr.args, :(state[$(QuoteNode(k))]))
    end
    :(NamedTuple{$keys,typeof($expr)}($expr))
end
@inline readstate(::Rule{R,W}, state::NamedTuple) where {R,W} = state[R]

# Get the state to write for the chain
@generated writestate(::Rule{R,W}, state::NamedTuple) where {R<:Tuple,W} = begin 
    expr = Expr(:tuple)
    keys = Tuple(W.parameters)
    for k in keys
        push!(expr.args, :(state[$(QuoteNode(k))]))
    end
    expr
end
@inline writestate(rule::Rule{R,W}, state::NamedTuple) where {R,W} = state[W]

# Merge new state with previous state 
# Returning a new NamedTuple with all keys having the most recent state
@generated function update_chainstate(rule::Rule{R,W}, state::NamedTuple{K,V}, writestate
                                     ) where {R,W,K,V}
    expr = Expr(:tuple)
    writekeys = W isa Symbol ? (W,) : W.parameters
    keys = (union(K, writekeys)...,)
    for (i, k) in enumerate(keys)
        if k in writekeys
            for (j, wkey) in enumerate(writekeys)
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
        NamedTuple{$keys,typeof(newstate)}(newstate)
    end
end
