
"""
    Neighborhood

Neighborhoods define the pattern of surrounding cells in the "neighborhood"
of the current cell. The `neighbors` function returns the surrounding
cells as an iterable.

The main kinds of neighborhood are demonstrated below:

![Neighborhoods](https://raw.githubusercontent.com/cesaraustralia/DynamicGrids.jl/media/Neighborhoods.png)

Neighborhoods can be used in [`NeighborhoodRule`](@ref) and [`SetNeighborhoodRule`](@ref) -
the same shapes with different purposes. In a `NeighborhoodRule` the neighborhood specifies
which cells around the current cell are returned as an iterable from the `neighbors` function.
These can be counted, summed, compared, or multiplied with a kernel in an
`AbstractKernelNeighborhood`, using [`kernelproduct`](@ref).

In `SetNeighborhoodRule` neighborhoods give the locations of cells around the central cell,
as [`offsets`] and absolute [`positions`](@ref) around the index of each neighbor. These
can then be written to manually.
"""
abstract type Neighborhood{R,N,L} end

ConstructionBase.constructorof(::Type{<:T}) where T <: Neighborhood{R,N,L} where {R,N,L} =
    T.name.wrapper{R,N,L}

radius(hood::Neighborhood{R}) where R = R
neighbors(hood::Neighborhood) = map(i -> _buffer(hood)[i], bufindices(hood))
_buffer(hood::Neighborhood) = hood._buffer
@inline positions(hood::Neighborhood, I) = map(o -> o .+ I, offsets(hood))
# @inline function bufindices(hood::Neighborhood{R}) where R
#     # Offsets can be anywhere in the buffer, specified with
#     # all dimensions.  Here we transform them to a linear index.
#     map(offsets(hood)) do o
#         i = o[1] + (R + 1)
#         j = o[2] + (R + 1)
#         i + (j - 1) * (2R + 1)
#     end
# end
@inline bufindices(hood::Neighborhood) = bufindices(hood, _buffer(hood))
@inline function bufindices(hood::Neighborhood{R,N}, buffer::AbstractArray{<:Any,N}) where {R,N}
    # Offsets can be anywhere in the buffer, specified with
    # all dimensions. Here we transform them to a linear index.
    bi = map(offsets(hood)) do o
        # Calculate strides
        S = 2R + 1
        strides = ntuple(i -> S^(i-1), N)
        # offesets indices are centered, we want them as regular array indices
        # Return the linear index in the square buffer
        sum(map((i, s) -> (i + R) * s, o, strides)) + 1
    end
    return bi
end

Base.eltype(hood::Neighborhood) = eltype(_buffer(hood))
Base.length(hood::Neighborhood{<:Any,<:Any,L}) where L = L
Base.ndims(hood::Neighborhood{<:Any,N}) where N = N
Base.iterate(hood::Neighborhood, args...) = iterate(neighbors(hood), args...)
Base.getindex(hood::Neighborhood, i) = getindex(_buffer(hood), bufindices(hood)[i])

"""
    RadialNeighborhood <: Neighborhood

Square neighborhoods with radius `R`, and side length `2R + 1`
"""
abstract type RadialNeighborhood{R,N,L} <: Neighborhood{R,N,L} end

"""
    Moore <: RadialNeighborhood

    Moore(radius::Int=1; ndims=2)
    Moore(; radius=1, ndims=2)
    Moore{R}(; ndims=2)
    Moore{R,N}()

Moore neighborhoods define the neighborhood as all cells within a horizontal or
vertical distance of the central cell. The central cell is omitted.
"""
struct Moore{R,N,L,B} <: RadialNeighborhood{R,N,L}
    _buffer::B
end
# Buffer is updated later during the simulation.
Moore(radius::Int=1; ndims=2) = Moore{radius,ndims}()
Moore(args...; radius=1, ndims=2) = Moore{radius,ndims}(args...)
Moore{R}(_buffer=nothing; ndims=2) where R = Moore{R,ndims,}(_buffer)
Moore{R,N}(_buffer=nothing) where {R,N} = Moore{R,N,(2R+1)^N-1}(_buffer)
Moore{R,N,L}(_buffer::B=nothing) where {R,N,L,B} = Moore{R,N,L,B}(_buffer)

@generated function bufindices(hood::Moore{R,N}) where {R,N}
    buflen = (2R + 1)^N # Use linear indexing
    centerpoint = buflen ÷ 2 + 1
    exp = Expr(:tuple)
    for i in 1:buflen
        if i != centerpoint
            push!(exp.args, :($i))
        end
    end
    return exp
end
offsets(hood::Moore) = _offsets(hood, _buffer(hood))
@generated function _offsets(hood::Moore{R,N}, buffer) where {R,N}
    exp = Expr(:tuple)
    for I in CartesianIndices(ntuple(_-> -R:R, N))
        if !all(map(iszero, Tuple(I)))
            push!(exp.args, :($(Tuple(I))))
        end
    end
    return exp
end
@inline _setbuffer(n::Moore{R,N,L}, buf::B2) where {R,N,L,B2} = Moore{R,N,L,B2}(buf)

# Neighborhood specific `sum` for performance
Base.sum(hood::Moore) = sum(_buffer(hood)) - _centerval(hood)

_centerval(hood::Neighborhood) = _centerval(hood, _buffer(hood))
function _centerval(hood::Neighborhood{R,N}, buffer::AbstractArray{<:Any,N}) where {R,N}
    I = ntuple(_ -> R + 1, N)
    buffer[I...]
end

"""
    Window <: RadialNeighborhood

    Window(; radius=1, ndims=2)
    Window{R}(; ndims=2)
    Window{R,N}()

A neighboorhood of radius R that includes the central cell.
`R = 1` gives a 3x3 matrix.
"""
struct Window{R,N,L,B} <: RadialNeighborhood{R,N,L}
    _buffer::B
end
Window(args...; radius=1, ndims=2) = Window{radius,ndims}(args...)
Window(R::Int, args...; ndims=2) = Window{R,ndims}(args...)
Window{R}(_buffer=nothing; ndims=2) where {R} = Window{R,ndims}(_buffer)
Window{R,N}(_buffer=nothing) where {R,N} = Window{R,N,(2R+1)^N}(_buffer)
Window{R,N,L}(_buffer::B=nothing) where {R,N,L,B} = Window{R,N,L,B}(_buffer)
Window(A::AbstractArray) = Window{(size(A, 1) - 1) ÷ 2,ndims(A)}()


@inline _setbuffer(::Window{R,N,L}, buf::B2) where {R,N,L,B2} = Window{R,N,L,B2}(buf)

# The central cell is included
@inline function offsets(hood::Window{R,2}) where R
    D = 2R + 1
    ntuple(i -> (rem(i-1, D)-R, (i-1) ÷ D - R), D^2)
end
@inline function offsets(hood::Window{R,1}) where R
    D = 2R + 1
    ntuple(i -> (rem(i-1, D)-R, (i-1) ÷ D - R), D^1)
end
bufindices(hood::Window{R,N}) where {R,N} = Base.OneTo((2R+1)^N)

neighbors(hood::Window) = _buffer(hood)

"""
    AbstractKernelNeighborhood <: Neighborhood

Abstract supertype for kernel neighborhoods.

These can wrap any other neighborhood object, and include a kernel of
the same length and positions as the neighborhood.
"""
abstract type AbstractKernelNeighborhood{R,N,L} <: Neighborhood{R,N,L} end

neighborhood(hood::AbstractKernelNeighborhood) = hood.neighborhood
neighbors(hood::AbstractKernelNeighborhood) = neighbors(neighborhood(hood))
offsets(hood::AbstractKernelNeighborhood) = offsets(neighborhood(hood))
positions(hood::AbstractKernelNeighborhood, I) = positions(neighborhood(hood), I)
kernel(hood::AbstractKernelNeighborhood) = hood.kernel

kernelproduct(hood::AbstractKernelNeighborhood) =
    kernelproduct(neighborhood(hood), kernel(hood))
function kernelproduct(hood::Neighborhood{<:Any,<:Any,L}, kernel) where L
    sum = zero(first(hood))
    @simd for i in 1:L
        sum += hood[i] * kernel[i]
    end
    return sum
end
function kernelproduct(hood::Window{<:Any,<:Any,L}, kernel) where L
    sum = zero(first(hood))
    @simd for i in 1:L
        @inbounds sum += _buffer(hood)[i] * kernel[i]
    end
    return sum
end

"""
    Kernel <: AbstractKernelNeighborhood

    Kernel(neighborhood, kernel)

Wrap any other neighborhood object, and includes a kernel of
the same length and positions as the neighborhood.

`R = 1` gives 3x3 matrices.
"""
struct Kernel{R,N,L,H,K} <: AbstractKernelNeighborhood{R,N,L}
    neighborhood::H
    kernel::K
end
Kernel(A::AbstractMatrix) = Kernel(Window(A), A)
function Kernel(hood::H, kernel::K) where {H<:Neighborhood{R,N,L},K} where {R,N,L}
    length(hood) == length(kernel) || _kernel_length_error(hood, kernel)
    Kernel{R,N,L,H,K}(hood, kernel)
end
function Kernel{R,N,L}(hood::H, kernel::K) where {R,N,L,H<:Neighborhood{R,N,L},K}
    Kernel{R,N,L,H,K}(hood, kernel)
end

function _kernel_length_error(hood, kernel)
    throw(ArgumentError("Neighborhood length $(length(hood)) does not match kernel length $(length(kernel))"))
end

function _setbuffer(n::Kernel{R,N,L,<:Any,K}, buf) where {R,N,L,K}
    hood = _setbuffer(neighborhood(n), buf)
    return Kernel{R,N,L,typeof(hood),K}(hood, kernel(n))
end

"""
    AbstractPositionalNeighborhood <: Neighborhood

Neighborhoods are tuples or vectors of custom coordinates tuples
that are specified in relation to the central point of the current cell.
They can be any arbitrary shape or size, but should be listed in column-major
order for performance.
"""
abstract type AbstractPositionalNeighborhood{R,N,L} <: Neighborhood{R,N,L} end

const CustomOffset = Tuple{Vararg{Int}}
const CustomOffsets = Union{AbstractArray{<:CustomOffset},Tuple{Vararg{<:CustomOffset}}}

"""
    Positional <: AbstractPositionalNeighborhood

    Positional(coord::Tuple{Vararg{Int}}...)
    Positional(offsets::Tuple{Tuple{Vararg{Int}}})

Neighborhoods that can take arbitrary shapes by specifying each coordinate,
as `Tuple{Int,Int}` of the row/column distance (positive and negative)
from the central point.

The neighborhood radius is calculated from the most distance coordinate.
For simplicity the buffer read from the main grid is a square with sides
`2r + 1` around the central point.

The dimensionality `N` of the neighborhood is taken from the length of
the first coordinate, e.g. `1`, `2` or `3`.
"""
struct Positional{R,N,L,O<:CustomOffsets,B} <: AbstractPositionalNeighborhood{R,N,L}
    "A tuple of tuples of Int, containing 2-D coordinates relative to the central point"
    offsets::O
    _buffer::B
end
Positional(args::CustomOffset...) = Positional(args)
function Positional(offsets::CustomOffsets, _buffer=nothing)
    R = _absmaxcoord(offsets)
    N = length(first(offsets))
    L = length(offsets)
    Positional{R,N,L}(offsets, _buffer)
end
function Positional{R,N,L}(offsets::O, _buffer::B=nothing) where {R,N,L,O<:CustomOffsets,B}
    Positional{R,N,L,O,B}(offsets, _buffer)
end

# Calculate the maximum absolute value in the offsets to use as the radius
_absmaxcoord(offsets::Union{AbstractArray,Tuple}) = maximum(map(x -> maximum(map(abs, x)), offsets))

ConstructionBase.constructorof(::Type{Positional{R,N,L,C,B}}) where {R,N,L,C,B} =
    Positional{R,N,L}

Base.length(hood::Positional) = length(offsets(hood))

offsets(hood::Positional) = hood.offsets
@inline _setbuffer(n::Positional{R,N,L,O}, buf::B2) where {R,N,L,O,B2} =
    Positional{R,N,L,O,B2}(offsets(n), buf)


"""
    LayeredPositional <: AbstractPositional

    LayeredPositional(layers::Positional...)

Sets of [`Positional`](@ref) neighborhoods that can have separate rules for each set.

`neighbors` for `LayeredPositional` returns a tuple of iterators
for each neighborhood layer.
"""
struct LayeredPositional{R,N,L,La,B} <: AbstractPositionalNeighborhood{R,N,L}
    "A tuple of custom neighborhoods"
    layers::La
    _buffer::B
end
LayeredPositional(layers::Positional...) = LayeredPositional(layers)
function LayeredPositional(layers::Tuple{Vararg{<:Positional}}, _buffer=nothing)
    R = maximum(map(radius, layers))
    N = ndims(first(layers))
    L = map(length, layers)
    LayeredPositional{R,N,L}(layers, _buffer)
end
function LayeredPositional{R,N,L}(layers, _buffer::B) where {R,N,L,B}
    # Child layers must have the same _buffer, and the
    # same R and L parameters. So we rebuild them all here.
    layers = map(l -> Positional{R,N,L}(offsets(l), _buffer), layers)
    LayeredPositional{R,N,L,typeof(layers),B}(layers, _buffer)
end

@inline neighbors(hood::LayeredPositional) = map(l -> neighbors(l), hood.layers)
@inline offsets(hood::LayeredPositional) = map(l -> offsets(l), hood.layers)
@inline positions(hood::LayeredPositional, args...) = map(l -> positions(l, args...), hood.layers)
@inline function _setbuffer(n::LayeredPositional{R,N,L}, buf) where {R,N,L}
    LayeredPositional{R,N,L}(n.layers, buf)
end

@inline Base.sum(hood::LayeredPositional) = map(sum, neighbors(hood))


"""
    VonNeumann(radius=1; ndims=2) -> Positional
    VonNeumann(; radius=1, ndims=2) -> Positional

A convenience wrapper to build Von-Neumann neighborhoods as
a [`Positional`](@ref) neighborhood.
"""
VonNeumann(args...; radius=1, ndims=2) = VonNeumann(radius, args...; ndims)
function VonNeumann(radius=1, _buffer=nothing; ndims=2)
    offsets = Tuple{Int,Int}[]
    rng = -radius:radius
    for j in rng, i in rng
        distance = abs(i) + abs(j)
        if distance <= radius && distance > 0
            push!(offsets, (i, j))
        end
    end
    return Positional(Tuple(offsets), _buffer)
end
# TODO: make VonNeumann a type and generate
# the neighborhod in a @generated function

# Get the size of a neighborhood dimension from its radius,
# which is always 2r + 1.
@inline hoodsize(hood::Neighborhood{R}) where R = hoodsize(R)
@inline hoodsize(radius::Integer) = 2radius + 1
