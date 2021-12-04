
# Map a rule over the grids it reads from, updating the grids it writes to.
# This is broken into setup methods and application methods,
# for dispatch and to introduce a function barrier for type stability.

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
        optmap(data, proc, opt, ruletype, rkeys) do I 
            cell_kernel!(data, ruletype, rule, rkeys, wkeys, I...)
        end
    end
end
function maprule!(
    data::AbstractSimData, proc::CPU, opt, ruletype::Val{<:NeighborhoodRule}, 
    rule, rkeys, args...
)
    hoodgrid = _firstgrid(data, rkeys)
    _mapneighborhoodrule!(data, hoodgrid, proc, opt, ruletype, rule, rkeys, args...)
end

# 2 dimensional (with procesess and optimisations)
function _mapneighborhoodrule!(
    data, hoodgrid::GridData{<:Tuple{Y,X},R}, proc, opt, ruletype, rule, rkeys, wkeys 
) where {Y,X,R}
    let data=data, hoodgrid=hoodgrid, proc=proc, opt=opt, ruletyp=ruletype, rule=rule, rkeys=rkeys, wkeys=wkeys
        B = 2R
        # UNSAFE: we must avoid sharing status blocks, it could cause race conditions 
        # when setting status from different threads. So we split the grid in 2 interleaved
        # sets of rows, so that we never run adjacent rows simultaneously
        procmap(proc, 1:2:_indtoblock(Y, B)) do bi
            row_kernel!(data, hoodgrid, proc, opt, ruletype, rule, rkeys, wkeys, bi)
        end
        procmap(proc, 2:2:_indtoblock(Y, B)) do bi
            row_kernel!(data, hoodgrid, proc, opt, ruletype, rule, rkeys, wkeys, bi)
        end
    end
    return nothing
end
# Arbitrary dimensions, no proc/opt selection
function _mapneighborhoodrule!(
    data, hoodgrid::GridData{<:Tuple,R}, proc, opt, ruletype, rule, rkeys, wkeys 
) where {R}
    for I in CartesianIndices(hoodgrid) 
        tI = Tuple(I)
        # Loop over the COLUMN of buffers covering the block
        neighborhood_kernel!(data, hoodgrid, ruletype, rule, rkeys, wkeys, tI...)
    end
    return nothing
end


### Rules that don't need a neighborhood buffer ####################

# optmap
# Map kernel over the grid, specialising on PerformanceOpt.

# Run kernel over the whole grid, cell by cell:
function optmap(
    f, simdata::AbstractSimData{S}, proc, ::NoOpt, ::Val{<:Rule}, rkeys
) where S<:Tuple{Y,X} where {Y,X}
    procmap(proc, 1:X) do j
        for i in 1:Y
            f((i, j)) # Run rule for each row in column j
        end
    end
end
# Use @simd for CellRule
function optmap(
    f, simdata::AbstractSimData{S}, proc, ::NoOpt, ::Val{<:CellRule}, rkeys
) where S<:Tuple{Y,X} where {Y,X}
    procmap(proc, 1:X) do j
        @simd for i in 1:Y
            f((i, j)) # Run rule for each row in column j
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
@inline function cell_kernel!(simdata, ruletype::Val{<:Rule}, rule, rkeys, wkeys, I...)
    readval = _readcell(simdata, rkeys, I...)
    writeval = applyrule(simdata, rule, readval, I)
    _writecell!(simdata, ruletype, wkeys, writeval, I...)
    writeval
end
@inline function cell_kernel!(simdata, ::Val{<:SetRule}, rule, rkeys, wkeys, I...)
    readval = _readcell(simdata, rkeys, I...)
    applyrule!(simdata, rule, readval, I)
    nothing
end

# neighborhood_kernel!
# Runs a rule for the current cell/neighborhood, when there is no
# row-based optimisation
@inline function neighborhood_kernel!(
    data, hoodgrid, ruletype::Val{<:NeighborhoodRule}, rule, rkeys, wkeys, I...
)
    src = parent(source(hoodgrid))
    buf = _getwindow(src, neighborhood(rule), I...)
    bufrule = _setbuffer(rule, buf)
    cell_kernel!(data, ruletype, bufrule, rkeys, wkeys, I...)
end

# row_kernel!
# Run a NeighborhoodRule rule row by row. When we move along a row by one cell, we 
# access only a single new column of data with the height of 4R, and move the existing
# data in the neighborhood buffers array across by one column. This saves on reads
# from the main array.
function row_kernel!(
    simdata::AbstractSimData, grid::GridData{<:Tuple{Y,X},R}, proc, opt::NoOpt,
    ruletype::Val, rule::Rule, rkeys, wkeys, bi
) where {Y,X,R}
    B = 2R
    i = _blocktoind(bi, B)
    i > Y && return nothing
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
    return nothing
end

#### Utils

_to_readonly(data::Tuple) = map(ReadableGridData, data)
_to_readonly(data::WritableGridData) = ReadableGridData(data)

# _maybemask!
# mask the source grid
_maybemask!(wgrids::Union{Tuple,NamedTuple}) = map(_maybemask!, wgrids)
_maybemask!(wgrid::GridData) = _maybemask!(wgrid, proc(wgrid), mask(wgrid))
_maybemask!(wgrid::GridData, proc, mask::Nothing) = nothing
function _maybemask!(
    wgrid::GridData{<:Tuple{Y,X}}, proc::CPU, mask::AbstractArray
) where {Y,X}
    procmap(proc, 1:X) do j
        @simd for i in 1:Y
            source(wgrid)[i, j] *= mask[i, j]
        end
    end
end
function _maybemask!(
    wgrid::GridData{<:Tuple{Y,X}}, proc, mask::AbstractArray
) where {Y,X}
    sourceview(wgrid) .*= mask
end

# _cleardest!
# only needed with optimisations
_cleardest!(grid) = _cleardest!(grid, opt(grid))
_cleardest!(grid, opt) = nothing
