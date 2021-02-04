"""
    Greyscale

    Greyscale(min=nothing, max=nothing)

A greeyscale scheme ith better performance than using a 
Colorschemes.jl scheme as there is not array access or interpolation.

`min` and `max` are values between `0.0` and `1.0` that define the range of greys used.
"""
struct Greyscale{M1,M2}
    min::M1
    max::M2
end
Greyscale(; min=nothing, max=nothing) = Greyscale(min, max)

Base.get(scheme::Greyscale, x::Real) = scale(x, scheme.min, scheme.max)

const Grayscale = Greyscale

"""
    ObjectScheme

    ObjectScheme()

Default colorscheme. Similar to `GreyScale` for `Number`.

Other grid objects can define a custom method to return colors from composite objects:

```julia
DynamicGrids.to_rgb(::ObjectScheme, obj::MyObjectType) = ...
```

Which must return an `ARGB32` value.
"""
struct ObjectScheme end

to_rgb(scheme::ObjectScheme, x::Real) = to_rgb(x)
