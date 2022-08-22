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

