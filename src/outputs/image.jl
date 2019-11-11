"""
Graphic outputs that display frames as RGB24 images.
"""
abstract type ImageOutput{T} <: GraphicOutput{T} end

(::Type{F})(o::T; kwargs...) where F <: ImageOutput where T <: ImageOutput =
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

processor(o::ImageOutput) = o.processor
minval(o::ImageOutput) = o.minval
maxval(o::ImageOutput) = o.maxval


showframe(frame, o::ImageOutput, data::AbstractSimData, f) = 
    showframe(frame, o, ruleset(data), f)
showframe(frame, o::ImageOutput, ruleset::AbstractRuleset, f) =
    showframe(frametoimage(o, ruleset, frame, f), o, f)

# Manual showframe without data/ruleset
showframe(o::ImageOutput, f=lastindex(o)) = showframe(o[f], o, Ruleset(), f) 


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
abstract type FrameProcessor end

abstract type MultiFrameProcessor <: FrameProcessor end

"""
Convert frame matrix to RGB24, using an FrameProcessor
"""
function frametoimage end

frametoimage(o::ImageOutput, i::Integer) = frametoimage(o, o[i], i)
frametoimage(o::ImageOutput, frame, i::Integer) = 
    frametoimage(processor(o), o, Ruleset(), o[i], i)
frametoimage(o::ImageOutput, args...) = frametoimage(processor(o), o, args...)

""""
Converts output frames to a colorsheme.
# Arguments
`scheme`: a ColorSchemes.jl colorscheme.
"""
struct ColorProcessor{S,Z,M} <: FrameProcessor
    scheme::S
    zerocolor::Z
    maskcolor::M
end
ColorProcessor(; scheme=Greyscale(), zerocolor=nothing, maskcolor=nothing) =
    ColorProcessor(scheme, zerocolor, maskcolor)

scheme(processor::ColorProcessor) = processor.scheme
zerocolor(processor::ColorProcessor) = processor.zerocolor
maskcolor(processor::ColorProcessor) = processor.maskcolor

frametoimage(p::ColorProcessor, o::Output, 
             ruleset::AbstractRuleset, frame::AbstractArray, t) = begin
    img = fill(RGB24(0), size(frame))
    for i in CartesianIndices(frame)
        img[i] = if !(maskcolor(p) isa Nothing) && ismasked(mask(ruleset), i)
            maskcolor(p)
        else
            x = frame[i]
            if hasminmax(o) isa HasMinMax
                x = normalise(x, minval(o), maxval(o))
            end
            if !(zerocolor(p) isa Nothing) && x == zero(x)
                zerocolor(p)
            else
                rgb(scheme(p), x)
            end
        end
    end
    img
end

abstract type BandColor end

struct Red <: BandColor end
struct Green <: BandColor end
struct Blue <: BandColor end

struct ThreeColor{C<:Tuple,Z,M} <: MultiFrameProcessor
    colors::C
    zerocolor::Z
    maskcolor::M
end
ThreeColor(; colors=(Red(), Green(), Blue()), zerocolor=nothing, maskcolor=nothing) =
    ThreeColor(colors, zerocolor, maskcolor)

colors(processor::ThreeColor) = processor.colors
zerocolor(processor::ThreeColor) = processor.zerocolor
maskcolor(processor::ThreeColor) = processor.maskcolor

frametoimage(p::ThreeColor, o::Output, ruleset, bands::NamedTuple, t) = begin
    img = fill(RGB24(0), size(first(bands)))
    ncols = length(colors(p))
    nbands = length(bands) 
    nbands == ncols || throw(ArgumentError("$nbands layers in model but $ncols colors"))

    for i in CartesianIndices(first(bands))
        img[i] = if !(maskcolor(p) isa Nothing) && ismasked(mask(ruleset), i)
            maskcolor(p)
        else
            if hasminmax(o) isa HasMinMax
                xs = map((f, mi, ma) -> normalise(f[i], mi, ma), values(bands), minval(o), maxval(o))
            else
                xs = map(f -> f[i], values(bands))
            end
            if !(zerocolor(p) isa Nothing) && all(map(x -> x .== zero(x), xs))
                zerocolor(p)
            else
                acc = (0.0, 0.0, 0.0)
                combine(colors(p), acc, xs)
            end
        end
    end
    img
end

combine(c::Tuple{Red,Vararg}, acc, xs) = combine(tail(c), (acc[1] + xs[1], acc[2], acc[3]), tail(xs))
combine(c::Tuple{Green,Vararg}, acc, xs) = combine(tail(c), (acc[1], acc[2] + xs[1], acc[3]), tail(xs))
combine(c::Tuple{Blue,Vararg}, acc, xs) = combine(tail(c), (acc[1], acc[2], acc[3] + xs[1]), tail(xs))
combine(c::Tuple{Nothing,Vararg}, acc, xs) = combine(tail(c), acc, tail(xs))
combine(c::Tuple{}, acc, xs) = RGB24(acc...)

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
    savegif(filename::String, o::Output, ruleset; [processor=processor(o)], [kwargs...])

Write the output array to a gif. You must pass a processor keyword argument for any
`Output` objects not in `ImageOutput` (which allready have a processor attached).

Saving very large gifs may trigger a bug in Imagemagick.
"""
savegif(filename::String, o::Output, ruleset=Ruleset(); 
        processor=processor(o), minval=0, maxval=1, kwargs...) = begin
    # fr = normaliseframe.(frames(o), minval, maxval)
    images = frametoimage.(Ref(processor), Ref(o), Ref(ruleset), frames(o), collect(firstindex(o):lastindex(o)))
    array = cat(images..., dims=3)
    FileIO.save(filename, array; kwargs...)
end


struct HasMinMax end
struct NoMinMax end

hasminmax(output::T) where T = (:minval in fieldnames(T)) ? HasMinMax() : NoMinMax()

normaliseframe(output::Output, a) = 
    normaliseframe(hasminmax(output), output, a)
normaliseframe(::HasMinMax, output, a::NamedTuple) =
    map(normaliseframe, values(a), minval(output), maxval(output))
normaliseframe(::HasMinMax, output, a::AbstractArray) =
    normaliseframe(a, minval(output), maxval(output))
normaliseframe(::NoMinMax, output, a) = a
normaliseframe(a::AbstractArray, minval::Number, maxval::Number) = normalise.(a, minval, maxval)
normaliseframe(a::AbstractArray, minval, maxval) = a

normalise(x::Number, minval::Number, maxval::Number) = 
    min((x - minval) / (maxval - minval), oneunit(eltype(x)))
