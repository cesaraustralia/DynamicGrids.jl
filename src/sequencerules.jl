# Sequence rules over the [`SimData`](@ref) object,
# calling [`maprule!`](@ref) for each individual `Rule`.
function sequencerules!(simdata::AbstractSimData)
    sequencerules!(simdata, rules(simdata))
end
function sequencerules!(simdata::AbstractSimData, rules::Tuple)
    # Run the first rules
    simdata = maprule!(simdata, rules[1])
    # Run the rest of the rules recursively
    sequencerules!(simdata, tail(rules))
end
sequencerules!(simdata::AbstractSimData, rules::Tuple{}) = simdata
