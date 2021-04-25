
# Map a rule over the grids it reads from and updating the grids it writes to.
# This is broken into a setup method and an application method
# to introduce a function barrier, for type stability.

maprule!(data::AbstractSimData, rule) = maprule!(data, Val{ruletype(rule)}(), rule)
function maprule!(data::AbstractSimData, ruletype::Val{<:CellRule}, rule)
    rkeys, _ = _getreadgrids(rule, data)
    wkeys, _ = _getwritegrids(rule, data)
    maprule!(RuleData(data), ruletype, rule, rkeys, wkeys)
    return data
end
function maprule!(data::AbstractSimData, ruletype::Val{<:NeighborhoodRule}, rule)
    rkeys, rgrids = _getreadgrids(rule, data)
    wkeys, wgrids = _getwritegrids(rule, data)
    # NeighborhoodRule will read from surrounding cells
    # so may incorporate cells from the masked area
    _maybemask!(rgrids)
    # Copy or zero out boundary where needed
    _updateboundary!(rgrids)
    _cleardest!(data[neighborhoodkey(rule)])
    maprule!(RuleData(data), ruletype, rule, rkeys, wkeys)
    # Swap the dest/source of grids that were written to
    # and combine the written grids with the original simdata
    return _replacegrids(data, wkeys, _swapsource(_to_readonly(wgrids)))
end
function maprule!(data::AbstractSimData, ruletype::Val{<:SetRule}, rule)
    rkeys, _ = _getreadgrids(rule, data)
    wkeys, wgrids = _getwritegrids(rule, data)
    map(_astuple(wkeys, wgrids)) do g
        copyto!(parent(dest(g)), parent(source(g)))
    end
    ruledata = RuleData(_combinegrids(data, wkeys, wgrids))
    maprule!(ruledata, ruletype, rule, rkeys, wkeys)
    return _replacegrids(data, wkeys, _swapsource(_to_readonly(wgrids)))
end
function maprule!(data::AbstractSimData, ruletype::Val{<:SetGridRule}, rule)
    rkeys, rgrids = _getreadgrids(rule, data)
    wkeys, wgrids = _getwritegrids(rule, data)
    _maybemask!(rgrids) # TODO... mask wgrids?
    ruledata = RuleData(_combinegrids(data, wkeys, wgrids))
    # Run the rule
    applyrule!(ruledata, rule)
    return data
end
function maprule!(data::AbstractSimData, ruletype::Val, rule, rkeys, wkeys)
    maprule!(data, proc(data), opt(data), ruletype, rule, rkeys, wkeys)
end

function maprule!(data::AbstractSimData, proc::CPU, opt, ruletype::Val, rule, rkeys, wkeys)
    let data=data, proc=proc, opt=opt, rule=rule,
        rkeys=rkeys, wkeys=wkeys, ruletype=ruletype
        optmap(data, proc, opt, ruletype, rkeys) do i, j
            cell_kernel!(data, ruletype, rule, rkeys, wkeys, i, j)
        end
    end
end
function maprule!(
    data::AbstractSimData{Y,X}, proc::CPU, opt, ruletype::Val{<:NeighborhoodRule}, 
    rule, args...
) where {Y,X}
    hoodgrid = data[neighborhoodkey(rule)]
    _mapneighborhoodgrid!(data, hoodgrid, proc, opt, ruletype, rule, args...)
end

function _mapneighborhoodgrid!(
    data, hoodgrid::GridData{Y,X,R}, proc, opt, ruletype, args...
) where {Y,X,R}
    let data=data, proc=proc, opt=opt, ruletype=ruletype, args=args
        B = 2R
        # UNSAFE: we must avoid sharing status blocks, it could cause race conditions 
        # when setting status from different threads. So we split the grid in 2 interleaved
        # sets of rows, so that we never run adjacent rows simultaneously
        procmap(proc, 1:2:_indtoblock(Y, B)) do bi
            row_kernel!(data, hoodgrid, proc, opt, ruletype, args..., bi)
        end
        procmap(proc, 2:2:_indtoblock(Y, B)) do bi
            if bi <=_indtoblock(Y, B)
                row_kernel!(data, hoodgrid, proc, opt, ruletype, args..., bi)
            end
        end
    end
    return nothing
end


### Rules that don't need a neighborhood buffer ####################

# optmap
# Map kernel over the grid, specialising on PerformanceOpt.
#
# Run kernels with SparseOpt, block by block:
function optmap(
    f, simdata::AbstractSimData{Y,X}, proc, ::SparseOpt, ruletype::Val{<:Rule}, rkeys
) where {Y,X}
    # Only use SparseOpt for single-grid rules with grid radii > 0
    grid = _firstgrid(simdata, rkeys)
    R = radius(grid)
    if R == 0
        optmap(f, simdata, proc, NoOpt(), ruletype, rkeys)
        return nothing
    end
    B = 2R
    status = sourcestatus(grid)
    let f=f, proc=proc, status=status
        procmap(proc, 1:_indtoblock(X, B)) do bj
            for  bi in 1:_indtoblock(Y, B)
                status[bi, bj] || continue
                # Convert from padded block to init dimensions
                istart, jstart = _blocktoind(bi, B) - R, _blocktoind(bj, B) - R
                # Stop at the init row/column size, not the padding or block multiple
                istop, jstop = min(istart + B - 1, Y), min(jstart + B - 1, X)
                # Skip the padding
                istart, jstart  = max(istart, 1), max(jstart, 1)
                for j in jstart:jstop 
                    @simd for i in istart:istop
                        f(i, j)
                    end
                end
            end
        end
    end
    return nothing
end
# Run kernel over the whole grid, cell by cell:
function optmap(
    f, simdata::AbstractSimData{Y,X}, proc, ::NoOpt, ::Val{<:Rule}, rkeys
) where {Y,X}
    procmap(proc, 1:X) do j
        for i in 1:Y
            f(i, j) # Run rule for each row in column j
        end
    end
end
function optmap(
    f, simdata::AbstractSimData{Y,X}, proc, ::NoOpt, ::Val{<:CellRule}, rkeys
) where {Y,X}
    procmap(proc, 1:X) do j
        @simd for i in 1:Y
            f(i, j) # Run rule for each row in column j
        end
    end
end

# procmap
# Map kernel over the grid, specialising on Processor
# Looping over cells or blocks on CPU
@inline procmap(f, proc::SingleCPU, range) =
    for n in range
        f(n) # Run rule over each column
    end
@inline procmap(f, proc::ThreadedCPU, range) =
    Threads.@threads for n in range
        f(n) # Run rule over each column, threaded
    end

# cell_kernel!
# runs a rule for the current cell
@inline function cell_kernel!(simdata, ruletype::Val{<:Rule}, rule, rkeys, wkeys, i, j)
    readval = _readcell(simdata, rkeys, i, j)
    writeval = applyrule(simdata, rule, readval, (i, j))
    _writecell!(simdata, ruletype, wkeys, writeval, i, j)
    writeval
end
@inline function cell_kernel!(simdata, ::Val{<:SetRule}, rule, rkeys, wkeys, i, j)
    readval = _readcell(simdata, rkeys, i, j)
    applyrule!(simdata, rule, readval, (i, j))
    nothing
end

# row_kernel!
# Run a NeighborhoodRule rule row by row. When we move along a row by one cell, we 
# access only a single new column of data with the height of 4R, and move the existing
# data in the neighborhood buffers array across by one column. This saves on reads
# from the main array.
function row_kernel!(
    simdata::AbstractSimData, grid::GridData{Y,X,R}, proc, opt::NoOpt,
    ruletype::Val, rule::Rule, rkeys, wkeys, bi
) where {Y,X,R}
    B = 2R
    i = _blocktoind(bi, B)
    # Loop along the block ROW.
    src = parent(source(grid))
    buffers = _initialise_buffers(src, Val{R}(), i, 1)
    blocklen = min(Y, i + B - 1) - i + 1
    for j = 1:X
        buffers = _update_buffers(buffers, src, Val{R}(), i, j)
        # Loop over the COLUMN of buffers covering the block
        for b in 1:blocklen
            @inbounds bufrule = _setbuffer(rule, buffers[b])
            cell_kernel!(simdata, ruletype, bufrule, rkeys, wkeys, i + b - 1, j)
        end
    end
end
function row_kernel!(
    simdata::AbstractSimData, grid::GridData{Y,X,R}, proc, opt::SparseOpt,
    ruletype::Val, rule::Rule, rkeys, wkeys, bi
) where {Y,X,R}
    B = 2R
    S = 2R + 1
    nblockcols = _indtoblock(X, B)
    src = parent(source(grid))
    srcstatus, dststatus = sourcestatus(grid), deststatus(grid)

    # Blocks ignore padding! the first block contains padding.
    i = _blocktoind(bi, B)
    # Get current bloc
    skippedlastblock = true

    # Initialise block status for the start of the row
    # The first column always runs, it's buggy otherwise.
    @inbounds bs11, bs12 = true, true
    @inbounds bs21, bs22 = true, true
    # New block status
    newbs12 = false
    newbs22 = false
    buffers = _initialise_buffers(src, Val{R}(), i, 1)
    for bj = 1:nblockcols
        # Shuffle current buffer status
        bs11, bs21 = bs12, bs22
        @inbounds bs12, bs22 = srcstatus[bi, bj + 1], srcstatus[bi + 1, bj + 1]
        # Skip this block if it and the neighboring blocks are inactive
        if !(bs11 | bs12 | bs21 | bs22)
            skippedlastblock = true
            # Run the rest of the chain if it exists and more than 1 grid is used
            if rule isa Chain && length(rule) > 1 && length(rkeys) > 1
                # Loop over the grid COLUMNS inside the block
                jstart = _blocktoind(bj, B)
                jstop = min(jstart + B - 1, X)
                for j in jstart:jstop
                    # Loop over the grid ROWS inside the block
                    blocklen = min(Y, i + B - 1) - i + 1
                    for b in 1:blocklen
                        cell_kernel!(simdata, ruletype, rule, rkeys, wkeys, i + b - 1, j)
                    end
                end
            end
            continue
        end
        # Define area to loop over with the block.
        # It's variable because the last block may be partial
        jstart = _blocktoind(bj, B)
        jstop = min(jstart + B - 1, X)

        # Reinitialise neighborhood buffers if we have skipped a section of the array
        if skippedlastblock
            buffers = _initialise_buffers(src, Val{R}(), i, jstart)
            skippedlastblock = false
        end
        # Shuffle new buffer status
        newbs11 = newbs12
        newbs21 = newbs22
        newbs12 = newbs22 = false

        # Loop over the grid COLUMNS inside the block
        for j in jstart:jstop
            # Update buffers unless feshly populated
            buffers = _update_buffers(buffers, src, Val{R}(), i, j)
            # Which block column are we in, 1 or 2
            curblockj = (j - jstart) ÷ R + 1
            # Loop over the COLUMN of buffers covering the block
            blocklen = min(Y, i + B - 1) - i + 1
            for b in 1:blocklen
                # Set rule buffer
                bufrule = _setbuffer(rule, buffers[b])
                # Run the rule kernel for the cell
                writeval = cell_kernel!(simdata, ruletype, bufrule, rkeys, wkeys, i + b - 1, j)
                # Update the status for the current block
                cs = _cellstatus(opt, wkeys, writeval)
                curblocki = R == 1 ? b : (b - 1) ÷ R + 1
                if curblocki == 1
                    curblockj == 1 ? (newbs11 |= cs) : (newbs12 |= cs)
                else
                    curblockj == 1 ? (newbs21 |= cs) : (newbs22 |= cs)
                end
            end

            # Combine new block status with deststatus array
            @inbounds dststatus[bi, bj] |= newbs11
            @inbounds dststatus[bi+1, bj] |= newbs21
            @inbounds dststatus[bi, bj+1] |= newbs12
            @inbounds dststatus[bi+1, bj+1] |= newbs22
        end
    end
    return nothing
end


#### Utils

@inline _cellstatus(opt::SparseOpt, wkeys::Tuple, writeval) = _isactive(writeval[1], opt)
@inline _cellstatus(opt::SparseOpt, wkeys, writeval) = _isactive(writeval, opt)

@inline _firstgrid(simdata, ::Val{K}) where K = simdata[K]
@inline _firstgrid(simdata, ::Tuple{Val{K},Vararg}) where K = simdata[K]

_to_readonly(data::Tuple) = map(ReadableGridData, data)
_to_readonly(data::WritableGridData) = ReadableGridData(data)

# _maybemask!
# mask the source grid
_maybemask!(wgrids::Union{Tuple,NamedTuple}) = map(_maybemask!, wgrids)
_maybemask!(wgrid::GridData) = _maybemask!(wgrid, proc(wgrid), mask(wgrid))
_maybemask!(wgrid::GridData, proc, mask::Nothing) = nothing
function _maybemask!(wgrid::GridData{Y,X}, proc::CPU, mask::AbstractArray) where {Y,X}
    procmap(proc, 1:X) do j
        @simd for i in 1:Y
            source(wgrid)[i, j] *= mask[i, j]
        end
    end
end
function _maybemask!(wgrid::GridData{Y,X}, proc, mask::AbstractArray) where {Y,X}
    sourceview(wgrid) .*= mask
end

# _cleardest!
# Clear the destination grid and its status for SparseOpt.
# NoOpt writes to every cell, so this is not required
_cleardest!(grid) = _cleardest!(grid, opt(grid))
function _cleardest!(grid, opt::SparseOpt)
    dest(grid) .= source(grid)
    deststatus(grid) .= false
end
_cleardest!(grid, opt) = nothing
