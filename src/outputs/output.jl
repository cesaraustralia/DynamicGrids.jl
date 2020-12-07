"""
Outputs are store or display simulation results, usually
as a vector of grids, one for each timestep - but they may also
sum, combine or otherwise manipulate the simulation grids to improve
performance, reduce memory overheads or similar.

Simulation outputs are decoupled from simulation behaviour,
and in many cases can be used interchangeably.
"""
abstract type Output{T,A} <: AbstractDimArray{T,1,Tuple{Ti},A} end
# Generic ImageOutput constructor. Converts an init array to vector of arrays.
function (::Type{T})(
    init::Union{NamedTuple,AbstractMatrix}; extent=nothing, kwargs...
) where T <: Output
    extent = extent isa Nothing ? Extent(; init=init, kwargs...) : extent
    T(; frames=[deepcopy(init)], running=false, extent=extent, kwargs...)
end

# Forward base methods to the frames array
Base.parent(o::Output) = frames(o)
Base.length(o::Output) = length(parent(o))
Base.size(o::Output) = size(parent(o))
Base.firstindex(o::Output) = firstindex(parent(o))
Base.lastindex(o::Output) = lastindex(parent(o))
Base.push!(o::Output, x) = push!(parent(o), x)
Base.step(o::Output) = step(tspan(o))

function DimensionalData.dims(o::Output)
    ts = tspan(o)
    val = isstored(o) ? ts : ts[end]:step(ts):ts[end]
    (Ti(val; mode=Sampled(Ordered(), Regular(step(ts)), Intervals(Start()))),)
end
DimensionalData.refdims(o::Output) = ()
DimensionalData.name(o::Output) = NoName()

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
stoppedframe(o::Output) = lastindex(o)

setrunning!(o::Output, val) = o.running = val
settspan!(o::Output, tspan) = settspan!(extent(o), tspan)
setfps!(o::Output, x) = nothing
settimestamp!(o::Output, f) = nothing
setstoppedframe!(o::Output, f) = nothing

isasync(o::Output) = false
isstored(o::Output) = true
isshowable(o::Output, frame) = false
initialise!(o::Output, data::AbstractSimData) = nothing
finalise!(o::Output, data::AbstractSimData) = nothing
initialisegraphics(o::Output, data::AbstractSimData) = nothing
finalisegraphics(o::Output, data::AbstractSimData) = nothing
delay(o::Output, frame) = nothing
showframe(o::Output, data) = nothing

frameindex(o::Output, data::AbstractSimData) = frameindex(o, currentframe(data))
frameindex(o::Output, f::Int) = isstored(o) ? f : oneunit(f)

function storeframe!(output::Output, data::AbstractSimData)
    checkbounds(output, frameindex(output, data))
    _storeframe!(eltype(output), output, data)
end

function _storeframe!(::Type{<:NamedTuple}, output::Output, data::AbstractSimData)
    map(values(grids(data)), keys(data)) do grid, key
        _copyto_output!(output[frameindex(output, data)][key], grid, proc(grid))
    end
end
function _storeframe!(::Type{<:AbstractArray}, output::Output, data::AbstractSimData)
    grid = first(grids(data))
    _copyto_output!(output[frameindex(output, data)], grid, proc(grid))
end

function _copyto_output!(outgrid, grid, proc::CPU)
    copyto!(outgrid, CartesianIndices(outgrid), source(grid), CartesianIndices(outgrid))
end

# Replicated frames
function storeframe!(output::Output{<:AbstractArray}, data::AbstractVector{<:AbstractSimData})
    f = frameindex(output, data[1])
    outgrid = output[f]
    for I in CartesianIndices(outgrid)
        replicatesum = zero(eltype(outgrid))
        for g in grids.(data)
            @inbounds replicatesum += first(g)[I]
        end
        @inbounds outgrid[I] = replicatesum / length(data)
    end
    return nothing
end
function storeframe!(output::Output{<:NamedTuple}, data::AbstractVector{<:AbstractSimData})
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
    return nothing
end

# Grids are preallocated and reused.
init_output_grids!(o::Output, init) = init_output_grids!(o[1], o::Output, init)
# Array grids are copied
function init_output_grids!(grid::AbstractArray, o::Output, init::AbstractArray)
    grid .= init
    return o
end
# The first grid in a named tuple is used if the output is a single Array
init_output_grids!(grid::AbstractArray, o::Output, init::NamedTuple) =
    init_output_grids!(grid, o, first(init))
# All arrays are copied if both are named tuples
function init_output_grids!(grids::NamedTuple, o::Output, inits::NamedTuple)
    map(grids, inits) do grid, init
        grids .= init
    end
    return o
end
