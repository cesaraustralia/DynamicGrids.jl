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

