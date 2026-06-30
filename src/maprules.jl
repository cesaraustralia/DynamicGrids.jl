
# Map a rule over the grids it reads from, updating the grids it writes to.
#
# This is split into setup methods and application methods,
# for dispatch and to introduce a function barrier for type stability.

# We dispatch on `ruletype(rule)` to allow wrapper rules
# to pass through the type of the wrapped rule.
# Putting the type in `Val` is best for performance.
maprule!(data::AbstractSimData, rule) =
    maprule!(data, _val_ruletype(rule), rule)

# CellRule
function maprule!(simdata::AbstractSimData, ruletype::Val{<:CellRule}, rule)
    rkeys, _ = _getreadgrids(rule, simdata)
    wkeys, _ = _getwritegrids(WriteMode, rule, simdata)
    ruledata = RuleData(simdata, rule)
    maprule!(ruledata, ruletype, rule, rkeys, wkeys)
    # Not swictch required
    return simdata
end

# NeighborhoodRule
function maprule!(simdata::AbstractSimData, ruletype::Val{<:NeighborhoodRule}, rule)
    rkeys, rgrids = _getreadgrids(rule, simdata)
    wkeys, wgrids = _getwritegrids(SwitchMode, rule, simdata)
    # Copy or zero out boundary where needed
    _update_boundary!(rgrids)
    _cleardest!(simdata[stencilkey(rule)])
    ruledata = RuleData(simdata, rule)
    maprule!(ruledata, ruletype, rule, rkeys, wkeys)
    # Swap the dest/source of grids that were written to
    # and combine the written grids with the original simdata
    final_rgrids = _to_readonly(_switch(wgrids))
    return _replacegrids(simdata, wkeys, final_rgrids)
end

# SetRule
function maprule!(simdata::AbstractSimData, ruletype::Val{<:SetRule}, rule)
    rkeys, _ = _getreadgrids(rule, simdata)
    wkeys, wgrids = _getwritegrids(SwitchMode, rule, simdata)
    map(_astuple(wkeys, wgrids)) do g
        copyto!(parent(dest(g)), parent(source(g)))
    end
    ruledata = RuleData(_combinegrids(simdata, wkeys, wgrids), rule)
    maprule!(ruledata, ruletype, rule, rkeys, wkeys)
    # We have to mask after SetRule
    final_grids = _maybemask!(_to_readonly(_switch(wgrids)))
    return _replacegrids(simdata, wkeys, final_grids)
end

_switch(xs::Tuple) = map(switch, xs)
_switch(x) = switch(x)

# SetGridRule
function maprule!(simdata::AbstractSimData, ruletype::Val{<:SetGridRule}, rule)
    rkeys, rgrids = _getreadgrids(rule, simdata)
    wkeys, wgrids = _getwritegrids(WriteMode, rule, simdata)
    ruledata = RuleData(_combinegrids(simdata, wkeys, wgrids), rule)
    # Run the rule
    applyrule!(ruledata, rule)
    # We don't mask here or do anything, its on the user
    return simdata
end
# Expand method arguments for dispatch on processor and optimisation
maprule!(ruledata::RuleData, ruletype::Val, rule, rkeys, wkeys) =
    maprule!(ruledata, proc(ruledata), opt(ruledata), ruletype, rule, rkeys, wkeys)

# Most Rules
# 2 dimensional, with processor selection and optimisations in `map_with_optimisation`
function maprule!(
    ruledata::RuleData{<:Tuple{Y,X}}, proc::CPU, opt::PerformanceOpt, ruletype::Val, rule, rkeys, wkeys
) where {Y,X}
    let ruledata=ruledata, proc=proc, opt=opt, ruletype=ruletype, rule=rule, rkeys=rkeys, wkeys=wkeys
        map_with_optimisation(ruledata, proc, opt, ruletype, rkeys, wkeys) do I 
            cell_kernel!(ruledata, ruletype, rule, rkeys, wkeys, I...)
        end
    end
end
# # Arbitrary dimensions, no processor or optimisation selection beyond CPU/GPU
function maprule!(ruledata::RuleData{<:Tuple}, proc::CPU, opt::PerformanceOpt, ruletype::Val, rule, rkeys, wkeys)
    let ruledata=ruledata, ruletype=ruletype, rule=rule, rkeys=rkeys, wkeys=wkeys
        for I in CartesianIndices(first(grids(ruledata)))
            cell_kernel!(ruledata, ruletype, rule, rkeys, wkeys, Tuple(I)...)
        end
    end
end
# Neighborhoods: Arbitrary dimensions, no processor or optimisation selection beyond CPU/GPU
function maprule!(
    data::RuleData{<:Tuple{Y,X}}, proc::CPU, opt::PerformanceOpt, ruletype::Val{<:NeighborhoodRule}, rule, rkeys, wkeys
) where {Y,X}
    hoodgrid = _firstgrid(data, rkeys)
    map_with_optimisation(data, proc, opt, ruletype, rkeys, wkeys) do I
        stencil_kernel!(data, hoodgrid, ruletype, rule, rkeys, wkeys, Tuple(I)...)
    end
    return nothing
end

_update_boundary!(gs::Union{NamedTuple,Tuple}) = map(_update_boundary!, gs)
_update_boundary!(g::GridData) = update_boundary!(g)

### Rules that don't need a stencil window ####################

# map_with_optimisation
# Map kernel over the grid, specialising on PerformanceOpt.

# Run kernel over the whole grid, cell by cell:
function map_with_optimisation(
    f, ruledata::AbstractSimData{S}, proc, ::NoOpt, ::Val{<:Rule}, rkeys, wkeys
) where S<:Tuple{I,J} where {I,J}
    map_on_processor(proc, simdata, 1:J) do j
        @simd for i in 1:I
            f((i, j))
        end
    end
end
function map_with_optimisation(
    f, simdata::AbstractSimData{S}, proc, ::NoOpt, ::Val{<:Rule}, rkeys, wkeys
) where S<:Tuple{I,J,K} where {I,J,K}
    map_on_processor(proc, simdata, 1:K) do k
        for j in 1:J 
            @simd for i in 1:I
                f((i, j, k))
            end
        end
    end
end
function map_with_optimisation(
    f, simdata::AbstractSimData{S}, proc, ::NoOpt, ::Val{<:Rule}, rkeys, wkeys
) where S<:Tuple{I,J,K,L} where {I,J,K,L}
    map_on_processor(proc, simdata, 1:L) do l
        for k in 1:K 
            for j in 1:J 
                @simd for i in 1:I
                    f((i, j, k, l))
                end
            end
        end
    end
end
function map_with_optimisation(
    f, simdata::AbstractSimData{S}, proc, ::NoOpt, ::Val{<:Rule}, rkeys, wkeys
) where S<:Tuple{I,J} where {I,J}
    map_on_processor(proc, simdata, 1:J) do j
        @simd for i in 1:I
            f((i, j))
        end
    end
end

# broacast_on_processor
# Map kernel over the grid, specialising on the processor
#
# Looping over cells or blocks on a single CPU
@inline function map_on_processor(f, proc::SingleCPU, data, range)
    for n in range
        f(n) # Run rule over each column
    end
end
# Or threaded on multiple CPUs
@inline function map_on_processor(f, proc::ThreadedCPU, data, range)
    Threads.@threads :static for n in range
        f(n) # Run rule over each column
    end
    # We don't want to share memory between neighborhoods
    # min_cols = max(3, 2radius(data) + 1)
    # N = Threads.nthreads()
    # allchunks = collect(Iterators.partition(rnge, min_cols))
    # chunks = map(1:N) do i
    #     allchunks[i:N:end]
    # end
    # tasks = map(chunks) do chunk
    #     Threads.@spawn begin
    #         for subchunk in chunk
    #             for n in subchunk
    #                 f(n)
    #             end
    #         end
    #     end
    # end
    # states = fetch.(tasks)
    return nothing
end

# cell_kernel!
# runs a rule for the current cell
@inline function cell_kernel!(data::RuleData, ruletype, rule, rkeys, wkeys, I...)
    # When we have replicates as an additional grid 
    # dimension we hide the extra dimension from rules.
    I1 = _strip_replicates(data, I)
    # We skip the cell if there is a mask layer
    m = mask(data)
    if !isnothing(m)
        m[I1...] || return nothing
    end
    # We read a value from the grid
    readval = _readcell(data, rkeys, I...)
    # Update the data object
    data1 = ConstructionBase.setproperties(data, (value=readval, indices = I))
    # Pass all of these to the applyrule function
    writeval = applyrule(data1, rule, readval, I1)
    # And write its result/s to the cell in the relevent grid/s
    _writecell!(data1, ruletype, wkeys, writeval, I...)
    # We also return the written value
    return writeval
end
@inline function cell_kernel!(data::RuleData, ::Val{<:SetRule}, rule, rkeys, wkeys, I...)
    I1 = _strip_replicates(data, I)
    m = mask(data)
    if !isnothing(m)
        m[I1...] || return nothing
    end
    readval = _readcell(data, rkeys, I...)
    data1 = ConstructionBase.setproperties(data, (value=readval, indices = I))
    # Rules will manually write to grids in `applyrule!`
    applyrule!(data1, rule, readval, I1)
    # In a SetRule there is no return value
    return nothing
end

_strip_replicates(data::RuleData, I) = _strip_replicates(replicates(data), I)
_strip_replicates(::Nothing, I::NTuple) = I
_strip_replicates(::Integer, I::NTuple{N}) where N = ntuple(i -> I[i], Val{N-1}())

# stencil_kernel!
# Runs a rule for the current cell/stencil
@inline function stencil_kernel!(
    data::RuleData, hoodgrid::GridData, ruletype::Val{<:NeighborhoodRule}, rule::Rule, rkeys, wkeys, I...
)
    rule1 = Stencils.rebuild(rule, unsafe_stencil(stencil(rule), hoodgrid, CartesianIndex(I)))
    cell_kernel!(data, ruletype, rule1, rkeys, wkeys, I...)
end

#### Utils

# Convert any GridData to GridData{<:ReadMode}
_to_readonly(data::Tuple) = map(_to_readonly, data)
_to_readonly(data::GridData) = GridData{ReadMode}(data)

# _maybemask!
# mask the source grid with the `mask` array, if it exists
_maybemask!(grids::Union{Tuple,NamedTuple}) = map(_maybemask!, grids)
_maybemask!(grid::GridData) = _maybemask!(grid, proc(grid), mask(grid))
_maybemask!(grid::GridData, proc, mask::Nothing) = grid
function _maybemask!(grid::GridData, proc::CPU, mask::AbstractArray)
    mv = maskval(grid)
    # `mask` is also a padded StencilArray
    # so we mask the whole thing to take care of the edges
    if isnothing(mv) || iszero(mv)
        source(grid) .*= parent(mask)
    else
        source(grid) .= ((a, m) -> m ? a : mv).(source(grid), parent(mask))
    end
    return grid
end

# _cleardest!
# Clear the desination grid. Only needed with some optimisations.
_cleardest!(grid) = _cleardest!(grid, opt(grid))
_cleardest!(grid, opt) = nothing
