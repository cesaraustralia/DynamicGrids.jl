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
    min::M1
    max::M2
end
Greyscale(; min=nothing, max=nothing) = Greyscale(min, max)

Base.get(scheme::Greyscale, x) = scale(x, scheme.min, scheme.max)

scale(x, ::Nothing, max) = x * max
scale(x, min, ::Nothing) = x * (one(min) - min) + min
scale(x, ::Nothing, ::Nothing) = x
scale(x, min, max) = x * (max - min) + min

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
frametoimage(processor::FrameProcessor, o::ImageOutput, ruleset, frame, i) =
    frametoimage(processor::FrameProcessor, maxval(o), minval(o), ruleset, frame, i)

frametoimage(o::ImageOutput, args...) = frametoimage(processor(o), o, args...)

""""
Converts output frames to a colorsheme.

## Arguments
- `scheme`: a ColorSchemes.jl colorscheme.
- `zerocolor`: an `RGB24` color to use when values are zero, or `nothing` to ignore.
- `maskcolor`: an `RGB24` color to use when cells are masked, or `nothing` to ignore.
"""
struct ColorProcessor{S,Z,M} <: FrameProcessor
    scheme::S
    zerocolor::Z
    maskcolor::M
end
"""
    ColorProcessor(; scheme=Greyscale(), zerocolor=nothing, maskcolor=nothing)
"""
ColorProcessor(; scheme=Greyscale(), zerocolor=nothing, maskcolor=nothing) =
    ColorProcessor(scheme, zerocolor, maskcolor)

scheme(processor::ColorProcessor) = processor.scheme
zerocolor(processor::ColorProcessor) = processor.zerocolor
maskcolor(processor::ColorProcessor) = processor.maskcolor

frametoimage(p::ColorProcessor, minval, maxval,
             ruleset::AbstractRuleset, frame::AbstractArray, t) = begin
    img = fill(RGB24(0), size(frame))
    for i in CartesianIndices(frame)
        img[i] = if !(maskcolor(p) isa Nothing) && ismasked(mask(ruleset), i)
            maskcolor(p)
        else
            x = if isnothing(minval) || isnothing(maxval)
                frame[i]
            else
                normalise(frame[i], minval, maxval)
            end
            if !(zerocolor(p) isa Nothing) && x == zero(x)
                zerocolor(p)
            else
                if x < 0 
                    println(i)
                    println(t)
                    println(x)
                end
                rgb(scheme(p), x)
            end
        end
    end
    img
end

rgb(scheme, x) = RGB24(get(scheme, x))
rgb(c::RGB24) = c
rgb(c::Tuple) = RGB24(c...)
rgb(c::Number) = RGB24(c)



abstract type BandColor end

struct Red <: BandColor end
struct Green <: BandColor end
struct Blue <: BandColor end


"""
ThreeColor processor. Assigns `Red()`, `Blue()`, `Green()` or `nothing` to 
any number of dynamic grids in any order. Duplicate colors will be summed.
The final color sums are combined into a composite color image for display.

## Arguments
- `colors`: a tuple or `Red()`, `Green()`, `Blue()`, or `nothing` matching the number of grids.
- `zerocolor`: an `RGB24` color to use when values are zero, or `nothing` to ignore.
- `maskcolor`: an `RGB24` color to use when cells are masked, or `nothing` to ignore.
"""
struct ThreeColor{C<:Tuple,Z,M} <: MultiFrameProcessor
    colors::C
    zerocolor::Z
    maskcolor::M
end
"""
    ThreeColor(; colors=(Red(), Green(), Blue()), zerocolor=nothing, maskcolor=nothing)

Kewyword argument constructor for the ThreeColor processor.
"""
ThreeColor(; colors=(Red(), Green(), Blue()), zerocolor=nothing, maskcolor=nothing) =
    ThreeColor(colors, zerocolor, maskcolor)

colors(processor::ThreeColor) = processor.colors
zerocolor(processor::ThreeColor) = processor.zerocolor
maskcolor(processor::ThreeColor) = processor.maskcolor

frametoimage(p::ThreeColor, minvals::Tuple, maxvals::Tuple, ruleset, bands::NamedTuple, t) = begin
    img = fill(RGB24(0), size(first(bands)))
    ncols = length(colors(p))
    nbands = length(bands) 
    if !(nbands == ncols == length(minvals) == length(maxvals)) 
        throw(ArgumentError("Number of grids ($nbands), processor colors ($ncols), minimum values ($(minval(o))) 
                             and maximum values ($(maxval(o))) must all be the same"))
    end

    for i in CartesianIndices(first(bands))
        img[i] = if !(maskcolor(p) isa Nothing) && ismasked(mask(ruleset), i)
            maskcolor(p)
        else
            xs = if isnothing(minval) || isnothing(maxval)
                map((f, mi, ma) -> normalise(f[i], mi, ma), values(bands), minvals, maxvals)
            else
                map(f -> f[i], values(bands))
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

"""

## Arguments
- `processors`: a list of color processors, defaulting to Greyscale()
- `layout`
"""
struct LayoutProcessor{L<:AbstractMatrix,P<:Tuple} <: MultiFrameProcessor
    layout::L
    processors::P
end
LayoutProcessor(layout::Vector, processors) = 
    LayoutProcessor(reshape(layout, length(layout), 1), processors)

layout(p::LayoutProcessor) = p.layout
processors(p::LayoutProcessor) = p.processors

LayoutProcessor(; layout=throw(ArgumentError("must include an Array for the layout keyword")), 
                processors=Tuple(ColorProcessor() for l in 1:maximum(layout))) =
    LayoutProcessor(layout, processors)

frametoimage(p::LayoutProcessor, minvals::Tuple, maxvals::Tuple, ruleset, frames::NamedTuple, t) = begin
    l = layout(p)
    if maximum(l) > length(frames)
        throw(ArgumentError("layout $(max(layout)) does not exist"))
    end
    sze = size(first(frames))
    img = fill(RGB24(0), sze .* size(l))
    for i in 1:size(l, 1), j in 1:size(l, 2)
        n = l[i, j]
        n == 0 && continue
        section = frametoimage(processors(p)[n], minvals[n], maxvals[n], ruleset, frames[n], t)
        for x in 1:size(section, 1), y in 1:size(section, 2)
            img[x + (i - 1) * sze[1], y + (j - 1) * sze[2]] = section[x, y]
        end
    end
    img
end

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
