
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
frames(d::AbstractSimData) = d.frames
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

"""
    SimData <: AbstractSimData

    SimData(extent::AbstractExtent, ruleset::AbstractRuleset)

Simulation dataset to hold all intermediate arrays, timesteps
and frame numbers for the current frame of the simulation.

Additional methods not found in `AbstractSimData`:

- `rules(d::SimData)` : get the simulation rules.
- `ruleset(d::SimData)` : get the simulation [`AbstractRuleset`](@ref).
"""
struct SimData{S<:Tuple,G<:NamedTuple,E,RS,F,CF,AF} <: AbstractSimData{S}
    grids::G
    extent::E
    ruleset::RS
    frames::F
    currentframe::CF
    auxframe::AF
end
function SimData{S}(
    grids::G, extent::E, ruleset::RS, frames::F, currentframe::CF, auxframe::AF
) where {S,G,E,RS,F,CF,AF}
    SimData{S,G,E,RS,F,CF,AF}(grids, extent, ruleset, frames, currentframe, auxframe)
end
SimData(o, ruleset::AbstractRuleset) = SimData(o, extent(o), ruleset)
function SimData(o, extent::AbstractExtent, ruleset::AbstractRuleset)
    frames_ = if hasdelay(rules(ruleset)) 
        isstored(o) || _notstorederror()
        frames(o) 
    else
        nothing 
    end
    SimData(extent, ruleset, frames_)
end
# Convert grids in extent to NamedTuple
SimData(extent::AbstractExtent, ruleset::AbstractRuleset, frames=nothing) = 
    SimData(_asnamedtuple(extent), ruleset)
function SimData(extent::AbstractExtent{<:NamedTuple{Keys}}, ruleset::AbstractRuleset, frames=nothing) where Keys
    # Calculate the neighborhood radus (and grid padding) for each grid

    S = Val{Tuple{gridsize(extent)...}}()
    radii = map(k-> Val{get(radius(ruleset), k, 0)}(), Keys)
    radii = NamedTuple{Keys}(radii)
    grids = _buildgrids(extent, ruleset, S, radii)
    # Construct the SimData for each grid
    SimData(grids, extent, ruleset, frames)
end
function SimData(
    grids::G, extent::AbstractExtent, ruleset::AbstractRuleset, frames
) where {G<:Union{NamedTuple{<:Any,<:Tuple{GridData,Vararg}},GridData}}
    currentframe = 1; auxframe = nothing
    S = Tuple{gridsize(extent)...}
    # SimData is isbits-only
    s_extent = StaticExtent(extent)
    s_ruleset = StaticRuleset(ruleset)
    SimData{S}(grids, s_extent, s_ruleset, frames, currentframe, auxframe)
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
function _initdata!(::Nothing, output, extent::AbstractExtent, ruleset::AbstractRuleset)
    SimData(output, extent, ruleset)
end
# Initialise a AbstractSimData object with a new `Extent` and `Ruleset`.
function _initdata!(
    simdata::SimData, output, extent::AbstractExtent, ruleset::AbstractRuleset
)
    # TODO: make sure this works with delays and new outputs?
    map(copy!, values(simdata), values(init(extent)))
    @set! simdata.extent = StaticExtent(extent)
    @set! simdata.ruleset = StaticRuleset(ruleset)
    if hasdelay(rules(ruleset)) 
        isstored(o) || _not_stored_delay_error()
        @set! simdata.frames = frames(o) 
    end
    simdata
end

"""
    SimData <: AbstractSimData

    RuleData(extent::AbstractExtent, settings::SimSettings)

`AbstractSimData` object that is passed to rules. Basically 
a trimmed-down version of [`SimData`](@ref).
"""
struct RuleData{S<:Tuple,G<:NamedTuple,E,Se,F,CF,AF} <: AbstractSimData{S}
    grids::G
    extent::E
    settings::Se
    frames::F
    currentframe::CF
    auxframe::AF
end
function RuleData{S}(
    grids::G, extent::E, settings::Se, frames::F, currentframe::CF, auxframe::AF
) where {S,G,E,Se,F,CF,AF}
    RuleData{S,G,E,Se,F,CF,AF}(grids, extent, settings, frames, currentframe, auxframe)
end
function RuleData(d::AbstractSimData{S}) where S
    RuleData{S}(grids(d), extent(d), settings(d), frames(d), currentframe(d), auxframe(d))
end

ConstructionBase.constructorof(::Type{<:RuleData{S}}) where {S} = RuleData{S}

settings(d::RuleData) = d.settings
boundary(d::RuleData) = boundary(settings(d))
proc(d::RuleData) = proc(settings(d))
opt(d::RuleData) = opt(settings(d))
