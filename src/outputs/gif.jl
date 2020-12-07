"""
savegif(filename::String, o::Output, data; processor=processor(o), fps=fps(o), [kwargs...])

Write the output array to a gif. You must pass a processor keyword argument for any
`Output` objects not in `ImageOutput` (which allready have a processor attached).

Saving very large gifs may trigger a bug in Imagemagick.
"""
function savegif(filename::String, o::Output, ruleset=Ruleset(); 
    minval=minval(o), maxval=maxval(o), processor=processor(o), kwargs...
)
    im_o = NoDisplayImageOutput(o; maxval=maxval, minval=minval, processor=processor)
    savegif(filename, im_o, ruleset; kwargs...) 
end
function savegif(filename::String, o::ImageOutput, ruleset=Ruleset();
    processor=processor(o), fps=fps(o), kwargs...
)
    length(o) == 1 && @warn "The output has length 1: the saved gif will be a single image"
    ext = extent(o)
    simdata = SimData(ext, ruleset)
    println(tspan(ext))
    images = map(collect(firstindex(o):lastindex(o))) do f
        @set! simdata.currentframe = f
        grid2image!(imgbuffer(o), processor, o, simdata)
    end
    array = cat(images..., dims=3)
    FileIO.save(filename, array; fps=fps, kwargs...)
end


"""
    GifOutput(init; 
        filename, tspan, fps=25.0, store=false, 
        font=autofont(),
        scheme=Greyscale()
        text=TextConfig(; font=font),
        processor=autoprocessor(init, text)
        minval=nothing, maxval=nothing
    )

Output that stores the simulation as images and saves a Gif file on completion.
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
GifOutput(; frames, running, extent, graphicconfig, imageconfig, filename, kwargs...) =
    GifOutput(frames, running, extent, graphicconfig, imageconfig, _allocgif(imageconfig, extent), filename)

filename(o::GifOutput) = o.filename
gif(o::GifOutput) = o.gif

showimage(image, o::GifOutput, data::SimData) = gif(o)[:, :, currentframe(data)] .= image 

finalisegraphics(o::GifOutput, data::AbstractSimData) = savegif(o)

savegif(o::GifOutput) = savegif(filename(o), o)
function savegif(filename::String, o::GifOutput, ruleset=nothing, fps=fps(o);
    processor=nothing, kwargs...
)
    FileIO.save(filename, gif(o); fps=fps, kwargs...)
end


_allocgif(i::ImageConfig, e::Extent) = _allocgif(processor(i), i::ImageConfig, e::Extent) 
function _allocgif(::Processor, i::ImageConfig, e::Extent)
    zeros(ARGB32, gridsize(e)..., length(tspan(e)))
end
function _allocgif(p::LayoutProcessor, i::ImageConfig, e::Extent)
    zeros(ARGB32, (gridsize(e) .* size(p.layout))..., length(tspan(e)))
end
