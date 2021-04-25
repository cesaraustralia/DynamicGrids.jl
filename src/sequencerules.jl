# Sequence rules over the [`SimData`](@ref) object,
# calling [`maprule!`](@ref) for each individual `Rule`.
function sequencerules!(simdata::AbstractSimData)
    newsimdata = sequencerules!(simdata, rules(simdata))
    _maybemask!(grids(newsimdata))
    newsimdata
end
function sequencerules!(simdata::AbstractSimData, rules::Tuple)
    # Mask writes to dest if a mask is provided, except for
    # CellRule which doesn't move values into masked areas
    rule = rules[1]
    rest = tail(rules)
    # Run the first rules
    newsimdata = maprule!(simdata, rule)
    # Run the rest of the rules recursively
    sequencerules!(newsimdata, rest)
end
sequencerules!(simdata::AbstractSimData, rules::Tuple{}) = simdata
