
"""
    AbstractSimData

Supertype for simulation data objects. Thes hold grids, settings other objects required
to run the simulation and potentially requireing access from rules.

An `AbstractSimData` object is accessable in [`applyrule`](@ref) as the first parameter.

Multiple grids can be indexed into using their key if you need to read
from arbitrary locations:

```julia
funciton applyrule(data::AbstractSimData, rule::SomeRule{Tuple{A,B}},W}, (a, b), I) where {A,B,W}
    grid_a = data[A]
    grid_b = data[B]
    ...
```

In single-grid simulations `AbstractSimData` objects can be indexed directly as 
if they are a `Matrix`.

## Methods

- `currentframe(data)`: get the current frame number, an `Int`
- `currenttime(data)`: the current frame time, which `isa eltype(tspan)`
- `aux(data, args...)`: get the `aux` data `NamedTuple`, or `Nothing`.
    adding a `Symbol` or `Val{:symbol}` argument will get a field of aux.
- `tspan(data)`: get the simulation time span, an `AbstractRange`.
- `timestep(data)`: get the simulaiton time step.
- `boundary(data)` : returns the [`BoundaryCondition`](@ref) - `Remove` or `Wrap`.
- `padval(data)` : returns the value to use as grid border padding.

These are available, but you probably shouldn't use them and their behaviour
is not guaranteed in furture versions. They will mean rule is useful only
in specific contexts.

- `settings(data)`: get the simulaitons [`SimSettings`](@ref) object.
- `extent(data)` : get the simulation [`AbstractExtent`](@ref) object.
- `init(data)` : get the simulation init `AbstractArray`/`NamedTuple`
- `mask(data)` : get the simulation mask `AbstractArray`
- `source(data)` : get the `source` grid that is being read from.
- `dest(data)` : get the `dest` grid that is being written to.
- `radius(data)` : returns the `Int` radius used on the grid,
    which is also the amount of border padding.
"""
abstract type AbstractSimData{S} end

@propagate_inbounds Base.setindex!(d::AbstractSimData, x, I...) = setindex!(first(grids(d)), x, I...)
@propagate_inbounds Base.getindex(d::AbstractSimData, I...) = getindex(first(grids(d)), I...)
Base.keys(d::AbstractSimData) = keys(grids(d))
Base.values(d::AbstractSimData) = values(grids(d))
Base.first(d::AbstractSimData) = first(grids(d))
Base.last(d::AbstractSimData) = last(grids(d))

gridsize(d::AbstractSimData) = gridsize(first(d))
padval(d::AbstractSimData) = padval(extent(d))

extent(d::AbstractSimData) = d.extent
grids(d::AbstractSimData) = d.grids
init(d::AbstractSimData) = init(extent(d))
mask(d::AbstractSimData) = mask(first(d))
aux(d::AbstractSimData, args...) = aux(extent(d), args...)
auxframe(d::AbstractSimData, key) = auxframe(d)[_unwrap(key)]
auxframe(d::AbstractSimData) = d.auxframe
tspan(d::AbstractSimData) = tspan(extent(d))
timestep(d::AbstractSimData) = step(tspan(d))
currentframe(d::AbstractSimData) = d.currentframe
currenttime(d::AbstractSimData) = tspan(d)[currentframe(d)]

# Getters forwarded to data
Base.getindex(d::AbstractSimData, key::Symbol) = getindex(grids(d), key)

# Get the actual current timestep, e.g. seconds instead of variable periods like Month
currenttimestep(d::AbstractSimData) = currenttime(d) + timestep(d) - currenttime(d)


# Uptate timestamp
function _updatetime(simdata::AbstractSimData, f::Integer) 
    @set! simdata.currentframe = f
    @set simdata.auxframe = _calc_auxframe(simdata)
end

# Convert regular index to block index
@inline _indtoblock(x::Int, blocksize::Int) = (x - 1) ÷ blocksize + 1

# Convert block index to regular index
@inline _blocktoind(x, blocksize) = (x - 1) * blocksize + 1


"""
    SimData <: AbstractSimData

    SimData(extent::AbstractExtent, ruleset::AbstractRuleset)

Simulation dataset to hold all intermediate arrays, timesteps
and frame numbers for the current frame of the simulation.

Additional methods not found in `AbstractSimData`:

- `rules(d::SimData)` : get the simulation rules.
- `ruleset(d::SimData)` : get the simulation [`AbstractRuleset`](@ref).
"""
struct SimData{S<:Tuple,G<:NamedTuple,E,RS,F,A} <: AbstractSimData{S}
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
    S = Val{Tuple{gridsize(extent)...}}()
    radii = map(k-> Val{get(radius(ruleset), k, 0)}(), Keys)
    radii = NamedTuple{Keys}(radii)
    grids = _buildgrids(extent, ruleset, S, radii)
    # Construct the SimData for each grid
    SimData(grids, extent, ruleset)
end
function SimData(
    grids::G, extent::AbstractExtent, ruleset::AbstractRuleset
) where {G<:Union{NamedTuple{<:Any,<:Tuple{GridData,Vararg}},GridData}}
    currentframe = 1; auxframe = nothing
    S = Tuple{gridsize(extent)...}
    # SimData is isbits-only
    s_extent = StaticExtent(extent)
    s_ruleset = StaticRuleset(ruleset)
    SimData{S,G,typeof(s_extent),typeof(s_ruleset),Int,typeof(auxframe)}(
        grids, s_extent, s_ruleset, currentframe, auxframe
    )
end
# For ConstrutionBase
function SimData{S}(
    grids::G, extent::E, ruleset::RS, currentframe::F, auxframe::A
) where {S,G,E,RS,F,A}
    SimData{S,G,E,RS,F,A}(grids, extent, ruleset, currentframe, auxframe)
end

_buildgrids(extent, ruleset, S, radii::NamedTuple) =
    map((r, in, pv) -> _buildgrids(extent, ruleset, S, r, in, pv), radii, init(extent), padval(extent))
function _buildgrids(extent, ruleset, ::Val{S}, ::Val{R}, init, padval) where {S,R}
    ReadableGridData{S,R}(
        init, mask(extent), proc(ruleset), opt(ruleset), boundary(ruleset), padval 
    )
end

ConstructionBase.constructorof(::Type{<:SimData{S}}) where S = SimData{S}

ruleset(d::SimData) = d.ruleset
rules(d::SimData) = rules(ruleset(d))
boundary(d::SimData) = boundary(ruleset(d))
proc(d::SimData) = proc(ruleset(d))
opt(d::SimData) = opt(ruleset(d))
settings(d::SimData) = settings(ruleset(d))

# When no simdata is passed in, create new AbstractSimData
function _initdata!(::Nothing, extent::AbstractExtent, ruleset::AbstractRuleset)
    SimData(extent, ruleset)
end
# Initialise a AbstractSimData object with a new `Extent` and `Ruleset`.
function _initdata!(
    simdata::SimData, extent::AbstractExtent, ruleset::AbstractRuleset
)
    map(copy!, values(simdata), values(init(extent)))
    @set! simdata.extent = StaticExtent(extent)
    @set! simdata.ruleset = StaticRuleset(ruleset)
    simdata
end


"""
    SimData <: AbstractSimData

    RuleData(extent::AbstractExtent, settings::SimSettings)

`AbstractSimData` object that is passed to rules. Basically 
a trimmed-down version of [`SimData`](@ref).
"""
struct RuleData{S<:Tuple,G<:NamedTuple,E,Se,F,A} <: AbstractSimData{S}
    grids::G
    extent::E
    settings::Se
    currentframe::F
    auxframe::A
end
function RuleData{S}(
    grids::G, extent::E, settings::Se, currentframe::F, auxframe::A
) where {S,G,E,Se,F,A}
    RuleData{S,G,E,Se,F,A}(grids, extent, settings, currentframe, auxframe)
end
function RuleData(d::AbstractSimData{S}) where S
    RuleData{S}(grids(d), extent(d), settings(d), currentframe(d), auxframe(d))
end

ConstructionBase.constructorof(::Type{<:RuleData{S}}) where {S} = RuleData{S}

settings(d::RuleData) = d.settings
boundary(d::RuleData) = boundary(settings(d))
proc(d::RuleData) = proc(settings(d))
opt(d::RuleData) = opt(settings(d))
