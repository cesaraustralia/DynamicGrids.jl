"""
    sequencerules!(simdata::AbstractSimData)

Sequence rules over the [`SimData`](@ref) object,
calling [`maprule!`](@ref) for each individual `Rule`.

If a Vector of `SimData` is used replicates will be run
with `Threads.@threads`.

TODO: use the new threading method.
"""
function sequencerules!(simdata::AbstractSimData)
    sequencerules!(simdata, precalculated_rules(simdata))
end
function sequencerules!(data::AbstractVector{T}) where T<:AbstractSimData
    newdata = copy(data)
    Threads.@threads for i in 1:length(data)
        newdata[i] = sequencerules!(data[i])
    end
    newdata
end
function sequencerules!(simdata::AbstractSimData, rules::Tuple)
    # Run the first rules
    simdata = maprule!(simdata, rules[1])
    # Run the rest of the rules recursively
    sequencerules!(simdata, tail(rules))
end
sequencerules!(simdata::AbstractSimData, rules::Tuple{}) = simdata
