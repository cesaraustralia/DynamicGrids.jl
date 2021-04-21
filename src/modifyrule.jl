# We have to use the original rules as they may be modified 
# elsewhere, like in an Interact.jl interface. So here we build them
# into the SimData object after running _modifyrules on them
function _updaterules(rules::Tuple, sd::AbstractSimData)
    newrs = ModelParameters.setparent(
        ruleset(sd),
        _modifyrules(_proc_setup(proc(sd), ModelParameters.stripparams(rules)), sd)
    )
    @set sd.ruleset = newrs
end

_modifyrules(rules::Tuple, simdata) =
    (modifyrule(rules[1], simdata), _modifyrules(tail(rules), simdata)...)
_modifyrules(rules::Tuple{}, simdata) = ()

# The default is to return a rule unchanged
modifyrule(rule, simdata) = rule

