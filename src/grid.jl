
"""
Simulation data specific to a single grid.
"""
abstract type GridData{Y,X,R,T,N,I} <: AbstractArray{T,N} end

function (::Type{G})(d::GridData{Y,X,R,T,N}) where {G<:GridData,Y,X,R,T,N}
    args = init(d), mask(d), proc(d), opt(d), boundary(d), padval(d),
        source(d), dest(d), sourcestatus(d), deststatus(d)
    G{Y,X,R,T,N,map(typeof, args)...}(args...)
end
function ConstructionBase.constructorof(::Type{T}) where T<:GridData{Y,X,R} where {Y,X,R}
    T.name.wrapper{Y,X,R}
end

GridDataOrReps = Union{GridData, Vector{<:GridData}}

# Array interface
Base.size(d::GridData) = size(source(d))
Base.axes(d::GridData) = axes(source(d))
Base.eltype(d::GridData) = eltype(source(d))
Base.firstindex(d::GridData) = firstindex(source(d))
Base.lastindex(d::GridData) = lastindex(source(d))

# Getters
init(d::GridData) = d.init
mask(d::GridData) = d.mask
radius(d::GridData{<:Any,<:Any,R}) where R = R
proc(d::GridData) = d.proc
opt(d::GridData) = d.opt
boundary(d::GridData) = d.boundary
padval(d::GridData) = d.padval
source(d::GridData) = d.source
dest(d::GridData) = d.dest
sourcestatus(d::GridData) = d.sourcestatus
deststatus(d::GridData) = d.deststatus

gridsize(d::GridData) = size(init(d))
gridsize(A::AbstractArray) = size(A)
gridsize(nt::NamedTuple) = gridsize(first(nt))
gridsize(nt::NamedTuple{(),Tuple{}}) = 0, 0
gridaxes(d::GridData) = map(Base.OneTo, gridsize(d))
gridview(d::GridData) = view(parent(dest(d)), map(a -> a .+ radius(d), gridaxes(d))...)


"""
    ReadableGridData(grid::GridData)
    ReadableGridData{Y,X,R}(init::AbstractArray, mask, opt, boundary, padval)

Simulation data and storage passed to rules for each timestep.
"""
struct ReadableGridData{
    Y,X,R,T,N,I<:AbstractArray{T,N},M,P<:Processor,Op<:PerformanceOpt,Ov,PV,S,D,SSt,DSt
} <: GridData{Y,X,R,T,N,I}
    init::I
    mask::M
    proc::P
    opt::Op
    boundary::Ov
    padval::PV
    source::S
    dest::D
    sourcestatus::SSt
    deststatus::DSt
end
function ReadableGridData{Y,X,R}(
    init::I, mask::M, proc::P, opt::Op, boundary::Ov, padval::PV, source::S,
    dest::D, sourcestatus::SSt, deststatus::DSt
) where {Y,X,R,I<:AbstractArray{T,N},M,P,Op,Ov,PV,S,D,SSt,DSt} where {T,N}
    ReadableGridData{Y,X,R,T,N,I,M,P,Op,Ov,PV,S,D,SSt,DSt}(
        init, mask, proc, opt, boundary, padval, source, dest, sourcestatus, deststatus
    )
end
# Generate simulation data to match a ruleset and init array.
@inline function ReadableGridData{X,Y,R}(
    init::AbstractArray, mask, proc, opt, boundary, padval
) where {Y,X,R}
    # We add one extra row and column of status blocks so
    # we dont have to worry about special casing the last block
    if R > 0
        source = _addpadding(init, R, padval)
        dest = _addpadding(init, R, padval)
    else
        if opt isa SparseOpt
            opt = NoOpt()
        end
        source = deepcopy(init)
        dest = deepcopy(init)
    end
    sourcestatus, deststatus = _build_status(opt, source, R)

    grid = ReadableGridData{X,Y,R}(
        init, mask, proc, opt, boundary, padval, source, dest, sourcestatus, deststatus
    )
    _updatestatus!(grid)
    return grid
end

#=
Initialise the block status array.
This tracks whether anything has to be done in an area of the main array.
=#
_updatestatus!(grid::GridData) = _updatestatus!(opt(grid), grid)
function _updatestatus!(opt::SparseOpt, grid)
    blocksize = 2 * radius(grid)
    src = parent(source(grid))
    for i in CartesianIndices(src)
        # Mark the status block if there is a non-zero value
        if !can_skip(opt, src[i])
            bi = _indtoblock.(Tuple(i), blocksize)
            @inbounds sourcestatus(grid)[bi...] = true
            @inbounds deststatus(grid)[bi...] = true
        end
    end
    return nothing
end
_updatestatus!(opt, grid) = nothing

function _copygrid!(grid::GridData{<:Any,<:Any,R}, init) where R
    pad_axes = map(ax -> ax .+ R, axes(init))
    copyto!(parent(source(grid)), CartesianIndices(pad_axes), init, CartesianIndices(init))
    _updatestatus!(grid)
end

# Swap source and dest arrays. Allways returns regular SimData.
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

#=
Find the maximum radius required by all rules
Add padding around the original init array, offset into the negative
So that the first real cell is still 1, 1
=#
function _addpadding(init::AbstractArray{T,N}, r, padval) where {T,N}
    h, w = size(init)
    paddedsize = h + 4r, w + 2r
    paddedindices = -r + 1:h + 3r, -r + 1:w + r
    sourceparent = fill(eltype(init)(padval), paddedsize)
    source = OffsetArray(sourceparent, paddedindices...)
    # Copy the init array to the middle section of the source array
    for j in 1:size(init, 2), i in 1:size(init, 1)
        @inbounds source[i, j] = init[i, j]
    end
    return source
end

Base.parent(d::ReadableGridData) = parent(source(d))

@propagate_inbounds function Base.getindex(d::ReadableGridData, I...)
    getindex(source(d), I...)
end

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
    WritableGridData(grid::GridData)

Passed to rules `<: `, and can be written to directly as
an array. This handles updates to SparseOpt() and writing to
the correct source/dest array.
"""
struct WritableGridData{
    Y,X,R,T,N,I<:AbstractArray{T,N},M,P<:Processor,Op<:PerformanceOpt,Ov,PV,S,D,SSt,DSt
} <: GridData{Y,X,R,T,N,I}
    init::I
    mask::M
    proc::P
    opt::Op
    boundary::Ov
    padval::PV
    source::S
    dest::D
    sourcestatus::SSt
    deststatus::DSt
end
function WritableGridData{Y,X,R}(
    init::I, mask::M, proc::P, opt::Op, boundary::Ov, padval::PV, 
    source::S, dest::D, sourcestatus::SSt, deststatus::DSt
) where {Y,X,R,I<:AbstractArray{T,N},M,P,Op,Ov,PV,S,D,SSt,DSt} where {T,N}
    WritableGridData{Y,X,R,T,N,I,M,P,Op,Ov,PV,S,D,SSt,DSt}(
        init, mask, proc, opt, boundary, padval, source, dest, sourcestatus, deststatus
    )
end

Base.parent(d::WritableGridData) = parent(dest(d))
@propagate_inbounds function Base.getindex(d::WritableGridData, I...)
    getindex(source(d), I...)
end
@propagate_inbounds function Base.setindex!(d::WritableGridData, x, I...)
    _setdeststatus!(d, x, I...)
    dest(d)[I...] = x
end

_setdeststatus!(d::WritableGridData, x, I...) = _setdeststatus!(d::WritableGridData, opt(d), x, I...)
function _setdeststatus!(d::WritableGridData{Y,X,R}, opt::SparseOpt, x, I...) where {Y,X,R}
    blockindex = _indtoblock.(I .+ R, 2R)
    @inbounds deststatus(d)[blockindex...] = !(opt.f(x))
    return nothing
end
_setdeststatus!(d::WritableGridData, opt::PerformanceOpt, x, I...) = nothing

