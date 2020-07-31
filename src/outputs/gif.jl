"""
savegif(filename::String, o::Output, data; processor=processor(o), fps=fps(o), [kwargs...])

Write the output array to a gif. You must pass a processor keyword argument for any
`Output` objects not in `ImageOutput` (which allready have a processor attached).

Saving very large gifs may trigger a bug in Imagemagick.
"""
savegif(filename::String, o::Output, ruleset=Ruleset(); 
        minval=minval(o), maxval=maxval(o), processor=processor(o), kwargs...) = begin
    im_o = NoDisplayImageOutput(o; maxval=maxval, minval=minval, processor=processor)
    savegif(filename, im_o, ruleset; kwargs...) 
end
savegif(filename::String, o::ImageOutput, ruleset=Ruleset();
        processor=processor(o), fps=fps(o), kwargs...) = begin
    images = map(frames(o), collect(firstindex(o):lastindex(o))) do frame, t
        grid2image(processor, o, ruleset, frame, t)
    end
    array = cat(images..., dims=3)
    FileIO.save(filename, array; fps=fps, kwargs...)
end


"""
    GifOutput(init; filename, tspan, fps=25.0, store=false, 
              processor=ColorProcessor(), minval=nothing, maxval=nothing)

Output that stores the simulation as images and saves a Gif file on completion.
"""
mutable struct GifOutput{T,F<:AbstractVector{T},E,GC,IC,I,N} <: ImageOutput{T}
    frames::F
    running::Bool 
    extent::E
    graphicconfig::GC
    imageconfig::IC
    image::I
    filename::N
end
GifOutput(; frames, running, extent, graphicconfig, imageconfig, filename, kwargs...) =
    GifOutput(frames, running, extent, graphicconfig, imageconfig, allocgif(extent), filename)

filename(o::GifOutput) = o.filename
gif(o::GifOutput) = o.gif

showimage(image, o::GifOutput, data::SimData, f, t) = gif(o)[:, :, f] = image 

finalise(o::GifOutput) = savegif(o)

allocgif(e::Extent) = zeros(ARGB32, gridsize(e)..., length(tspan(e)))

savegif(o::GifOutput) = savegif(filename(o), o)
savegif(filename::String, o::GifOutput, ruleset=nothing, fps=fps(o);
        processor=nothing, kwargs...) = begin
    !(processor isa Nothing) && @warn "Cannot set the processor on savegif for GifOutput. Run the sim again"
    FileIO.save(filename, o.image; fps=fps, kwargs...)
end
