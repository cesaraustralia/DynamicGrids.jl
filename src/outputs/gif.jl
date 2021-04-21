"""
    savegif(filename::String, o::Output; kw...)

Write the output array to a gif.

# Keywords

- `fps`: `Real` frames persecond. Defaults to the `fps` of the output, or `25`.
- `minval`: Minimum value in the grid(s) to normalise for conversion to an RGB pixel. 
    `Number` or `Tuple` for multiple grids. 
- `maxval`: Maximum value in the grid(s) to normalise for conversion to an RGB pixel. 
    `Number` or `Tuple` for multiple grids. 
- `font`: `String` name of font to search for. A default will be guessed.
- `text`: `TextConfig()` or `nothing` for no text. Default is `TextConfig(; font=font)`.
- `scheme`: ColorSchemes.jl scheme, `ObjectScheme()` or `Greyscale()`
- `imagegen`: `ImageGenerator` like `Image` or `Layout`. Will be detected automatically
"""
function savegif(filename::String, o::Output, ruleset=Ruleset(); 
    minval=minval(o), maxval=maxval(o), 
    scheme=ObjectScheme(), imagegen=autoimagegen(init(o), scheme), 
    font=autofont(), text=TextConfig(font=font), textconfig=text, kw...
)
    im_o = NoDisplayImageOutput(o; 
        imageconfig=ImageConfig(init(o); 
            minval=minval, maxval=maxval, imagegen=imagegen, textconfig=textconfig
        )
    )
    savegif(filename, im_o, ruleset; kw...) 
end
function savegif(filename::String, o::ImageOutput, ruleset=Ruleset(); fps=fps(o), kw...) 
    length(o) == 1 && @warn "The output has length 1: the saved gif will be a single image"
    simdata = SimData(o, ruleset)
    images = map(firstindex(o):lastindex(o)) do f
        @set! simdata.currentframe = f
        Array(grid_to_image!(o, simdata, o[f]))
    end
    array = cat(images..., dims=3)
    @show size(array)
    FileIO.save(filename, array; fps=fps, kw...)
    array
end


"""
    GifOutput <: ImageOutput

    GifOutput(init; filename, tspan, kw...)

Output that stores the simulation as images and saves a Gif file on completion.

# Arguments:
- `init`: initialisation `Array` or `NamedTuple` of `Array`

# Keywords

- `filename`: File path to save the gif file to.
- `tspan`: `AbstractRange` timespan for the simulation
- `aux`: NamedTuple of arbitrary input data. Use `get(data, Aux(:key), I...)` 
    to access from a `Rule` in a type-stable way.
- `mask`: `BitArray` for defining cells that will/will not be run.
- `padval`: padding value for grids with neighborhood rules. The default is `zero(eltype(init))`.
- `font`: `String` font name, used in default `TextConfig`. A default will be guessed.
- `text`: [`TextConfig`](@ref) object or `nothing` for no text.
- `scheme`: ColorSchemes.jl scheme, or `Greyscale()`
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
function GifOutput(; frames, running, extent, graphicconfig, imageconfig, filename, kw...)
    gif = _allocgif(imageconfig, extent)
    GifOutput(frames, running, extent, graphicconfig, imageconfig, gif, filename)
end

filename(o::GifOutput) = o.filename
gif(o::GifOutput) = o.gif

showimage(image, o::GifOutput, data::AbstractSimData) = gif(o)[:, :, currentframe(data)] .= image 

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
