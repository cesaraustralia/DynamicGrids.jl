const MASKCOL = ARGB32(0.5)
const ZEROCOL = ARGB32(0.3)

"""
    Greyscale(min=nothing, max=nothing)

Default colorscheme. Better performance than using a Colorschemes.jl
scheme as there is array access or interpolation.

`min` and `max` are values between `0.0` and `1.0` that
define the range of greys used.
"""
struct Greyscale{M1,M2}
    min::M1
    max::M2
end
Greyscale(; min=nothing, max=nothing) = Greyscale(min, max)

Base.get(scheme::Greyscale, x) = scale(x, scheme.min, scheme.max)

"""
    Grayscale(min=nothing, max=nothing)

Alternate name for [`Greyscale()`](@ref).
"""
const Grayscale = Greyscale


"""
Grid processors convert a frame of the simulation into an `RGB`
image for display. Frames may be one or multiple grids.
"""
abstract type GridProcessor end

imgsize(p::GridProcessor, init::NamedTuple) = imgsize(p, first(init))
imgsize(::GridProcessor, init::AbstractArray) = size(init)
textconfig(::GridProcessor) = nothing

"""
    grid2image!(o::ImageOutput, data::SimData)
    grid2image!(p::GridProcessor, o::ImageOutput, data::SimData, grids; t=currenttime(data))

Convert a grid or `NamedRuple` of grids to an `RGB` image, using a [`GridProcessor`](@ref).
But it they can be dispatched on together when required for custom outputs.
"""
function grid2image! end
grid2image!(o::ImageOutput, data::SimData) = grid2image!(imgbuffer(o), processor(o), o, data)
grid2image!(img, proc, o::ImageOutput, data::SimData) = grid2image!(img, proc, o, data, grids(data))

"""
Grid processors that convert one grid into an image array.

The first grid will be displayed if a `SingleGridProcessor` is
used with a `NamedTuple` of grids.
"""
abstract type SingleGridProcessor <: GridProcessor end

_allocimage(p::GridProcessor, init) = fill(ARGB32(0), imgsize(p, init)...)

function grid2image!(
    img, p::SingleGridProcessor, o::ImageOutput, data::SimData, grids::NamedTuple;
    name=string(first(keys(grids))), time=currenttime(data)
)
    grid2image!(img, p, o, data, first(grids); name=name, time=time)
end
function grid2image!(
    img, p::SingleGridProcessor, o::ImageOutput, data::SimData, grid::AbstractArray;
    name=nothing, time=currenttime(data)
)
    grid2image!(img, p, mask(o), minval(o), maxval(o), data, grid; name=name, time=time)
end
function grid2image!(
    img, p::SingleGridProcessor, mask, minval, maxval, data::SimData{Y,X}, grid::AbstractArray;
    name=nothing, time=currenttime(data)
) where {Y,X}
    for j in 1:X, i in 1:Y
        @inbounds val = grid[i, j]
        pixel = rgb(cell2rgb(p, mask, minval, maxval, data, val, (i, j)))
        @inbounds img[i, j] = pixel
    end
    _rendertext!(img, textconfig(p), name, time)
    return img
end

"""
    ColorProcessor(; scheme=Greyscale(), zerocolor=nothing, maskcolor=nothing)

Converts output grids to a colorsheme.

## Arguments / Keyword Arguments
- `scheme`: a ColorSchemes.jl colorscheme, [`Greyscale`](@ref) or object that defines
  `Base.get(obj, val)` and returns a `Color` or a value that can be converted to `Color`
  using `ARGB32(val)`.
- `zerocolor`: a `Color` to use when values are zero, or `nothing` to ignore.
- `maskcolor`: a `Color` to use when cells are masked, or `nothing` to ignore.
- `textconfig`: a [`TextConfig`](@ref) object.
"""
Base.@kwdef struct ColorProcessor{S,Z,M,TC} <: SingleGridProcessor
    scheme::S      = Greyscale()
    zerocolor::Z   = ZEROCOL
    maskcolor::M   = MASKCOL
    textconfig::TC = TextConfig()
end
ColorProcessor(scheme, zerocolor=ZEROCOL, maskcolor=MASKCOL) =
    ColorProcessor(scheme, zerocolor, maskcolor, TextConfig())

scheme(p::ColorProcessor) = p.scheme
zerocolor(p::ColorProcessor) = p.zerocolor
maskcolor(p::ColorProcessor) = p.maskcolor
textconfig(p::ColorProcessor) = p.textconfig

# Show colorscheme in Atom etc
Base.show(io::IO, m::MIME"image/svg+xml", p::ColorProcessor) = show(io, m, scheme(p))

@inline function cell2rgb(p::ColorProcessor, mask, minval, maxval, data::SimData, val, I)
    if !(maskcolor(p) isa Nothing) && ismasked(mask, I...)
        rgb(maskcolor(p))
    else
        normval = normalise(val, minval, maxval)
        if !(zerocolor(p) isa Nothing) && normval == zero(normval)
            rgb(zerocolor(p))
        elseif normval isa Number && isnan(normval)
            zerocolor(p) isa Nothing ? rgb(scheme(p), 0) : rgb(zerocolor(p))
        else
            rgb(scheme(p), normval)
        end
    end
end

"""
    SparseOptInspector()

A [`GridProcessor`](@ref) that checks [`SparseOpt`](@ref) visually.
Cells that do not run show in gray. Errors show in red, but if they do there's a bug.
"""
struct SparseOptInspector <: SingleGridProcessor end

function cell2rgb(p::SparseOptInspector, mask, minval, maxval, data::SimData, val, I::Tuple)
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
            rgb(normedval)
        else
            rgb(0.0, 0.0, 0.0)
        end
    elseif normedval > 0
        rgb(1.0, 0.0, 0.0) # This (a red cell) would mean there is a bug in SparseOpt
    else
        rgb(0.5, 0.5, 0.5)
    end
end



"""
Processors that convert a frame containing multiple grids into a single image.
"""
abstract type MultiGridProcessor <: GridProcessor end

"""
    LayoutProcessor(layout::Array, processors::Matrix, textconfig::TextConfig)

LayoutProcessor allows displaying multiple grids in a block layout,
by specifying a layout matrix and a list of [`SingleGridProcessor`](@ref)
to be run for each.

## Arguments
- `layout`: A Vector or Matrix containing the keys or numbers of grids in the locations to
  display them. `nothing`, `missing` or `0` values will be skipped.
- `processors`: tuple of SingleGridProcessor, one for each grid in the simulation.
  Can be `nothing` or any other value for grids not in layout.
- `textconfig` : [`TextConfig`] object for printing time and grid name labels.
"""
Base.@kwdef struct LayoutProcessor{L<:AbstractMatrix,P,TC} <: MultiGridProcessor
    layout::L
    processors::P
    textconfig::TC = nothing
    LayoutProcessor(layouts::L, processors::P, textconfig::TC) where {L,P,TC} = begin
        processors = map(p -> (@set p.textconfig = textconfig), map(_asprocessor, processors))
        new{L,typeof(processors),TC}(layouts, processors, textconfig)
    end
end
# Convenience constructor to convert Vector input to a column Matrix
LayoutProcessor(layout::AbstractVector, processors, textconfig) =
    LayoutProcessor(reshape(layout, length(layout), 1), processors, textconfig)

_asprocessor(p::GridProcessor) = p
_asprocessor(x) = ColorProcessor(x)

layout(p::LayoutProcessor) = p.layout
processors(p::LayoutProcessor) = p.processors
textconfig(p::LayoutProcessor) = p.textconfig

imgsize(p::LayoutProcessor, init::NamedTuple) = size(first(init)) .* size(p.layout)


function grid2image!(
    img, p::LayoutProcessor, o::ImageOutput, data::SimData, grids::NamedTuple
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
        # Run processor for section
        grid2image!(
            view(img, I, J), processors(p)[n], mask(o), _valn(minval(o), n), 
            _valn(maxval(o), n), data, grids[n];
            name=string(keys(grids)[n]), time=nothing
        )
    end
    _rendertime!(img, textconfig(p), currenttime(data))
    img
end

_valn(::Nothing, n) = nothing
_valn(vals, n) = vals[n]

@noinline _grididnotinkeyserror(grid_id, grids) =
    throw(ArgumentError("$grid_id is not in $(keys(grids))"))
@noinline _wronglengtherror(f, ngrids, n) =
    throw(ArgumentError("Number of grids ($ngrids) and legtn of $f ($n) must be the same"))


# Automatically choose a processor

function autoprocessor(init, scheme, textconfig)
    ColorProcessor(first(_iterableschemes(scheme)), ZEROCOL, MASKCOL, textconfig)
end
function autoprocessor(init::NamedTuple, scheme, textconfig)
    rows = length(init) ÷ 4 + 1
    cols = (length(init) - 1) ÷ rows + 1
    layout = reshape([keys(init)...], (rows, cols))
    processors = autoprocessor.(values(init), _iterableschemes(scheme), Ref(textconfig))
    LayoutProcessor(layout, processors, textconfig)
end

_iterableschemes(::Nothing) = (Greyscale(),)
_iterableschemes(schemes::Union{Tuple,NamedTuple,AbstractVector}) = schemes
_iterableschemes(scheme) = (scheme,)


# Color manipulation tools

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

"""
    rgb(val)

Convert a number, tuple or color to an ARGB32 value.
"""
rgb(vals::Tuple) = ARGB32(vals...)
rgb(vals...) = ARGB32(vals...)
rgb(val::Number) = ARGB32(RGB(val))
rgb(val::Color) = ARGB32(val)
rgb(val::ARGB32) = val
rgb(val::Bool) = (ARGB32(0), ARGB32(1))[val+1]
"""
    rgb(scheme, val)

Convert a color scheme and value to an RGB value.
"""
rgb(scheme, val) = rgb(get(scheme, val))
