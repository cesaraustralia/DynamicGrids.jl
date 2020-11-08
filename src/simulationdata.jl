
"""
Simulation data specific to a single grid.
"""
abstract type GridData{T,N,I} <: AbstractArray{T,N} end

function (::Type{T})(d::GridData) where T <: GridData
    T(init(d), mask(d), radius(d), opt(d), overflow(d), source(d), dest(d),
      sourcestatus(d), deststatus(d), localstatus(d))
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
radius(d::GridData) = d.radius
radius(d::Tuple{<:GridData,Vararg}) = map(radius, d)
opt(d::GridData) = d.opt
overflow(d::GridData) = d.overflow
source(d::GridData) = d.source
dest(d::GridData) = d.dest
sourcestatus(d::GridData) = d.sourcestatus
deststatus(d::GridData) = d.deststatus
localstatus(d::GridData) = d.localstatus
gridsize(d::GridData) = size(init(d))
gridsize(A::AbstractArray) = size(A)
gridsize(nt::NamedTuple) = gridsize(first(nt))
gridsize(nt::NamedTuple{(),Tuple{}}) = 0, 0
gridsize(t::Tuple) = gridsize(first(t))
gridsize(t::Tuple{}) = 0, 0


"""
    ReadableGridData(griddata::GridData)
    ReadableGridData(init::AbstractArray, mask, radius, overflow)

Simulation data and storage passed to rules for each timestep.
"""
struct ReadableGridData{T,N,I<:AbstractArray{T,N},M,R,Op,Ov,S,St,LSt} <: GridData{T,N,I}
    init::I
    mask::M
    radius::R
    opt::Op
    overflow::Ov
    source::S
    dest::S
    sourcestatus::St
    deststatus::St
    localstatus::LSt
end
# Generate simulation data to match a ruleset and init array.
function ReadableGridData(init::AbstractArray, mask, radius, opt, overflow)
    r = radius
    # We add one extra row and column of status blocks so
    # we dont have to worry about special casing the last block
    if r > 0
        hoodsize = 2r + 1
        blocksize = 2r
        source = addpadding(init, r)
        dest = addpadding(init, r)
        nblocs = indtoblock.(size(source), blocksize) .+ 1
        sourcestatus = zeros(Bool, nblocs)
        deststatus = zeros(Bool, nblocs)
        updatestatus!(source, sourcestatus, deststatus, r)
        localstatus = zeros(Bool, 2, 2)
    else
        if opt isa SparseOpt
            opt = NoOpt()
        end
        source = deepcopy(init)
        dest = deepcopy(init)
        sourcestatus = deststatus = true
        localstatus = nothing
    end

    ReadableGridData(init, mask, radius, opt, overflow, source, dest,
                     sourcestatus, deststatus, localstatus)
end

Base.parent(d::ReadableGridData) = parent(source(d))

@propagate_inbounds function Base.getindex(d::ReadableGridData, I...)
    getindex(source(d), I...)
end


"""
    ReadableGridData(griddata::GridData)

Passed to rules `<: ManualRule`, and can be written to directly as
an array. This handles updates to SparseOpt() and writing to
the correct source/dest array.
"""
struct WritableGridData{T,N,I<:AbstractArray{T,N},M,R,Op,Ov,S,St,LSt} <: GridData{T,N,I}
    init::I
    mask::M
    radius::R
    opt::Op
    overflow::Ov
    source::S
    dest::S
    sourcestatus::St
    deststatus::St
    localstatus::LSt
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

Base.parent(d::WritableGridData) = parent(dest(d))
@propagate_inbounds function Base.getindex(d::WritableGridData, I...)
    getindex(source(d), I...)
end



abstract type AbstractSimData end

"""
    SimData(extent::Extent, ruleset::Ruleset)

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

These are available, but you probably shouldn't use them and thier behaviour
is not guaranteed in furture versions. They will mean rule is useful only
in specific contexts.

- `extent(d::SimData)` : get the simulation [`Extent`](@ref) object.
- `init(data::SimData)` : get the simulation init `AbstractArray`/`NamedTuple`
- `mask(data::SimData)` : get the simulation mask `AbstractArray`
- `ruleset(d::SimData)` : get the simulation [`Ruleset`](@ref).
- `source(data::SimData)` : get the `source` grid that is being read from.
- `dest(data::SimData)` : get the `dest` grid that is being written to.

"""
struct SimData{G<:NamedTuple,E,R,PR,F} <: AbstractSimData
    grids::G
    extent::E
    ruleset::R
    precalculated_ruleset::PR
    currentframe::F
end
# Convert grids in extent to NamedTuple
SimData(extent, ruleset::Ruleset) =
    SimData(asnamedtuple(extent), ruleset::Ruleset)
SimData(extent::Extent{<:NamedTuple{Keys}}, ruleset::Ruleset) where Keys = begin
    # Calculate the neighborhood radus (and grid padding) for each grid
    radii = NamedTuple{Keys}(get(radius(ruleset), key, 0) for key in Keys)
    # Construct the SimData for each grid
    griddata = map(init(extent), radii) do in, ra
        ReadableGridData(in, mask(extent), ra, opt(ruleset), overflow(ruleset))
    end
    SimData(griddata, extent, ruleset)
end
SimData(griddata::NamedTuple, extent, ruleset::Ruleset) = begin
    currentframe = 1;
    SimData(griddata, extent, ruleset, ruleset, currentframe)
end

# Getters
extent(d::SimData) = d.extent
ruleset(d::SimData) = d.ruleset
precalculated_ruleset(d::SimData) = d.precalculated_ruleset
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
Base.keys(d::SimData) = keys(grids(d))
Base.values(d::SimData) = values(grids(d))
Base.first(d::SimData) = first(grids(d))
Base.last(d::SimData) = last(grids(d))

gridsize(d::SimData) = gridsize(first(d))
opt(d::SimData) = opt(ruleset(d))
overflow(d::SimData) = overflow(ruleset(d))
rules(d::SimData) = rules(ruleset(d))
precalculated_rules(d::SimData) = rules(precalculated_ruleset(d))
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
function addpadding(init::AbstractArray{T,N}, r) where {T,N}
    sze = size(init)
    paddedsize = sze .+ 2r
    paddedindices = -r + 1:sze[1] + r, -r + 1:sze[2] + r
    sourceparent = fill!(similar(init, paddedsize), zero(T))
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
function updatestatus!(grid::GridData)
    updatestatus!(parent(source(grid)), sourcestatus(grid), deststatus(grid), radius(grid))
end
function updatestatus!(source, sourcestatus, deststatus, radius)
    blocksize = 2radius
    source = parent(source)
    for i in CartesianIndices(source)
        # Mark the status block if there is a non-zero value
        if source[i] != 0
            bi = indtoblock.(Tuple(i), blocksize)
            @inbounds sourcestatus[bi...] = true
            @inbounds deststatus[bi...] = true
        end
    end
    return nothing
end
updatestatus!(source, sourcestatus::Bool, deststatus::Bool, radius) = nothing

# When replicates are an Integer, construct a vector of SimData
function initdata!(::Nothing, extent, ruleset::Ruleset, nreplicates::Integer)
    [SimData(extent, ruleset) for r in 1:nreplicates]
end
# When simdata is a Vector, the existing SimData arrays are re-initialised
function initdata!(
    simdata::AbstractVector{<:AbstractSimData}, extent, ruleset, nreplicates::Integer
)
    map(d -> initdata!(d, extent, ruleset, nothing), simdata)
end
# When no simdata is passed in, create new SimData
function initdata!(::Nothing, extent, ruleset::Ruleset, nreplicates::Nothing)
    SimData(extent, ruleset)
end
# Initialise a SimData object with a new `Extent` and `Ruleset`.
function initdata!(
    simdata::AbstractSimData, extent::Extent, ruleset::Ruleset, nreplicates::Nothing
)
    map(values(simdata), values(init(extent))) do grid, init
        for j in 1:gridsize(grid)[2], i in 1:gridsize(grid)[1]
            @inbounds source(grid)[i, j] = dest(grid)[i, j] = init[i, j]
        end
        updatestatus!(grid)
    end
    @set! simdata.extent = extent
    @set! simdata.ruleset = ruleset
    simdata
end

# Convert regular index to block index
indtoblock(x::Int, blocksize::Int) = (x - 1) ÷ blocksize + 1

# Convert block index to regular index
blocktoind(x, blocksize) = (x - 1) * blocksize + 1
