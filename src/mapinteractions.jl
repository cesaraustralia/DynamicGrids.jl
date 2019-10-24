mapinteraction!(multidata::MultiSimData, interaction) = begin
    nrows, ncols = framesize(multidata)
     
    # Only pass in the data that the interaction wants, in that order
    interactiondata = map(key -> WritableSimData(multidata[key]), keys(interaction))

    for j in 1:ncols, i in 1:nrows
        ismasked(multidata, i, j) && continue
        state = map(d -> source(d)[i, j], interactiondata) 
        applyinteraction!(interaction, interactiondata, state, (i, j))
    end
end

