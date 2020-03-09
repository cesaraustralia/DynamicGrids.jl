
"""
Simulation data for a singule ruleset.
"""
abstract type AbstractGridData{T,N,I} end

"""
Common fields for SimData and WritableGridData. Which are basically 
identical except for with methods.
"""
@mix struct GridDataMixin{T,N,I<:AbstractArray{T,N},M,R,S,St,LSt,B}
    init::I
    mask::M
    radius::R
    source::S
    dest::S
    sourcestatus::St
    deststatus::St
    localstatus::LSt
    buffers::B
end

GridDataOrReps = Union{AbstractGridData, Vector{<:AbstractGridData}}

(::Type{T})(data::AbstractGridData) where T <: AbstractGridData =
    T(init(data), mask(data), radius(data), source(data), dest(data), sourcestatus(data), deststatus(data),
      localstatus(data), buffers(data))

# Array interface
Base.length(d::AbstractGridData) = length(source(d))
Base.firstindex(d::AbstractGridData) = firstindex(source(d))
Base.lastindex(d::AbstractGridData) = lastindex(source(d))
Base.size(d::AbstractGridData) = size(source(d))
Base.iterate(d::AbstractGridData, args...) = iterate(source(d), args...)
Base.ndims(::AbstractGridData{T,N}) where {T,N} = N
Base.eltype(::AbstractGridData{T}) where T = T

# Getters
init(d::AbstractGridData) = d.init
mask(d::AbstractGridData) = d.mask
radius(d::AbstractGridData) = d.radius
source(d::AbstractGridData) = d.source
dest(d::AbstractGridData) = d.dest
sourcestatus(d::AbstractGridData) = d.sourcestatus
deststatus(d::AbstractGridData) = d.deststatus
localstatus(d::AbstractGridData) = d.localstatus
buffers(d::AbstractGridData) = d.buffers
framesize(d::AbstractGridData) = size(init(d))

"""
Get the actual current timestep, ie. not variable periods like Month
"""
currenttimestep(d::AbstractGridData) = currenttime(d) + timestep(d) - currenttime(d)


""" 
Simulation data and storage passed to rules for each timestep.
"""
@GridDataMixin struct GridData{} <: AbstractGridData{T,N,I} end

"""
Generate simulation data to match a ruleset and init array.
"""
GridData(init::AbstractArray, mask, radius) = begin
    r = radius
    # We add one extra row/column so we dont have to worry about
    # special casing the last block
    if r > 0
        hoodsize = 2r + 1
        blocksize = 2r
        source = addpadding(init, r)
        nblocs = indtoblock.(size(source), blocksize) .+ 1
        sourcestatus = BitArray(zeros(Bool, nblocs))
        deststatus = deepcopy(sourcestatus)
        updatestatus!(source, sourcestatus, deststatus, r)

        buffers = [zeros(eltype(init), hoodsize, hoodsize) for i in 1:blocksize]
        localstatus = zeros(Bool, 2, 2)
    else
        source = deepcopy(init)
        sourcestatus = deststatus = true
        buffers = nothing
        localstatus = nothing
    end
    dest = deepcopy(source)

    GridData(init, mask, radius, source, dest, sourcestatus, deststatus, localstatus, buffers)
end

ConstructionBase.constructorof(::Type{GridData}) =
    (init, args...) -> GridData{eltype(init),ndims(init),typeof(init),typeof.(args)...}(init, args...)

Base.@propagate_inbounds Base.getindex(d::GridData, I...) = getindex(source(d), I...)



"""
Simulation data hold all intermediate arrays, timesteps
and frame numbers for the current frame of the siulation.

It is accessable from a rule.
"""
abstract type AbstractSimData end

"""
Concrete simulation data.
"""
struct SimData{I,D,Ru,STi,CTi,CFr} <: AbstractSimData
    init::I
    data::D
    ruleset::Ru
    starttime::STi
    currenttime::CTi
    currentframe::CFr
end
SimData(init::AbstractArray, ruleset::Ruleset, starttime) = 
    SimData((_default_=init,), ruleset::Ruleset, starttime) 
SimData(init::NamedTuple, ruleset::Ruleset, starttime) = begin
    # Calculate the neighborhood radus (and grid padding) for each grid
    radii = NamedTuple{keys(init)}(get(radius(ruleset), key, 0) for key in keys(init))
    # Construct the SimData for each grid
    griddata = map((in, ra) -> GridData(in, mask(ruleset), ra), init, radii)
    SimData(init, griddata, ruleset, starttime)
end
SimData(init, griddata, ruleset::Ruleset, starttime) =
    SimData(init, griddata, ruleset, starttime, starttime, 1)


# Getters
init(d::SimData) = d.init
ruleset(d::SimData) = d.ruleset
data(d::SimData) = d.data
starttime(d::SimData) = d.starttime
currenttime(d::SimData) = d.currenttime
currentframe(d::SimData) = d.currentframe

# Getters forwarded to data
Base.getindex(d::SimData, key) = getindex(data(d), key)
Base.keys(d::SimData) = keys(data(d))
Base.values(d::SimData) = values(data(d))
Base.first(d::SimData) = first(data(d))
Base.last(d::SimData) = last(data(d))
framesize(d::SimData) = framesize(first(data(d)))
mask(d::SimData) = mask(ruleset(d))
rules(d::SimData) = rules(ruleset(d))
overflow(d::SimData) = overflow(ruleset(d))
timestep(d::SimData) = timestep(ruleset(d))
cellsize(d::SimData) = cellsize(ruleset(d))


"""
WriteableSimData is passed to rules `<: PartialRule`, and can be written to directly as
an array. This handles updates to block status and writing to the correct source/dest
array. Is always converted back to regular `SimData`.
"""
@GridDataMixin struct WritableGridData{} <: AbstractGridData{T,N,I} end

ConstructionBase.constructorof(::Type{WritableGridData}) =
    (init, args...) -> SimData{eltype(init),ndims(init),typeof(init),typeof.(args)...}(init, args...)

Base.@propagate_inbounds Base.setindex!(d::WritableGridData, x, I...) = begin
    r = radius(d)
    if r > 0
        bi = indtoblock.(I .+ r, 2r)
        deststatus(d)[bi...] = true
    end
    dest(d)[I...] = x
end

Base.@propagate_inbounds Base.getindex(d::WritableGridData, I...) = getindex(dest(d), I...)


"""
Swap source and dest arrays. Allways returns regular SimData.
"""
swapsource(data::AbstractGridData) = begin
    src = data.source
    dst = data.dest
    @set! data.dest = src
    @set data.source = dst
end
swapsource(d::SimData) = @set d.data = map(swapsource, d.data)

"""
Uptate timestamp
"""
updatetime(data::SimData, f::Integer) = begin
    @set! data.currentframe = f
    @set data.currenttime = timefromframe(data, f)
end
updatetime(simdata::AbstractVector{<:SimData}, f) = updatetime.(simdata, f)
updatetime(simdata::SimData, f) =
    @set simdata.data = map(d -> updatetime(d, f), data(simdata))

timefromframe(simdata::AbstractSimData, f::Int) = 
    starttime(simdata) + (f - 1) * timestep(simdata)

"""
Find the maximum radius required by all rules
Add padding around the original init array, offset into the negative
So that the first real cell is still 1, 1
"""
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

"""
Initialise the block status array.
This tracks whether anything has to be done in an area of the main array.
"""
updatestatus!(data::Tuple) = map(updatestatus!, data) 
updatestatus!(data::AbstractSimData) = 
    updatestatus!(parent(source(data)), sourcestatus(data), deststatus(data), radius(data))
updatestatus!(source, sourcestatus::Bool, deststatus::Bool, radius) = nothing
updatestatus!(source, sourcestatus, deststatus, radius) = begin
    blocksize = 2radius
    source = parent(source)
    for i in CartesianIndices(source)
        # Mark the status block if there is a non-zero value
        if source[i] != 0
            bi = indtoblock.(Tuple(i), blocksize)
            sourcestatus[bi...] = true
            deststatus[bi...] = true
        end
    end
end

copystatus!(data::Tuple{Vararg{<:AbstractGridData}}) = map(copystatus!, data)
copystatus!(data::AbstractGridData) =
    copystatus!(sourcestatus(data), deststatus(data))
copystatus!(srcstatus, deststatus) = nothing
copystatus!(srcstatus::AbstractArray, deststatus::AbstractArray) = 
    @inbounds return srcstatus .= deststatus

"""
When simdata is passed in, the existing SimData arrays are re-initialised
"""
initdata!(simdata::AbstractSimData, ruleset, init, starttime, nreplicates) =
    initdata!(simdata, ruleset, init, starttime)
"""
When no simdata is passed in, the existing SimData arrays are re-initialised
"""
initdata!(::Nothing, ruleset::Ruleset, init, starttime, nreplicates::Integer) =
    [initdata!(nothing, ruleset, init, starttime, nothing) for r in 1:nreplicates]
"""
When SimData with replicates is passed in, the existing SimData replicates are re-initialised
"""
initdata!(simdata::AbstractVector{<:AbstractSimData}, ruleset, init, starttime, nreplicates::Integer) =
    map(d -> initdata!(d, ruleset, init, starttime, nothing), simdata)
initdata!(::Nothing, ruleset::Ruleset, init, starttime, nreplicates::Nothing) =
    SimData(init, ruleset, starttime)

"""
Initialise a SimData object with a new `Ruleset` and starttime.
"""
initdata!(simdata::AbstractSimData, ruleset::Ruleset, initgrids, starttime) = begin
    map(values(simdata), initgrids) do data, init
        for j in 1:framesize(data)[2], i in 1:framesize(simdata)[1]
            @inbounds source(data)[i, j] = dest(data)[i, j] = init[i, j]
        end
        updatestatus!(data)
    end
    @set! simdata.ruleset = ruleset
    @set! simdata.starttime = starttime
    simdata
end

"Convert regular index to block index"
indtoblock(x, blocksize) = (x - 1) ÷ blocksize + 1

"Convert block index to regular index"
blocktoind(x, blocksize) = (x - 1) * blocksize + 1
