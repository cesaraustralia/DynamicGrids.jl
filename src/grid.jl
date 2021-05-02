"""
    GridData <: AbstractArray

Simulation data specific to a single grid.
"""
abstract type GridData{S,R,T,N} <: StaticArray{S,T,N} end

function (::Type{G})(d::GridData{S,R,T,N}) where {G<:GridData,S,R,T,N}
    args = source(d), dest(d), mask(d), proc(d), opt(d), boundary(d), padval(d),
        sourcestatus(d), deststatus(d)
    G{S,R,T,N,map(typeof, args)...}(args...)
end
function ConstructionBase.constructorof(::Type{T}) where T<:GridData{S,R} where {S,R}
    T.name.wrapper{S,R}
end

GridDataOrReps = Union{GridData, Vector{<:GridData}}

# Array interface
# Base.size(d::GridData{<:Tuple{S}}) where {S} = (Y, X)
# Base.axes(d::GridData) = map(Base.OneTo, size(d))
# Base.eltype(d::GridData{<:Any,<:Any,T}) where T = T
# Base.firstindex(d::GridData) = 1
# Base.lastindex(d::GridData{<:Tuple{S}}) where {S} = Y * X

# Getters
mask(d::GridData) = d.mask
radius(d::GridData{<:Any,R}) where R = R
proc(d::GridData) = d.proc
opt(d::GridData) = d.opt
boundary(d::GridData) = d.boundary
padval(d::GridData) = d.padval
source(d::GridData) = d.source
dest(d::GridData) = d.dest
sourcestatus(d::GridData) = d.sourcestatus
deststatus(d::GridData) = d.deststatus

gridsize(d::GridData) = size(d)
gridsize(A::AbstractArray) = size(A)
gridsize(nt::NamedTuple) = gridsize(first(nt))
gridsize(nt::NamedTuple{(),Tuple{}}) = 0, 0
gridview(d::GridData) = sourceview(d)
sourceview(d::GridData) = view(parent(source(d)), map(a -> a .+ radius(d), axes(d))...)
destview(d::GridData) = view(parent(dest(d)), map(a -> a .+ radius(d), axes(d))...)
source_array_or_view(d::GridData) = source(d) isa OffsetArray ? sourceview(d) : source(d)
dest_array_or_view(d::GridData) = dest(d) isa OffsetArray ? destview(d) : dest(d)

function Base.copy!(grid::GridData{<:Any,R}, A::AbstractArray) where R
    pad_axes = map(ax -> ax .+ R, axes(A))
    copyto!(parent(source(grid)), CartesianIndices(pad_axes), A, CartesianIndices(A))
    _updatestatus!(grid)
    return grid
end
function Base.copy!(A::AbstractArray, grid::GridData{<:Any,R}) where R
    pad_axes = map(ax -> ax .+ R, axes(A))
    copyto!(A, CartesianIndices(A), parent(source(grid)), CartesianIndices(pad_axes))
    return A
end
function Base.copy!(A::AbstractDimArray{T,N}, grid::GridData{<:Any,R}) where {T,N,R}
    copy!(parent(A), grid)
    return A
end
function Base.copy!(grid::GridData{<:Any,R}, A::AbstractDimArray{T,N}) where {R,T,N}
    copy!(grid, parent(A))
    return grid
end
function Base.copy!(dst::GridData{<:Any,RD}, src::GridData{<:Any,RS}) where {RD,RS}
    dst_axes = map(s -> RD:s + RD, gridsize(dst))
    src_axes = map(s -> RS:s + RS, gridsize(src))
    copyto!(parent(source(dst)), CartesianIndices(dst_axes), 
            parent(source(src)), CartesianIndices(src_axes)
    )
    return dst
end

@propagate_inbounds Base.getindex(d::GridData{s}, I...) where s = getindex(parent(d), I...)
@propagate_inbounds Base.getindex(d::GridData{s}, i1::Int, I::Int...) where s = 
    getindex(parent(d), i1, I...)

# _swapsource => ReadableGridData
# Swap source and dest arrays of a grid
_swapsource(d::Tuple) = map(_swapsource, d)
function _swapsource(grid::GridData)
    src = grid.source
    dst = grid.dest
    @set! grid.dest = src
    @set! grid.source = dst
    srcstatus = grid.sourcestatus
    dststatus = grid.deststatus
    @set! grid.deststatus = srcstatus
    return @set grid.sourcestatus = dststatus
end

# _updatestatus!
# Initialise the block status array.
# This tracks whether anything has to be done in an area of the main array.
_updatestatus!(grid::GridData) = _updatestatus!(opt(grid), grid)
function _updatestatus!(opt::SparseOpt, grid)
    blocksize = 2 * radius(grid)
    src = parent(source(grid))
    for I in CartesianIndices(src)
        # Mark the status block (by default a non-zero value)
        if _isactive(src[I], opt)
            bi = _indtoblock.(Tuple(I), blocksize)
            @inbounds sourcestatus(grid)[bi...] = true
            @inbounds deststatus(grid)[bi...] = true
        end
    end
    return nothing
end
_updatestatus!(opt, grid) = nothing

# _build_arrays => Tuple{AbstractArray,AbstractArray}
function _build_arrays(init, padval, opt, ::Val{Tuple{Y,X,0}}) where {Y,X}
    deepcopy(init), deepcopy(init)
end
function _build_arrays(init, padval, opt, ::Val{Tuple{Y,X,R}}) where {Y,X,R}
    # Find the maximum radius required by all rules
    # Add padding around the original init array, offset into the negative
    # So that the first real cell is still 1, 1
    paddedsize = Y + 4R, X + 2R
    paddedindices = -R + 1:Y + 3R, -R + 1:X + R
    sourceparent = fill(convert(eltype(init), padval), paddedsize)
    source = OffsetArray(sourceparent, paddedindices...)
    # Copy the init array to the middle section of the source array
    for j in 1:size(init, 2), i in 1:size(init, 1)
        @inbounds source[i, j] = init[i, j]
    end
    return source, deepcopy(source)
end
function _build_arrays(init, padval, opt::Differentiable, ::Val{Tuple{Y,X,0}}) where {Y,X}
    bi, bj = _indtoblock.(size(init), 8)
    vY, vX = Val{bi}(), Val{bj}()
    sI = SMatrix{8,8}(CartesianIndices(Base.OneTo.((bi, bj))))
    source = map(I -> DynamicGrids._getblock(A, vY, vX, DynamicGrids._blocktoind.(I.I, 8)...), sI)
    return source, deepcopy(source)
end
function _build_arrays(init, padval, opt::Differentiable, ::Val{Tuple{Y,X,R}}) where {Y,X,R}
    paddedsize = Y + 4R, X + 2R
    bi, bj = _indtoblock.(paddedsize, 8)
    vY, vX = Val{bi}(), Val{bj}()
    sI = SMatrix{bi,bj}(CartesianIndices(Base.OneTo.((bi, bj))))
    source = map(sI) do I
        DynamicGrids._getblock(init, vY, vX, DynamicGrids._blocktoind.(I.I, 8)...)
    end
    return source, deepcopy(source)
end

# _build_status => (Matrix{Bool}, Matrix{Bool})
# Build block-status arrays
# We add an additional block that is never used so we can 
# index into it in the block loop without checking
function _build_status(opt::SparseOpt, source, r)
    hoodsize = 2r + 1
    blocksize = 2r
    nblocs = _indtoblock.(size(source), blocksize) .+ 1
    sourcestatus = zeros(Bool, nblocs)
    deststatus = zeros(Bool, nblocs)
    sourcestatus, deststatus
end
_build_status(opt::PerformanceOpt, init, r) = nothing, nothing

"""
    ReadableGridData <: GridData

    ReadableGridData(grid::GridData)
    ReadableGridData{S,R}(init::AbstractArray, mask, opt, boundary, padval)

Simulation data and storage passed to rules for each timestep.

# Type parameters

- `Y`: number of rows 
- `X`: number of columns
- `R`: grid padding radius 
"""
struct ReadableGridData{
    S<:Tuple,R,T,N,Sc,D,M,P<:Processor,Op<:PerformanceOpt,Bo,PV,SSt,DSt
} <: GridData{S,R,T,N}
    source::Sc
    dest::D
    mask::M
    proc::P
    opt::Op
    boundary::Bo
    padval::PV
    sourcestatus::SSt
    deststatus::DSt
end
function ReadableGridData{S,R}(
    source::Sc, dest::D, mask::M, proc::P, opt::Op, boundary::Bo, 
    padval::PV, sourcestatus::SSt, deststatus::DSt
) where {S,R,Sc<:AbstractArray{T,N},D,M,P,Op,Bo,PV,SSt,DSt} where {T,N}
    ReadableGridData{S,R,T,N,Sc,D,M,P,Op,Bo,PV,SSt,DSt}(
        source, dest, mask, proc, opt, boundary, padval, sourcestatus, deststatus
    )
end
# Generate simulation data to match a ruleset and init array.
@inline function ReadableGridData{S,R}(
    init::AbstractArray, mask, proc, opt, boundary, padval
) where {Y,X,R}
    source, dest = _build_arrays(init, padval, opt, Val{Tuple{Y,X,R}}()) 
    sourcestatus, deststatus = _build_status(opt, source, R)
    grid = ReadableGridData{Y,X,R}(
        source, dest, mask, proc, opt, boundary, padval, sourcestatus, deststatus
    )
    _updatestatus!(grid)
    return grid
end

Base.parent(d::ReadableGridData{S,<:Any,T,N}) where {S,T,N} = SizedArray{S,T,N}(sourceview(d))


"""
    WritableGridData <: GridData

    WritableGridData(grid::GridData)

Passed to rules as write grids, and can be written to directly as an array, 
or preferably using `add!` etc. All writes handle updates to SparseOpt() 
and writing to the correct source/dest array.

Reads are _always from the source array_, as rules must not be sequential between
cells. This means using e.g. `+=` is not supported, instead use `add!`.
"""
struct WritableGridData{
    S<:Tuple,R,T,N,Sc<:AbstractArray{T,N},D<:AbstractArray{T,N},
    M,P<:Processor,Op<:PerformanceOpt,Bo,PV,SSt,DSt
} <: GridData{S,R,T,N}
    source::Sc
    dest::D
    mask::M
    proc::P
    opt::Op
    boundary::Bo
    padval::PV
    sourcestatus::SSt
    deststatus::DSt
end
function WritableGridData{S,R}(
    source::Sc, dest::D, mask::M, proc::P, opt::Op, 
    boundary::Bo, padval::PV, sourcestatus::SSt, deststatus::DSt
) where {S,R,Sc<:AbstractArray{T,N},D<:AbstractArray{T,N},M,P,Op,Bo,PV,SSt,DSt} where {T,N}
    WritableGridData{S,R,T,N,Sc,D,M,P,Op,Bo,PV,SSt,DSt}(
        source, dest, mask, proc, opt, boundary, padval, sourcestatus, deststatus
    )
end

Base.parent(d::WritableGridData{S}) where {S} = SizedArray{S}(destview(d))


### UNSAFE / LOCKS required

# Base.setindex!
# This is not safe for general use. 
# It can be used where only identical transformations of a cell 
# can happen from any other cell, such as setting all 1s to 2.
@propagate_inbounds function Base.setindex!(d::WritableGridData, x, I...)
    _setindex!(d, proc(d), x, I...)
end
@propagate_inbounds function Base.setindex!(d::WritableGridData, x, i1::Int, I::Int...)
    _setindex!(d, proc(d), x, i1, I...)
end

@propagate_inbounds function _setindex!(d::WritableGridData, opt::SingleCPU, x, I...)
    @boundscheck checkbounds(dest(d), I...)
    @inbounds _setdeststatus!(d, x, I...)
    @inbounds dest(d)[I...] = x
end
@propagate_inbounds function _setindex!(d::WritableGridData, proc::ThreadedCPU, x, I...)
    # Dest status is not threadsafe, even if the 
    # setindex itself is safe. So we LOCK
    lock(proc)
    @inbounds _setdeststatus!(d, x, I...)
    unlock(proc)
    @inbounds dest(d)[I...] = x
end

# _setdeststatus!
# Sets the status of the destination block that the current index is in.
# It can't turn of block status as the block is larger than the cell
# But should be used inside a LOCK
_setdeststatus!(d::WritableGridData{<:Any,R}, x, I...) where R = 
    _setdeststatus!(d, opt(d), x, I...)
function _setdeststatus!(d::WritableGridData{<:Any,R}, opt::SparseOpt, x, I...) where R
    blockindex = _indtoblock.(I .+ R, 2R)
    @inbounds deststatus(d)[blockindex...] |= !(opt.f(x))
    return nothing
end
_setdeststatus!(d::WritableGridData{<:Any,R}, opt::PerformanceOpt, x, I...) where R = nothing
