"""
    AbstractPositionalNeighborhood <: Neighborhood

Positional neighborhoods are tuples of coordinates that are specified in relation
to the central point of the current cell. They can be any arbitrary shape or size,
but should be listed in column-major order for performance.
"""
abstract type AbstractPositionalNeighborhood{R,N,L} <: Neighborhood{R,N,L} end

const CustomOffset = Tuple{Vararg{Int}}
const CustomOffsets = Union{AbstractArray{<:CustomOffset},Tuple{Vararg{<:CustomOffset}}}

"""
    Positional <: AbstractPositionalNeighborhood

    Positional(coord::Tuple{Vararg{Int}}...)
    Positional(offsets::Tuple{Tuple{Vararg{Int}}})
    Positional{O}()

Neighborhoods that can take arbitrary shapes by specifying each coordinate,
as `Tuple{Int,Int}` of the row/column distance (positive and negative)
from the central point.

The neighborhood radius is calculated from the most distant coordinate.
For simplicity the window read from the main grid is a square with sides
`2r + 1` around the central point.

The dimensionality `N` of the neighborhood is taken from the length of
the first coordinate, e.g. `1`, `2` or `3`.


Example radius `R = 1`:

```
N = 1   N = 2

 ▄▄      ▀▄
          ▀
```

Example radius `R = 2`:

```
N = 1   N = 2

         ▄▄
 ▀ ▀▀   ▀███
           ▀
```

Using the `O` parameter e.g. `Positional{((1, 2), (1, 1))}()` removes any
runtime cost of generating the neighborhood.
"""
struct Positional{O,R,N,L,W} <: AbstractPositionalNeighborhood{R,N,L}
    "A tuple of tuples of Int, containing 2-D coordinates relative to the central point"
    _window::W
end
Positional(args::CustomOffset...) = Positional(args)
function Positional(offsets::CustomOffsets, _window=nothing)
    Positional{offsets}(_window)
end
function Positional(offsets::O, _window=nothing) where O
    Positional{offsets}(_window)
end
function Positional{O}(_window=nothing) where O
    R = _absmaxcoord(O)
    N = length(first(O))
    L = length(O)
    Positional{O,R,N,L}(_window)
end
function Positional{O,R,N,L}(_window::W=nothing) where {O,R,N,L,W}
    Positional{O,R,N,L,W}(_window)
end

# Calculate the maximum absolute value in the offsets to use as the radius
function _absmaxcoord(offsets::Union{AbstractArray,Tuple})
    maximum(map(x -> maximum(map(abs, x)), offsets))
end

function ConstructionBase.constructorof(::Type{Positional{O,R,N,L,W}}) where {O,R,N,L,W}
    Positional{O,R,N,L}
end

offsets(::Type{<:Positional{O}}) where O = O

@inline function setwindow(n::Positional{O,R,N,L}, win::W2) where {O,R,N,L,W2}
    Positional{O,R,N,L,W2}(win)
end

"""
    LayeredPositional <: AbstractPositional

    LayeredPositional(layers::Positional...)

Sets of [`Positional`](@ref) neighborhoods that can have separate rules for each set.

`neighbors` for `LayeredPositional` returns a tuple of iterators
for each neighborhood layer.
"""
struct LayeredPositional{R,N,L,La,W} <: AbstractPositionalNeighborhood{R,N,L}
    "A tuple of custom neighborhoods"
    layers::La
    _window::W
end
LayeredPositional(layers::Positional...) = LayeredPositional(layers)
function LayeredPositional(layers::Tuple{Vararg{<:Positional}}, _window=nothing)
    R = maximum(map(radius, layers))
    N = ndims(first(layers))
    L = map(length, layers)
    LayeredPositional{R,N,L}(layers, _window)
end
function LayeredPositional{R,N,L}(layers, _window::W) where {R,N,L,W}
    # Child layers must have the same _window, and the
    # same R and L parameters. So we rebuild them all here.
    layers = map(l -> Positional{offsets(l),R,N,L}(_window), layers)
    LayeredPositional{R,N,L,typeof(layers),W}(layers, _window)
end

@inline neighbors(hood::LayeredPositional) = map(l -> neighbors(l), hood.layers)
@inline offsets(::Type{<:LayeredPositional{R,N,L,La}}) where {R,N,L,La} =
    map(p -> offsets(p), tuple_contents(La))
@inline positions(hood::LayeredPositional, args::Tuple) = map(l -> positions(l, args...), hood.layers)
@inline function setwindow(n::LayeredPositional{R,N,L}, win) where {R,N,L}
    LayeredPositional{R,N,L}(n.layers, win)
end

@inline Base.sum(hood::LayeredPositional) = map(sum, neighbors(hood))

function _subwindow(l::Neighborhood{R,N}, window) where {R,N}
    
    window_inds = ntuple(_-> R + 1, R + 1, N)

    vals = map(ps) do p
        window[p...]
    end
    L = (2R + 1) ^ N
    S = Tuple{ntuple(_ -> 2R + 1, N)...}
    return SArray{S,eltype(window),N,L}(vals)
end
