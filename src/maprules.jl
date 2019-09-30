"""
Apply the rule for each cell in the grid, using optimisations
allowed for the supertype of the rule.
"""
maprule!(data::AbstractSimData, rule::AbstractRule) = blockrun!(data, rule)

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
                blockdo!(data, context, (i, j), args...)
            end
        end
    else
        for j in 1:ncols, i in 1:nrows
            ismasked(data, i, j) && continue
            blockdo!(data, context, (i, j), args...)
        end
    end
end

@inline blockdo!(data, rule::AbstractRule, I) = begin
    @inbounds state = source(data)[I...]
    @inbounds dest(data)[I...] = applyrule(rule, data, state, I)
    nothing
end


maprule!(data::AbstractSimData, rule::AbstractPartialRule) = begin
    data = WritableSimData(data)
    # Update active blocks in the dest array
    @inbounds parent(dest(data)) .= parent(source(data))
    # Run the rule for active blocks
    blockrun!(data, rule)
    updatestatus!(sourcestatus(data), deststatus(data))
end

@inline blockdo!(data::WritableSimData, rule::AbstractPartialRule, I) = begin
    state = source(data)[I...]
    state == zero(state) && return
    applyrule!(rule, data, state, I)
end


struct UpdateDest end
@inline blockdo!(data::WritableSimData, ::UpdateDest, I) = begin
    out = source(data)[I...]
    dest(data)[I...] = out
end

"""
Run the rule for all cells, writing the result to the dest array
The neighborhood is copied to the rules neighborhood buffer array for performance
# TODO test 1d
"""
# maprule!(data::AbstractSimData{T,1}, rule::Union{AbstractNeighborhoodRule, Tuple{AbstractNeighborhoodRule,Vararg}},
#           args...)  where T = begin
#     # The rule provides the neighborhood buffer
#     r = radius(data)
#     sze = hoodsize(r)
#     buf = similar(init(data), sze, sze)
#     src, dst = source(data), dest(data)
#     nrows = framesize(data)
#     handleoverflow!(data, r)
#     # Setup buffer array between rows
#     # Ignore the first column, it wil be copied over in the main loop
#     for i in 2:sze
#         @inbounds buf[i] = src[i-1-r]
#     end
#     # Run rule for a row
#     @inbounds for i in 1:nrows
#         copyto!(buf, 1, buf, 2)
#         buf[sze] = src[i+r]
#         state = buf[r+1]
#         dst[i] = applyrule(rule, data, state, (i,))
#     end
# end

maprule!(data::AbstractSimData{T,2}, rule::Union{AbstractNeighborhoodRule,Chain{<:Tuple{AbstractNeighborhoodRule,Vararg}}}, 
         args...) where T = begin
    # The rule provides the neighborhood buffer
    r = radius(rule)
    blocksize = 2r
    hoodsize = 2r + 1
    src, dst = parent(source(data)), parent(dest(data))
    srcstatus, dststatus = sourcestatus(data), deststatus(data)
    sumstatus = localstatus(data)
    bufs = buffers(data)
    nrows, ncols = framesize(data)

    handleoverflow!(data, r)
    # Use the simplest number type at or above eltype(src) that can be added
    center = r + 1
    deststatus(data) .= false

    # Run the rule row by row. When we move along a row by one cell, we access only
    # a single new column of data same the hight of the nighborhood, and move the existing
    # data in the neighborhood buffer array accross by one column. This saves on reads
    # from the main array, and focusses reads and writes in the small buffer array that
    # should be in fast local memory.
    @inbounds for bi = 1:size(srcstatus, 1) - 1
        sumstatus .= false
        i = blocktoind(bi, blocksize)
        rowsinblock = min(blocksize, nrows - blocksize * (bi - 1))
        skippedlastblock = true
        freshbuffer = true

        b11, b12 = srcstatus[bi,     1], srcstatus[bi,     2]
        b21, b22 = srcstatus[bi + 1, 1], srcstatus[bi + 1, 2]
        sumstatus[1, 2] = false
        sumstatus[2, 2] = false
        for bj = 1:size(srcstatus, 2) - 1
            sumstatus[1, 1] = sumstatus[1, 2]
            sumstatus[2, 1] = sumstatus[2, 2]
            sumstatus[1, 2] = false
            sumstatus[2, 2] = false

            b11, b21 = b12, b22
            b12, b22 = srcstatus[bi, bj + 1], srcstatus[bi + 1, bj + 1]

            jstart = blocktoind(bj, blocksize)
            jstop = min(jstart + blocksize - 1, ncols)

            # Use this block unless it or its neighbors are active
            if !(b11 | b12 | b21 | b22)
                # Skip this block
                skippedlastblock = true
                continue
            end

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

            for j in jstart:jstop
                centerbj = j - jstart < r ? 1 : 2
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
                for b in 1:rowsinblock
                    ii = i + b - 1
                    ismasked(data, ii, j) && continue

                    centerbi = b <= r ? 1 : 2
                    # Run the rule using buffer b
                    buf = bufs[b]
                    state = buf[center, center]
                    # @assert state == src[ii + r, j + r]
                    newstate = applyrule(rule, data, state, (ii, j), buf)
                    sumstatus[centerbi, centerbj] |= newstate != zero(newstate)
                    dst[ii + r, j + r] = newstate
                end
                # Combine blocks with the previous rows / cols
                # TODO only write the first column
                dststatus[bi, bj] |= sumstatus[1, 1]
                dststatus[bi, bj+1] |= sumstatus[1, 2]
                dststatus[bi+1, bj] |= sumstatus[2, 1]
                # Start new block fresh to remove old status
                dststatus[bi+1, bj+1] = sumstatus[2, 2]
            end
        end
    end
    updatestatus!(sourcestatus(data), deststatus(data))
end

"""
Wrap overflow where required. This optimisation allows us to ignore
bounds checks on neighborhoods and still use a wraparound grid.
"""
handleoverflow!(data::AbstractSimData, r::Integer) = handleoverflow!(data, overflow(data), r)
handleoverflow!(data::AbstractSimData{T,1}, overflow::WrapOverflow, r::Integer) where T = begin
    # Copy two sides
    @inbounds copyto!(source, 1-r:0, source, nrows+1-r:nrows)
    @inbounds copyto!(source, nrows+1:nrows+r, source, 1:r)
end
handleoverflow!(data::AbstractSimData{T,2}, overflow::WrapOverflow, r::Integer) where T = begin
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

updatestatus!(copyto::AbstractArray, copyfrom::AbstractArray) = @inbounds copyto .= copyfrom
updatestatus!(copyto, copyfrom) = nothing


"""
    applyrule(rules::Chain, data, state, (i, j))

Chained rules. If a `Chain` of rules is passed to applyrule, run them sequentially for each 
cell.  This can have much beter performance as no writes occur between rules, and they are
essentially compiled together into compound rules. This gives correct results only for
AbstractCellRule, or for a single AbstractNeighborhoodRule followed by AbstractCellRule.
"""
@inline applyrule(rules::Chain{<:Tuple{<:AbstractNeighborhoodRule,Vararg}}, data, state, index, buf) = begin
    state = applyrule(rules[1], data, state, index, buf)
    applyrule(tail(rules), data, state, index)
end
@inline applyrule(rules::Chain, data, state, index) = begin
    state == zero(state) && return state
    newstate = applyrule(rules[1], data, state, index)
    applyrule(tail(rules), data, newstate, index)
end
@inline applyrule(rules::Chain{Tuple{}}, data, state, index) = state
