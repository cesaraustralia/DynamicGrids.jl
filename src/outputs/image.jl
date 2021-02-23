"""
    ImageConfig

    ImageConfig(init; kw...) 

Common configuration component for all [`ImageOutput`](@ref).

# Keywords

- `init` output init object, used to generate other arguments automatically.
- `minval`: Minimum value in the grid(s) to normalise for conversion to an RGB pixel. 
    Number or `Tuple` for multiple grids. 
- `maxval`: Maximum value in the grid(s) to normalise for conversion to an RGB pixel. 
    Number or `Tuple` for multiple grids. 
- `font`: `String` name of font to search for. A default will be guessed.
- `text`: `TextCongif()` or `nothing` for no text. Default is `TextCongif(; font=font)`.
- `scheme`: ColorSchemes.jl scheme, or `Greyscale()`. ObjectScheme() by default.
- `imagegen`: [`ImageGenerator`](@ref) like [`Image`](@ref) or [`Layout`](@ref) Will 
    be detected automatically
"""
struct ImageConfig{P,Min,Max,IB,TC}
    imagegen::P
    minval::Min
    maxval::Max
    imagebuffer::IB
    textconfig::TC
end
function ImageConfig(init; 
    font=autofont(), text=TextConfig(; font=font), textconfig=text, 
    scheme=ObjectScheme(), imagegen=autoimagegen(init, scheme), 
    minval=nothing, maxval=nothing, kw...
) 
    imagebuffer = _allocimage(imagegen, init)
    ImageConfig(imagegen, minval, maxval, imagebuffer, textconfig)
end

imagegen(ic::ImageConfig) = ic.imagegen
minval(ic::ImageConfig) = ic.minval
maxval(ic::ImageConfig) = ic.maxval
imagebuffer(ic::ImageConfig) = ic.imagebuffer
textconfig(ic::ImageConfig) = ic.textconfig

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
function (::Type{T})(init::Union{NamedTuple,AbstractMatrix}; 
    extent=nothing, graphicconfig=nothing, imageconfig=nothing, kw...
) where T <: ImageOutput
    extent = extent isa Nothing ? Extent(; init=init, kw...) : extent
    graphicconfig = graphicconfig isa Nothing ? GraphicConfig(; kw...) : extent
    imageconfig = imageconfig isa Nothing ? ImageConfig(init; kw...) : imageconfig
    T(; 
        frames=[deepcopy(init)], running=false, extent=extent, 
        graphicconfig=graphicconfig, imageconfig=imageconfig, kw...
    )
end

imageconfig(o::Output) = ImageConfig(init(o))
imageconfig(o::ImageOutput) = o.imageconfig

imagegen(o::Output) = imagegen(imageconfig(o))
minval(o::Output) = minval(imageconfig(o))
maxval(o::Output) = maxval(imageconfig(o))
imagebuffer(o::Output) = imagebuffer(imageconfig(o))
textconfig(o::Output) = textconfig(imageconfig(o))

showframe(o::ImageOutput, data) = showimage(grid_to_image!(o, data), o, data)
showimage(image, o, data) = showimage(image, o)

# Headless image output
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
