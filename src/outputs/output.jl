
"""
Outputs are store or display simulation results, usually
as a vector of grids, one for each timestep - but they may also
sum, combine or otherwise manipulate the simulation grids to improve
performance, reduce memory overheads or similar.

Simulation outputs are decoupled from simulation behaviour,
and in many cases can be used interchangeably.
"""
abstract type Output{T} <: AbstractVector{T} end

# Generic ImageOutput constructor. Converts an init array to vector of arrays.
(::Type{T})(init::Union{NamedTuple,AbstractMatrix}; extent=nothing, kwargs...) where T <: Output = begin
    extent = extent isa Nothing ? Extent(; init=init, kwargs...) : extent
    T(; frames=[deepcopy(init)], running=false, extent=extent, kwargs...)
end

# Forward base methods to the frames array
Base.parent(o::Output) = frames(o)
Base.length(o::Output) = length(frames(o))
Base.size(o::Output) = size(frames(o))
Base.firstindex(o::Output) = firstindex(frames(o))
Base.lastindex(o::Output) = lastindex(frames(o))
Base.@propagate_inbounds Base.getindex(o::Output, i::Union{Int,AbstractVector,Colon}) =
    getindex(frames(o), i)
Base.@propagate_inbounds Base.setindex!(o::Output, x, i::Union{Int,AbstractVector,Colon}) =
    setindex!(frames(o), x, i)
Base.push!(o::Output, x) = push!(frames(o), x)
Base.step(o::Output) = step(tspan(o))

DimensionalData.DimensionalArray(o::Output{<:NamedTuple}; key=first(keys(o[1]))) =
    cat(map(f -> f[key], frames(o)...); dims=timedim(o))
DimensionalData.DimensionalArray(o::Output{<:DimensionalArray}) =
    cat(frames(o)...; dims=timedim(o))
DimensionalData.dims(o::Output) = begin
    ts = tspan(o)
    val = isstored(o) ? ts : ts[end]:step(ts):ts[end]
    (Ti(val; mode=Sampled(Ordered(), Regular(step(ts)), Intervals(Start()))),)
end


# Getters and setters
frames(o::Output) = o.frames
isrunning(o::Output) = o.running
extent(o::Output) = o.extent
init(o::Output) = init(extent(o))
mask(o::Output) = mask(extent(o))
aux(o::Output) = aux(extent(o))
tspan(o::Output) = tspan(extent(o))
timestep(o::Output) = step(tspan(o))

ruleset(o::Output) =
    throw(ArgumentError("No ruleset on the output. Pass one to `sim!` as the second argument"))
fps(o::Output) = nothing

setrunning!(o::Output, val) = o.running = val
settspan!(o::Output, tspan) = settspan!(extent(o), tspan)
setfps!(o::Output, x) = nothing
settimestamp!(o::Output, f) = nothing
setstoppedframe!(o::Output, f) = nothing

"""
    isasync(o::Output)

Check if the output should run asynchonously.
"""
isasync(o::Output) = false

"""
    isastored(o::Output)

Check if the output is storing each frame, or just the the current one.
"""
isstored(o::Output) = true

"""
    isshowable(o::Output)

Check if the output can be shown visually.
"""
isshowable(o::Output, f) = false

"""
    initialise(o::Output)

Initialise the output display, if it has one.
"""
initialise(o::Output) = nothing

"""
    finalise(o::Output)

Finalise the output display, if it has one.
"""
finalise(o::Output) = nothing

"""
    finalise(o::Output, data::SimData)

Finalise the output data, then call `finalise(o)`.
"""
finalise!(o::Output, data::AbstractSimData) = finalise(o)

"""
    delay(o::Output, f)

`Graphic` outputs delay the simulations to match some `fps` rate,
but other outputs just do nothing and continue.
"""
delay(o::Output, f) = nothing

"""
    showframe(o::Output, , data::SimData, f, t)

Show the grid(s) in the output, if it can do that.
"""
showframe(o::Output, args...) = nothing

"""
    frameindex(o::Output, data::SimData)

Get the index of the current frame in the output.

Every frame has an index of 1 if the simulation isn't stored
"""
frameindex(o::Output, data::AbstractSimData) = frameindex(o, currentframe(data))
frameindex(o::Output, f::Int) = isstored(o) ? f : oneunit(f)

"""
    storeframe!(o::Output, data::AbstractSimData)

Store the current simulaiton frame in the output.
"""
storeframe!(output::Output, data::AbstractSimData) = begin
    f = frameindex(output, data)
    checkbounds(output, f)
    storeframe!(eltype(output), output, data, f)
end
storeframe!(::Type{<:NamedTuple}, output::Output, simdata::AbstractSimData, f::Int) = begin
    map(values(grids(simdata)), keys(simdata)) do grid, key
        outgrid = output[f][key]
        _storeloop(outgrid, grid)
    end
end
storeframe!(::Type{<:AbstractArray}, output::Output, simdata::AbstractSimData, f::Int) = begin
    outgrid = output[f]
    _storeloop(outgrid, first(grids(simdata)))
end
_storeloop(outgrid, grid) =
    for j in axes(outgrid, 2), i in axes(outgrid, 1)
        @inbounds outgrid[i, j] = grid[i, j]
    end
# Replicated frames
storeframe!(output::Output{<:AbstractArray}, data::AbstractVector{<:AbstractSimData}) = begin
    f = frameindex(output, data[1])
    outgrid = output[f]
    for I in CartesianIndices(outgrid)
        replicatesum = zero(eltype(outgrid))
        for g in grids.(data)
            @inbounds replicatesum += first(g)[I]
        end
        @inbounds outgrid[I] = replicatesum / length(data)
    end
end
storeframe!(output::Output{<:NamedTuple}, data::AbstractVector{<:AbstractSimData}) = begin
    f = frameindex(output, data[1])
    outgrids = output[f]
    gridsreps = NamedTuple{keys(first(data))}(map(d -> d[key], data) for key in keys(first(data)))
    map(outgrids, gridsreps) do outgrid, gridreps
        for I in CartesianIndices(outgrid)
            replicatesum = zero(eltype(outgrid))
            for gr in gridreps
                @inbounds replicatesum += gr[I]
            end
            @inbounds outgrid[I] = replicatesum / length(data)
        end
    end
end

# Grids are preallocated and reused.
initgrids!(o::Output, init) = initgrids!(o[1], o::Output, init)
# Array grids are copied
initgrids!(grid::AbstractArray, o::Output, init::AbstractArray) = begin
    grid .= init
    # for f = (firstindex(o) + 1):lastindex(o)
        # @inbounds o[f] .= zero(eltype(init))
    # end
    o
end
# The first grid in a named tuple is used if the output is a single Array
initgrids!(grid::AbstractArray, o::Output, init::NamedTuple) =
    initgrids!(grid, o, first(init))
# All arrays are copied if both are named tuples
initgrids!(grids::NamedTuple, o::Output, init::NamedTuple) = begin
    for key in keys(init)
        @inbounds grids[key] .= init[key]
    end
    o
end
