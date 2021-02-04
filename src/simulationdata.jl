
abstract type AbstractSimData{Y,X} end

"""
    SimData <: AbstractSimData

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
- `boundary(data::SimData)` : returns the [`BoundaryCondition`](@ref) - `Remove` or `Wrap`.
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
struct SimData{Y,X,G<:NamedTuple,E,RS,F,A} <: AbstractSimData{Y,X}
    grids::G
    extent::E
    ruleset::RS
    currentframe::F
    auxframe::A
end
# Get the extent, usually from an Output
SimData(x, ruleset::AbstractRuleset) = SimData(extent(x), ruleset)
# Convert grids in extent to NamedTuple
SimData(extent::AbstractExtent, ruleset::AbstractRuleset) = 
    SimData(_asnamedtuple(extent), ruleset)
function SimData(extent::AbstractExtent{<:NamedTuple{Keys}}, ruleset::AbstractRuleset) where Keys
    # Calculate the neighborhood radus (and grid padding) for each grid
    y, x = gridsize(extent)
    radii = NamedTuple{Keys}(get(radius(ruleset), key, 0) for key in Keys)
    # Construct the SimData for each grid
    grids = map(init(extent), radii, padval(extent)) do in, r, pv
        ReadableGridData{y,x,r}(
            in, mask(extent), proc(ruleset), opt(ruleset), boundary(ruleset), pv 
        )
    end
    SimData(grids, extent, ruleset)
end
function SimData(
    grids::G, extent::AbstractExtent, ruleset::AbstractRuleset
) where {G<:Union{NamedTuple{<:Any,<:Tuple{GridData,Vararg}},GridData}}
    currentframe = 1; auxframe = nothing
    Y, X = gridsize(extent)
    # SimData is isbits-only
    s_extent = StaticExtent(extent)
    s_ruleset = StaticRuleset(ruleset)
    SimData{Y,X,G,typeof(s_extent),typeof(s_ruleset),Int,typeof(auxframe)}(
        grids, s_extent, s_ruleset, currentframe, auxframe
    )
end
# For ConstrutionBase
function SimData{Y,X}(
    grids::G, extent::E, ruleset::RS, currentframe::F, auxframe::A
) where {Y,X,G,E,RS,F,A}
    SimData{Y,X,G,E,RS,F,A}(grids, extent, ruleset, currentframe, auxframe)
end

ConstructionBase.constructorof(::Type{<:SimData{Y,X}}) where {Y,X} = SimData{Y,X}


# Getters
extent(d::SimData) = d.extent
ruleset(d::SimData) = d.ruleset
grids(d::SimData) = d.grids
init(d::SimData) = init(extent(d))
mask(d::SimData) = mask(first(d))
aux(d::SimData, args...) = aux(extent(d), args...)
auxframe(d::SimData, key) = auxframe(d)[_unwrap(key)]
auxframe(d::SimData) = d.auxframe
tspan(d::SimData) = tspan(extent(d))
timestep(d::SimData) = step(tspan(d))
currentframe(d::SimData) = d.currentframe
currenttime(d::SimData) = tspan(d)[currentframe(d)]

# Getters forwarded to data
Base.getindex(d::SimData, key::Symbol) = getindex(grids(d), key)

"""
    Base.get(data::SimData, key::Union{Symbol,Aux,Grid}, I...)

Allows parameters to be taken from a single value, another grid or an aux array.

If aux arrays are a `DimArray` time sequence (with a `Ti` dim) the currect date will be 
calculated automatically.

Currently this is cycled by default, but will use Cyclic mode in DiensionalData.jl in future.
"""
@propagate_inbounds Base.get(data::SimData, val, I...) = val
@propagate_inbounds Base.get(data::SimData, key::Grid{K}, I...) where K = data[K][I...]
@propagate_inbounds Base.get(data::SimData, key::Aux, I...) = _auxval(data, key, I...)

@propagate_inbounds Base.setindex!(d::SimData, x, I...) = setindex!(first(grids(d)), x, I...)
@propagate_inbounds Base.getindex(d::SimData, I...) = getindex(first(grids(d)), I...)
Base.keys(d::SimData) = keys(grids(d))
Base.values(d::SimData) = values(grids(d))
Base.first(d::SimData) = first(grids(d))
Base.last(d::SimData) = last(grids(d))

gridsize(d::SimData) = gridsize(first(d))
proc(d::SimData) = proc(ruleset(d))
opt(d::SimData) = opt(ruleset(d))
boundary(d::SimData) = boundary(ruleset(d))
padval(d::SimData) = padval(extent(d))
rules(d::SimData) = rules(ruleset(d))

# Get the actual current timestep, e.g. seconds instead of variable periods like Month
currenttimestep(d::SimData) = currenttime(d) + timestep(d) - currenttime(d)


# Uptate timestamp
function _updatetime(simdata::SimData, f::Integer) 
    @set! simdata.currentframe = f
    @set simdata.auxframe = _calc_auxframe(simdata)
end

# When no simdata is passed in, create new SimData
function _initdata!(::Nothing, extent::AbstractExtent, ruleset::AbstractRuleset)
    SimData(extent, ruleset)
end
# Initialise a SimData object with a new `Extent` and `Ruleset`.
function _initdata!(
    simdata::AbstractSimData, extent::AbstractExtent, ruleset::AbstractRuleset
)
    map(_copygrid!, values(simdata), values(init(extent)))
    @set! simdata.extent = StaticExtent(extent)
    @set! simdata.ruleset = StaticRuleset(ruleset)
    simdata
end

# Convert regular index to block index
@inline _indtoblock(x::Int, blocksize::Int) = (x - 1) ÷ blocksize + 1

# Convert block index to regular index
@inline _blocktoind(x, blocksize) = (x - 1) * blocksize + 1
