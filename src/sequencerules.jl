#= Threaded replicate simulations. If `nreplicates` is set the data object
will be a vector of replicate data, so we loop over it with threads.
TODO: use new threading method =#
sequencerules!(data::AbstractVector{T}) where T<:AbstractSimData = begin
    newdata = copy(data)
    Threads.@threads for i in 1:length(data)
        newdata[i] = sequencerules!(data[i])
    end
    newdata
end
#= Iterate over all rules recursively, updating the simdata object at each step.
Returns the simdata object with source and dest arrays ready for the next rule 
in the sequence, or the next timestep. =#
sequencerules!(simdata::AbstractSimData) = 
    sequencerules!(simdata, rules(simdata))
sequencerules!(simdata::AbstractSimData, rules::Tuple) = begin
    # Run the first rules
    simdata = maprule!(simdata, rules[1])
    # Run the rest of the rules recursively
    sequencerules!(simdata, tail(rules))
end
sequencerules!(simdata::AbstractSimData, rules::Tuple{}) = simdata
