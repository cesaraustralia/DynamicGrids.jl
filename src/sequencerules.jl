
# Sequence rules over the [`SimData`](@ref) object,
# calling [`maprule!`](@ref) for each individual `Rule`.
function sequencerules!(simdata::AbstractSimData)
    newsimdata = sequencerules!(simdata, rules(simdata))
    # We run masking here to mask out cells that are `false` in the 
    # `mask` array, if it exists. Not all rules run masking, so it is
    # applied here so that the final grid is always masked.
    _maybemask!(grids(newsimdata))
    newsimdata
end
function sequencerules!(simdata::AbstractSimData, rules::Tuple)
    rule = rules[1]
    rest = tail(rules)
    # Run the first rules
    newsimdata = maprule!(simdata, rule)
    # Run the rest of the rules recursively
    sequencerules!(newsimdata, rest)
end
sequencerules!(simdata::AbstractSimData, rules::Tuple{}) = simdata
