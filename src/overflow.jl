
#= Wrap overflow where required. This optimisation allows us to ignore
bounds checks on neighborhoods and still use a wraparound grid. =#
handleoverflow!(griddata) = handleoverflow!(griddata, overflow(griddata))
handleoverflow!(griddata::GridData{T,2}, ::WrapOverflow) where T = begin
    r = radius(griddata)

    # TODO optimise this. Its mostly a placeholder so wrapping still works in GOL tests.
    src = source(griddata)
    nrows, ncols = gridsize(griddata)

    startpadrow = startpadcol = 1-r:0
    endpadrow = nrows+1:nrows+r
    endpadcol = ncols+1:ncols+r
    startrow = startcol = 1:r
    endrow = nrows+1-r:nrows
    endcol = ncols+1-r:ncols
    rows = 1:nrows
    cols = 1:ncols

    # Left
    @inbounds copyto!(src, CartesianIndices((rows, startpadcol)),
                      src, CartesianIndices((rows, endcol)))
    # Right
    @inbounds copyto!(src, CartesianIndices((rows, endpadcol)),
                      src, CartesianIndices((rows, startcol)))
    # Top
    @inbounds copyto!(src, CartesianIndices((startpadrow, cols)),
                      src, CartesianIndices((endrow, cols)))
    # Bottom
    @inbounds copyto!(src, CartesianIndices((endpadrow, cols)),
                      src, CartesianIndices((startrow, cols)))

    # Copy four corners
    # Top Left
    @inbounds copyto!(src, CartesianIndices((startpadrow, startpadcol)),
                      src, CartesianIndices((endrow, endcol)))
    # Top Right
    @inbounds copyto!(src, CartesianIndices((startpadrow, endpadcol)),
                      src, CartesianIndices((endrow, startcol)))
    # Botom Left
    @inbounds copyto!(src, CartesianIndices((endpadrow, startpadcol)),
                      src, CartesianIndices((startrow, endcol)))
    # Botom Right
    @inbounds copyto!(src, CartesianIndices((endpadrow, endpadcol)),
                      src, CartesianIndices((startrow, startcol)))

    # Wrap status
    status = sourcestatus(griddata)
    # status[:, 1] .|= status[:, end-1] .| status[:, end-2]
    # status[1, :] .|= status[end-1, :] .| status[end-2, :]
    # status[end-1, :] .|= status[1, :]
    # status[:, end-1] .|= status[:, 1]
    # status[end-2, :] .|= status[1, :]
    # status[:, end-2] .|= status[:, 1]
    # FIXME: Buggy currently, just running all in Wrap mode
    status .= true
    griddata
end

handleoverflow!(griddata::WritableGridData, ::RemoveOverflow) = begin
    r = radius(griddata)
    # Zero edge padding, as it can be written to in writable rules.
    src = parent(source(griddata))
    npadrows, npadcols = size(source(griddata))

    startpadrow = startpadcol = 1:r
    endpadrow = npadrows-r+1:npadrows
    endpadcol = npadcols-r+1:npadcols
    padrows, padcols = axes(src)

    for j = startpadcol, i = padrows
        src[i, j] = zero(eltype(src))
    end
    for j = endpadcol, i = padrows
        src[i, j] = zero(eltype(src))
    end
    for j = padcols, i = startpadrow
        src[i, j] = zero(eltype(src))
    end
    for j = padcols, i = endpadrow
        src[i, j] = zero(eltype(src))
    end
    griddata
end
