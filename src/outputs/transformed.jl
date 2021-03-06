"""
    TransformedOutput(f, init; tspan::AbstractRange, kw...) 

An output that stores the result of some function `f` of the grid/s

# Arguments

- `f`: a function or functor that accepts an `AbstractArray` or `NamedTuple` of
    `AbstractArray` with names matchin `init`. The `AbstractArray` will be a view into 
    the grid the same size as the init grids, removing any padding that has been added.
- `init`: initialisation `Array` or `NamedTuple` of `Array`

# Keywords

- `tspan`: `AbstractRange` timespan for the simulation
- `aux`: NamedTuple of arbitrary input data. Use `get(data, Aux(:key), I...)` 
    to access from a `Rule` in a type-stable way.
- `mask`: `BitArray` for defining cells that will/will not be run.
- `padval`: padding value for grids with neighborhood rules. The default is `zero(eltype(init))`.
"""
mutable struct TransformedOutput{T,A<:AbstractVector{T},E,F,B} <: Output{T,A} 
    frames::A
    running::Bool
    extent::E
    f::F
    buffer::B
end
function TransformedOutput(f::Function, init::Union{NamedTuple,AbstractMatrix}; extent=nothing, kw...)
    extent = extent isa Nothing ? Extent(; init=init, kw...) : extent
    buffer = init isa NamedTuple ? map(zero, init) : zero(init)
    frames = append!([f(init)], map(_ -> f(buffer), tspan(extent)))
    TransformedOutput(frames, false, extent, f, buffer)
end
function TransformedOutput(init; kw...)
    throw(ArgumentError("TransformedOutput must be passed a function and the init grid(s) as arguments"))
end

function storeframe!(o::TransformedOutput, data::AbstractSimData) 
    o[frameindex(o, data)] = _store_x(o, grids(data))
end

function _store_x(o::TransformedOutput, grids::NamedTuple)
    # Make a new named tuple of raw arrays without wrappers, copying
    # to the buffer where an OffsetArray was used for padding
    # Often it's faster to copy than use a view when f is sum/mean etc
    nt = map(grids, o.buffer) do g, b
        source(g) isa OffsetArray ? copy!(b, g) : parent(source(g))
    end
    o.f(nt)
end
function _store_x(o::TransformedOutput, grids::NamedTuple{(:_default_,)})
    g = first(grids)
    A = source(g) isa OffsetArray ? copy!(o.buffer, g) : parent(source(g))
    o.f(A)
end

init_output_grids!(o::TransformedOutput, init) = nothing
_initdata!(o::TransformedOutput, init) = nothing
