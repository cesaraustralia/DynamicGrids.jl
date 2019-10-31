mapinteraction!(multidata::MultiSimData, interaction::Interaction) = begin
    nrows, ncols = framesize(multidata)
     
    # Only pass in the data that the interaction wants, in that order
    interactiondata = map(key -> multidata[key], keys(interaction))

    for j in 1:ncols, i in 1:nrows
        ismasked(multidata, i, j) && continue
        state = map(d -> source(d)[i, j], interactiondata) 
        newstate = applyinteraction(interaction, interactiondata, state, (i, j))
        map(interactiondata, newstate) do d, s
            @inbounds dest(d)[i, j] = s
        end
    end
end

mapinteraction!(multidata::MultiSimData, interaction::PartialInteraction) = begin
    nrows, ncols = framesize(multidata)
     
    # Only pass in the data that the interaction wants, in that order
    keys_ = keys(interaction)
    interactiondata = @set multidata.data = NamedTuple{keys_}(map(key -> WritableSimData(multidata[key]), keys_))

    # Copy all the source and dest arrays
    map(data(interactiondata)) do d 
        dest(d) .= source(d) 
    end

    # println(typeof(data(interactiondata)))
    for j in 1:ncols, i in 1:nrows
        ismasked(multidata, i, j) && continue
        state = map(d -> source(d)[i, j], data(interactiondata)) 
        applyinteraction!(interaction, interactiondata, state, (i, j))
    end
    println()
    display(source(data(interactiondata)[2]))
    display(dest(data(interactiondata)[2]))
end

