"""
savegif(filename::String, o::Output, data; imagegen=imagegen(o), fps=fps(o), [kw...])

Write the output array to a gif. You must pass an `imagegen` keyword argument for any
`Output` objects not in `ImageOutput` (which allready have a `imagegen` attached).

Saving very large gifs may trigger a bug in Imagemagick.
"""
function savegif(filename::String, o::Output, ruleset=Ruleset(); 
    minval=minval(o), maxval=maxval(o), imagegen=imagegen(o), 
    font=autofont(), text=TextCongif(), textconfig=text, kw...
)
    im_o = NoDisplayImageOutput(o; 
        imageconfig=ImageConfig(; 
            init=init(o), minval=minval, maxval=maxval, imagegen=imagegen, textconfig=textconfig
        )
    )
    savegif(filename, im_o, ruleset; kw...) 
end
function savegif(filename::String, o::ImageOutput, ruleset=Ruleset();
    imagegen=imagegen(o), fps=fps(o), kw...
)
    length(o) == 1 && @warn "The output has length 1: the saved gif will be a single image"
    ext = extent(o)
    simdata = SimData(ext, ruleset)
    println(tspan(ext))
    images = map(collect(firstindex(o):lastindex(o))) do f
        @set! simdata.currentframe = f
        grid_to_image!(o, simdata)
    end
    array = cat(images..., dims=3)
    FileIO.save(filename, array; fps=fps, kw...)
end


"""
    GifOutput(init; filename, tspan::AbstractRange, 
        aux=nothing, mask=nothing, padval=zero(eltype(init)),
        fps=25.0, store=false, 
        font=autofont(),
        scheme=Greyscale()
        text=TextConfig(; font=font),
        imagegen=autoimagegen(init, text)
        minval=nothing, maxval=nothing
    )

Output that stores the simulation as images and saves a Gif file on completion.

## Arguments:
- `init`: initialisation `Array` or `NamedTuple` of `Array`

## Keyword Argument:
- `tspan`: `AbstractRange` timespan for the simulation
- `aux`: NamedTuple of arbitrary input data. Use `get(data, Aux(:key), I...)` 
  to access from a `Rule` in a type-stable way.
- `mask`: `BitArray` for defining cells that will/will not be run.
- `padval`: padding value for grids with neighborhood rules. The default is `zero(eltype(init))`.
- `font`: `String` font name
- `scheme`: ColorSchemes.jl scheme, or `Greyscale()`
- `text`: [`TextConfig`](@ref) object or `nothing`.
- `imagegen`: [`ImageGenerator`](@ref)
- `minval`: minimum value(s) to set colour maximum
- `maxval`: maximum values(s) to set colour minimum
"""
mutable struct GifOutput{T,F<:AbstractVector{T},E,GC,IC,G,N} <: ImageOutput{T,F}
    frames::F
    running::Bool 
    extent::E
    graphicconfig::GC
    imageconfig::IC
    gif::G
    filename::N
end
GifOutput(; frames, running, extent, graphicconfig, imageconfig, filename, kw...) =
    GifOutput(frames, running, extent, graphicconfig, imageconfig, _allocgif(imageconfig, extent), filename)

filename(o::GifOutput) = o.filename
gif(o::GifOutput) = o.gif


showimage(image, o::GifOutput, data::SimData) = gif(o)[:, :, currentframe(data)] .= image 

finalisegraphics(o::GifOutput, data::AbstractSimData) = savegif(o)

savegif(o::GifOutput) = savegif(filename(o), o)
function savegif(filename::String, o::GifOutput, fps=fps(o); kw...)
    FileIO.save(filename, gif(o); fps=fps, kw...)
end


_allocgif(i::ImageConfig, e::Extent) = _allocgif(imagegen(i), i::ImageConfig, e::Extent) 
function _allocgif(::ImageGenerator, i::ImageConfig, e::Extent)
    zeros(ARGB32, gridsize(e)..., length(tspan(e)))
end
function _allocgif(p::Layout, i::ImageConfig, e::Extent)
    zeros(ARGB32, (gridsize(e) .* size(p.layout))..., length(tspan(e)))
end
