
"""
    blockrun(data, context, args...)

Runs simulations over the block grid. Inactive blocks do not run.

This can lead to order of magnitude performance improvments in sparse 
simulations where large areas of the grid are filled with zeros.
"""
function blockrun! end

"""
    celldo!(data, context, args...)

Run rule for particular cell. Applied to active cells inside [`blockrun!`](@ref).
"""
function celldo! end

"""
    maprule!(data, rule)

Apply the rule for each cell in the grid, using optimisations
specific to the supertype of the rule.
"""
function maprule! end

"""
Regular rules just run over the grid blocks
"""
maprule!(data::AbstractSimData, rule::Rule) = blockrun!(data, rule)

blockrun!(data, context, args...) = begin
    nrows, ncols = framesize(data)
    r = radius(data)
    if r > 0
        blocksize = 2r
        status = sourcestatus(data)

        @inbounds for bj in 1:size(status, 2) - 1, bi in 1:size(status, 1) - 1
            status[bi, bj] || continue
            # Convert from padded block to init dimensions
            istart = blocktoind(bi, blocksize) - r
            jstart = blocktoind(bj, blocksize) - r
            # Stop at the init row/column size, not the padding or block multiple
            istop = min(istart + blocksize - 1, nrows)
            jstop = min(jstart + blocksize - 1, ncols)
            # Skip the padding
            istart = max(istart, 1)
            jstart = max(jstart, 1)

            for j in jstart:jstop, i in istart:istop
                ismasked(data, i, j) && continue
                celldo!(data, context, (i, j), args...)
            end
        end
    else
        for j in 1:ncols, i in 1:nrows
            ismasked(data, i, j) && continue
            celldo!(data, context, (i, j), args...)
        end
    end
end

@inline celldo!(data, rule::Rule, I) = begin
    @inbounds state = source(data)[I...]
    @inbounds dest(data)[I...] = applyrule(rule, data, state, I)
    nothing
end


"""
Parital rules must copy the grid to dest as not all cells will be written.
Block status is also updated.
"""
maprule!(data::AbstractSimData, rule::PartialRule) = begin
    data = WritableSimData(data)
    # Update active blocks in the dest array
    @inbounds parent(dest(data)) .= parent(source(data))
    # Run the rule for active blocks
    blockrun!(data, rule)
    updatestatus!(sourcestatus(data), deststatus(data))
end

@inline celldo!(data::WritableSimData, rule::PartialRule, I) = begin
    state = source(data)[I...]
    state == zero(state) && return
    applyrule!(rule, data, state, I)
end

@inline celldo!(data::WritableSimData, rule::PartialNeighborhoodRule, I) = begin
    state = source(data)[I...]
    state == zero(state) && return
    applyrule!(rule, data, state, I)
    zerooverflow!(data, overflow(data), radius(data))
end

# TODO overflow should be wrapped back around?
zerooverflow!(data, overflow::WrapOverflow, r) = nothing
zerooverflow!(data, overflow::RemoveOverflow, r) = begin
    # Zero edge padding, as it can be written to in writable rules.
    src = parent(source(data))
    nrows, ncols = size(src)
    for j = 1:r, i = 1:nrows
        src[i, j] = zero(eltype(src))
    end
    for j = ncols-r+1:ncols, i = 1:nrows
        src[i, j] = zero(eltype(src))
    end
    for j = 1:ncols, i = 1:r
        src[i, j] = zero(eltype(src))
    end
    for j = 1:ncols, i = nrows-r+1:nrows
        src[i, j] = zero(eltype(src))
    end
end

"""
Run the rule for all cells, writing the result to the dest array
The neighborhood is copied to the rules neighborhood buffer array for performance
# TODO test 1d
"""
maprule!(data::SingleSimData{T,2}, rule::Union{NeighborhoodRule,Chain{<:Tuple{NeighborhoodRule,Vararg}}},
         args...) where T = begin
    r = radius(rule)
    # Blocks are cell smaller than the hood, because this works very nicely
    # for looking at only 4 blocks at a time. Larger blocks mean each neighborhood
    # is more likely to be active, smaller means handling more than 2 neighborhoods per block.
    # It would be good to test if this is the sweet spot for performance.
    # It probably isn't for game of life size grids.
    blocksize = 2r
    hoodsize = 2r + 1
    nrows, ncols = framesize(data)
    # We unwrap offset arrays and work with the underlying array
    src, dst = parent(source(data)), parent(dest(data))
    srcstatus, dststatus = sourcestatus(data), deststatus(data)
    # curstatus and newstatus track active status for 4 local blocks
    curstatus = zeros(Bool, 2, 2)
    newstatus = zeros(Bool, 2, 2)
    # Initialise status for the dest. Is this needed?
    # deststatus(data) .= false
    # Get the preallocated neighborhood buffers
    bufs = buffers(data)
    # Center of the buffer for both axes
    bufcenter = r + 1

    # Wrap overflow, or zero padding if not wrapped
    handleoverflow!(data, r)

    # Run the rule row by row. When we move along a row by one cell, we access only
    # a single new column of data the same hight of the nighborhood, and move the existing
    # data in the neighborhood buffer array accross by one column. This saves on reads
    # from the main array, and focusses reads and writes in the small buffer array that
    # should be in fast local memory.

    # Loop down the block COLUMN
    @inbounds for bi = 1:size(srcstatus, 1) - 1
        i = blocktoind(bi, blocksize)
        # Get current block
        rowsinblock = min(blocksize, nrows - blocksize * (bi - 1))
        skippedlastblock = true
        freshbuffer = true

        # Initialise block status for the start of the row
        curstatus = srcstatus[bi:bi+1, 1:2]
        newstatus .= false

        # Loop along the block ROW. This is faster because we are reading
        # 1 column from the main array for 2 blocks at each step, not actually along the row.
        for bj = 1:size(srcstatus, 2) - 1
            newstatus[1, 1] = newstatus[1, 2]
            newstatus[2, 1] = newstatus[2, 2]
            newstatus[1, 2] = false
            newstatus[2, 2] = false

            # Copy the status accross
            curstatus[:, 1] .= curstatus[:, 2]
            # Get a new column of status from srcstatus
            curstatus[:, 2] .= srcstatus[bi:bi+1, bj + 1]

            jstart = blocktoind(bj, blocksize)
            jstop = min(jstart + blocksize - 1, ncols)

            # Use this block if it or its neighbors are active
            if !any(curstatus)
                # Skip this block
                skippedlastblock = true
                continue
            end

            # Reinitialise neighborhood buffers if we have skipped a section of the array
            if skippedlastblock
                for y = 1:hoodsize
                    for b in 1:rowsinblock
                        for x = 1:hoodsize
                            val = src[i + b + x - 2, jstart + y - 1]
                            bufs[b][x, y] = val
                        end
                    end
                end
                skippedlastblock = false
                freshbuffer = true
            end

            # Loop over the grid COLUMNS inside the block
            for j in jstart:jstop
                # Which block column are we in
                curblockj = j - jstart < r ? 1 : 2
                if freshbuffer
                    freshbuffer = false
                else
                    # Move the neighborhood buffers accross one column
                    for b in 1:rowsinblock
                        buf = bufs[b]
                        # copyto! uses linear indexing, so 2d dims are transformed manually
                        copyto!(buf, 1, buf, hoodsize + 1, (hoodsize - 1) * hoodsize)
                    end
                    # Copy a new column to each neighborhood buffer
                    for b in 1:rowsinblock
                        buf = bufs[b]
                        for x in 1:hoodsize
                            buf[x, hoodsize] = src[i + b + x - 2, j + 2r]
                        end
                    end
                end

                # Loop over the grid ROWS inside the block
                for b in 1:rowsinblock
                    ii = i + b - 1
                    ismasked(data, ii, j) && continue
                    # Which block row are we in
                    curblocki = b <= r ? 1 : 2
                    # Run the rule using buffer b
                    buf = bufs[b]
                    state = buf[bufcenter, bufcenter]
                    # @assert state == src[ii + r, j + r]
                    newstate = applyrule(rule, data, state, (ii, j), buf)
                    # Update the status for the block
                    newstatus[curblocki, curblockj] |= newstate != zero(newstate)
                    # Write the new state to the dest array
                    dst[ii + r, j + r] = newstate
                end

                # Combine blocks with the previous rows / cols
                dststatus[bi, bj] |= newstatus[1, 1]
                dststatus[bi, bj+1] |= newstatus[1, 2]
                dststatus[bi+1, bj] |= newstatus[2, 1]
                # Start new block fresh to remove old status
                dststatus[bi+1, bj+1] = newstatus[2, 2]
            end
        end
    end
    updatestatus!(sourcestatus(data), deststatus(data))
end

"""
Wrap overflow where required. This optimisation allows us to ignore
bounds checks on neighborhoods and still use a wraparound grid.
"""
handleoverflow!(data::SingleSimData, r::Integer) = handleoverflow!(data, overflow(data), r)
handleoverflow!(data::SingleSimData{T,1}, overflow::WrapOverflow, r::Integer) where T = begin
    # Copy two sides
    @inbounds copyto!(source, 1-r:0, source, nrows+1-r:nrows)
    @inbounds copyto!(source, nrows+1:nrows+r, source, 1:r)
end
handleoverflow!(data::SingleSimData{T,2}, overflow::WrapOverflow, r::Integer) where T = begin
    # TODO optimise this. Its mostly a placeholder so wrapping still works in GOL tests.
    src = source(data)
    nrows, ncols = framesize(data)
    # Left
    @inbounds copyto!(src, CartesianIndices((1:nrows, 1-r:0)),
                      src, CartesianIndices((1:nrows, ncols+1-r:ncols)))
    # Right
    @inbounds copyto!(src, CartesianIndices((1:nrows, ncols+1:ncols+r)),
                      src, CartesianIndices((1:nrows, 1:r)))
    # Top
    @inbounds copyto!(src, CartesianIndices((1-r:0, 1:ncols)),
                      src, CartesianIndices((ncols+1-r:ncols, 1:ncols)))
    # Bottom
    @inbounds copyto!(src, CartesianIndices((ncols+1:ncols+r, 1:ncols)),
                      src, CartesianIndices((1:r, 1:ncols)))

    # Copy four corners
    @inbounds copyto!(src, CartesianIndices((1-r:0, 1-r:0)),
                      src, CartesianIndices((nrows+1-r:nrows, ncols+1-r:ncols)))
    @inbounds copyto!(src, CartesianIndices((1-r:0, ncols+1:ncols+r)),
                      src, CartesianIndices((nrows+1-r:nrows, 1:r)))
    @inbounds copyto!(src, CartesianIndices((nrows+1:nrows+r, ncols+1:ncols+r)),
                      src, CartesianIndices((1:r, 1:r)))
    @inbounds copyto!(src, CartesianIndices((nrows+1:nrows+r, 1-r:0)),
                      src, CartesianIndices((1:r, ncols+1-r:ncols)))

    # Wrap status
    status = sourcestatus(data)
    # status[:, 1] .|= status[:, end-1] .| status[:, end-2]
    # status[1, :] .|= status[end-1, :] .| status[end-2, :]
    # status[end-1, :] .|= status[1, :]
    # status[:, end-1] .|= status[:, 1]
    # status[end-2, :] .|= status[1, :]
    # status[:, end-2] .|= status[:, 1]
    # FIXME: Buggy currently, just running all in Wrap mode
    status .= true
end
handleoverflow!(data, overflow::RemoveOverflow, r) = nothing


combinestatus(x::Number, y::Number) = x + y
combinestatus(x::Integer, y::Integer) = x | y

updatestatus!(copyto, copyfrom) = nothing
updatestatus!(copyto::AbstractArray, copyfrom::AbstractArray) =
    @inbounds copyto .= copyfrom
