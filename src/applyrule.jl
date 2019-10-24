"""
    applyrule(rules::Chain, data, state, (i, j))

Chained rules. If a `Chain` of rules is passed to applyrule, run them sequentially for each 
cell.  This can have much beter performance as no writes occur between rules, and they are
essentially compiled together into compound rules. This gives correct results only for
AbstractCellRule, or for a single AbstractNeighborhoodRule followed by AbstractCellRule.
"""
@inline applyrule(rules::Chain{<:Tuple{<:AbstractNeighborhoodRule,Vararg}}, data, state, index, buf) = begin
    state = applyrule(rules[1], data, state, index, buf)
    applyrule(tail(rules), data, state, index)
end
@inline applyrule(rules::Chain, data, state, index) = begin
    state == zero(state) && return state
    newstate = applyrule(rules[1], data, state, index)
    applyrule(tail(rules), data, newstate, index)
end
@inline applyrule(rules::Chain{Tuple{}}, data, state, index) = state

