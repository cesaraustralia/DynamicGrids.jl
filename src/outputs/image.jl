
const IMAGECONFIG_KEYWORDS = """
- `minval`: Minimum value in the grid(s) to normalise for conversion to an RGB pixel. 
    A `Vector/Matrix` for multiple grids, matching the `layout` array. 
    Note: The default is `0`, and will not be updated automatically for the simulation.
- `maxval`: Maximum value in the grid(s) to normalise for conversion to an RGB pixel. 
    A `Vector/Matrix` for multiple grids, matching the `layout` array. 
    Note: The default is `1`, and will not be updated automatically for the simulation.
- `font`: `String` name of font to search for. A default will be guessed.
- `text`: `TextConfig()` or `nothing` for no text. Default is `TextConfig(; font=font)`.
$IMAGE_RENDERER_KEYWORDS
- `renderer`: [`Renderer`](@ref) like [`Image`](@ref) or [`Layout`](@ref). Will be detected 
    automatically, and use `scheme`, `zerocolor` and `maskcolor` keywords if available.
    Can be a `Vector/Matrix` for multiple grids, matching the `layout` array. 
"""

"""
    ImageConfig

    ImageConfig(init; kw...) 

Common configuration component for all [`ImageOutput`](@ref).

# Arguments

- `init` output init object, used to generate other arguments automatically.

# Keywords

$IMAGECONFIG_KEYWORDS
"""
struct ImageConfig{IB,Min,Max,Bu,TC}
    renderer::IB
    minval::Min
    maxval::Max
    imagebuffer::Bu
    textconfig::TC
end
function ImageConfig(init; 
    font=autofont(), text=TextConfig(; font=font), textconfig=text, 
    renderer=nothing, minval=0, maxval=1, tspan=nothing, kw...
) 
    # Generate a renderer automatically if it is not passed in
    renderer = renderer isa Nothing ? autorenderer(init; kw...) : renderer
    # Allocate an image buffer based on the renderer and init grids
    imagebuffer = _allocimage(renderer, init, tspan)
    ImageConfig(renderer, minval, maxval, imagebuffer, textconfig)
end

renderer(ic::ImageConfig) = ic.renderer
minval(ic::ImageConfig) = ic.minval
maxval(ic::ImageConfig) = ic.maxval
imagebuffer(ic::ImageConfig) = ic.imagebuffer
textconfig(ic::ImageConfig) = ic.textconfig

const IMAGEOUTPUT_KEYWORDS = """
$GRAPHICOUTPUT_KEYWORDS

## [`ImageConfig`](@ref) keywords:
$IMAGECONFIG_KEYWORDS

An `ImageConfig` object can be also passed to the `imageconfig` keyword, and other keywords will be ignored.
"""

"""
    ImageOutput <: GraphicOutput

Abstract supertype for Graphic outputs that display the simulation frames as RGB images.

`ImageOutput`s must have [`Extent`](@ref), [`GraphicConfig`](@ref) 
and [`ImageConfig`](@ref) components, and define a [`showimage`](@ref) method.

See [`GifOutput`](@ref) for an example.

Although the majority of the code is maintained here to enable sharing
and reuse, most `ImageOutput`s are not provided in DynamicGrids.jl to avoid
heavy dependencies on graphics libraries. See
[DynamicGridsGtk.jl](https://github.com/cesaraustralia/DynamicGridsGtk.jl)
and [DynamicGridsInteract.jl](https://github.com/cesaraustralia/DynamicGridsInteract.jl)
for implementations.

# User Arguments for all `GraphicOutput`:

- `init`: initialisation `AbstractArray` or `NamedTuple` of `AbstractArray`

# Minimum user keywords for all `ImageOutput`:

$IMAGEOUTPUT_KEYWORDS

## Internal keywords for constructors of objects extending `GraphicOutput`: 

The default constructor will generate these objects and pass them to the inheriting 
object constructor, which must accept the following keywords:

- `frames`: a `Vector` of simulation frames (`NamedTuple` or `Array`). 
- `running`: A `Bool`.
- `extent` an [`Extent`](@ref) object.
- `graphicconfig` a [`GraphicConfig`](@ref)object.
- `imageconfig` a [`ImageConfig`](@ref)object.

Users can also pass in these entire objects if required.
"""
abstract type ImageOutput{T,F} <: GraphicOutput{T,F} end


# Generic `ImageOutput` constructor that construct an `ImageOutput` from another `Output`.
function (::Type{F})(o::T; 
    frames=frames(o), extent=extent(o), graphicconfig=graphicconfig(o),
    imageconfig=imageconfig(o), textconfig=textconfig(o), kw...
) where F <: ImageOutput where T <: Output 
    F(; 
        frames=frames, running=false, extent=extent, graphicconfig=graphicconfig, 
        imageconfig=imageconfig, textconfig=textconfig, kw...
    )
end

# Generic `ImageOutput` constructor. Converts an init `AbstractArray` or `NamedTuple` 
# to a vector of `AbstractArray`s, uses `kw` to constructs required 
# [`Extent`](@ref), [`GraphicConfig`](@ref) and [`ImageConfig`](@ref) objects unless
# they are specifically passed in using `extent`, `graphicconfig`, `imageconfig`.

# All other keyword arguments are passed to these constructors. 
# Unused or mis-spelled keyword arguments are ignored.
function (::Type{T})(init::Union{NamedTuple,AbstractArray}; 
    extent=nothing, graphicconfig=nothing, imageconfig=nothing, store=nothing, kw...
) where T <: ImageOutput
    extent = extent isa Nothing ? Extent(; init=init, kw...) : extent
    store = check_stored(extent, store)
    graphicconfig = graphicconfig isa Nothing ? GraphicConfig(; store, kw...) : extent
    imageconfig = imageconfig isa Nothing ? ImageConfig(init; kw...) : imageconfig
    frames = [_replicate_init(init, replicates(extent))]
    T(; 
        frames, running=false, extent, graphicconfig, imageconfig, store, kw...
    )
end

# Getters
imageconfig(o::ImageOutput) = o.imageconfig
# Other outputs get a constructed ImageConfig
imageconfig(o::Output) = ImageConfig(init(o))

# Methods forwarded to ImageConfig
renderer(o::Output) = renderer(imageconfig(o))
minval(o::Output) = minval(imageconfig(o))
maxval(o::Output) = maxval(imageconfig(o))
imagebuffer(o::Output) = imagebuffer(imageconfig(o))
textconfig(o::Output) = textconfig(imageconfig(o))

# GraphicOutput interface methods
showframe(o::ImageOutput, data) = showimage(render!(o, data), o, data)
showimage(image, o, data) = showimage(image, o)


# Headless image output. Useful for gifs and testing.
mutable struct NoDisplayImageOutput{T,F<:AbstractVector{T},E,GC,IC} <: ImageOutput{T,F}
    frames::F
    running::Bool 
    extent::E
    graphicconfig::GC
    imageconfig::IC
end
function NoDisplayImageOutput(; 
    frames, running, extent, graphicconfig, imageconfig, kw...
)
    NoDisplayImageOutput(frames, running, extent, graphicconfig, imageconfig)
end
