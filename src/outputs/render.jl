const MASKCOL = ARGB32(0.5)
const ZEROCOL = ARGB32(0.3)

"""
    Renderer

Abstract supertype for objects that convert a frame of the simulation into an `ARGB32`
image for display. Frames may be a single grid or a `NamedTuple` of multiple grids.
"""
abstract type Renderer end

imagesize(p::Renderer, init::NamedTuple) = imagesize(p, first(init))
imagesize(::Renderer, init::AbstractArray) = size(init)

_allocimage(p::Renderer, init) = fill(ARGB32(0), imagesize(p, init)...)

function render!(o::ImageOutput, data::AbstractSimData)
    render!(o, data, grids(data))
end
function render!(o::ImageOutput, data::AbstractSimData, grids)
    render!(imagebuffer(o), renderer(o), o, data, grids)
end

"""
    SingleGridRenderer <: Renderer

Abstract supertype for [`Renderer`](@ref)s that convert a single grid 
into an image array.

The first grid will be displayed if a `SingleGridRenderer` is
used with a `NamedTuple` of grids.
"""
abstract type SingleGridRenderer <: Renderer end

function render!(
    imagebuffer, ig::SingleGridRenderer, o::ImageOutput, data::AbstractSimData, 
    grids::NamedTuple;
    name=string(first(keys(grids))), time=currenttime(data)
)
    render!(imagebuffer, ig, o, data, first(grids); name=name, time=time)
end
function render!(
    imagebuffer, ig::SingleGridRenderer, o::ImageOutput, data::AbstractSimData, 
    grids::NamedTuple{(DEFAULT_KEY,)};
    name=nothing, time=currenttime(data)
)
    render!(imagebuffer, ig, o, data, first(grids); name=name, time=time)
end
function render!(
    imagebuffer, ig::SingleGridRenderer, o::ImageOutput, 
    data::AbstractSimData{S}, grid::AbstractArray;
    name=nothing, time=currenttime(data), accessor=nothing,
    minval=minval(o), maxval=maxval(o),
) where S<:Tuple{Y,X} where {Y,X}
    for j in 1:X, i in 1:Y
        @inbounds val = grid[i, j]
        val = if accessor isa Nothing
            _access(DynamicGrids.accessor(ig), val)
        else
            _access(accessor, val)
        end
        pixel = to_rgb(cell_to_pixel(ig, mask(o), minval, maxval, data, val, (i, j)))
        @inbounds imagebuffer[i, j] = pixel
    end
    _rendertext!(imagebuffer, textconfig(o), name, time)
    return imagebuffer
end

"""
    Image <: SingleGridRenderer

    Image(f=identity; scheme=ObjectScheme(), zerocolor=nothing, maskcolor=nothing)

Converts output grids to a colorsheme.

# Arguments

- `f`: a function to convert value from the grid to `Real`
    oran `RGB`. `Real` will be scaled by minval/maxval and be colored by the `scheme`.
    `RGB` is used directly in the output. This is useful for grids of complex objects,
    but not necessary for numbers. The default is `identity`.

# Keywords

- `scheme`: a ColorSchemes.jl colorscheme, [`ObjectScheme`](@ref) or object that defines
    `Base.get(obj, val)` and returns a `Color` or a value that can be converted to `Color`
    using `ARGB32(val)`.
- `zerocolor`: a `Col` to use when values are zero, or `nothing` to ignore.
- `maskcolor`: a `Color` to use when cells are masked, or `nothing` to ignore.
"""
struct Image{A,S,Z,M} <: SingleGridRenderer
    accessor::A
    scheme::S
    zerocolor::Z
    maskcolor::M
end
Image(accesor::Union{Function,Int}, scheme, zerocolor=ZEROCOL) = Image(scheme, zerocolor, MASKCOL)
Image(scheme, zerocolor=ZEROCOL, maskcolor=MASKCOL) = Image(identity, scheme, zerocolor, MASKCOL)
Image(accessor::Union{Function,Int}; kw...) = Image(; accessor, kw...)
Image(; accessor::Union{Function,Int}=identity, scheme=ObjectScheme(), zerocolor=ZEROCOL, maskcolor=MASKCOL, kw...) =
    Image(accessor, scheme, zerocolor, maskcolor)

accessor(p::Image) = p.accessor
scheme(p::Image) = p.scheme
zerocolor(p::Image) = p.zerocolor
maskcolor(p::Image) = p.maskcolor

# Show colorscheme in Atom etc
Base.show(io::IO, m::MIME"image/svg+xml", p::Image) = show(io, m, scheme(p))

@inline function cell_to_pixel(ig::Image, mask, minval, maxval, data::AbstractSimData, val, I)
    if !(maskcolor(ig) isa Nothing) && ismasked(mask, I...)
        to_rgb(maskcolor(ig))
    else
        normval = normalise(val, minval, maxval)
        if !(zerocolor(ig) isa Nothing) && normval == zero(typeof(normval))
            to_rgb(zerocolor(ig))
        elseif normval isa Number && isnan(normval)
            zerocolor(ig) isa Nothing ? to_rgb(scheme(ig), 0) : to_rgb(zerocolor(ig))
        else
            to_rgb(scheme(ig), normval)
        end
    end
end

"""
    SparseOptInspector()

A [`Renderer`](@ref) that checks [`SparseOpt`](@ref) visually.
Cells that do not run show in gray. Errors show in red, but if they do there's a bug.
"""
struct SparseOptInspector{A} <: SingleGridRenderer 
    accessor::A
end
SparseOptInspector() = SparseOptInspector(identity)

accessor(p::SparseOptInspector) = p.accessor

function cell_to_pixel(p::SparseOptInspector, mask, minval, maxval, data::AbstractSimData, val, I::Tuple)
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
    MultiGridRenderer <: Renderer

Abstract type for `Renderer`s that convert a frame containing multiple 
grids into a single image.
"""
abstract type MultiGridRenderer <: Renderer end

"""
    Layout <: MultiGridRenderer

    Layout(layout::Array, renderer::Matrix)

Layout allows displaying multiple grids in a block layout, by specifying a
layout matrix and a list of [`Image`](@ref)s to be run for each.

# Arguments

- `layout`: A `Vector` or `Matrix` containing the keys or numbers of grids in the 
    locations to display them. `nothing`, `missing` or `0` values will be skipped.
- `renderers`: `Vector/Matrix` of [`Image`](@ref), matching the `layout`.
    Can be `nothing` or any other value for grids not in layout.
"""
Base.@kwdef struct Layout{L<:Union{AbstractVector,AbstractMatrix},R} <: MultiGridRenderer
    layout::L
    renderers::R
    Layout(layouts::L, renderers::R) where {L,R} = begin
        imgens = map(_asrenderer, renderers)
        new{L,typeof(imgens)}(layouts, imgens)
    end
end

_asrenderer(p::Renderer) = p
_asrenderer(x) = Image(x)

layout(p::Layout) = p.layout
renderers(p::Layout) = p.renderers
imagesize(p::Layout, init::NamedTuple) = imagesize(p, first(init))
imagesize(p::Layout, init::Array) = imagesize(size(init), size(p.layout))
imagesize(gs::NTuple{2}, ls::NTuple{2}) = gs .* ls
imagesize(gs::NTuple{2}, ls::NTuple{1}) = gs .* (first(ls), 1)

function render!(
    imagebuffer, l::Layout, o::ImageOutput, data::AbstractSimData, grids::NamedTuple
)
    npanes = length(layout(l))
    minv, maxv = minval(o), maxval(o)
    if !(minv isa Nothing)
        length(minv) == npanes || _wronglengtherror(minval, npanes, length(minv))
    end
    if !(maxv isa Nothing)
        length(maxv) == npanes || _wronglengtherror(maxval, npanes, length(maxv))
    end

    grid_ids = map(_grid_ids, layout(l))
    grid_accessors = map(_grid_accessor, layout(l))
    # Loop over the layout matrix
    for I in CartesianIndices(grid_ids)
        grid_id = grid_ids[I]
        # Accept symbol keys and numbers, skip missing/nothing/0
        (ismissing(grid_id) || grid_id === nothing || grid_id == 0)  && continue
        n = if grid_id isa Symbol
            found = findfirst(k -> k === grid_id, keys(grids))
            found === nothing && _grididnotinkeyserror(grid_id, grids)
            found
        else
            grid_id
        end
        Itup = length(Tuple(I)) == 1 ? (Tuple(I)..., 1) : Tuple(I) 
        im_I = map(Itup, gridsize(data)) do l, gs
            (l - 1) * gs + 1:l * gs
        end
        lin = LinearIndices(grid_ids)[I]

        # Run image renderers for section
        render!(
            view(imagebuffer, im_I...), renderers(l)[lin], o, data, grids[n];
            name=string(keys(grids)[n]), time=nothing,
            minval=_get(minv, lin), maxval=_get(maxv, lin),
            accessor=grid_accessors[I],
        )
    end
    _rendertime!(imagebuffer, textconfig(o), currenttime(data))
    return imagebuffer
end

_get(::Nothing, I) = nothing
_get(vals, I) = vals[I]

_grid_ids(id::Symbol) = id
_grid_ids(id::Integer) = id
_grid_ids(::Nothing) = nothing
_grid_ids(::Missing) = missing
_grid_ids(id::Pair{Symbol}) = first(id)
_grid_ids(id) = throw(ArgumentError("Layout id $id is not a valid grid name. Use an `Int`, `Symbol`, `Pair{Symbol,<:Any}` or `nothing`"))

_grid_accessor(id::Pair) = last(id)
_grid_accessor(id) = nothing

_access(::Nothing, obj) = obj
_access(f::Function, obj) = f(obj)
_access(i::Int, obj) = obj[i] 

@noinline _grididnotinkeyserror(grid_id, grids) =
    throw(ArgumentError("$grid_id is not in $(keys(grids))"))
@noinline _wronglengtherror(f, npanes, len) =
    throw(ArgumentError("Number of layout panes ($npanes) and length of $f ($len) must be the same"))


# Automatically choose an image renderer

autorenderer(init; scheme=ObjectScheme(), zerocolor=ZEROCOL, maskcolor=MASKCOL, kw...) = 
    _autorenderer(init, scheme, zerocolor, maskcolor; kw...)

_autorenderer(init, scheme, zerocolor, maskcolor; kw...) = _asrenderer(scheme, zerocolor, maskcolor)
function _autorenderer(init::NamedTuple, scheme, zerocolor, maskcolor; 
    layout=_autolayout(init), 
    renderers=_autorenderers(layout, scheme, zerocolor, maskcolor),
    kw...
)
    Layout(layout, renderers)
end

_asrenderer(renderer::Renderer, zerocolor, maskcolor) = renderer
_asrenderer(scheme, zerocolor, maskcolor) = Image(scheme, zerocolor, maskcolor)

function _autolayout(init)
    rows = length(init) ÷ 4 + 1
    cols = (length(init) - 1) ÷ rows + 1
    reshape([keys(init)...], (rows, cols))
end

function _autorenderers(layout, scheme, zerocolor, maskcolor)
    _asrenderer_key.(layout, _iterable(scheme), _iterable(zerocolor), _iterable(maskcolor))
end

_asrenderer_key(key, args...) = _asrenderer(args...)

_iterable(obj::AbstractArray) = obj
_iterable(obj) = (obj,)

# Coll conversion tools

# Set a value to be between zero and one, before converting to Color.
# min and max of `nothing` are assumed to be 0 and 1.
normalise(x::X, minv, maxv) where X = max(min((x - minv) / (maxv - minv), oneunit(X)), zero(X))
normalise(x::X, minv, maxv::Nothing) where X = max((x - minv) / (oneunit(X) - minv), zero(X))
normalise(x::X, minv::Nothing, maxv) where X = min(x / maxv, oneunit(X), oneunit(X))
normalise(x, minv::Nothing, maxv::Nothing) = x
normalise(x; min=Nothing, max=Nothing) = normalise(x, min, max)

# Rescale a value between 0 and 1 to be between `min` and `max`.
# This can be used to shrink the range of a colorsheme that is displayed.
# min and max of `nothing` are assumed to be 0 and 1.
scale(x, min, max) = x * (max - min) + min
scale(x, ::Nothing, max) = x * max
scale(x, min, ::Nothing) = x * (oneunit(typeof(min)) - min) + min
scale(x, ::Nothing, ::Nothing) = x

to_rgb(vals::Tuple) = ARGB32(vals...)
to_rgb(val::Real) = ARGB32(RGB(val))
to_rgb(val::Color) = ARGB32(val)
to_rgb(val::ARGB32) = val
# Handle external colorshemes, such as from ColorSchemes.jl
to_rgb(scheme, val::Real) = to_rgb(get(scheme, val))
