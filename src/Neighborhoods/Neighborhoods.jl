module Neighborhoods

using ConstructionBase, StaticArrays

export Neighborhood, Window, AbstractKernelNeighborhood, Kernel,
       Moore, VonNeumann, AbstractPositionalNeighborhood, Positional, LayeredPositional

export neighbors, neighborhood, kernel, kernelproduct, offsets, positions, radius, distances

export setwindow, updatewindow, unsafe_updatewindow

export pad_axes, unpad_axes

export broadcast_neighborhood, broadcast_neighborhood!

"""
    Neighborhood

Neighborhoods define the pattern of surrounding cells in the "neighborhood"
of the current cell. The `neighbors` function returns the surrounding
cells as an iterable.

The main kinds of neighborhood are demonstrated below:

![Neighborhoods](https://raw.githubusercontent.com/cesaraustralia/DynamicGrids.jl/media/Neighborhoods.png)

Neighborhoods can be used in `NeighborhoodRule` and `SetNeighborhoodRule` -
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

"""
    kernelproduct(rule::NeighborhoodRule})
    kernelproduct(hood::AbstractKernelNeighborhood)
    kernelproduct(hood::Neighborhood, kernel)

Returns the vector dot product of the neighborhood and the kernel,
although differing from `dot` in that the dot product is not take for
vector members of the neighborhood - they are treated as scalars.
"""
function kernelproduct end

"""
    radius(rule, [key]) -> Int

Return the radius of a rule or ruleset if it has one, otherwise zero.
"""
function radius end
radius(hood::Neighborhood{R}) where R = R

"""
    neighbors(x::Union{Neighborhood,NeighborhoodRule}}) -> iterable

Returns an indexable iterator for all cells in the neighborhood,
either a `Tuple` of values or a range.

Custom `Neighborhood`s must define this method.
"""
function neighbors end
function neighbors(hood::Neighborhood)
    map(i -> _window(hood)[i], window_indices(hood))
end

"""
    offsets(x) -> iterable

Returns an indexable iterable over all cells, containing `Tuple`s of
the index offset from the central cell.

Custom `Neighborhood`s must define this method.
"""
function offsets end
offsets(hood::Neighborhood) = offsets(typeof(hood))
_window(hood::Neighborhood) = hood._window

"""
    positions(x::Union{Neighborhood,NeighborhoodRule}}, cellindex::Tuple) -> iterable

Returns an indexable iterable, over all cells as `Tuple`s of each
index in the main array. Useful in `SetNeighborhoodRule` for
setting neighborhood values, or for getting values in an Aux array.
"""
function positions end
@inline function positions(hood::Neighborhood, I::CartesianIndex)
     positions(hood, CartesianIndex(Tuple(I)))
end
@inline positions(hood::Neighborhood, I::Int...) = positions(hood, I)
@inline positions(hood::Neighborhood, I::Tuple) = map(o -> o .+ I, offsets(hood))

"""
    distances(hood::Neighborhood)

Get the center-to-center distance of each neighborhood position from the central cell,
so that horizontally or vertically adjacent cells have a distance of `1.0`, and a
diagonally adjacent cell has a distance of `sqrt(2.0)`.

Vales are calculated at compile time, so `distances` can be used inside rules with little
overhead.
"""
@generated function distances(hood::Neighborhood{N,R,L}) where {N,R,L}
    expr = Expr(:tuple, ntuple(i -> :(bd[bi[$i]]), L)...)
    return quote
        bd = window_distances(hood)
        bi = window_indices(hood)
        $expr
    end
end

@generated function window_indices(H::Neighborhood{R,N}) where {R,N}
    # Offsets can be anywhere in the window, specified with
    # all dimensions. Here we transform them to a linear index.
    bi = map(offsets(H)) do o
        # Calculate strides
        S = 2R + 1
        strides = ntuple(i -> S^(i-1), N)
        # Offset indices are centered, we want them as regular array indices
        # Return the linear index in the square window
        sum(map((i, s) -> (i + R) * s, o, strides)) + 1
    end
    return Expr(:tuple, bi...)
end

@generated function window_distances(hood::Neighborhood{R,N}) where {R,N}
    values = map(CartesianIndices(ntuple(_ -> SOneTo{2R+1}(), N))) do I
        sqrt(sum((Tuple(I) .- (R + 1)) .^ 2))
    end
    x = SArray(values)
    quote
        return $x
    end
end

Base.eltype(hood::Neighborhood) = eltype(_window(hood))
Base.length(hood::Neighborhood{<:Any,<:Any,L}) where L = L
Base.ndims(hood::Neighborhood{<:Any,N}) where N = N
# Note: size is radial, and may not relate to `length` in the same way
# as in an array. A neighborhood does not have to include all cells includeding
# in the area covered by `size` and `axes`.
Base.size(hood::Neighborhood{R,N}) where {R,N} = ntuple(_ -> 2R+1, N)
Base.axes(hood::Neighborhood{R,N}) where {R,N} = ntuple(_ -> SOneTo{2R+1}(), N)
Base.iterate(hood::Neighborhood, args...) = iterate(neighbors(hood), args...)
Base.getindex(hood::Neighborhood, i) = begin
    getindex(_window(hood), window_indices(hood)[i])
end

"""
    Moore <: Neighborhood

    Moore(radius::Int=1; ndims=2)
    Moore(; radius=1, ndims=2)
    Moore{R}(; ndims=2)
    Moore{R,N}()

Moore neighborhoods define the neighborhood as all cells within a horizontal or
vertical distance of the central cell. The central cell is omitted.

Radius `R = 1`:

```
N = 1   N = 2
 
 ▄ ▄     █▀█
         ▀▀▀
```

Radius `R = 2`:

```
N = 1   N = 2

        █████
▀▀ ▀▀   ██▄██
        ▀▀▀▀▀
```

Using `R` and `N` type parameters removes runtime cost of generating the neighborhood,
compated to passing arguments/keywords.
"""
struct Moore{R,N,L,W} <: Neighborhood{R,N,L}
    _window::W
end
Moore(radius::Int=1; ndims=2) = Moore{radius,ndims}()
Moore(args...; radius=1, ndims=2) = Moore{radius,ndims}(args...)
Moore{R}(_window=nothing; ndims=2) where R = Moore{R,ndims,}(_window)
Moore{R,N}(_window=nothing) where {R,N} = Moore{R,N,(2R+1)^N-1}(_window)
Moore{R,N,L}(_window::W=nothing) where {R,N,L,W} = Moore{R,N,L,W}(_window)

@generated function offsets(::Type{<:Moore{R,N}}) where {R,N}
    exp = Expr(:tuple)
    for I in CartesianIndices(ntuple(_-> -R:R, N))
        if !all(map(iszero, Tuple(I)))
            push!(exp.args, :($(Tuple(I))))
        end
    end
    return exp
end
@inline setwindow(n::Moore{R,N,L}, win::W2) where {R,N,L,W2} = Moore{R,N,L,W2}(win)

"""
    VonNeumann(radius=1; ndims=2) -> Positional
    VonNeumann(; radius=1, ndims=2) -> Positional
    VonNeumann{R,N}() -> Positional

A Von Neuman neighborhood is a damond-shaped, omitting the central cell:

Radius `R = 1`:

```
N = 1   N = 2

 ▄ ▄     ▄▀▄
          ▀
```

Radius `R = 2`:

```
N = 1   N = 2

         ▄█▄
▀▀ ▀▀   ▀█▄█▀
          ▀
```

In 1 dimension it is identical to [`Moore`](@ref).

Using `R` and `N` type parameters removes runtime cost of generating the neighborhood,
compated to passing arguments/keywords.
"""
struct VonNeumann{R,N,L,W} <: Neighborhood{R,N,L}
    _window::W
end
VonNeumann(; radius=1, ndims=2) = VonNeumann(radius; ndims)
VonNeumann(radius, _window=nothing; ndims=2) = VonNeumann{radius,ndims}(_window)
VonNeumann{R}(_window=nothing; ndims=2) where R = VonNeumann{R,ndims}(_window)
function VonNeumann{R,N}(_window=nothing) where {R,N}
    L = 2sum(1:R) + 2R
    VonNeumann{R,N,L}(_window)
end
VonNeumann{R,N,L}(_window::W=nothing) where {R,N,L,W} = VonNeumann{R,N,L,W}(_window)

@inline setwindow(n::VonNeumann{R,N,L}, win::W2) where {R,N,L,W2} = VonNeumann{R,N,L,W2}(win)

@generated function offsets(::Type{T}) where {T<:VonNeumann{R,N}} where {R,N}
    offsets_expr = Expr(:tuple)
    rngs = ntuple(_ -> -R:R, N)
    for I in CartesianIndices(rngs)
        manhatten_distance = sum(map(abs, Tuple(I)))
        if manhatten_distance in 1:R
            push!(offsets_expr.args, Tuple(I))
        end
    end
    return offsets_expr
end

"""
    Window <: Neighborhood

    Window(; radius=1, ndims=2)
    Window{R}(; ndims=2)
    Window{R,N}()

A neighboorhood of radius R that includes the central cell.

Radius `R = 1`:

```
N = 1   N = 2
        
 ▄▄▄     ███
         ▀▀▀
```

Radius `R = 2`:

```
N = 1   N = 2

        █████
▀▀▀▀▀   █████
        ▀▀▀▀▀
```
"""
struct Window{R,N,L,W} <: Neighborhood{R,N,L}
    _window::W
end
Window(; radius=1, ndims=2) = Window{radius,ndims}(args...)
Window(R::Int, args...; ndims=2) = Window{R,ndims}(args...)
Window{R}(_window=nothing; ndims=2) where {R} = Window{R,ndims}(_window)
Window{R,N}(_window=nothing) where {R,N} = Window{R,N,(2R+1)^N}(_window)
Window{R,N,L}(_window::W=nothing) where {R,N,L,W} = Window{R,N,L,W}(_window)
Window(A::AbstractArray) = Window{(size(A, 1) - 1) ÷ 2,ndims(A)}()

# The central cell is included
@inline function offsets(::Type{<:Window{R,N}}) where {R,N}
    D = 2R + 1
    ntuple(i -> (rem(i - 1, D) - R, (i - 1) ÷ D - R), D^N)
end

distances(hood::Window) = Tuple(window_distances(hood))

@inline setwindow(::Window{R,N,L}, win::W2) where {R,N,L,W2} = Window{R,N,L,W2}(win)

window_indices(hood::Window{R,N}) where {R,N} = SOneTo{(2R + 1)^N}()

neighbors(hood::Window) = _window(hood)

"""
    AbstractKernelNeighborhood <: Neighborhood

Abstract supertype for kernel neighborhoods.

These can wrap any other neighborhood object, and include a kernel of
the same length and positions as the neighborhood.
"""
abstract type AbstractKernelNeighborhood{R,N,L,H} <: Neighborhood{R,N,L} end

neighbors(hood::AbstractKernelNeighborhood) = neighbors(neighborhood(hood))
offsets(::Type{<:AbstractKernelNeighborhood{<:Any,<:Any,<:Any,H}}) where H = offsets(H)
positions(hood::AbstractKernelNeighborhood, I::Tuple) = positions(neighborhood(hood), I)

"""
    kernel(hood::AbstractKernelNeighborhood) => iterable

Returns the kernel object, an array or iterable matching the length
of the neighborhood.
"""
function kernel end
kernel(hood::AbstractKernelNeighborhood) = hood.kernel

"""
    neighborhood(x) -> Neighborhood

Returns a neighborhood object.
"""
function neighborhood end
neighborhood(hood::AbstractKernelNeighborhood) = hood.neighborhood

"""
    kernelproduct(hood::AbstractKernelNeighborhood)
    kernelproduct(hood::Neighborhood, kernel)

Take the vector dot produce of the neighborhood and the kernel,
without recursion into the values of either. Essentially `Base.dot`
without recursive calls on the contents, as these are rarely what is
intended.
"""
function kernelproduct(hood::AbstractKernelNeighborhood)
    kernelproduct(neighborhood(hood), kernel(hood))
end
function kernelproduct(hood::Neighborhood{<:Any,<:Any,L}, kernel) where L
    sum = zero(first(hood))
    @simd for i in 1:L
        @inbounds sum += hood[i] * kernel[i]
    end
    return sum
end
function kernelproduct(hood::Window{<:Any,<:Any,L}, kernel) where L
    sum = zero(first(hood))
    @simd for i in 1:L
        @inbounds sum += _window(hood)[i] * kernel[i]
    end
    return sum
end

"""
    Kernel <: AbstractKernelNeighborhood

    Kernel(neighborhood, kernel)

Wrap any other neighborhood object, and includes a kernel of
the same length and positions as the neighborhood.
"""
struct Kernel{R,N,L,H,K} <: AbstractKernelNeighborhood{R,N,L,H}
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

function setwindow(n::Kernel{R,N,L,<:Any,K}, win) where {R,N,L,K}
    hood = setwindow(neighborhood(n), win)
    return Kernel{R,N,L,typeof(hood),K}(hood, kernel(n))
end

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



# Utils

# Get the size of a neighborhood dimension from its radius,
# which is always 2r + 1.
@inline hoodsize(hood::Neighborhood{R}) where R = hoodsize(R)
@inline hoodsize(radius::Integer) = 2radius + 1

# Copied from StaticArrays. If they can do it...
Base.@pure function tuple_contents(::Type{X}) where {X<:Tuple}
    return tuple(X.parameters...)
end
tuple_contents(xs::Tuple) = xs

"""
    readwindow(hood::Neighborhood, A::AbstractArray, I) => SArray

Get a single window square from an array, as an `SArray`, checking bounds.
"""
readwindow(hood::Neighborhood, A::AbstractArray, I::Int...) = readwindow(hood, A, I)
readwindow(hood::Neighborhood, A::AbstractArray, I::CartesianIndex) = readwindow(hood, A, Tuple(I))
@inline function readwindow(hood::Neighborhood{R,N}, A::AbstractArray, I) where {R,N}
    for O in ntuple(_ -> (-R, R), N)
        edges = Tuple(I) .+ O
        map(I -> checkbounds(A, I...), edges)
    end
    return unsafe_readwindow(hood, A, I)
end

"""
    unsafe_readwindow(hood::Neighborhood, A::AbstractArray, I) => SArray

Get a single window square from an array, as an `SArray`, without checking bounds.
"""
@inline unsafe_readwindow(hood::Neighborhood, A::AbstractArray, I::CartesianIndex) =
    unsafe_readwindow(hood, A, Tuple(I))
@inline unsafe_readwindow(hood::Neighborhood, A::AbstractArray, I::Int...) =
    unsafe_readwindow(hood, A, I)
@generated function unsafe_readwindow(
    ::Neighborhood{R,N}, A::AbstractArray{T,N}, I::NTuple{N,Int}
) where {T,R,N}
    S = 2R+1
    L = S^N
    sze = ntuple(_ -> S, N)
    vals = Expr(:tuple)
    nh = CartesianIndices(ntuple(_ -> -R:R, N))
    for i in 1:L
        Iargs = map(Tuple(nh[i]), 1:N) do nhi, n
            :(I[$n] + $nhi)
        end
        Iexp = Expr(:tuple, Iargs...)
        exp = :(@inbounds A[$Iexp...])
        push!(vals.args, exp)
    end

    sze_exp = Expr(:curly, :Tuple, sze...)
    return :(SArray{$sze_exp,$T,$N,$L}($vals))
end
@generated function unsafe_readwindow(
    ::Neighborhood{R,N1}, A::AbstractArray{T,N2}, I::NTuple{N3,Int}
) where {T,R,N1,N2,N3}
    throw(DimensionMismatch("neighborhood has $N1 dimensions while array has $N2 and index has $N3"))
end

# Reading windows without padding
# struct Padded{S,V}
#     padval::V
# end
# Padded{S}(padval::V) where {S,V} = Padded{S,V}(padval)

# @generated function unsafe_readwindow(
#     ::Neighborhood{R,N}, bounds::Padded{V}, ::AbstractArray{T,N}, I::NTuple{N,Int}
# ) where {T,R,N,V}
#     R = 1
#     S = 2R+1
#     L = S^N
#     sze = ntuple(_ -> S, N)
#     vals = Expr(:tuple)
#     for X in CartesianIndices(ntuple(_ -> -R:R, N))
#         if X in CartesianIndices(V)
#             # Generate indices for this position
#             Iargs = map(Tuple(X), 1:N) do x, n
#                 :(I[$n] + $x)
#             end
#             Iexp = Expr(:tuple, Iargs...)
#             push!(vals.args, :(@inbounds A[$Iexp...]))
#         else
#             push!(vals.args, :(bounds.padval))
#         end
#     end

#     sze_exp = Expr(:curly, :Tuple, sze...)
#     return :(SArray{$sze_exp,$T,$N,$L}($vals))
# end

"""
    updatewindow(x, A::AbstractArray, I...) => Neighborhood

Set the window of a neighborhood to values from the array A around index `I`.

Bounds checks will reduce performance, aim to use `unsafe_setwindow` directly.
"""
@inline function updatewindow(x, A::AbstractArray, i, I...)
    setwindow(x, readwindow(x, A, i, I...))
end

"""
    unsafe_setwindow(x, A::AbstractArray, I...) => Neighborhood

Set the window of a neighborhood to values from the array A around index `I`.

No bounds checks occur, ensure that A has padding of at least the neighborhood radius.
"""
@inline function unsafe_updatewindow(h::Neighborhood, A::AbstractArray, i, I...)
    setwindow(h, unsafe_readwindow(h, A, i, I...))
end

"""
    broadcast_neighborhood(f, hood::Neighborhood, As...)

Simple neighborhood application, where `f` is passed 
each neighborhood in `A`, returning a new array.

The result is smaller than `A` on all sides, by the neighborhood radius.
"""
function broadcast_neighborhood(f, hood::Neighborhood, sources...)
    checksizes(sources...)
    ax = unpad_axes(first(sources), hood)
    sourceview = view(first(sources), ax...)
    broadcast(sourceview, CartesianIndices(ax)) do _, I
        applyneighborhood(f, sources, I)
    end
end

"""
    broadcast_neighborhood!(f, hood::Neighborhood{R}, dest, sources...)

Simple neighborhood broadcast where `f` is passed each neighborhood
of `src` (except padding), writing the result of `f` to `dest`.

`dest` must either be smaller than `src` by the neighborhood radius on all
sides, or be the same size, in which case it is assumed to also be padded.
"""
function broadcast_neighborhood!(f, hood::Neighborhood, dest, sources)
    checksizes(sources...)
    if axes(dest) === axes(src)
        ax = unpad_axes(src, hood)
        destview = view(dest, ax...)
        broadcast!(destview, CartesianIndices(ax)) do I
            applyneighborhood(f, sources, I)
        end
    else
        broadcast!(dest, CartesianIndices(unpad_axes(src, hood))) do I
            applyneighborhood(f, sources, I)
        end
    end
end

function checksizes(sources...)
    map(sources) do s
        size(s) === size(first(sources)) || throw(ArgumentError("Source array sizes must match"))
    end
end

function applyneighborhood(f, sources, I)
    hoods = map(sources) do s
        unsafe_updatewindow(hood, s, I)
    end
    f(hoods...)
end

"""
    pad_axes(A, hood::Neighborhood{R})
    pad_axes(A, radius::Int)

Add padding to axes.
"""
pad_axes(A, hood::Neighborhood{R}) where R = pad_axes(A, R)
function pad_axes(A, radius::Int)
    map(axes(A)) do axis
        firstindex(axis) - radius:lastindex(axis) + radius
    end
end
"""
    unpad_axes(A, hood::Neighborhood{R})
    unpad_axes(A, radius::Int)

Remove padding from axes.
"""
unpad_axes(A, hood::Neighborhood{R}) where R = unpad_axes(A, R)
function unpad_axes(A, radius::Int)
    map(axes(A)) do axis
        firstindex(axis) + radius:lastindex(axis) - radius
    end
end

end # Module Neighborhoods

