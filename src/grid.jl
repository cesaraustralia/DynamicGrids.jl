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
    args = source(d), dest(d), mask(d), proc(d), opt(d), boundary(d), padval(d),
        sourcestatus(d), deststatus(d)
    G{S,R,T,N,map(typeof, args)...}(args...)
end
function ConstructionBase.constructorof(::Type{T}) where T<:GridData{S,R} where {S,R}
    T.name.wrapper{S,R}
end

# Getters
radius(d::GridData{<:Any,R}) where R = R
mask(d::GridData) = d.mask
proc(d::GridData) = d.proc
opt(d::GridData) = d.opt
boundary(d::GridData) = d.boundary
padval(d::GridData) = d.padval
source(d::GridData) = d.source
dest(d::GridData) = d.dest
sourcestatus(d::GridData) = d.sourcestatus
deststatus(d::GridData) = d.deststatus

# Get the size of the grid
gridsize(d::GridData) = size(d)
gridsize(A::AbstractArray) = size(A)
gridsize(nt::NamedTuple) = gridsize(first(nt))
gridsize(nt::NamedTuple{(),Tuple{}}) = 0, 0

# Get a view of the grid, without padding
gridview(d::GridData) = sourceview(d)
# Get a view of the grid source, without padding
sourceview(d::GridData) = view(parent(source(d)), map(a -> a .+ radius(d), axes(d))...)
# Get a view of the grid dest, without padding
destview(d::GridData) = view(parent(dest(d)), map(a -> a .+ radius(d), axes(d))...)
# Get an a view of the source, preferring the underlying array if it is not a padded OffsetArray
source_array_or_view(d::GridData) = source(d) isa OffsetArray ? sourceview(d) : source(d)
# Get an a view of the dest, preferring the underlying array if it is not a padded OffsetArray
dest_array_or_view(d::GridData) = dest(d) isa OffsetArray ? destview(d) : dest(d)

# Base methods
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

@propagate_inbounds Base.getindex(d::GridData{s}, I...) where s = getindex(source(d), I...)
@propagate_inbounds function Base.getindex(d::GridData{s}, i1::Int, I::Int...) where s 
    getindex(source(d), i1, I...)
end


# Local utility methods

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

# _addpadding => OffsetArray{T,N}
# Find the maximum radius required by all rules
# Add padding around the original init array, offset into the negative
# So that the first real cell is still 1, 1
function _addpadding(init::AbstractArray{T,N}, r, padval) where {T,N}
    h, w = size(init)
    paddedsize = h + 4r, w + 2r
    paddedindices = -r + 1:h + 3r, -r + 1:w + r
    sourceparent = fill(convert(eltype(init), padval), paddedsize)
    source = OffsetArray(sourceparent, paddedindices...)
    # Copy the init array to the middle section of the source array
    for j in 1:size(init, 2), i in 1:size(init, 1)
        @inbounds source[i, j] = init[i, j]
    end
    return source
end


# SparseOpt methods

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

# _indtoblock
# Convert regular index to block index
@inline _indtoblock(x::Int, blocksize::Int) = (x - 1) ÷ blocksize + 1

# _blocktoind
# Convert block index to regular index
@inline _blocktoind(x, blocksize) = (x - 1) * blocksize + 1

"""
    ReadableGridData <: GridData

    ReadableGridData(grid::GridData)
    ReadableGridData{S,R}(init::AbstractArray, mask, opt, boundary, padval)

[`GridData`](@ref) object passed to rules for reading only.
Reads are always from the `source` array.
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
@inline function ReadableGridData{S,R}(
    init::AbstractArray, mask, proc, opt, boundary, padval
) where {S,R}
    # If the grid radius is larger than zero we pad it as an OffsetArray
    if R > 0
        source = _addpadding(init, R, padval)
        dest = _addpadding(init, R, padval)
    else
        # TODO: SparseOpt with no radius
        if opt isa SparseOpt
            opt = NoOpt()
        end
        source = deepcopy(init)
        dest = deepcopy(init)
    end
    sourcestatus, deststatus = _build_status(opt, source, R)

    grid = ReadableGridData{S,R}(
        source, dest, mask, proc, opt, boundary, padval, sourcestatus, deststatus
    )
    _updatestatus!(grid)
    return grid
end

Base.parent(d::ReadableGridData{S,<:Any,T,N}) where {S,T,N} = SizedArray{S,T,N}(sourceview(d))

"""
    WritableGridData <: GridData

    WritableGridData(grid::GridData)

[`GridData`](@ref) object passed to rules as write grids, and can be written 
to directly as an array, or preferably using `add!` etc. All writes handle 
updates to `SparseOpt()` and writing to the correct source/dest array.

Reads are always from the `source` array, while writes are always to the 
`dest` array. This is because rules application must not be sequential 
between cells - the order of cells the rule is applied to does not matter. 
This means that using e.g. `+=` is not supported. Instead use `add!`.
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
