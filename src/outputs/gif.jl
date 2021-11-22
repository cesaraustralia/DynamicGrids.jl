"""
    savegif(filename::String, o::Output; kw...)

Write the output array to a gif.

# Arguments

- `filename`: File path to save the gif file to.
- `output`: An [`Output`](@ref) object. Note that to make a gif, the output should stores
    frames, and run with `store=true`, and `@assert DynamicGrids.istored(o)` should pass.

# Keywords

[`ImageConfig`](@ref) keywords:

$IMAGECONFIG_KEYWORDS
"""
function savegif(filename::String, o::Output, ruleset=Ruleset(); 
    minval=minval(o), maxval=maxval(o), 
    scheme=ObjectScheme(), renderer=autorenderer(init(o), scheme), 
    font=autofont(), text=TextConfig(font=font), textconfig=text, kw...
)
    im_o = NoDisplayImageOutput(o; 
        imageconfig=ImageConfig(init(o); 
            minval=minval, maxval=maxval, renderer=renderer, textconfig=textconfig
        )
    )
    savegif(filename, im_o, ruleset; kw...) 
end
function savegif(filename::String, o::ImageOutput, ruleset=Ruleset(); fps=fps(o), kw...) 
    length(o) == 1 && @warn "The output has length 1: the saved gif will be a single image"
    simdata = SimData(o, ruleset)
    images = map(firstindex(o):lastindex(o)) do f
        @set! simdata.currentframe = f
        Array(render!(o, simdata, o[f]))
    end
    array = cat(images..., dims=3)
    FileIO.save(filename, array; fps=fps, kw...)
    array
end

"""
    GifOutput <: ImageOutput

    GifOutput(init; filename, tspan, kw...)

Output that stores the simulation as images and saves a Gif file on completion.

# Arguments:

- `init`: initialisation `AbstractArrayArray` or `NamedTuple` of `AbstractArrayArray`.

# Keywords

Storing the gif:
- `filename`: File path to save the gif file to.

$IMAGEOUTPUT_KEYWORDS
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

# Getters
filename(o::GifOutput) = o.filename
gif(o::GifOutput) = o.gif

# Output/ImageOutput interface methods
maybesleep(output::GifOutput, f) = nothing
function showimage(image, o::GifOutput, data::AbstractSimData)
    gif(o)[:, :, currentframe(data)] .= image 
end
finalisegraphics(o::GifOutput, data::AbstractSimData) = savegif(o)

# The gif is already generated, just save it again if neccessary
savegif(o::GifOutput) = savegif(filename(o), o)
function savegif(filename::String, o::GifOutput, fps=fps(o); kw...)
    FileIO.save(filename, gif(o); fps=fps, kw...)
end

# Preallocate the 3 dimensional gif array
_allocgif(i::ImageConfig, e::Extent) = _allocgif(renderer(i), i::ImageConfig, e::Extent) 
function _allocgif(r::Renderer, i::ImageConfig, e::Extent)
    zeros(ARGB32, imagesize(r, e)..., length(tspan(e)))
end
