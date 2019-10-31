"""
Threaded replicate simulations. If `nreplicates` is set the data object
will be a vector of replicate data, so we loop over it with threads.
"""
sequencerules!(data::AbstractVector{<:AbstractSimData}, rules) = begin
    Threads.@threads for i in 1:length(data)
        sequencerules!(data[i], rules)
    end
    data
end

"""
Iterate over all rules recursively, swapping source and dest arrays.
Returns the data object with source and dest arrays ready for the next iteration.
"""
sequencerules!(data::SimData) = sequencerules!(data, rules(data))
sequencerules!(data::SimData, rules::Tuple) = begin
    # Run the first rule for the whole frame
    maprule!(data, rules[1])
    # Swap the source and dest arrays
    data = swapsource(data)
    # Run the rest of the rules, recursively
    sequencerules!(data, tail(rules))
end
@inline sequencerules!(data::SimData, rules::Tuple{}) = data

sequencerules!(data::MultiSimData) = begin
    @set! data.data = map(sequencerules!, data.data)
    sequenceinteractions!(data)
end

sequenceinteractions!(multidata::MultiSimData) = 
    sequenceinteractions!(multidata, interactions(multidata))
sequenceinteractions!(multidata::MultiSimData, interactions::Tuple) = begin
    # Run the first rule for the whole frame
    mapinteraction!(multidata, interactions[1])
    @set! multidata.data = map(swapsource, data(multidata))

    # Run the rest of the interactions, recursively
    sequenceinteractions!(multidata, tail(interactions))
end
sequenceinteractions!(multidata::MultiSimData, interactions::Tuple{}) = multidata
