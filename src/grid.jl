abstract type GridMode end
abstract type ReadMode <: GridMode end
abstract type WriteMode <: GridMode end
abstract type SwitchMode <: WriteMode end

"""
    AbstractGridArray <: AbstractSwitchingStencilArray

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
abstract type AbstractGridData{Mode,S,R,T,N,A,H,B,P} <: Stencils.AbstractSwitchingStencilArray{S,R,T,N,A,H,B,P} end

function (::Type{G})(
    d::AbstractGridData{<:Any,S,R,T,N,A}
) where {G<:AbstractGridData{<:GridMode},S,R,T,N,A}
    args = stencil(d), boundary(d), padding(d), proc(d), opt(d), optdata(d), mask(d), maskval(d)
    G{S,R,T,N,A,map(typeof, args)...}(source(d), dest(d), args...)
end

# Getters
proc(d::AbstractGridData) = d.proc
opt(d::AbstractGridData) = d.opt
optdata(d::AbstractGridData) = d.optdata
mask(d::AbstractGridData) = d.mask
maskval(d::AbstractGridData) = d.maskval

# Get the size of the grid
gridsize(d::AbstractGridData) = size(d)
gridsize(A::AbstractArray) = size(A)
gridsize(nt::NamedTuple) = gridsize(first(nt))
gridsize(nt::NamedTuple{(),Tuple{}}) = 0, 0

# Get a view of the grid, without padding
gridview(d::AbstractGridData) = sourceview(d)
# Get a view of the grid source, without padding
sourceview(d::AbstractGridData) = _unpad_view(source(d), d)
# Get a view of the grid dest, without padding
destview(d::AbstractGridData) = _unpad_view(dest(d), d)

_unpad_view(A, d::AbstractGridData) = view(A, axes(d)...)

# Get an a view of the source, preferring the underlying array if it is not a padded OffsetArray
source_array_or_view(d::AbstractGridData) = source(d) isa OffsetArray ? sourceview(d) : source(d)
# Get an a view of the dest, preferring the underlying array if it is not a padded OffsetArray
dest_array_or_view(d::AbstractGridData) = dest(d) isa OffsetArray ? destview(d) : dest(d)

_build_optdata(opt::PerformanceOpt, init, r) = nothing

# _indtoblock
# Convert regular index to block index
@inline _indtoblock(x::Int, blocksize::Int) = (x - 1) ÷ blocksize + 1

# _blocktoind
# Convert block index to regular index
@inline _blocktoind(x::Int, blocksize::Int) = (x - 1) * blocksize + 1

"""
    GridData <: GridData

    GridData(grid::GridData)
    GridData{S,R}(init::AbstractArray, mask, opt, boundary, padding)

[`GridData`](@ref) object passed to rules for reading only.

Has `ReadMode`, `WriteMode` and `SwitchMode` to control behaviour.

Reads are always from the `source` array.
"""
struct GridData{
    Mode,S<:Tuple,R,T,N,A,H,B,P,Pr<:Processor,Op<:PerformanceOpt,OpD,Ma,MV
} <: AbstractGridData{Mode,S,R,T,N,A,H,B,P}
    source::A
    dest::A
    stencil::H
    boundary::B
    padding::P
    proc::Pr
    opt::Op
    optdata::OpD
    mask::Ma
    maskval::MV
end
function GridData{Mode,S,R}(
    source::A, dest::A, stencil::H, boundary::B, padding::P,
    proc::Pr, opt::Op, optdata::OpD, mask::Ma, maskval::MV
) where {Mode,S,R,A<:AbstractArray{T,N},H,B,P,Pr,Op,OpD,Ma,MV} where {T,N}
    GridData{Mode,S,R,T,N,A,H,B,P,Pr,Op,OpD,Ma,MV}(
        source, dest, stencil, boundary, padding, proc, opt, optdata, mask, maskval
    )
end
@inline function GridData{Mode,S,R}(
    init::AbstractArray{<:Any,N}, stencil::Stencil, boundary::BoundaryCondition, padding::Padding, proc, opt, mask, maskval
) where {Mode,S,R,N}
    # If the grid radius is larger than zero we pad it as an OffsetArray
    if R > 0
        # Blocks (only used for 2d sims) need additional vertical padding.
        # TODO: this needs clarification.
        r = N == 2 ? ((R, 3R), (R, R)) : R
        source = Stencils.pad_array(padding, boundary, stencil, init)
        dest = Stencils.pad_array(padding, boundary, stencil, init)
    else
        source = deepcopy(init)
        dest = deepcopy(init)
    end
    optdata = _build_optdata(opt, source, R)

    grid = GridData{Mode,S,R}(
        source, dest, stencil, boundary, padding, proc, opt, optdata, mask, maskval
    )
    update_boundary!(grid)
    return grid
end

function ConstructionBase.constructorof(
    ::Type{G}
) where G<:GridData{Mode,S,R} where {Mode,S,R}
    GridData{Mode,S,R}
end

# function Base.parent(d::ReadableGridData{S,<:Any,T,N}) where {S,T,N}
#     SizedArray{S,T,N}(source_array_or_view(d))
# end


# function Base.parent(d::WritableGridData{S,<:Any,T,N}) where {S,T,N}
    # SizedArray{S,T,N}(dest_array_or_view(d))
# end

### UNSAFE / LOCKS required

# Base.setindex!
# This is not safe for general use.
# It can be used where only identical transformations of a cell
# can happen from any other cell, such as setting all 1s to 2.
@propagate_inbounds function Base.setindex!(d::GridData{<:WriteMode}, x, I...)
    _setindex!(d, proc(d), x, I...)
end
@propagate_inbounds function Base.setindex!(d::GridData{<:WriteMode}, x, i1::Int, I::Int...)
    _setindex!(d, proc(d), x, i1, I...)
end

@propagate_inbounds function _setindex!(d::GridData{<:WriteMode}, proc::SingleCPU, x, I...)
    @boundscheck checkbounds(dest(d), I...)
    # @inbounds 
    _setoptindex!(d, x, I...)
    # @inbounds 
    source(d)[I...] = x
end
@propagate_inbounds function _setindex!(d::GridData{<:WriteMode}, proc::ThreadedCPU, x, I...)
    # Dest status is not threadsafe, even if the
    # setindex itself is safe. So we LOCK
    lock(proc)
    # @inbounds 
    _setoptindex!(d, x, I...)
    unlock(proc)
    # @inbounds 
    source(d)[I...] = x
end
@propagate_inbounds function _setindex!(d::GridData{<:SwitchMode}, proc::SingleCPU, x, I...)
    @boundscheck checkbounds(dest(d), I...)
    # @inbounds 
    _setoptindex!(d, x, I...)
    # @inbounds 
    dest(d)[I...] = x # In switch mode we write to `dest`
end
@propagate_inbounds function _setindex!(d::GridData{<:SwitchMode}, proc::ThreadedCPU, x, I...)
    # Dest status is not threadsafe, even if the
    # setindex itself is safe. So we LOCK
    lock(proc)
    # @inbounds 
    _setoptindex!(d, x, I...)
    unlock(proc)
    # @inbounds 
    dest(d)[I...] = x # In switch mode we write to `dest`
end

# _setoptindex!
# Do anything the optimisation needs on `setindex`
_setoptindex!(d::GridData{<:WriteMode,<:Any,R}, x, I...) where R = _setoptindex!(d, opt(d), x, I...)
_setoptindex!(d::GridData{<:WriteMode,<:Any,R}, opt::PerformanceOpt, x, I...) where R = nothing

Stencils.switch(d::Tuple) = map(switch, d)
function Stencils.switch(grids::NamedTuple{<:Any,Tuple{T,Vararg}}) where {T<:GridData{<:SwitchMode}}
    map(switch, grids)
end
function Stencils.switch(A::T) where {T<:GridData{<:SwitchMode}}
    od = switch(opt(A), optdata(A))
    T(dest(A), source(A), stencil(A), boundary(A), padding(A), proc(A), opt(A), od, mask(A), maskval(A))
end
Stencils.switch(::PerformanceOpt, optdata) = optdata

Stencils.after_update_boundary!(grid::GridData) = Stencils.after_update_boundary!(grid, opt(grid))
Stencils.after_update_boundary!(grid::GridData, opt) = grid
