
"""
Simulation data specific to a single grid.
"""
abstract type GridData{Y,X,R,T,N,I} <: AbstractArray{T,N} end

function (::Type{G})(d::GridData{Y,X,R,T,N}) where {G<:GridData,Y,X,R,T,N}
    args = init(d), mask(d), opt(d), overflow(d), padval(d), 
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
radius(d::Tuple{<:GridData,Vararg}) = map(radius, d)
opt(d::GridData) = d.opt
overflow(d::GridData) = d.overflow
padval(d::GridData) = d.padval
source(d::GridData) = d.source
dest(d::GridData) = d.dest
sourcestatus(d::GridData) = d.sourcestatus
deststatus(d::GridData) = d.deststatus
gridsize(d::GridData) = size(init(d))
gridsize(A::AbstractArray) = size(A)
gridsize(nt::NamedTuple) = gridsize(first(nt))
gridsize(nt::NamedTuple{(),Tuple{}}) = 0, 0
gridsize(t::Tuple) = gridsize(first(t))
gridsize(t::Tuple{}) = 0, 0


"""
    ReadableGridData(griddata::GridData)
    ReadableGridData{Y,X,R}(init::AbstractArray, mask, opt, overflow, padval)

Simulation data and storage passed to rules for each timestep.
"""
struct ReadableGridData{Y,X,R,T,N,I<:AbstractArray{T,N},M,Op,Ov,P,S,D,SSt,DSt} <: GridData{Y,X,R,T,N,I}
    init::I
    mask::M
    opt::Op
    overflow::Ov
    padval::P
    source::S
    dest::D
    sourcestatus::SSt
    deststatus::DSt
end
function ReadableGridData{Y,X,R}(
    init::I, mask::M, opt::Op, overflow::Ov, padval::P, source::S, 
    dest::D, sourcestatus::SSt, deststatus::DSt
) where {Y,X,R,I<:AbstractArray{T,N},M,Op,Ov,P,S,D,SSt,DSt} where {T,N}
    ReadableGridData{Y,X,R,T,N,I,M,Op,Ov,P,S,D,SSt,DSt}(
        init, mask, opt, overflow, padval, source, dest, sourcestatus, deststatus
    )
end
# Generate simulation data to match a ruleset and init array.
@inline function ReadableGridData{X,Y,R}(
    init::AbstractArray, mask, opt, overflow, padval
) where {Y,X,R}
    # We add one extra row and column of status blocks so
    # we dont have to worry about special casing the last block
    if R > 0
        source = addpadding(init, R, padval)
        dest = addpadding(init, R, padval)
    else
        if opt isa SparseOpt
            opt = NoOpt()
        end
        source = deepcopy(init)
        dest = deepcopy(init)
    end
    sourcestatus, deststatus = _build_status(opt, source, R)

    grid = ReadableGridData{X,Y,R}(
        init, mask, opt, overflow, padval, source, dest, sourcestatus, deststatus
    )
    updatestatus!(grid)
    return grid
end

Base.parent(d::ReadableGridData) = parent(source(d))

@propagate_inbounds function Base.getindex(d::ReadableGridData, I...)
    getindex(source(d), I...)
end

function _build_status(opt::SparseOpt, source, r)
    hoodsize = 2r + 1
    blocksize = 2r
    nblocs = indtoblock.(size(source), blocksize) .+ 1
    sourcestatus = zeros(Bool, nblocs)
    deststatus = zeros(Bool, nblocs)
    sourcestatus, deststatus
end
_build_status(opt::PerformanceOpt, init, r) = nothing, nothing


"""
    ReadableGridData(griddata::GridData)

Passed to rules `<: ManualRule`, and can be written to directly as
an array. This handles updates to SparseOpt() and writing to
the correct source/dest array.
"""
struct WritableGridData{Y,X,R,T,N,I<:AbstractArray{T,N},M,Op,Ov,P,S,D,SSt,DSt} <: GridData{Y,X,R,T,N,I}
    init::I
    mask::M
    opt::Op
    overflow::Ov
    padval::P
    source::S
    dest::D
    sourcestatus::SSt
    deststatus::DSt
end
function WritableGridData{Y,X,R}(
    init::I, mask::M, opt::Op, overflow::Ov, padval::P, source::S, 
    dest::D, sourcestatus::SSt, deststatus::DSt
) where {Y,X,R,I<:AbstractArray{T,N},M,Op,Ov,P,S,D,SSt,DSt} where {T,N}
    WritableGridData{Y,X,R,T,N,I,M,Op,Ov,P,S,D,SSt,DSt}(
        init, mask, opt, overflow, padval, source, dest, sourcestatus, deststatus
    )
end

Base.parent(d::WritableGridData) = parent(dest(d))
@propagate_inbounds function Base.getindex(d::WritableGridData, I...)
    getindex(source(d), I...)
end
Base.@propagate_inbounds Base.setindex!(d::WritableGridData, x, I...) = begin
    r = radius(d)
    _setdeststatus!(d, x, I)
    dest(d)[I...] = x
end

# Methods for writing to a WritableGridData grid from ManualRule. These are (approximately)
# associative and commutative so that write order does not affect the result.
for (f, op) in ((:add!, :+), (:sub!, :-), (:and!, :&), (:or!, :|), (:xor!, :xor))
    @eval begin
        @propagate_inbounds function ($f)(d::WritableGridData, x, I...)
            @boundscheck checkbounds(dest(d), I...)
            @inbounds _setdeststatus!(d, x, I)
            @inbounds ($f)(dest(d), x, I...)
        end
        @propagate_inbounds ($f)(A::AbstractArray, x, I...) = A[I...] = ($op)(A[I...], x)
    end
end

_setdeststatus!(d::WritableGridData, x, I) = _setdeststatus!(d::WritableGridData, opt(d), x, I) 
function _setdeststatus!(d::WritableGridData, opt::SparseOpt, x, I)
    r = radius(d)
    blockindex = indtoblock.(I .+ r, 2r)
    @inbounds deststatus(d)[blockindex...] = !(opt.f(x))
    return nothing
end
_setdeststatus!(d::WritableGridData, opt, x, I) = nothing



abstract type AbstractSimData{Y,X} end

"""
    SimData(extent::AbstractExtent, ruleset::AbstractRuleset)

Simulation dataset to hold all intermediate arrays, timesteps
and frame numbers for the current frame of the simulation.

A simdata object is accessable in [`applyrule`](@ref) as the first parameter.

Multiple grids can be indexed into using their key if you need to read
from arbitrary locations:

```julia
funciton applyrule(data::SimData, rule::SomeRule{Tuple{A,B}},W}, (a, b), cellindex) where {A,B,W}
    grid_a = data[A]
    grid_b = data[B]
    ...
```

In single grid simulations `SimData` can be indexed directly as if it is a `Matrix`.

## Methods

- `currentframe(data::SimData)`: get the current frame number, an `Int`
- `currenttime(data::SimData)`: the current frame time, which `isa eltype(tspan)`
- `aux(d::SimData, args...)`: get the `aux` data `NamedTuple`, or `Nothing`.
  adding a `Symbol` or `Val{:symbol}` argument will get a field of aux.
- `tspan(d::SimData)`: get the simulation time span, an `AbstractRange`.
- `timestep(d::SimData)`: get the simulaiton time step.
- `radius(data::SimData)` : returns the `Int` radius used on the grid,
  which is also the amount of border padding.
- `overflow(data::SimData)` : returns the [`Overflow`](@ref) - `RemoveOverflow` or `WrapOverflow`.
- `padval(data::SimData)` : returns the value to use as grid border padding.

These are available, but you probably shouldn't use them and thier behaviour
is not guaranteed in furture versions. They will mean rule is useful only
in specific contexts.

- `extent(d::SimData)` : get the simulation [`AbstractExtent`](@ref) object.
- `init(data::SimData)` : get the simulation init `AbstractArray`/`NamedTuple`
- `mask(data::SimData)` : get the simulation mask `AbstractArray`
- `ruleset(d::SimData)` : get the simulation [`AbstractRuleset`](@ref).
- `source(data::SimData)` : get the `source` grid that is being read from.
- `dest(data::SimData)` : get the `dest` grid that is being written to.

"""
struct SimData{Y,X,G<:NamedTuple,E,RS,F} <: AbstractSimData{Y,X}
    grids::G
    extent::E
    ruleset::RS
    currentframe::F
end
# Convert grids in extent to NamedTuple
SimData(extent, ruleset::AbstractRuleset) = SimData(asnamedtuple(extent), ruleset)
SimData(extent::AbstractExtent{<:NamedTuple{Keys}}, ruleset::AbstractRuleset) where Keys = begin
    # Calculate the neighborhood radus (and grid padding) for each grid
    y, x = gridsize(extent)
    radii = NamedTuple{Keys}(get(radius(ruleset), key, 0) for key in Keys)
    # Construct the SimData for each grid
    grids = map(init(extent), radii) do in, r
        ReadableGridData{y,x,r}(
            in, mask(extent), opt(ruleset), overflow(ruleset), padval(ruleset)
        )
    end
    SimData(grids, extent, ruleset)
end
@inline SimData(grids::G, extent::E, ruleset::AbstractRuleset) where {G,E} = begin
    currentframe = 1;
    Y, X = gridsize(extent)
    # SimData is isbits-only
    s_extent = StaticExtent(extent)
    s_ruleset = StaticRuleset(ruleset)
    SimData{Y,X,G,typeof(s_extent),typeof(s_ruleset),Int}(
        grids, s_extent, s_ruleset, currentframe
    )
end
# For ConstrutionBase
SimData{Y,X}(
    grids::G, extent::E, ruleset::RS, currentframe::F
) where {Y,X,G,E,RS,F} = begin
    SimData{Y,X,G,E,RS,F}(grids, extent, ruleset, currentframe)
end
ConstructionBase.constructorof(::Type{<:SimData{Y,X}}) where {Y,X} = SimData{Y,X}

# Getters
extent(d::SimData) = d.extent
ruleset(d::SimData) = d.ruleset
grids(d::SimData) = d.grids
init(d::SimData) = init(extent(d))
mask(d::SimData) = mask(first(d))
aux(d::SimData, args...) = aux(extent(d), args...)
tspan(d::SimData) = tspan(extent(d))
timestep(d::SimData) = step(tspan(d))
currentframe(d::SimData) = d.currentframe
currenttime(d::SimData) = tspan(d)[currentframe(d)]
currenttime(d::Vector{<:SimData}) = currenttime(d[1])
@inline add(d::SimData, x, I...) = add(firs(d), x, I...)


# Getters forwarded to data
Base.getindex(d::SimData, i::Symbol) = getindex(grids(d), i)

@propagate_inbounds Base.setindex!(d::SimData, x, I...) = setindex!(first(grids(d)), x, I...)
@propagate_inbounds Base.getindex(d::SimData, I...) = getindex(first(grids(d)), I...)
Base.keys(d::SimData) = keys(grids(d))
Base.values(d::SimData) = values(grids(d))
Base.first(d::SimData) = first(grids(d))
Base.last(d::SimData) = last(grids(d))

gridsize(d::SimData) = gridsize(first(d))
opt(d::SimData) = opt(ruleset(d))
overflow(d::SimData) = overflow(ruleset(d))
padval(d::SimData) = padval(ruleset(d))
rules(d::SimData) = rules(ruleset(d))
cellsize(d::SimData) = cellsize(ruleset(d))

# Get the actual current timestep, e.g. seconds instead of variable periods like Month
currenttimestep(d::SimData) = currenttime(d) + timestep(d) - currenttime(d)


# Swap source and dest arrays. Allways returns regular SimData.
swapsource(d::Tuple) = map(swapsource, d)
function swapsource(grid::GridData)
    src = grid.source
    dst = grid.dest
    @set! grid.dest = src
    @set! grid.source = dst
    srcstatus = grid.sourcestatus
    dststatus = grid.deststatus
    @set! grid.deststatus = srcstatus
    return @set grid.sourcestatus = dststatus
end

# Uptate timestamp
updatetime(simdata::SimData, f::Integer) = @set! simdata.currentframe = f
updatetime(simdata::AbstractVector{<:SimData}, f) = updatetime.(simdata, f)

#=
Find the maximum radius required by all rules
Add padding around the original init array, offset into the negative
So that the first real cell is still 1, 1
=#
function addpadding(init::AbstractArray{T,N}, r, padval) where {T,N}
    h, w = size(init)
    paddedsize = h + 4r, w + 2r
    paddedindices = -r + 1:h + 3r, -r + 1:w + r
    sourceparent = fill!(similar(init, paddedsize), padval)
    source = OffsetArray(sourceparent, paddedindices...)
    # Copy the init array to the middle section of the source array
    for j in 1:size(init, 2), i in 1:size(init, 1)
        @inbounds source[i, j] = init[i, j]
    end
    return source
end

#=
Initialise the block status array.
This tracks whether anything has to be done in an area of the main array.
=#
updatestatus!(grid::GridData) = updatestatus!(opt(grid), grid)
function updatestatus!(opt::SparseOpt, grid)
    blocksize = 2 * radius(grid)
    src = parent(source(grid))
    for i in CartesianIndices(src)
        # Mark the status block if there is a non-zero value
        if !can_skip(opt, src[i])
            bi = indtoblock.(Tuple(i), blocksize)
            @inbounds sourcestatus(grid)[bi...] = true
            @inbounds deststatus(grid)[bi...] = true
        end
    end
    return nothing
end
updatestatus!(opt, grid) = nothing

# When replicates are an Integer, construct a vector of SimData
function initdata!(::Nothing, extent, ruleset::AbstractRuleset, nreplicates::Integer)
    [SimData(extent, ruleset) for r in 1:nreplicates]
end
# When simdata is a Vector, the existing SimData arrays are re-initialised
function initdata!(
    simdata::AbstractVector{<:AbstractSimData}, extent, ruleset, nreplicates::Integer
)
    map(d -> initdata!(d, extent, ruleset, nothing), simdata)
end
# When no simdata is passed in, create new SimData
function initdata!(::Nothing, extent, ruleset::AbstractRuleset, nreplicates::Nothing)
    SimData(extent, ruleset)
end
# Initialise a SimData object with a new `Extent` and `Ruleset`.
function initdata!(
    simdata::AbstractSimData, extent::AbstractExtent, ruleset::AbstractRuleset, nreplicates::Nothing
)
    map(_copygrids!, values(simdata), values(init(extent)))
    @set! simdata.extent = StaticExtent(extent)
    @set! simdata.ruleset = StaticRuleset(ruleset)
    simdata
end

function _copygrids!(grid::GridData{<:Any,<:Any,R}, init) where R
    pad_axes = map(ax -> ax .+ R, axes(init))
    copyto!(parent(source(grid)), CartesianIndices(pad_axes), init, CartesianIndices(init))
    updatestatus!(grid)
end

# Convert regular index to block index
@inline indtoblock(x::Int, blocksize::Int) = (x - 1) ÷ blocksize + 1

# Convert block index to regular index
@inline blocktoind(x, blocksize) = (x - 1) * blocksize + 1
