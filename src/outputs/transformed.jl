"""
    TransformedOutput(f, init; tspan::AbstractRange, kw...) 

An output that stores the result of some function `f` of the grid/s.

# Arguments

- `f`: a function or functor that accepts an `AbstractArray` or `NamedTuple` of
    `AbstractArray` with names matching `init`. The `AbstractArray` will be a view into 
    the grid the same size as the init grids, removing any padding that has been added.
- `init`: initialisation `Array` or `NamedTuple` of `Array`

# Keywords

- `tspan`: `AbstractRange` timespan for the simulation
- `aux`: NamedTuple of arbitrary input data. Use `get(data, Aux(:key), I...)` 
    to access from a `Rule` in a type-stable way.
- `mask`: `BitArray` for defining cells that will/will not be run.
- `padval`: padding value for grids with stencil rules. The default is `zero(eltype(init))`.

$EXPERIMENTAL
"""
mutable struct TransformedOutput{T,A<:AbstractVector{T},E,F,B} <: Output{T,A} 
    frames::A
    running::Bool
    extent::E
    f::F
    buffer::B
end
function TransformedOutput(f::Function, init::Union{NamedTuple,AbstractMatrix}; extent=nothing, kw...)
    # We have to handle some things manually as we are changing the standard output frames
    extent = extent isa Nothing ? Extent(; init=init, kw...) : extent
    # Define buffers to copy to before applying `f`
    buffer = init isa NamedTuple ? map(zero, init) : zero(init)
    zeroframe = f(buffer)
    # Build simulation frames from the output of `f` for empty frames
    frames = [deepcopy(zeroframe) for f in eachindex(tspan(extent))]
    # Set the first frame to the output of `f` for `init`
    frames[1] = f(init)

    return TransformedOutput(frames, false, extent, f, buffer)
end
function TransformedOutput(init; kw...)
    throw(ArgumentError("TransformedOutput must be passed a function and the init grid(s) as arguments"))
end

function storeframe!(o::TransformedOutput, data::AbstractSimData) 
    transformed = _transform_grids(o, grids(data))
    i = frameindex(o, data) 
    # Copy the transformed grid/s to the output frames, 
    # instead of just assigning (see issue #169)
    o[i] = _copytransformed!(o[i], transformed)
end

# Copy arrays manually as reducing functions can return the original object without copy.
_copytransformed!(dest::NamedTuple, src::NamedTuple) = map(_copytransformed!, dest, src)
_copytransformed!(dest::AbstractArray, src::AbstractArray) = dest .= src
# Non-array output is just assigned
_copytransformed!(dest, src) = src
_copytransformed!(dest::StaticArray, src::StaticArray) = src

# Multi/named grid simulation, f is passed a NamedTuple
function _transform_grids(o::TransformedOutput, grids::NamedTuple)
    # Make a new named tuple of raw arrays without wrappers, copying
    # to the buffer where an OffsetArray was used for padding.
    # Often it's faster to copy than use a view when f is sum/mean etc.
    nt = map(grids, o.buffer) do g, b
        source(g) isa OffsetArray ? copy!(b, sourceview(g)) : source(g)
    end
    o.f(nt)
end
# Single unnamed grid simulation, f is passed an AbstractArray
function _transform_grids(o::TransformedOutput, grids::NamedTuple{(DEFAULT_KEY,)})
    g = first(grids)
    A = source(g) isa OffsetArray ? copy!(o.buffer, sourceview(g)) : source(g)
    o.f(A)
end

init_output_grids!(o::TransformedOutput, init) = nothing
initdata!(o::TransformedOutput, init) = nothing
