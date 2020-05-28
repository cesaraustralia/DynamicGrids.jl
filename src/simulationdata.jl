
"""
Simulation data specific to a singule grid.
"""
abstract type GridData{T,N,I} <: AbstractArray{T,N} end

# Common fields for GridData and WritableGridData, which are
# identical except for their indexing methods
@mix struct GridDataMixin{T,N,I<:AbstractArray{T,N},M,R,O,S,St,LSt}
    init::I
    mask::M
    radius::R
    overflow::O
    source::S
    dest::S
    sourcestatus::St
    deststatus::St
    localstatus::LSt
end

GridDataOrReps = Union{GridData, Vector{<:GridData}}

(::Type{T})(d::GridData) where T <: GridData =
    T(init(d), mask(d), radius(d), overflow(d), source(d), dest(d),
      sourcestatus(d), deststatus(d), localstatus(d))

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
overflow(d::GridData) = d.overflow
source(d::GridData) = d.source
dest(d::GridData) = d.dest
sourcestatus(d::GridData) = d.sourcestatus
deststatus(d::GridData) = d.deststatus
localstatus(d::GridData) = d.localstatus
gridsize(d::GridData) = size(init(d))


"""
Simulation data and storage passed to rules for each timestep.
"""
@GridDataMixin struct ReadableGridData{} <: GridData{T,N,I} end

# Generate simulation data to match a ruleset and init array.
ReadableGridData(init::AbstractArray, mask, radius, overflow) = begin
    r = radius
    # We add one extra row and column of status blocks so
    # we dont have to worry about special casing the last block
    if r > 0
        hoodsize = 2r + 1
        blocksize = 2r
        source = addpadding(init, r)
        nblocs = indtoblock.(size(source), blocksize) .+ 1
        sourcestatus = zeros(Bool, nblocs)
        deststatus = deepcopy(sourcestatus)
        updatestatus!(source, sourcestatus, deststatus, r)

        localstatus = zeros(Bool, 2, 2)
    else
        source = deepcopy(init)
        sourcestatus = deststatus = true
        localstatus = nothing
    end
    dest = deepcopy(source)

    ReadableGridData(init, mask, radius, overflow, source, dest,
                     sourcestatus, deststatus, localstatus)
end

Base.parent(d::ReadableGridData) = parent(source(d))
Base.@propagate_inbounds Base.getindex(d::ReadableGridData, I...) = getindex(source(d), I...)

"""
WriteableGridData is passed to rules `<: ManualRule`, and can be written to directly as
an array. This handles updates to block optimisations and writing to the correct
source/dest array.
"""
@GridDataMixin struct WritableGridData{} <: GridData{T,N,I} end

Base.@propagate_inbounds Base.setindex!(d::WritableGridData, x, I...) = begin
    r = radius(d)
    @inbounds dest(d)[I...] = x
    if deststatus(d) isa AbstractArray
        @inbounds deststatus(d)[indtoblock.(I .+ r, 2r)...] = true
    end
end

Base.parent(d::WritableGridData) = parent(dest(d))
Base.@propagate_inbounds Base.getindex(d::WritableGridData, I...) = getindex(dest(d), I...)



abstract type AbstractSimData end

"""
Simulation data hold all intermediate arrays, timesteps
and frame numbers for the current frame of the siulation.

A simdata object is accessable in `applyrule` as the second parameter.

Multiple grids can be indexed into using their key. Single grids
can be indexed as if SimData is regular array.
"""
struct SimData{I,D,Ru,TS,CFr} <: AbstractSimData
    init::I
    data::D
    ruleset::Ru
    tspan::TS
    currentframe::CFr
end
SimData(init::AbstractArray, mask::Union{Nothing,AbstractArray}, ruleset::Ruleset, tspan) =
    SimData((_default_=init,), mask, ruleset::Ruleset, tspan)
SimData(init::NamedTuple, mask::Union{Nothing,AbstractArray}, ruleset::Ruleset, tspan) = begin
    # Calculate the neighborhood radus (and grid padding) for each grid
    radii = NamedTuple{keys(init)}(get(radius(ruleset), key, 0) for key in keys(init))
    # Construct the SimData for each grid
    griddata = map(init, radii) do in, ra
        ReadableGridData(in, mask, ra, overflow(ruleset))
    end
    SimData(init, griddata, ruleset, tspan)
end
SimData(init::NamedTuple, griddata::NamedTuple, ruleset::Ruleset, tspan) = begin
    currentframe = 1; 
    SimData(init, griddata, ruleset, tspan, currentframe)
end


# Getters
init(d::SimData) = d.init
ruleset(d::SimData) = d.ruleset
data(d::SimData) = d.data
grids(d::SimData) = d.data
tspan(d::SimData) = d.tspan
starttime(d::SimData) = first(tspan(d))
timestep(d::SimData) = step(tspan(d))
currenttime(d::SimData) = tspan(d)[currentframe(d)]
currenttime(d::Vector{<:SimData}) = currenttime(d[1])
currentframe(d::SimData) = d.currentframe

# Getters forwarded to data
Base.getindex(d::SimData, i) = getindex(grids(d), i)
Base.keys(d::SimData) = keys(grids(d))
Base.values(d::SimData) = values(grids(d))
Base.first(d::SimData) = first(grids(d))
Base.last(d::SimData) = last(grids(d))

gridsize(d::SimData) = gridsize(first(d))
mask(d::SimData) = mask(first(d))
rules(d::SimData) = rules(ruleset(d))
overflow(d::SimData) = overflow(ruleset(d))
opt(d::SimData) = opt(ruleset(d))
timestep(d::SimData) = step(tspan(d))

# Get the actual current timestep, e.g. seconds instead of variable periods like Month
currenttimestep(d::SimData) = currenttime(d) + timestep(d) - currenttime(d)


# Swap source and dest arrays. Allways returns regular SimData.
swapsource(d::Tuple) = map(swapsource, d)
swapsource(data::GridData) = begin
    src = data.source
    dst = data.dest
    @set! data.dest = src
    @set data.source = dst
end

# Uptate timestamp
updatetime(data::SimData, f::Integer) = begin
    @set! data.currentframe = f
end
updatetime(simdata::AbstractVector{<:SimData}, f) = updatetime.(simdata, f)

#=
Find the maximum radius required by all rules
Add padding around the original init array, offset into the negative
So that the first real cell is still 1, 1
=#
addpadding(init::AbstractArray{T,N}, r) where {T,N} = begin
    sze = size(init)
    paddedsize = sze .+ 2r
    paddedindices = -r + 1:sze[1] + r, -r + 1:sze[2] + r
    sourceparent = similar(init, paddedsize...)
    source = OffsetArray(sourceparent, paddedindices...)
    source .= zero(eltype(source))
    # Copy the init array to he middle section of the source array
    for j in 1:size(init, 2), i in 1:size(init, 1)
        @inbounds source[i, j] = init[i, j]
    end
    source
end

#=
Initialise the block status array.
This tracks whether anything has to be done in an area of the main array.
=#
updatestatus!(data::GridData) =
    updatestatus!(parent(source(data)), sourcestatus(data), deststatus(data), radius(data))
updatestatus!(source, sourcestatus::Bool, deststatus::Bool, radius) = nothing
updatestatus!(source, sourcestatus, deststatus, radius) = begin
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
end

copystatus!(data::Tuple{Vararg{<:GridData}}) = map(copystatus!, data)
copystatus!(data::GridData) =
    copystatus!(sourcestatus(data), deststatus(data))
copystatus!(srcstatus, deststatus) = nothing
copystatus!(srcstatus::AbstractArray, deststatus::AbstractArray) =
    @inbounds return srcstatus .= deststatus

# When replicates are an Integer, construct a vector of SimData
initdata!(::Nothing, init, mask, ruleset::Ruleset, tspan, nreplicates::Integer) =
    [SimData(init, mask, ruleset, tspan) for r in 1:nreplicates]
# When simdata is a Vector, the existing SimData arrays are re-initialised
initdata!(simdata::AbstractVector{<:AbstractSimData}, init, mask, ruleset, tspan, nreplicates::Integer) =
    map(d -> initdata!(d, init, mask, ruleset, tspan, nothing), simdata)
# When no simdata is passed in, create new SimData
initdata!(::Nothing, init, mask, ruleset::Ruleset, tspan, nreplicates::Nothing) =
    SimData(init, mask, ruleset, tspan)
# Initialise a SimData object with a new `Ruleset` and tspan.
initdata!(simdata::AbstractSimData, inits::NamedTuple, mask, ruleset::Ruleset, tspan, nreplicates::Nothing) = begin
    map(values(simdata), values(inits)) do grid, init
        for j in 1:gridsize(grid)[2], i in 1:gridsize(grid)[1]
            @inbounds source(grid)[i, j] = dest(grid)[i, j] = init[i, j]
        end
        updatestatus!(grid)
    end
    @set! simdata.ruleset = ruleset
    @set! simdata.tspan = tspan
    simdata
end
initdata!(simdata::AbstractSimData, init::AbstractArray, mask, ruleset::Ruleset, tspan, nreplicates::Nothing) =
    initdata!(simdata, (_default_=init,), mask, ruleset, tspan, nreplicates)

# Convert regular index to block index
indtoblock(x, blocksize) = (x - 1) ÷ blocksize + 1

# Convert block index to regular index
blocktoind(x, blocksize) = (x - 1) * blocksize + 1
