"""
Graphic outputs that display frames as RGB24 images.
"""
abstract type AbstractImageOutput{T} <: AbstractGraphicOutput{T} end

(::Type{F})(o::T; kwargs...) where F <: AbstractImageOutput where T <: AbstractImageOutput =
    F(; frames=frames(o), starttime=starttime(o), endtime=endtime(o), 
      fps=fps(o), showfps=showfps(o), timestamp=timestamp(o), stampframe=stampframe(o), store=store(o),
      processor=processor(o), minval=minval(o), maxval=maxval(o),
      kwargs...)

"""
Mixin for outputs that output images and can use an image processor.
"""
@premix @default_kw struct Image{P,Mi,Ma}
    processor::P | ColorProcessor()
    minval::Mi   | 0.0
    maxval::Ma   | 1.0
end

processor(o::AbstractImageOutput) = o.processor
minval(o::AbstractImageOutput) = o.minval
maxval(o::AbstractImageOutput) = o.maxval


showframe(frame, o::AbstractImageOutput, data::AbstractSimData, f) = 
    showframe(frame, o, ruleset(data), f)
showframe(frame, o::AbstractImageOutput, ruleset::AbstractRuleset, f) =
    showframe(frametoimage(o, ruleset, frame, f), o, f)

# Manual showframe without data/ruleset
showframe(o::AbstractImageOutput, f=lastindex(o)) = showframe(o[f], o::AbstractImageOutput, f) 
showframe(frame, o::AbstractImageOutput, f) =
    showframe(frametoimage(o, normaliseframe(o, frame), f), o::AbstractOutput, f)


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

frametoimage(o::AbstractImageOutput, i::Integer) = frametoimage(o, o[i], i)
frametoimage(o::AbstractImageOutput, frame::AbstractArray, i::Integer) = 
    frametoimage(processor(o), o, Ruleset(), o[i], i)
frametoimage(o::AbstractImageOutput, args...) = frametoimage(processor(o), o, args...)

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


struct HasMinMax end
struct NoMinMax end

hasminmax(output::T) where T = (:minval in fieldnames(T)) ? HasMinMax() : NoMinMax()

normaliseframe(output::AbstractOutput, a::AbstractArray) = 
    normaliseframe(hasminmax(output), output, a)
normaliseframe(::HasMinMax, output, a::AbstractArray) =
    normaliseframe(a, minval(output), maxval(output))
normaliseframe(a::AbstractArray, minval::Number, maxval::Number) = normalise.(a, minval, maxval)
normaliseframe(a::AbstractArray, minval, maxval) = a
normaliseframe(::NoMinMax, output, a::AbstractArray) = a

normalise(x::Number, minval::Number, maxval::Number) = min((x - minval) / (maxval - minval), oneunit(eltype(x)))
