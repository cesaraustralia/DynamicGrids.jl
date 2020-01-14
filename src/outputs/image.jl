"""
Graphic outputs that displays an output frame as an RGB24 images.
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
    minval::Mi   | 0
    maxval::Ma   | 1
end

processor(o::ImageOutput) = o.processor
minval(o::ImageOutput) = o.minval
maxval(o::ImageOutput) = o.maxval

processor(o::Output) = Greyscale()
minval(o::Output) = 0
maxval(o::Output) = 1


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

"Alternate name for Greyscale()"
const Grayscale = Greyscale



"""
Frame processors convert a frame of the grid simulation into an RGB24 image for display.
"""
abstract type FrameProcessor end

"""
Processors that convert one frame of a single grid model to an image.
"""
abstract type SingleFrameProcessor <: FrameProcessor end

"""
Processors that convert frames from multiple grids to a single image.
"""
abstract type MultiFrameProcessor <: FrameProcessor end

"""
Convert a frame to an RGB24 image, using a FrameProcessor
"""
function frametoimage end

frametoimage(o::ImageOutput, i::Integer) = frametoimage(o, o[i], i)
frametoimage(o::ImageOutput, frame, i::Integer) = 
    frametoimage(processor(o), o, Ruleset(), o[i], i)
frametoimage(o::ImageOutput, ruleset::AbstractRuleset, i::Integer) = 
    frametoimage(processor(o), o, ruleset, o[i], i)
frametoimage(processor::FrameProcessor, o::ImageOutput, ruleset, frame, i) =
    frametoimage(processor::FrameProcessor, minval(o), maxval(o), ruleset, frame, i)

frametoimage(o::ImageOutput, args...) = frametoimage(processor(o), o, args...)

""""
    ColorProcessor(; scheme=Greyscale(), zerocolor=nothing, maskcolor=nothing)

Converts output frames to a colorsheme.

## Arguments / Keyword Arguments
- `scheme`: a ColorSchemes.jl colorscheme.
- `zerocolor`: an `RGB24` color to use when values are zero, or `nothing` to ignore.
- `maskcolor`: an `RGB24` color to use when cells are masked, or `nothing` to ignore.
"""
@default_kw struct ColorProcessor{S,Z,M} <: SingleFrameProcessor
    scheme::S    | Greyscale()
    zerocolor::Z | nothing
    maskcolor::M | nothing
end

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
            x = if minval === nothing || maxval === nothing
                frame[i]
            else
                normalise(frame[i], minval, maxval)
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

rgb(scheme, x) = RGB24(get(scheme, x))
rgb(c::RGB24) = c
rgb(c::Tuple) = RGB24(c...)
rgb(c::Number) = RGB24(c)


abstract type BandColor end

struct Red <: BandColor end
struct Green <: BandColor end
struct Blue <: BandColor end


"""
    ThreeColorProcessor(; colors=(Red(), Green(), Blue()), zerocolor=nothing, maskcolor=nothing)

Assigns `Red()`, `Blue()`, `Green()` or `nothing` to 
any number of dynamic grids in any order. Duplicate colors will be summed.
The final color sums are combined into a composite color image for display.

## Arguments / Keyword Arguments
- `colors`: a tuple or `Red()`, `Green()`, `Blue()`, or `nothing` matching the number of grids.
- `zerocolor`: an `RGB24` color to use when values are zero, or `nothing` to ignore.
- `maskcolor`: an `RGB24` color to use when cells are masked, or `nothing` to ignore.
"""
@default_kw struct ThreeColorProcessor{C<:Tuple,Z,M} <: MultiFrameProcessor
    colors::C    | (Red(), Green(), Blue())
    zerocolor::Z | nothing
    maskcolor::M | nothing
end

colors(processor::ThreeColorProcessor) = processor.colors
zerocolor(processor::ThreeColorProcessor) = processor.zerocolor
maskcolor(processor::ThreeColorProcessor) = processor.maskcolor

frametoimage(p::ThreeColorProcessor, minval::Tuple, maxval::Tuple, ruleset, grids::NamedTuple, t) = begin
    img = fill(RGB24(0), size(first(grids)))
    ncols = length(colors(p))
    ngrids = length(grids) 
    if !(ngrids == ncols == length(minval) == length(maxval)) 
        throw(ArgumentError("Number of grids ($ngrids), processor colors ($ncols), minval ($(length(minval))) 
                            and maxival ($(length(maxval))) must be the same"))
    end
    for i in CartesianIndices(first(grids))
        img[i] = if !(maskcolor(p) isa Nothing) && ismasked(mask(ruleset), i)
            maskcolor(p)
        else
            xs = if minval === nothing || maxval === nothing
                map(f -> f[i], values(grids))
            else
                map((f, mi, ma) -> normalise(f[i], mi, ma), values(grids), minval, maxval)
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
LayoutProcessor(layout::Array, processors)
    LayoutProcessor(reshape(layout, length(layout), 1), processors)

## Arguments / Keyword arguments
- `layout`: A Vector or Matrix containing the keyes or numbers of frames in the locations to
  display them. `nothing`, `missing` or `0` values will be skipped.
- `processors`: tuple of SingleFrameProcessor, one for each grid in the simulation. 
  Can be `nothing` for unused grids.
"""
@default_kw struct LayoutProcessor{L<:AbstractMatrix,P} <: MultiFrameProcessor
    layout::L     | throw(ArgumentError("must include an Array for the layout keyword")) 
    processors::P | throw(ArgumentError("include a tuple of processors for each grid"))
end
# Convenience constructor to convert Vector input to a column Matrix
LayoutProcessor(layout::AbstractVector, processors) = 
    LayoutProcessor(reshape(layout, length(layout), 1), processors)

layout(p::LayoutProcessor) = p.layout
processors(p::LayoutProcessor) = p.processors

frametoimage(p::LayoutProcessor, minval::Tuple, maxval::Tuple, ruleset, grids::NamedTuple, t) = begin
    if !(length(grids) == length(minval) == length(maxval)) 
        throw(ArgumentError("Number of grids ($(length(grids)), minval ($(length(minval))) 
                            and maxival ($(length((maxval))) must be the same"))
    end

    grid_ids = layout(p)
    sze = size(first(grids))
    img = fill(RGB24(0), sze .* size(grid_ids))
    # Loop over the layout matrix
    for i in 1:size(grid_ids, 1), j in 1:size(grid_ids, 2)
        grid_id = grid_ids[i, j]
        # Accept symbol keys and numbers, skip missing/nothing/0
        (ismissing(grid_id) || grid_id === nothing || grid_id == 0)  && continue
        n = if grid_id isa Symbol
            found = findfirst(k -> k === grid_id, keys(grids)) 
            found === nothing && throw(ArgumentError("$grid_id is not in $(keys(grids))"))
            found 
        else
            grid_id
        end
        # Run processor for section
        section = frametoimage(processors(p)[n], minval[n], maxval[n], ruleset, grids[n], t)
        # Copy section into image
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
        processor=processor(o), minval=minval(o), maxval=maxval(o), kwargs...) = begin
    images = map(frames(o), collect(firstindex(o):lastindex(o))) do frame, t 
        frametoimage(processor, minval, maxval, ruleset, frame, t) 
    end
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
