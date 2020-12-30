
"""
Neighborhoods define the pattern of surrounding cells in the "neighborhood"
of the current cell. The `neighbors` function returns the surrounding
cells as an iterable.

The main kinds of neighborhood are demonstrated below:

![Neighborhoods](https://raw.githubusercontent.com/cesaraustralia/DynamicGrids.jl/media/Neighborhoods.png)

```julia
Moore{3}()
```
"""
abstract type Neighborhood{R} end

ConstructionBase.constructorof(::Type{<:T}) where T <: Neighborhood{R} where R =
    T.name.wrapper{R}

radius(hood::Neighborhood{R}) where R = R
_buffer(hood::Neighborhood) = hood._buffer
@inline positions(hood::Neighborhood, I) = (I .+ o for o in offsets(hood))

Base.eltype(hood::Neighborhood) = eltype(_buffer(hood))
Base.iterate(hood::Neighborhood, args...) = iterate(neighbors(hood), args...)
Base.getindex(hood::Neighborhood, I...) = getindex(_buffer(hood), I...)
Base.setindex!(hood::Neighborhood, val, I...) = setindex!(_buffer(hood), val, I...)
Base.copyto!(dest::Neighborhood, dof, source::Neighborhood, sof, N) =
    copyto!(_buffer(dest), dof, _buffer(source), sof, N)

"""
Moore-style square neighborhoods
"""
abstract type RadialNeighborhood{R} <: Neighborhood{R} end

"""
    Moore(radius::Int=1)

Moore neighborhoods define the neighborhood as all cells within a horizontal or
vertical distance of the central cell. The central cell is omitted.
"""
struct Moore{R,B} <: RadialNeighborhood{R}
    _buffer::B
end
# Buffer is updated later during the simulation.
# but can be passed in now to avoid the allocation.
# This might be bad design. SimData could instead hold a list of
# ruledata for the rule that holds this buffer, with
# the neighborhood. So you can do neighbors(data)
Moore(radius::Int=1, _buffer=nothing) = Moore{radius}(_buffer)
Moore{R}(_buffer=nothing) where R = Moore{R,typeof(_buffer)}(_buffer)

@inline function neighbors(hood::Moore{R}) where R
    # Use linear indexing
    buflen = (2R + 1)^2
    centerpoint = buflen ÷ 2 + 1
    return (_buffer(hood)[i] for i in 1:buflen if i != centerpoint)
end
@inline function offsets(hood::Moore{R}) where R
    ((i, j) for j in -R:R, i in -R:R if i != (0, 0))
end
@inline _setbuffer(n::Moore{R}, buf::B2) where {R,B2} = Moore{R,B2}(buf)

Base.length(hood::Moore{R}) where R = (2R + 1)^2 - 1
# Neighborhood specific `sum` for performance:w
Base.sum(hood::Moore) = _sum(hood, _centerval(hood))

_centerval(hood::Neighborhood{R}) where R = _buffer(hood)[R + 1, R + 1]
_sum(hood::Neighborhood, cell) = sum(_buffer(hood)) - cell


"""
Abstract supertype for window neighborhoods.

These are radial neighborhoods that inlude the central cell.
"""
abstract type AbstractWindow{R} <: RadialNeighborhood{R} end

Base.length(hood::AbstractWindow{R}) where R = (2R + 1)^2
neighbors(hood::AbstractWindow) = _buffer(hood)

# The central cell is included
@inline offsets(hood::AbstractWindow{R}) where R = ((i, j) for j in -R:R, i in -R:R)

"""
    Window{R}()

A neighboorhood of radius R that includes the central cell.
`R = 1` gives a 3x3 matrix.
"""
struct Window{R,B} <: AbstractWindow{R}
    _buffer::B
end
@inline Window{R}() where R = Window{R,Nothing}(nothing)
@inline Window(R::Int) = Window{R}()
@inline Window(A::AbstractArray) = Window{(size(A, 1) - 1) ÷ 2}()

@inline _setbuffer(::Window{R}, buf::B2) where {R,B2} = Window{R,B2}(buf)

"""
Abstract supertype for kernel neighborhoods.

These can wrap any other neighborhood object, and include a kernel of 
the same length and positions as the neighborhood.
"""
abstract type AbstractKernel{R} <: Neighborhood{R} end

neighborhood(hood::AbstractKernel) = hood.neighborhood
neighbors(hood::AbstractKernel) = neighbors(neighborhood(hood))
kernel(hood::AbstractKernel) = hood.kernel

Base.length(hood::AbstractKernel) = length(neighborhood(hood))

# We override dot for AbstractKernel as we always mean the sum of the 
# products of the kernel and buffer values - never a nested dot product.
function LinearAlgebra.dot(hood::AbstractKernel{R}) where R
    sum = zero(eltype(kernel(hood)))
    @simd for i in 1:length(hood) 
        @inbounds sum += kernel(hood)[i] * neighbors(hood)[i]
    end
    sum
end

"""
    Kernel(neighborhood, kernel)

Wrap any other neighborhood object, and includes a kernel of 
the same length and positions as the neighborhood.

`R = 1` gives 3x3 matrices.
"""
struct Kernel{R,N,K} <: AbstractKernel{R}
    neighborhood::N
    kernel::K
end
@inline Kernel(A::AbstractMatrix) = Kernel(Window(A), A)
@inline function Kernel(hood::N, kernel::K) where {N<:Neighborhood{R},K} where R
    length(hood) == length(kernel) || _kernel_length_error(hood, kernel)
    Kernel{R,N,K}(hood, kernel)
end

@noinline _kernel_length_error(hood, kernel) =
    throw(ArgumentError("Neighborhood length $(length(hood)) does not match kernel length $(length(kernel))"))

@inline function _setbuffer(n::Kernel{R,<:Any,K}, buf) where {R,K}
    hood = _setbuffer(neighborhood(n), buf)
    Kernel{R,typeof(hood),K}(hood, kernel(n))
end

@inline ConstructionBase.constructorof(::Type{Kernel{R,N,K}}) where {R,N,K} = Kernel{R}

"""
Neighborhoods are tuples or vectors of custom coordinates tuples
that are specified in relation to the central point of the current cell.
They can be any arbitrary shape or size, but should be listed in column-major
order for performance.
"""
abstract type AbstractPositional{R} <: Neighborhood{R} end

const CustomOffset = Tuple{Vararg{Int}}
const CustomOffsets = Union{AbstractArray{<:CustomOffset},Tuple{Vararg{<:CustomOffset}}}

"""
    Positional(coord::Tuple{Vararg{Int}}...)
    Positional(offsets::Tuple{Tuple{Vararg{Int}}})

Neighborhoods that can take arbitrary shapes by specifying each coordinate,
as `Tuple{Int,Int}` of the row/column distance (positive and negative)
from the central point.

The neighborhood radius is calculated from the most distance coordinate.
For simplicity the buffer read from the main grid is a square with sides
`2r + 1` around the central point, and is not shrunk or offset to match the
coordinates if they are not symmetrical.
"""
struct Positional{R,O<:CustomOffsets,B} <: AbstractPositional{R}
    "A tuple of tuples of Int, containing 2-D coordinates relative to the central point"
    offsets::O
    _buffer::B
end
Positional(args::CustomOffset...) = Positional(args)
Positional(offsets::CustomOffsets, _buffer=nothing) =
    Positional{_absmaxcoord(offsets)}(offsets, _buffer)
Positional{R}(offsets::CustomOffsets, _buffer=nothing) where R =
    Positional{R,typeof(offsets),typeof(_buffer)}(offsets, _buffer)

# Calculate the maximum absolute value in the offsets to use as the radius
_absmaxcoord(offsets::Union{AbstractArray,Tuple}) = maximum(map(x -> maximum(map(abs, x)), offsets))
_absmaxcoord(neighborhood::Positional) = absmaxcoord(offsets(neighborhood))

ConstructionBase.constructorof(::Type{Positional{R,C,B}}) where {R,C,B} = Positional{R}

Base.length(hood::Positional) = length(offsets(hood))

offsets(hood::Positional) = hood.offsets
@inline neighbors(hood::Positional) =
    (_buffer(hood)[(offset .+ radius(hood) .+ 1)...] for offset in offsets(hood))
@inline set_buffer(n::Positional{R,O}, buf::B2) where {R,O,B2} = Positional{R,O,B2}(offsets(n), buf)

"""
    LayeredPositional(layers::Positional...)

Sets of [`Positional`](@ref) neighborhoods that can have separate rules for each set.

`neighbors` for `LayeredPositional` returns a tuple of iterators
for each neighborhood layer.
"""
struct LayeredPositional{R,L,B} <: AbstractPositional{R}
    "A tuple of custom neighborhoods"
    layers::L
    _buffer::B
end
LayeredPositional(layers::Positional...) =
    LayeredPositional(layers)
LayeredPositional(layers::Tuple{Vararg{<:Positional}}, _buffer=nothing) =
    LayeredPositional{maximum(map(radius, layers))}(layers, _buffer)
LayeredPositional{R}(layers, _buffer) where R = begin
    # Child layers must have the same _buffer
    layers = map(l -> (@set l._buffer = _buffer), layers)
    LayeredPositional{R,typeof(layers),typeof(_buffer)}(layers, _buffer)
end

@inline neighbors(hood::LayeredPositional) = map(l -> neighbors(l), hood.layers)
@inline offsets(hood::LayeredPositional) = map(l -> offsets(l), hood.layers)
@inline positions(hood::LayeredPositional, args...) = map(l -> positions(l, args...), hood.layers)
@inline _setbuffer(n::LayeredPositional{R,L}, buf::B2) where {R,L,B2} = 
    LayeredPositional{R,L,B2}(n.layers, buf)

@inline Base.sum(hood::LayeredPositional) = map(sum, neighbors(hood))

"""
    VonNeumann(radius=1)

A convenience wrapper to build Von-Neumann neighborhoods as
a [`Positional`](@ref) neighborhood.
"""
function VonNeumann(radius=1, _buffer=nothing)
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

"""
    hoodsize(radius)

Get the size of a neighborhood dimension from its radius,
which is always 2r + 1.
"""
@inline hoodsize(hood::Neighborhood) = hoodsize(radius(hood))
@inline hoodsize(radius::Integer) = 2radius + 1
