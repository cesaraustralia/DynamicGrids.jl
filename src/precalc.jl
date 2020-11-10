# We have to keep the original rulset pointer as it may be modified 
# elsewhere like in an Interact.jl interface. `Ruleset` is mutable,
# and rules has an abstract field type.
precalcrules(simdata::Vector{<:SimData}) = map(precalcrules, simdata)
precalcrules(simdata::SimData) = precalcrules(simdata, rules(simdata))
function precalcrules(simdata::SimData, rules)
    @set simdata.precalculated_ruleset = ModelParameters.setparent(
        precalculated_ruleset(simdata),
        precalcrules(ModelParameters.stripparams(rules), simdata)
    )
end

precalcrules(rules::Tuple, simdata) =
    (precalcrule(rules[1], simdata), precalcrules(tail(rules), simdata)...)
precalcrules(rules::Tuple{}, simdata) = ()


# Interface method
precalcrule(chain::Chain{R,W}, simdata) where {R,W} =
    Chain{R,W}(precalcrules(rules(chain), simdata))
# Support for legacy pluralised version
precalcrule(rule, simdata) = precalcrules(rule, simdata)
# The default is to return a rule unchanged
precalcrules(rule, simdata) = rule
