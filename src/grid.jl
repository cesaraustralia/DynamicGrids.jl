"""
    GridData <: StaticArrgriay

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
abstract type GridData{S,R,T,N,A,H,B,P} <: Neighborhoods.AbstractSwitchingNeighborhoodArray{S,R,T,N,A,H,B,P} end

function (::Type{G})(d::GridData{S,R,T,N,A}) where {G<:GridData,S,R,T,N,A}
    args = neighborhood(d), boundary(d), padding(d), proc(d), opt(d), optdata(d), mask(d)
    G{S,R,T,N,A,map(typeof, args)...}(source(d), dest(d), args...)
end
function ConstructionBase.constructorof(::Type{T}) where T<:GridData{S,R} where {S,R}
    T.name.wrapper{S,R}
end

# Getters
proc(d::GridData) = d.proc
opt(d::GridData) = d.opt
optdata(d::GridData) = d.optdata
mask(d::GridData) = d.mask

# Get the size of the grid
gridsize(d::GridData) = size(d)
gridsize(A::AbstractArray) = size(A)
gridsize(nt::NamedTuple) = gridsize(first(nt))
gridsize(nt::NamedTuple{(),Tuple{}}) = 0, 0

# Get a view of the grid, without padding
gridview(d::GridData) = sourceview(d)
# Get a view of the grid source, without padding
sourceview(d::GridData) = _unpad_view(source(d), d)
# Get a view of the grid dest, without padding
destview(d::GridData) = _unpad_view(dest(d), d)

_unpad_view(A, d::GridData) = view(A, axes(d)...)

# Get an a view of the source, preferring the underlying array if it is not a padded OffsetArray
source_array_or_view(d::GridData) = source(d) isa OffsetArray ? sourceview(d) : source(d)
# Get an a view of the dest, preferring the underlying array if it is not a padded OffsetArray
dest_array_or_view(d::GridData) = dest(d) isa OffsetArray ? destview(d) : dest(d)

# @propagate_inbounds Base.getindex(d::GridData{s}, I...) where s = getindex(source(d), I...)
# @propagate_inbounds function Base.getindex(d::GridData{s}, i1::Int, I::Int...) where s
#     getindex(source(d), i1, I...)
# end

Neighborhoods.switch(d::Tuple) = map(switch, d)
function Neighborhoods.switch(grids::NamedTuple{<:Any,Tuple{T,Vararg}}) where {T<:GridData}
    map(switch, grids)
end
function Neighborhoods.switch(A::T) where {T<:GridData}
    od = switch(opt(A), optdata(A))
    T(dest(A), source(A), neighborhood(A), boundary(A), padding(A), proc(A), opt(A), od, mask(A))
end
Neighborhoods.switch(::PerformanceOpt, optdata) = optdata

Neighborhoods.after_update_boundary!(grid::GridData) = Neighborhoods.after_update_boundary!(grid, opt(grid))
Neighborhoods.after_update_boundary!(grid, opt) = grid


_build_optdata(opt::PerformanceOpt, init, r) = nothing

# _indtoblock
# Convert regular index to block index
@inline _indtoblock(x::Int, blocksize::Int) = (x - 1) ÷ blocksize + 1

# _blocktoind
# Convert block index to regular index
@inline _blocktoind(x::Int, blocksize::Int) = (x - 1) * blocksize + 1

"""
    ReadableGridData <: GridData

    ReadableGridData(grid::GridData)
    ReadableGridData{S,R}(init::AbstractArray, mask, opt, boundary, padding)

[`GridData`](@ref) object passed to rules for reading only.
Reads are always from the `source` array.
"""
struct ReadableGridData{
    S<:Tuple,R,T,N,A,H,B,P,Pr<:Processor,Op<:PerformanceOpt,OpD,M
} <: GridData{S,R,T,N,A,H,B,P}
    source::A
    dest::A
    neighborhood::H
    boundary::B
    padding::P
    proc::Pr
    opt::Op
    optdata::OpD
    mask::M
end
function ReadableGridData{S,R}(
    source::A, dest::A, neighborhood::H, boundary::B, padding::P,
    proc::Pr, opt::Op, optdata::OpD, mask::M,
) where {S,R,A<:AbstractArray{T,N},H,B,P,Pr,Op,OpD,M} where {T,N}
    ReadableGridData{S,R,T,N,A,H,B,P,Pr,Op,OpD,M}(
        source, dest, neighborhood, boundary, padding, proc, opt, optdata, mask
    )
end
@inline function ReadableGridData{S,R}(
    init::AbstractArray{<:Any,N}, neighborhood::Neighborhood, boundary::BoundaryCondition, padding::Padding, proc, opt, mask
) where {S,R,N}
    # If the grid radius is larger than zero we pad it as an OffsetArray
    if R > 0
        # Blocks (only used for 2d sims) need additional vertical padding.
        # TODO: this needs clarification.
        r = N == 2 ? ((R, 3R), (R, R)) : R
        source = Neighborhoods.pad_array(padding, boundary, neighborhood, init)
        dest = Neighborhoods.pad_array(padding, boundary, neighborhood, init)
    else
        source = deepcopy(init)
        dest = deepcopy(init)
    end
    optdata = _build_optdata(opt, source, R)

    grid = ReadableGridData{S,R}(
        source, dest, neighborhood, boundary, padding, proc, opt, optdata, mask
    )
    update_boundary!(grid)
    return grid
end

# function Base.parent(d::ReadableGridData{S,<:Any,T,N}) where {S,T,N}
#     SizedArray{S,T,N}(source_array_or_view(d))
# end

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
    S<:Tuple,R,T,N,A,H,B,P,Pr<:Processor,Op<:PerformanceOpt,OpD,M
} <: GridData{S,R,T,N,A,H,B,P}
    source::A
    dest::A
    neighborhood::H
    boundary::B
    padding::P
    proc::Pr
    opt::Op
    optdata::OpD
    mask::M
end
function WritableGridData{S,R}(
    source::A, dest::A, neighborhood::H, boundary::B, padding::P,
    proc::Pr, opt::Op, optdata::OpD, mask::M
) where {S,R,A<:AbstractArray{T,N},H,B,P,Pr,Op,OpD,M} where {T,N}
    WritableGridData{S,R,T,N,A,H,B,P,Pr,Op,OpD,M}(
        source, dest, neighborhood, boundary, padding, proc, opt, optdata, mask
    )
end

# function Base.parent(d::WritableGridData{S,<:Any,T,N}) where {S,T,N}
    # SizedArray{S,T,N}(dest_array_or_view(d))
# end


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
    # @inbounds 
    _setoptindex!(d, x, I...)
    # @inbounds 
    dest(d)[I...] = x
end
@propagate_inbounds function _setindex!(d::WritableGridData, proc::ThreadedCPU, x, I...)
    # Dest status is not threadsafe, even if the
    # setindex itself is safe. So we LOCK
    lock(proc)
    # @inbounds 
    _setoptindex!(d, x, I...)
    unlock(proc)
    # @inbounds 
    dest(d)[I...] = x
end

# _setoptindex!
# Do anything the optimisation needs on `setindex`
_setoptindex!(d::WritableGridData{<:Any,R}, x, I...) where R = _setoptindex!(d, opt(d), x, I...)
_setoptindex!(d::WritableGridData{<:Any,R}, opt::PerformanceOpt, x, I...) where R = nothing
