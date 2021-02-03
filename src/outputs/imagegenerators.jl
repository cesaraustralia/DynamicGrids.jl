const MASKCOL = ARGB32(0.5)
const ZEROCOL = ARGB32(0.3)

"""
    Greyscale(min=nothing, max=nothing)

Better performance than using a Colorschemes.jl
scheme as there is array access or interpolation.

`min` and `max` are values between `0.0` and `1.0` that
define the range of greys used.
"""
struct Greyscale{M1,M2}
    min::M1
    max::M2
end
Greyscale(; min=nothing, max=nothing) = Greyscale(min, max)

Base.get(scheme::Greyscale, x::Real) = scale(x, scheme.min, scheme.max)

const Grayscale = Greyscale

"""
    ObjectColor()

Default colorscheme. Similar to `GreyScale` for `Number`.

Other grid objects can define a custom method: 

```julia
DynamicGrids.to_rgb(::ObjectColor, obj::MyObjectType) = ...
```

Which must return an ARGB32 value.
"""
struct ObjectScheme end

to_rgb(scheme::ObjectScheme, x::Real) = to_rgb(x)


"""
Abstract supertype converting a frame of the simulation into an `ARGB32`
image for display. Frames may be a single grid or a `NamedTuple` of multiple grids.
"""
abstract type ImageGenerator end

imagesize(p::ImageGenerator, init::NamedTuple) = imagesize(p, first(init))
imagesize(::ImageGenerator, init::AbstractArray) = size(init)

_allocimage(p::ImageGenerator, init) = fill(ARGB32(0), imagesize(p, init)...)

"""
    grid_to_image!(o::ImageOutput, data::SimData)
    grid_to_image!(p::ImageGenerator, o::ImageOutput, data::SimData, grids; t=currenttime(data))

Convert a grid or `NamedRuple` of grids to an `ARGB32` image, using an 
[`ImageGenerator`](@ref).
"""
function grid_to_image! end
grid_to_image!(o::ImageOutput, data::SimData) = 
    grid_to_image!(imagebuffer(o), imagegen(o), o, data, grids(data))

"""
Abstract supertype for [`ImageGenerator`](@ref)s that convert one grid into an image array.

The first grid will be displayed if a `SingleGridImageGenerator` is
used with a `NamedTuple` of grids.
"""
abstract type SingleGridImageGenerator <: ImageGenerator end

function grid_to_image!(
    imagebuffer, p::SingleGridImageGenerator, o::ImageOutput, data::SimData, 
    grids::NamedTuple;
    name=string(first(keys(grids))), time=currenttime(data)
)
    grid_to_image!(imagebuffer, p, o, data, first(grids); name=name, time=time)
end
function grid_to_image!(
    imagebuffer, p::SingleGridImageGenerator, o::ImageOutput, data::SimData, 
    grids::NamedTuple{(:_default_,)};
    name=nothing, time=currenttime(data)
)
    grid_to_image!(imagebuffer, p, o, data, first(grids); name=name, time=time)
end
function grid_to_image!(
    imagebuffer, p::SingleGridImageGenerator, o::ImageOutput, 
    data::SimData{Y,X}, grid::AbstractArray; 
    name=nothing, time=currenttime(data), minval=minval(o), maxval=maxval(o),
) where {Y,X}
    for j in 1:X, i in 1:Y
        @inbounds val = grid[i, j]
        pixel = to_rgb(cell_to_pixel(p, mask(o), minval, maxval, data, val, (i, j)))
        @inbounds imagebuffer[i, j] = pixel
    end
    _rendertext!(imagebuffer, textconfig(o), name, time)
    return imagebuffer
end

"""
    Image(; scheme=ObjectColor(), zerocolor=nothing, maskcolor=nothing)

Converts output grids to a colorsheme.

## Arguments / Keyword Arguments
- `scheme`: a ColorSchemes.jl colorscheme, [`ObjectColor`](@ref) or object that defines
  `Base.get(obj, val)` and returns a `Color` or a value that can be converted to `Color`
  using `ARGB32(val)`.
- `zerocolor`: a `Color` to use when values are zero, or `nothing` to ignore.
- `maskcolor`: a `Color` to use when cells are masked, or `nothing` to ignore.
"""
Base.@kwdef struct Image{S,Z,M} <: SingleGridImageGenerator
    scheme::S      = ObjectScheme()
    zerocolor::Z   = ZEROCOL
    maskcolor::M   = MASKCOL
end
Image(scheme, zerocolor=ZEROCOL) = Image(scheme, zerocolor, MASKCOL)

scheme(p::Image) = p.scheme
zerocolor(p::Image) = p.zerocolor
maskcolor(p::Image) = p.maskcolor

# Show colorscheme in Atom etc
Base.show(io::IO, m::MIME"image/svg+xml", p::Image) = show(io, m, scheme(p))

@inline function cell_to_pixel(p::Image, mask, minval, maxval, data::SimData, val, I)
    if !(maskcolor(p) isa Nothing) && ismasked(mask, I...)
        to_rgb(maskcolor(p))
    else
        normval = normalise(val, minval, maxval)
        if !(zerocolor(p) isa Nothing) && normval == zero(normval)
            to_rgb(zerocolor(p))
        elseif normval isa Number && isnan(normval)
            zerocolor(p) isa Nothing ? to_rgb(scheme(p), 0) : to_rgb(zerocolor(p))
        else
            to_rgb(scheme(p), normval)
        end
    end
end

"""
    SparseOptInspector()

A [`ImageGenerator`](@ref) that checks [`SparseOpt`](@ref) visually.
Cells that do not run show in gray. Errors show in red, but if they do there's a bug.
"""
struct SparseOptInspector <: SingleGridImageGenerator end

function cell_to_pixel(p::SparseOptInspector, mask, minval, maxval, data::SimData, val, I::Tuple)
    opt(data) isa SparseOpt || error("Can only use SparseOptInspector with SparseOpt grids")
    r = radius(first(grids(data)))
    blocksize = 2r
    blockindex = _indtoblock.((I[1] + r,  I[2] + r), blocksize)
    normedval = normalise(val, minval, maxval)
    status = sourcestatus(first(data))
    # This is done at the start of the next frame, so wont show up in
    # the image properly. So do it preemtively?
    _wrapstatus!(status)
    if status[blockindex...]
        if normedval > 0
            to_rgb(normedval)
        else
            to_rgb((0.0, 0.0, 0.0))
        end
    elseif normedval > 0
        to_rgb((1.0, 0.0, 0.0)) # This (a red cell) would mean there is a bug in SparseOpt
    else
        to_rgb((0.5, 0.5, 0.5))
    end
end

"""
ImageGenerators that convert a frame containing multiple grids into a single image.
"""
abstract type MultiGridImageGenerator <: ImageGenerator end

"""
    Layout(layout::Array, imagegens::Matrix)

Layout allows displaying multiple grids in a block layout,
by specifying a layout matrix and a list of [`SingleGridImageGenerator`](@ref)
to be run for each.

## Arguments
- `layout`: A Vector or Matrix containing the keys or numbers of grids in the locations to
  display them. `nothing`, `missing` or `0` values will be skipped.
- `imagegens`: tuple of [`Image`](@ref), one for each grid in the simulation.
  Can be `nothing` or any other value for grids not in layout.
"""
Base.@kwdef struct Layout{L<:AbstractMatrix,P} <: MultiGridImageGenerator
    layout::L
    imagegens::P
    Layout(layouts::L, imagegens::P) where {L,P} = begin
        imgens = map(_asimagegen, imagegens)
        new{L,typeof(imgens)}(layouts, imgens)
    end
end
# Convenience constructor to convert Vector input to a column Matrix
function Layout(layout::AbstractVector, imagegens)
    Layout(reshape(layout, length(layout), 1), imagegens)
end

_asimagegen(p::ImageGenerator) = p
_asimagegen(x) = Image(x)

layout(p::Layout) = p.layout
imagegens(p::Layout) = p.imagegens

imagesize(p::Layout, init::NamedTuple) = size(first(init)) .* size(p.layout)

function grid_to_image!(
    imagebuffer, p::Layout, o::ImageOutput, data::SimData, grids::NamedTuple
)
    ngrids = length(grids)
    if !(minval(o) isa Nothing)
        length(minval(o)) == ngrids || _wronglengtherror(minval, ngrids, length(minval(o)))
    end
    if !(maxval(o) isa Nothing)
        length(maxval(o)) == ngrids || _wronglengtherror(maxval, ngrids, length(maxval(o)))
    end

    grid_ids = layout(p)
    # Loop over the layout matrix
    for i in 1:size(grid_ids, 1), j in 1:size(grid_ids, 2)
        grid_id = grid_ids[i, j]
        # Accept symbol keys and numbers, skip missing/nothing/0
        (ismissing(grid_id) || grid_id === nothing || grid_id == 0)  && continue
        n = if grid_id isa Symbol
            found = findfirst(k -> k === grid_id, keys(grids))
            found === nothing && _grididnotinkeyserror(grid_id, grids)
            found
        else
            grid_id
        end
        I, J = map((i, j), gridsize(data)) do k, s
            (k - 1) * s + 1:k * s
        end
        # Run image generators for section
        grid_to_image!(
            view(imagebuffer, I, J), imagegens(p)[n], o, data, grids[n];
            name=string(keys(grids)[n]), time=nothing,
            minval=_valn(minval(o), n), maxval=_valn(maxval(o), n), 
        )
    end
    _rendertime!(imagebuffer, textconfig(o), currenttime(data))
    return imagebuffer
end

_valn(::Nothing, n) = nothing
_valn(vals, n) = vals[n]

@noinline _grididnotinkeyserror(grid_id, grids) =
    throw(ArgumentError("$grid_id is not in $(keys(grids))"))
@noinline _wronglengtherror(f, ngrids, n) =
    throw(ArgumentError("Number of grids ($ngrids) and length of $f ($n) must be the same"))


# Automatically choose an image generator

function autoimagegen(init, scheme)
    Image(first(_iterableschemes(scheme)), ZEROCOL, MASKCOL)
end
function autoimagegen(init::NamedTuple, scheme)
    rows = length(init) ÷ 4 + 1
    cols = (length(init) - 1) ÷ rows + 1
    layout = reshape([keys(init)...], (rows, cols))
    imagegen = autoimagegen.(values(init), _iterableschemes(scheme))
    Layout(layout, imagegen)
end

_iterableschemes(::Nothing) = (ObjectColor(),)
_iterableschemes(schemes::Union{Tuple,NamedTuple,AbstractArray}) = schemes
_iterableschemes(scheme) = (scheme,)


# Pre-rgb manipulation tools

"""
    normalise(x, min, max)

Set a value to be between zero and one, before converting to Color.
min and max of `nothing` are assumed to be 0 and 1.
"""
normalise(x, minval::Number, maxval::Number) =
    max(min((x - minval) / (maxval - minval), oneunit(x)), zero(x))
normalise(x, minval::Number, maxval::Nothing) =
    max((x - minval) / (oneunit(x) - minval), zero(x))
normalise(x, minval::Nothing, maxval::Number) =
    min(x / maxval, oneunit(x), oneunit(x))
normalise(x, minval::Nothing, maxval::Nothing) = x

"""
    scale(x, min, max)

Rescale a value between 0 and 1 to be between `min` and `max`.
This can be used to shrink the range of a colorsheme that is displayed.
min and max of `nothing` are assumed to be 0 and 1.
"""
scale(x, min, max) = x * (max - min) + min
scale(x, ::Nothing, max) = x * max
scale(x, min, ::Nothing) = x * (oneunit(min) - min) + min
scale(x, ::Nothing, ::Nothing) = x

to_rgb(vals::Tuple) = ARGB32(vals...)
to_rgb(val::Real) = ARGB32(RGB(val))
to_rgb(val::Color) = ARGB32(val)
to_rgb(val::ARGB32) = val
# Handle external colorshemes, such as from ColorSchemes.jl
to_rgb(scheme, val::Real) = to_rgb(get(scheme, val))
