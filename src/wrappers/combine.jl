"""
    Combine{R,W} <: MultiRuleWrapper{R,W}

    Combine(f, rules::Tuple)
    Combine(f, rules...)

Combine the results of multiple independent rules with the function `f`.

Only `ReturnRule` like `CellRule` and `NeighborhoodRule` can be used in `Combine`.
"""
struct Combine{R,W,F,RL} <: MultiRuleWrapper{R,W}
    f::F
    rules::RL
end
function Combine(f, rules::Tuple{Vararg{<:ReturnRule}})
    wkeys = Tuple{union(map(k -> _asiterable(_writekeys(k)), rules)...)...} 
    rkeys = Tuple{union(map(k -> _asiterable(_readkeys(k)), rules)...)...}
    Combine{rkeys,wkeys,typeof(f),typeof(rules)}(f, rules)
end
Combine(f, rules::ReturnRule...) = Combine(f, rules)

function applyrule(data::AbstractSimData, rule::Combine, state, I)
    values = map(rules(rule)) do r
        read = _filter_readstate(rule, state)
        applyrule(data, r, readstate, I) 
    end
    combined = rule.f(values)
    return _astuple(rule, combined)
end
