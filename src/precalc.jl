# We have to keep the original rulset pointer as it may be modified 
# elsewhere like in an Interact.jl interface. `Ruleset` is mutable,
# and rules has an abstract field type.
precalcrules(simdata::Vector, rules::Tuple) = map(sd -> precalcrules(sd, rules), simdata)
function precalcrules(sd::SimData, rules::Tuple)
    @set sd.ruleset = ModelParameters.setparent(
        ruleset(sd),
        precalcrules(proc_setup(proc(sd), ModelParameters.stripparams(rules)), sd)
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
