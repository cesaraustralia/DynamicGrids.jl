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
