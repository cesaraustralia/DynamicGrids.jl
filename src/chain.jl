"""
    Chain(rules...)
    Chain(rules::Tuple)

`Chain`s allow chaining rules together to be completed in a single processing step,
without intermediate reads or writes from grids.

They are potentially compiled together into a single function call, especially if you
use `@inline` on all `applyrule` methods. `Chain` can hold either all [`CellRule`](@ref)
or [`NeighborhoodRule`](@ref) followed by [`CellRule`](@ref).

[`SetRule`](@ref) can't be used in `Chain`, as it doesn't have a return value.

![Chain rule diagram](https://raw.githubusercontent.com/cesaraustralia/DynamicGrids.jl/media/Chain.png)
"""
struct Chain{R,W,T<:Union{Tuple{},Tuple{Union{<:NeighborhoodRule,<:CellRule},Vararg{<:CellRule}}}} <: Rule{R,W}
    rules::T
end
Chain(rules...) = Chain(rules)
Chain(rules::Tuple) = begin
    rkeys = Tuple{union(map(k -> _asiterable(_readkeys(k)), rules)...)...}
    wkeys = Tuple{union(map(k -> _asiterable(_writekeys(k)), rules)...)...}
    Chain{rkeys,wkeys,typeof(rules)}(rules)
end

rules(chain::Chain) = chain.rules
# Only the first rule in a chain can be a NeighborhoodRule
radius(chain::Chain) = radius(chain[1])
neighborhoodkey(chain::Chain) = neighborhoodkey(chain[1])
neighborhood(chain::Chain) = neighborhood(chain[1])
neighbors(chain::Chain) = neighbors(chain[1])
@inline function _setbuffer(chain::Chain{R,W}, buf) where {R,W}
    rules = (_setbuffer(chain[1], buf), tail(chain.rules)...)
    Chain{R,W,typeof(rules)}(rules)
end

function Base.tail(chain::Chain{R,W}) where {R,W}
    chaintail = tail(rules(chain))
    Chain{R,W,typeof(chaintail)}(chaintail)
end
Base.getindex(chain::Chain, i) = getindex(rules(chain), i)
Base.iterate(chain::Chain) = iterate(rules(chain))
Base.length(chain::Chain) = length(rules(chain))
Base.firstindex(chain::Chain) = firstindex(rules(chain))
Base.lastindex(chain::Chain) = lastindex(rules(chain))

@generated function applyrule(data::SimData, chain1::Chain{R,W,T}, state1, index) where {R,W,T}
    expr = Expr(:block)
    nrules = length(T.parameters)
    for i in 1:nrules
        # Variables are numbered to make debugging type stability easier
        state = Symbol("state$i")
        nextstate = Symbol("state$(i+1)") 
        rule = Symbol("rule$i") 
        read = Symbol("read$i") 
        write = Symbol("write$i") 
        chain = Symbol("chain$i") 
        nextchain = Symbol("chain$(i+1)") 
        rule_expr = quote
            $rule = $chain[1]
            # Get the state needed by this rule
            $read = _filter_readstate($rule, $state)
            # Run the rule
            $write = applyrule(data, $rule, $read, index)
            # Create new state with the result and state from other rules
            $nextstate = _update_chainstate($rule, $state, $write)
            $nextchain = tail($chain)
        end
        push!(expr.args, rule_expr)
    end
    laststate = Symbol("state$(nrules+1)")
    push!(expr.args, :(_filter_writestate(chain1, $laststate)))
    expr
end

"""
    _filter_readstate(rule, state::NamedTuple)

Get the state to pass to the specific rule as a `NamedTuple` or single value
"""
@generated function _filter_readstate(::Rule{R,W}, state::NamedTuple) where {R<:Tuple,W}
    expr = Expr(:tuple)
    keys = Tuple(R.parameters)
    for k in keys
        push!(expr.args, :(state[$(QuoteNode(k))]))
    end
    :(NamedTuple{$keys}($expr))
end
@inline _filter_readstate(::Rule{R,W}, state::NamedTuple) where {R,W} = state[R]

"""
    _filter_writestate(rule, state::NamedTuple)

Get the state to write for the specific rule
"""
@generated function _filter_writestate(::Rule{R,W}, state::NamedTuple) where {R<:Tuple,W<:Tuple}
    expr = Expr(:tuple)
    keys = Tuple(W.parameters)
    for k in keys
        push!(expr.args, :(state[$(QuoteNode(k))]))
    end
    expr
end

"""
    update_chainstate(rule::Rule, state::NamedTuple, writestate)

Merge new state with previous state.

Returns a new `NamedTuple` with all keys having the most recent state
"""
@generated function _update_chainstate(rule::Rule{R,W}, state::NamedTuple{K,V}, writestate
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
    :(NamedTuple{$keys}($expr))
end
