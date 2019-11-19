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
Iterate over all rules recursively, swapping source and dest arrays after
each rule or interaction is run.

Returns a data object with source and dest arrays ready for the next rule 
in the sequence, or the next timestep.
"""
sequencerules!(data::SimData) = sequencerules!(data, rules(data))
sequencerules!(data::SimData, rules::Tuple) = begin
    # Run the first rule over the whole frame
    maprule!(data, rules[1])
    # Swap the source and dest grids
    data = swapsource(data)
    # Run the rest of the rules recursively
    sequencerules!(data, tail(rules))
end
@inline sequencerules!(data::SimData, rules::Tuple{}) = data

sequencerules!(multidata::MultiSimData) = begin
    # Sequence the rules for each grid separately
    @set! multidata.data = map(sequencerules!, multidata.data)
    # Sequence all the interactions together
    sequenceinteractions!(multidata)
end

sequenceinteractions!(multidata::MultiSimData) = 
    sequenceinteractions!(multidata, interactions(multidata))
sequenceinteractions!(multidata::MultiSimData, interactions::Tuple) = begin
    # Run the first interaction
    mapinteraction!(multidata, interactions[1])
    # Swap source and dest for all grids
    @set! multidata.data = map(swapsource, data(multidata))
    # Run the rest of the interactions recursively
    sequenceinteractions!(multidata, tail(interactions))
end
sequenceinteractions!(multidata::MultiSimData, interactions::Tuple{}) = multidata
