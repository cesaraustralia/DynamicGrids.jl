
# _updaterules
# Update the StaticRuleset in the SimData object with
# a (potentially) modifed version of the original rules tuple.
# This must be passed in to allow async updating from a live
# interface while the simulation runs.
function _updaterules(rules::Tuple, sd::AbstractSimData)
    newrs = ModelParameters.setparent(
        ruleset(sd),
        _modifyrules(_proc_setup(proc(sd), ModelParameters.stripparams(rules)), sd)
    )
    @set sd.ruleset = newrs
end

# _modifyrules
# Run `modifyrule` for each rule, recursively.
_modifyrules(rules::Tuple, simdata) =
    (modifyrule(rules[1], simdata), _modifyrules(tail(rules), simdata)...)
_modifyrules(rules::Tuple{}, simdata) = ()

# The default `modifyrule` returns the rule unchanged.
modifyrule(rule, simdata) = rule

# Generate any initialisation data the rules need
function initialiserules(simdata)
    map(rules(simdata)) do rule
        initialiserule(simdata, rule)
    end
end

initialiserule(simdata, rule) = nothing

function _validaterules(ruleset::Ruleset, sd::AbstractSimData)
    map(rule -> validaterule(rule, sd), rules(ruleset))
end

validaterule(rule::Rule, sd::AbstractSimData) = true
