# We have to keep the original rulset as it may be modified elsewhere
# like in an Interact.jl interface. `Ruleset` is mutable.
precalcrules!(simdata::Vector{<:SimData}) = precalcrules!.(simdata)
precalcrules!(simdata::SimData) = begin
    simdata.ruleset.rules = precalcrules(rules(simdata), simdata)
    simdata
end

"""
    precalcrules(rule::Rule, simdata::SimData)

Precalculates rule at each timestep, if there are any fields that need
to be updated over time. Rules are usually immutable (it's faster), so
return a whole new rule object with changes you need applied.
They will be discarded, and `rule` will always be the original object passed in.

Setfield.jl and Flatten.jl may help for this.

The default action is to return the existing rule without change.
"""
function precalcrules end
precalcrules(rule, simdata) = rule
precalcrules(rules::Tuple, simdata) =
    (precalcrules(rules[1], simdata), precalcrules(tail(rules), simdata)...)
precalcrules(rules::Tuple{}, simdata) = ()
precalcrules(chain::Chain{R,W}, simdata) where {R,W} =
    Chain{R,W}(precalcrules(rules(chain), simdata))
