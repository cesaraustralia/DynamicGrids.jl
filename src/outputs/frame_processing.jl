
"""
Default colorscheme. Better performance than using a Colorschemes.jl scheme.
"""
struct Greyscale{M1,M2}
    max::M1
    min::M2
end
Greyscale(; min=nothing, max=nothing) = Greyscale(max, min)

const Grayscale = Greyscale

# Greyscale is the default processor
processor(x) = Greyscale()

"""
Frame processors convert arrays into RGB24 images for display.
"""
abstract type AbstractFrameProcessor end


"""
Convert frame matrix to RGB24, using an AbstractFrameProcessor
"""
function frametoimage end

@inline frametoimage(o::AbstractImageOutput, args...) = frametoimage(processor(o), o, args...)
frametoimage(o::AbstractImageOutput, i::Integer) = frametoimage(processor(o), o, Ruleset(), o[i], i)
frametoimage(o::AbstractImageOutput, i::Integer) = frametoimage(processor(o), o, Ruleset(), o[i], i)

""""
Converts output frames to a colorsheme.
# Arguments
`scheme`: a ColorSchemes.jl colorscheme.
"""
struct ColorProcessor{S,Z,M} <: AbstractFrameProcessor
    scheme::S
    zerocolor::Z
    maskcolor::M
end

ColorProcessor(; scheme=Greyscale(), zerocolor=nothing, maskcolor=nothing) =
    ColorProcessor(scheme, zerocolor, maskcolor)


frametoimage(p::ColorProcessor, o::AbstractOutput, ruleset::AbstractRuleset, frame, t) = begin
    frame = normaliseframe(o, frame)
    img = similar(frame, RGB24)
    for i in CartesianIndices(frame)
        x = frame[i]
        img[i] = if !(p.maskcolor isa Nothing) && ismasked(mask(ruleset), i)
            p.maskcolor
        elseif !(p.zerocolor isa Nothing) && x == zero(x)
            p.zerocolor
        else
            rgb(p.scheme, x)
        end
    end
    img
end

rgb(g::Greyscale, x) = RGB24(scale(x, g.min, g.max))
rgb(scheme::ColorSchemes.ColorScheme, x) = RGB24(get(scheme, x))
rgb(c::RGB24) = c
rgb(c::Tuple) = RGB24(c...)
rgb(c::Number) = RGB24(c)

scale(x, ::Nothing, max) = x * max
scale(x, min, ::Nothing) = x * (one(min) - min) + min
scale(x, ::Nothing, ::Nothing) = x
scale(x, min, max) = x * (max - min) + min

"""
    savegif(filename::String, o::AbstractOutput, ruleset::AbstractRuleset; [processor=processor(o)], [kwargs...])

Write the output array to a gif. You must pass a processor keyword argument for any
`AbstractOutut` objects not in `AbstractImageOutput` (which allready have a processor attached).

Saving very large gifs may trigger a bug in Imagemagick.
"""
savegif(filename::String, o::AbstractOutput, ruleset::AbstractRuleset=Ruleset(); 
        processor=processor(o), kwargs...) = begin
    images = frametoimage.(Ref(processor), Ref(o), Ref(ruleset), frames(o), collect(firstindex(o):lastindex(o)))
    array = cat(images..., dims=3)
    FileIO.save(filename, array; kwargs...)
end
