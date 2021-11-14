
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
abstract type Neighborhood{R,L} end

ConstructionBase.constructorof(::Type{<:T}) where T <: Neighborhood{R,L} where {R,L} =
    T.name.wrapper{R,L}

radius(hood::Neighborhood{R}) where R = R
neighbors(hood::Neighborhood{R}) where R = map(i -> _buffer(hood)[i], bufindices(hood))
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
@inline function bufindices(hood::Neighborhood{R}, buffer::AbstractArray{<:Any,N}) where {R,N}
    # Offsets can be anywhere in the buffer, specified with
    # all dimensions. Here we transform them to a linear index.
    map(offsets(hood)) do o
        # Calculate strides
        S = 2R + 1
        strides = ntuple(i -> S^(i-1), N)
        # offesets indices are centered, we want them as regular array indices
        # Return the linear index in the square buffer
        return sum(map((i, s) -> (i + R) * s, o, strides)) + 1
    end
end

Base.eltype(hood::Neighborhood) = eltype(_buffer(hood))
Base.length(hood::Neighborhood{<:Any,L}) where L = L
Base.iterate(hood::Neighborhood, args...) = iterate(neighbors(hood), args...)
Base.getindex(hood::Neighborhood, i) = getindex(_buffer(hood), bufindices(hood)[i])
Base.ndims(hood::Neighborhood) = ndims(_buffer(hood))

"""
    RadialNeighborhood <: Neighborhood

Square neighborhoods with radius `R`, and side length `2R + 1`
"""
abstract type RadialNeighborhood{R,L} <: Neighborhood{R,L} end

"""
    Moore <: RadialNeighborhood

    Moore(radius::Int=1)

Moore neighborhoods define the neighborhood as all cells within a horizontal or
vertical distance of the central cell. The central cell is omitted.
"""
struct Moore{R,L,B} <: RadialNeighborhood{R,L}
    _buffer::B
end
# Buffer is updated later during the simulation.
Moore(radius::Int=1) = Moore{radius}()
Moore{R}(_buffer=nothing) where R = Moore{R,(2R+1)^2-1}(_buffer)
Moore{R,L}(_buffer::B=nothing) where {R,L,B} = Moore{R,L,B}(_buffer)

@generated function bufindices(hood::Moore{R}) where R
    buflen = (2R + 1)^2 # Use linear indexing
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
@generated function _offsets(hood::Moore{R}, buffer::AbstractArray{<:Any,N}) where {R,N}
    exp = Expr(:tuple)
    for I in CartesianIndices(ntuple(_-> -R:R, N))
        if !all(map(iszero, Tuple(I)))
            push!(exp.args, :($(Tuple(I))))
        end
    end
    return exp
end
@inline _setbuffer(n::Moore{R,L}, buf::B2) where {R,L,B2} = Moore{R,L,B2}(buf)

# Neighborhood specific `sum` for performance
Base.sum(hood::Moore) = sum(_buffer(hood)) - _centerval(hood)

_centerval(hood::Neighborhood) = _centerval(hood, _buffer(hood))
function _centerval(hood::Neighborhood{R}, buffer::AbstractArray{<:Any,N}) where {R,N}
    I = ntuple(_ -> R + 1, N)
    buffer[I...]
end

"""
    Window <: RadialNeighborhood

    Window{R}()

A neighboorhood of radius R that includes the central cell.
`R = 1` gives a 3x3 matrix.
"""
struct Window{R,L,B} <: RadialNeighborhood{R,L}
    _buffer::B
end
Window(R::Int) = Window{R}()
Window{R}(_buffer=nothing) where R = Window{R,(2R+1)^2}(_buffer)
Window{R,L}(_buffer::B=nothing) where {R,L,B} = Window{R,L,B}(_buffer)
Window(A::AbstractArray) = Window{(size(A, 1) - 1) ÷ 2}()


@inline _setbuffer(::Window{R,L}, buf::B2) where {R,L,B2} = Window{R,L,B2}(buf)

# The central cell is included
@inline function offsets(hood::Window{R}) where R 
    D = 2R + 1
    ntuple(i -> (rem(i-1, D)-R, (i-1) ÷ D - R), D^2)
end
bufindices(hood::Window{R}) where R = Base.OneTo((2R+1)^2)

neighbors(hood::Window) = _buffer(hood)

"""
    AbstractKernelNeighborhood <: Neighborhood

Abstract supertype for kernel neighborhoods.

These can wrap any other neighborhood object, and include a kernel of
the same length and positions as the neighborhood.
"""
abstract type AbstractKernelNeighborhood{R,L} <: Neighborhood{R,L} end

neighborhood(hood::AbstractKernelNeighborhood) = hood.neighborhood
neighbors(hood::AbstractKernelNeighborhood) = neighbors(neighborhood(hood))
offsets(hood::AbstractKernelNeighborhood) = offsets(neighborhood(hood))
positions(hood::AbstractKernelNeighborhood, I) = positions(neighborhood(hood), I)
kernel(hood::AbstractKernelNeighborhood) = hood.kernel

kernelproduct(hood::AbstractKernelNeighborhood) = 
    kernelproduct(neighborhood(hood), kernel(hood))
function kernelproduct(hood::Neighborhood{<:Any,L}, kernel) where L
    sum = zero(first(hood))
    @simd for i in 1:L
        sum += hood[i] * kernel[i]
    end
    return sum
end
function kernelproduct(hood::Window{<:Any,L}, kernel) where L
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
struct Kernel{R,L,N,K} <: AbstractKernelNeighborhood{R,L}
    neighborhood::N
    kernel::K
end
Kernel(A::AbstractMatrix) = Kernel(Window(A), A)
function Kernel(hood::N, kernel::K) where {N<:Neighborhood{R,L},K} where {R,L}
    length(hood) == length(kernel) || _kernel_length_error(hood, kernel)
    Kernel{R,L,N,K}(hood, kernel)
end
function Kernel{R,L}(hood::N, kernel::K) where {R,L,N<:Neighborhood{R,L},K}
    Kernel{R,L,N,K}(hood, kernel)
end

@noinline _kernel_length_error(hood, kernel) =
    throw(ArgumentError("Neighborhood length $(length(hood)) does not match kernel length $(length(kernel))"))

@inline function _setbuffer(n::Kernel{R,L,<:Any,K}, buf) where {R,L,K}
    hood = _setbuffer(neighborhood(n), buf)
    return Kernel{R,L,typeof(hood),K}(hood, kernel(n))
end

"""
    AbstractPositionalNeighborhood <: Neighborhood

Neighborhoods are tuples or vectors of custom coordinates tuples
that are specified in relation to the central point of the current cell.
They can be any arbitrary shape or size, but should be listed in column-major
order for performance.
"""
abstract type AbstractPositionalNeighborhood{R,L} <: Neighborhood{R,L} end

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
"""
struct Positional{R,L,O<:CustomOffsets,B} <: AbstractPositionalNeighborhood{R,L}
    "A tuple of tuples of Int, containing 2-D coordinates relative to the central point"
    offsets::O
    _buffer::B
end
Positional(args::CustomOffset...) = Positional(args)
Positional(offsets::CustomOffsets, _buffer=nothing) =
    Positional{_absmaxcoord(offsets),length(offsets)}(offsets, _buffer)
Positional{R,L}(offsets::O, _buffer::B=nothing) where {R,L,O<:CustomOffsets,B} =
    Positional{R,L,O,B}(offsets, _buffer)

# Calculate the maximum absolute value in the offsets to use as the radius
_absmaxcoord(offsets::Union{AbstractArray,Tuple}) = maximum(map(x -> maximum(map(abs, x)), offsets))

ConstructionBase.constructorof(::Type{Positional{R,L,C,B}}) where {R,L,C,B} =
    Positional{R,L}

Base.length(hood::Positional) = length(offsets(hood))

offsets(hood::Positional) = hood.offsets
@inline _setbuffer(n::Positional{R,L,O}, buf::B2) where {R,L,O,B2} =
    Positional{R,L,O,B2}(offsets(n), buf)


"""
    LayeredPositional <: AbstractPositional

    LayeredPositional(layers::Positional...)

Sets of [`Positional`](@ref) neighborhoods that can have separate rules for each set.

`neighbors` for `LayeredPositional` returns a tuple of iterators
for each neighborhood layer.
"""
struct LayeredPositional{R,L,La,B} <: AbstractPositionalNeighborhood{R,L}
    "A tuple of custom neighborhoods"
    layers::La
    _buffer::B
end
LayeredPositional(layers::Positional...) = LayeredPositional(layers)
LayeredPositional(layers::Tuple{Vararg{<:Positional}}, _buffer=nothing) =
    LayeredPositional{maximum(map(radius, layers)),map(length, layers)}(layers, _buffer)
LayeredPositional{R,L}(layers, _buffer::B) where {R,L,B} = begin
    # Child layers must have the same _buffer, and the same R and L parameters
    layers = map(l -> Positional{R,L}(offsets(l), _buffer), layers)
    LayeredPositional{R,L,typeof(layers),B}(layers, _buffer)
end

@inline neighbors(hood::LayeredPositional) = map(l -> neighbors(l), hood.layers)
@inline offsets(hood::LayeredPositional) = map(l -> offsets(l), hood.layers)
@inline positions(hood::LayeredPositional, args...) = map(l -> positions(l, args...), hood.layers)
@inline _setbuffer(n::LayeredPositional{R,L}, buf) where {R,L} =
    LayeredPositional{R,L}(n.layers, buf)

@inline Base.sum(hood::LayeredPositional) = map(sum, neighbors(hood))

"""
    VonNeumann(radius=1) -> Positional

A convenience wrapper to build Von-Neumann neighborhoods as
a [`Positional`](@ref) neighborhood.
"""
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

# Get the size of a neighborhood dimension from its radius,
# which is always 2r + 1.
@inline hoodsize(hood::Neighborhood{R}) where R = hoodsize(R)
@inline hoodsize(radius::Integer) = 2radius + 1
