# We have to keep the original rulset pointer as it may be modified 
# elsewhere like in an Interact.jl interface. `Ruleset` is mutable,
# and rules has an abstract field type.
precalcrules!(simdata::Vector{<:SimData}) = precalcrules!.(simdata)
function precalcrules!(simdata::SimData)
    simdata.ruleset.rules = _precalcrules(ModelParameters.simplify(rules(simdata)), simdata)
    return simdata
end

_precalcrules(rules::Tuple, simdata) =
    (precalcrule(rules[1], simdata), _precalcrules(tail(rules), simdata)...)
_precalcrules(rules::Tuple{}, simdata) = ()


# Interface method
precalcrule(chain::Chain{R,W}, simdata) where {R,W} =
    Chain{R,W}(_precalcrules(rules(chain), simdata))
# Support for legacy pluralised version
precalcrule(rule, simdata) = precalcrules(rule, simdata)
# The default is to return a rule unchanged
precalcrules(rule, simdata) = rule
