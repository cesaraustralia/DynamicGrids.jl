"""
    RuleWrapper <: Rule

A `Rule` that wraps other rules, altering their behaviour or how they are run.
"""
abstract type RuleWrapper{R,W} <: Rule{R,W} end

_val_ruletype(rule::RuleWrapper) = Val{ruletype(rule)}()

"""
    MultiRuleWrapper <: RuleWrapper

A `Rule` that wraps muliple other rules, altering their behaviour or how they are run.
"""
abstract type MultiRuleWrapper{R,W} <: RuleWrapper{R,W} end

# Rule interface
rules(rule::MultiRuleWrapper) = rule.rules
# Only the first rule in rule can be a NeighborhoodRule, but this seems annoying...
radius(rule::MultiRuleWrapper) = radius(first(rules(rule)))
# Forward ruletype to the contained rule
ruletype(rule::MultiRuleWrapper) = ruletype(first(rules(rule)))
stencilkey(rule::MultiRuleWrapper) = stencilkey(first(rules(rule)))
stencil(rule::MultiRuleWrapper) = stencil(first(rules(rule)))
neighbors(rule::MultiRuleWrapper) = neighbors(first(rules(rule)))
modifyrule(rule::MultiRuleWrapper, data) = @set rule.rules = _modifyrules(rules(rule), data)
@inline function Stencils.setneighbors(rule::MultiRuleWrapper{R,W}, win) where {R,W}
    rules = map(r -> setneighbors(r, win), rules(rule))
    @set rules.rule = rules
end

# Base interface
Base.tail(rule::MultiRuleWrapper) = @set rule.rules = tail(rules(rule))
Base.getindex(rule::MultiRuleWrapper, i) = getindex(rules(rule), i)
Base.iterate(rule::MultiRuleWrapper) = iterate(rules(rule))
Base.iterate(rule::MultiRuleWrapper, nothing) = iterate(rules(rule), nothing)
Base.length(rule::MultiRuleWrapper) = length(rules(rule))
Base.firstindex(rule::MultiRuleWrapper) = firstindex(rules(rule))
Base.lastindex(rule::MultiRuleWrapper) = lastindex(rules(rule))


# Utils

# Get the state to pass to the specific rule as a `NamedTuple` or single value
@generated function _filter_readstate(::Rule{R,W}, state::NamedTuple) where {R<:Tuple,W}
    expr = Expr(:tuple)
    keys = Tuple(R.parameters)
    for k in keys
        push!(expr.args, :(state[$(QuoteNode(k))]))
    end
    :(NamedTuple{$keys}($expr))
end
@inline _filter_readstate(::Rule{R,W}, state::NamedTuple) where {R,W} = state[R]

# Get the state to write for the specific rule
@generated function _filter_writestate(data::AbstractSimData, ::Rule{R,W}, state::NamedTuple) where {R<:Tuple,W<:Tuple}
    expr = Expr(:tuple)
    # We only write when there is actually a corresponding grid
    # This allows non-grid variable passing between Chain rules
    for k in Tuple(p for p in W.parameters if p in keys(data))
        push!(expr.args, :(state[$(QuoteNode(k))]))
    end
    expr
end
