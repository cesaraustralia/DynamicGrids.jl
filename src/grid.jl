"""
    GridData <: StaticArray

Simulation data specific to a single grid.

These behave like arrays, but contain both source and 
destination arrays as simulations need separate read and 
write steps to maintain independence between cells.

`GridData` objects also contain other data and settings needed
for optimisations.

# Type parameters

- `S`: grid size type tuple
- `R`: grid padding radius 
- `T`: grid data type
"""
abstract type GridData{S,R,T,N} <: StaticArray{S,T,N} end

function (::Type{G})(d::GridData{S,R,T,N}) where {G<:GridData,S,R,T,N}
    args = source(d), dest(d), mask(d), proc(d), opt(d), boundary(d), padval(d), optdata(d)
    G{S,R,T,N,map(typeof, args)...}(args...)
end
function ConstructionBase.constructorof(::Type{T}) where T<:GridData{S,R} where {S,R}
    T.name.wrapper{S,R}
end

# Return a SizedArray with similar, instead of a StaticArray
Base.similar(A::GridData) = similar(sourceview(A))
Base.similar(A::GridData, ::Type{T}) where T = similar(sourceview(A), T)
Base.similar(A::GridData, I::Tuple{Int,Vararg{Int}}) = similar(sourceview(A), I)
Base.similar(A::GridData, ::Type{T}, I::Tuple{Int,Vararg{Int}}) where T =
    similar(sourceview(A), T, I)

# Getters
radius(d::GridData{<:Any,R}) where R = R
mask(d::GridData) = d.mask
proc(d::GridData) = d.proc
opt(d::GridData) = d.opt
optdata(d::GridData) = d.optdata
boundary(d::GridData) = d.boundary
padval(d::GridData) = d.padval
source(d::GridData) = d.source
dest(d::GridData) = d.dest

# Get the size of the grid
gridsize(d::GridData) = size(d)
gridsize(A::AbstractArray) = size(A)
gridsize(nt::NamedTuple) = gridsize(first(nt))
gridsize(nt::NamedTuple{(),Tuple{}}) = 0, 0

# Get a view of the grid, without padding
gridview(d::GridData) = sourceview(d)
# Get a view of the grid source, without padding
sourceview(d::GridData) = _padless_view(source(d), axes(d), radius(d))
# Get a view of the grid dest, without padding
destview(d::GridData) = _padless_view(dest(d), axes(d), radius(d))

_padless_view(A::OffsetArray, axes, radius) = _padless_view(parent(A), axes, radius)
function _padless_view(A::AbstractArray, axes, radius)
    ranges = map(axes) do axis
        axis .+ radius
    end
    return view(A, ranges...)
end


# Get an a view of the source, preferring the underlying array if it is not a padded OffsetArray
source_array_or_view(d::GridData) = source(d) isa OffsetArray ? sourceview(d) : source(d)
# Get an a view of the dest, preferring the underlying array if it is not a padded OffsetArray
dest_array_or_view(d::GridData) = dest(d) isa OffsetArray ? destview(d) : dest(d)

# Base methods
function Base.copy!(grid::GridData{<:Any,R}, A::AbstractArray) where R
    pad_axes = map(ax -> ax .+ R, axes(A))
    copyto!(parent(source(grid)), CartesianIndices(pad_axes), A, CartesianIndices(A))
    return _update_optdata!(grid)
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
    dst_axes = map(s -> RD:s + RD, size(dst))
    src_axes = map(s -> RS:s + RS, size(src))
    copyto!(parent(source(dst)), CartesianIndices(dst_axes), 
            parent(source(src)), CartesianIndices(src_axes)
    )
    return dst
end

@propagate_inbounds Base.getindex(d::GridData{s}, I...) where s = getindex(source(d), I...)
@propagate_inbounds function Base.getindex(d::GridData{s}, i1::Int, I::Int...) where s 
    getindex(source(d), i1, I...)
end

# Local utility methods

# _addpadding => OffsetArray{T,N}
# Find the maximum radius required by all rules
# Add padding around the original init array, offset into the negative
# So that the first real cell is still 1, 1
function _addpadding(init::AbstractArray{T,1}, r, padval) where T
    l = length(init)
    paddedsize = l + 2r
    paddedaxis = -r + 1:l + r
    sourceparent = fill(convert(T, padval), paddedsize)
    source = OffsetArray(sourceparent, paddedaxis)
    # Copy the init array to the middle section of the source array
    for i in 1:l
        @inbounds source[i] = init[i]
    end
    return source
end
function _addpadding(init::AbstractArray{T,2}, r, padval) where T
    h, w = size(init)
    paddedsize = h + 4r, w + 2r
    paddedaxes = -r + 1:h + 3r, -r + 1:w + r
    pv = convert(eltype(init), padval)
    sourceparent = similar(init, typeof(pv), paddedsize...)
    sourceparent .= Ref(pv)
    # Copy the init array to the middle section of the source array
    _padless_view(sourceparent, axes(init), r) .= init
    source = OffsetArray(sourceparent, paddedaxes...)
    return source
end

# _swapsource => ReadableGridData
# Swap source and dest arrays of a grid
_swapsource(d::Tuple) = map(_swapsource, d)
function _swapsource(grid::GridData)
    src = grid.source
    dst = grid.dest
    @set! grid.dest = src
    @set! grid.source = dst
    _swapoptdata(opt(grid), grid)
end

_swapoptdata(opt::PerformanceOpt, grid::GridData) = grid

_build_optdata(opt::PerformanceOpt, init, r) = nothing

_update_optdata!(grid::GridData) = _update_optdata!(grid, opt(grid))
_update_optdata!(grid, opt) = grid

# _indtoblock
# Convert regular index to block index
@inline _indtoblock(x::Int, blocksize::Int) = (x - 1) ÷ blocksize + 1

# _blocktoind
# Convert block index to regular index
@inline _blocktoind(x::Int, blocksize::Int) = (x - 1) * blocksize + 1

"""
    ReadableGridData <: GridData

    ReadableGridData(grid::GridData)
    ReadableGridData{S,R}(init::AbstractArray, mask, opt, boundary, padval)

[`GridData`](@ref) object passed to rules for reading only.
Reads are always from the `source` array.
"""
struct ReadableGridData{
    S<:Tuple,R,T,N,Sc,D,M,P<:Processor,Op<:PerformanceOpt,Bo,PV,OD
} <: GridData{S,R,T,N}
    source::Sc
    dest::D
    mask::M
    proc::P
    opt::Op
    boundary::Bo
    padval::PV
    optdata::OD
end
function ReadableGridData{S,R}(
    source::Sc, dest::D, mask::M, proc::P, opt::Op, boundary::Bo, 
    padval::PV, optdata::OD
) where {S,R,Sc<:AbstractArray{T,N},D<:AbstractArray{T,N},M,P,Op,Bo,PV,OD} where {T,N}
    ReadableGridData{S,R,T,N,Sc,D,M,P,Op,Bo,PV,OD}(
        source, dest, mask, proc, opt, boundary, padval, optdata
    )
end
@inline function ReadableGridData{S,R}(
    init::AbstractArray, mask, proc, opt, boundary, padval
) where {S,R}
    # If the grid radius is larger than zero we pad it as an OffsetArray
    if R > 0
        source = _addpadding(init, R, padval)
        dest = _addpadding(init, R, padval)
    else
        source = deepcopy(init)
        dest = deepcopy(init)
    end
    optdata = _build_optdata(opt, source, R)

    grid = ReadableGridData{S,R}(
        source, dest, mask, proc, opt, boundary, padval, optdata
    )
    return _update_optdata!(grid)
end

function Base.parent(d::ReadableGridData{S,<:Any,T,N}) where {S,T,N}
    SizedArray{S,T,N}(source_array_or_view(d))
end

"""
    WritableGridData <: GridData

    WritableGridData(grid::GridData)

[`GridData`](@ref) objet passed to rules as write grids, and can be written 
to directly as an array, or preferably using `add!` etc. All writes handle 
updates to `SparseOpt()` and writing to the correct source/dest array.

Reads are always from the `source` array, while writes are always to the 
`dest` array. This is because rules application must not be sequential 
between cells - the order of cells the rule is applied to does not matter. 
This means that using e.g. `+=` is not supported. Instead use `add!`.
"""
struct WritableGridData{
    S<:Tuple,R,T,N,Sc,D,M,P<:Processor,Op<:PerformanceOpt,Bo,PV,OD
} <: GridData{S,R,T,N}
    source::Sc
    dest::D
    mask::M
    proc::P
    opt::Op
    boundary::Bo
    padval::PV
    optdata::OD
end
function WritableGridData{S,R}(
    source::Sc, dest::D, mask::M, proc::P, opt::Op, 
    boundary::Bo, padval::PV, optdata::OD
) where {S,R,Sc<:AbstractArray{T,N},D<:AbstractArray{T,N},M,P,Op,Bo,PV,OD} where {T,N}
    WritableGridData{S,R,T,N,Sc,D,M,P,Op,Bo,PV,OD}(
        source, dest, mask, proc, opt, boundary, padval, optdata
    )
end

function Base.parent(d::WritableGridData{S,<:Any,T,N}) where {S,T,N}
    SizedArray{S,T,N}(dest_array_or_view(d))
end


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

@propagate_inbounds function _setindex!(d::WritableGridData, proc::SingleCPU, x, I...)
    @boundscheck checkbounds(dest(d), I...)
    @inbounds _setoptindex!(d, x, I...)
    @inbounds dest(d)[I...] = x
end
@propagate_inbounds function _setindex!(d::WritableGridData, proc::ThreadedCPU, x, I...)
    # Dest status is not threadsafe, even if the 
    # setindex itself is safe. So we LOCK
    lock(proc)
    @inbounds _setoptindex!(d, x, I...)
    unlock(proc)
    @inbounds dest(d)[I...] = x
end

# _setoptindex!
# Do anything the optimisation needs on `setindex`
_setoptindex!(d::WritableGridData{<:Any,R}, x, I...) where R = _setoptindex!(d, opt(d), x, I...)
_setoptindex!(d::WritableGridData{<:Any,R}, opt::PerformanceOpt, x, I...) where R = nothing
