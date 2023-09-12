
# Map a rule over the grids it reads from, updating the grids it writes to.
#
# This is split into setup methods and application methods,
# for dispatch and to introduce a function barrier for type stability.

# We dispatch on `ruletype(rule)` to allow wrapper rules
# to pass through the type of the wrapped rule.
# Putting the type in `Val` is best for performance.
maprule!(data::AbstractSimData, rule) =
    maprule!(data, _val_ruletype(rule), rule)
# Cellrule
function maprule!(data::AbstractSimData, ruletype::Val{<:CellRule}, rule)
    rkeys, _ = _getreadgrids(rule, data)
    wkeys, _ = _getwritegrids(WriteMode, rule, data)
    maprule!(RuleData(data), ruletype, rule, rkeys, wkeys)
    return data
end
# NeighborhoodRule
function maprule!(data::AbstractSimData, ruletype::Val{<:NeighborhoodRule}, rule)
    rkeys, rgrids = _getreadgrids(rule, data)
    wkeys, wgrids = _getwritegrids(SwitchMode, rule, data)
    # Copy or zero out boundary where needed
    _update_boundary!(rgrids)
    _cleardest!(data[stencilkey(rule)])
    maprule!(RuleData(data), ruletype, rule, rkeys, wkeys)
    _maybemask!(wgrids)
    # Swap the dest/source of grids that were written to
    # and combine the written grids with the original simdata
    new_rgrids = _to_readonly(switch(wgrids))
    d =  _replacegrids(data, wkeys, new_rgrids)
    return d
end
# SetRule
function maprule!(data::AbstractSimData, ruletype::Val{<:SetRule}, rule)
    rkeys, _ = _getreadgrids(rule, data)
    wkeys, wgrids = _getwritegrids(SwitchMode, rule, data)
    map(_astuple(wkeys, wgrids)) do g
        copyto!(parent(dest(g)), parent(source(g)))
    end
    ruledata = RuleData(_combinegrids(data, wkeys, wgrids))
    maprule!(ruledata, ruletype, rule, rkeys, wkeys)
    _maybemask!(wgrids)
    return _replacegrids(data, wkeys, _to_readonly(switch(wgrids)))
end
# SetGridRule (not actually broadcast - it applies to the whole grid manually)
function maprule!(data::AbstractSimData, ruletype::Val{<:SetGridRule}, rule)
    rkeys, rgrids = _getreadgrids(rule, data)
    wkeys, wgrids = _getwritegrids(WriteMode, rule, data)
    ruledata = RuleData(_combinegrids(data, wkeys, wgrids))
    # Run the rule
    applyrule!(ruledata, rule)
    return data
end
# Expand method arguments for dispatch on processor and optimisation
function maprule!(data::AbstractSimData, ruletype::Val, rule, rkeys, wkeys)
    maprule!(data, proc(data), opt(data), ruletype, rule, rkeys, wkeys)
end

_update_boundary!(gs::Union{NamedTuple,Tuple}) = map(_update_boundary!, gs)
_update_boundary!(g::GridData) = update_boundary!(g)

# Most Rules
# 2 dimensional, with processor selection and optimisations in `broadcast_with_optimisation`
# function maprule!(data::AbstractSimData{<:Tuple{Y,X}}, proc::CPU, opt, ruletype::Val, rule, rkeys, wkeys) where {Y,X}
#     let data=data, proc=proc, opt=opt, rule=rule,
#         rkeys=rkeys, wkeys=wkeys, ruletype=ruletype
#         broadcast_with_optimisation(data, proc, opt, ruletype, rkeys) do I 
#             cell_kernel!(data, ruletype, rule, rkeys, wkeys, I...)
#         end
#     end
# end
# Arbitrary dimensions, no processor or optimisation selection beyond CPU/GPU
function maprule!(data::AbstractSimData, proc::CPU, opt, ruletype::Val, rule, rkeys, wkeys)
    let data=data, proc=proc, opt=opt, rule=rule,
        rkeys=rkeys, wkeys=wkeys, ruletype=ruletype
        for I in CartesianIndices(first(grids(data)))
            cell_kernel!(data, ruletype, rule, rkeys, wkeys, Tuple(I)...)
        end
    end
end

# Neighborhood rules
# 2 dimensional, with processor selection and optimisations
# function maprule!(
#     data::AbstractSimData{<:Tuple{Y,X}}, proc::CPU, opt, ruletype::Val{<:NeighborhoodRule}, 
#     rule, rkeys, wkeys
# ) where {Y,X}
#     hoodgrid = _firstgrid(data, rkeys)
#     let data=data, hoodgrid=hoodgrid, proc=proc, opt=opt, ruletyp=ruletype, rule=rule, rkeys=rkeys, wkeys=wkeys
#         B = 2radius(hoodgrid)
#         # UNSAFE: we must avoid sharing status blocks, it could cause race conditions 
#         # when setting status from different threads. So we split the grid in 2 interleaved
#         # sets of rows, so that we never run adjacent rows simultaneously
#         broacast_on_processor(proc, 1:2:_indtoblock(Y, B)) do bi
#             row_kernel!(data, hoodgrid, proc, opt, ruletype, rule, rkeys, wkeys, bi)
#         end
#         broacast_on_processor(proc, 2:2:_indtoblock(Y, B)) do bi
#             row_kernel!(data, hoodgrid, proc, opt, ruletype, rule, rkeys, wkeys, bi)
#         end
#     end
#     return nothing
# end
# Arbitrary dimensions, no processor or optimisation selection beyond CPU/GPU
function maprule!(
    data::AbstractSimData, proc::CPU, opt, ruletype::Val{<:NeighborhoodRule}, rule, rkeys, wkeys
)
    hoodgrid = _firstgrid(data, rkeys)
    for I in CartesianIndices(hoodgrid) 
        stencil_kernel!(data, hoodgrid, ruletype, rule, rkeys, wkeys, Tuple(I)...)
    end
    return nothing
end


### Rules that don't need a stencil window ####################

# broadcast_with_optimisation
# Map kernel over the grid, specialising on PerformanceOpt.

# Run kernel over the whole grid, cell by cell:
function broadcast_with_optimisation(
    f, simdata::AbstractSimData{S}, proc, ::NoOpt, ::Val{<:Rule}, rkeys
) where S<:Tuple{Y,X} where {Y,X}
    broadcast_on_processor(proc, 1:X) do j
        for i in 1:Y
            f((i, j)) # Run rule for each row in column j
        end
    end
end
# Use @simd for CellRule
function broadcast_with_optimisation(
    f, simdata::AbstractSimData{S}, proc, ::NoOpt, ::Val{<:CellRule}, rkeys
) where S<:Tuple{Y,X} where {Y,X}
    broadcast_on_processor(proc, 1:X) do j
        @simd for i in 1:Y
            f((i, j)) # Run rule for each row in column j
        end
    end
end

# broacast_on_processor
# Map kernel over the grid, specialising on the processor
#
# Looping over cells or blocks on a single CPU
@inline function broadcast_on_processor(f, proc::SingleCPU, range)
    for n in range
        f(n) # Run rule over each column
    end
end
# Or threaded on multiple CPUs
@inline function broadcast_on_processor(f, proc::ThreadedCPU, range)
    Threads.@threads for n in range
        f(n) # Run rule over each column, threaded
    end
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

# stencil_kernel!
# Runs a rule for the current cell/stencil, when there is no
# row-based optimisation
@inline function stencil_kernel!(
    data::AbstractSimData, hoodgrid::GridData, ruletype::Val{<:NeighborhoodRule}, rule, rkeys, wkeys, I...
)
    rule1 = Stencils.rebuild(rule, unsafe_neighbors(stencil(rule), hoodgrid, CartesianIndex(I)))
    cell_kernel!(data, ruletype, rule1, rkeys, wkeys, I...)
end

# row_kernel!
# Run a NeighborhoodRule rule row by row. When we move along a row by one cell, we 
# access only a single new column of data with the height of 4R, and move the existing
# data in the stencil windows array across by one column. This saves on reads
# from the main array.
function row_kernel!(
    simdata::AbstractSimData, grid::GridData{<:Tuple{Y,X},R}, proc, opt::NoOpt,
    ruletype::Val, rule::Rule, rkeys, wkeys, bi
) where {Y,X,R}
    B = 2R
    i = _blocktoind(bi, B)
    i > Y && return nothing
    # Loop along the block ROW.
    blocklen = min(Y, i + B - 1) - i + 1
    for j = 1:X
        # windows = _slide_windows(windows, src, Val{R}(), i, j)
        # Loop over the COLUMN of windows covering the block
        for b in 1:blocklen
            rule1 = Stencils.rebuild(rule, unsafe_neighbors(stencil(rule), grid, CartesianIndex(i, j)))
            cell_kernel!(simdata, ruletype, rule1, rkeys, wkeys, i + b - 1, j)
        end
    end
    return nothing
end


#### Utils

# Convert any GridData to GridData{<:ReadMode}
_to_readonly(data::Tuple) = map(_to_readonly, data)
_to_readonly(data::GridData) = GridData{ReadMode}(data)

# _maybemask!
# mask the source grid with the `mask` array, if it exists
_maybemask!(wgrids::Union{Tuple,NamedTuple}) = map(_maybemask!, wgrids)
_maybemask!(wgrid::GridData) = _maybemask!(wgrid, proc(wgrid), mask(wgrid))
_maybemask!(wgrid::GridData, proc, mask::Nothing) = nothing
function _maybemask!(
    wgrid::GridData{<:GridMode,<:Tuple{Y,X}}, proc::CPU, mask::AbstractArray
) where {Y,X}
    A = source(wgrid)
    pv = padval(wgrid)
    broadcast_on_processor(proc, 1:X) do j
        if isnothing(pv) || pv == zero(eltype(wgrid))
            @simd for i in 1:Y
                A[i, j] *= mask[i, j]
            end
        else
            @simd for i in 1:Y
                A[i, j] = mask[i, j] ? A[i, j] : pv
            end
        end
    end
end
function _maybemask!(
    wgrid::GridData{<:GridMode,<:Tuple{Y,X}}, proc, mask::AbstractArray
) where {Y,X}
    A = source(wgrid)
    pv = padval(wgrid)
    if isnothing(pv) || iszero(pv)
        for j in 1:X
            @simd for i in 1:Y
                source(wgrid)[i, j] *= mask[i, j]
            end
        end
    else
        for j in 1:X
            @simd for i in 1:Y
                A[i, j] = mask[i, j] ? A[i, j] : pv
            end
        end
    end
end

# _cleardest!
# Clear the desination grid. Only needed with some optimisations.
_cleardest!(grid) = _cleardest!(grid, opt(grid))
_cleardest!(grid, opt) = nothing
