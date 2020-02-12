"""
Graphic outputs that display the grid(s) as an RGB24 images.
"""
abstract type ImageOutput{T} <: GraphicOutput{T} end

"""
Construct one ImageOutput from another ImageOutput.
"""
(::Type{F})(o::T; kwargs...) where F <: ImageOutput where T <: ImageOutput = F(;
    frames=frames(o),
    starttime=starttime(o),
    endtime=endtime(o),
    fps=fps(o),
    showfps=showfps(o),
    timestamp=timestamp(o),
    stampframe=stampframe(o),
    store=store(o),
    processor=processor(o),
    minval=minval(o),
    maxval=maxval(o),
    kwargs...
)

"""
Mixin for outputs that output images and can use an image processor.
"""
@premix @default_kw struct Image{P,Mi,Ma}
    processor::P | ColorProcessor()
    minval::Mi   | 0
    maxval::Ma   | 1
end

processor(o::Output) = Greyscale()
processor(o::ImageOutput) = o.processor

minval(o::Output) = 0
minval(o::ImageOutput) = o.minval

maxval(o::Output) = 1
maxval(o::ImageOutput) = o.maxval



# Allow construcing a frame with the ruleset passed in instead of SimData
showgrid(o::ImageOutput, f, t) = showgrid(o[f], o, Ruleset(), f, t)
showgrid(grid, o::ImageOutput, ruleset::AbstractRuleset, f, t) =
    showgrid(grid2image(o, ruleset, grid, f), o, f, t)

"""
Default colorscheme. Better performance than using a Colorschemes.jl
scheme as there is no interpolation.
"""
struct Greyscale{M1,M2}
    min::M1
    max::M2
end
Greyscale(; min=nothing, max=nothing) = Greyscale(min, max)

Base.get(scheme::Greyscale, x) = scale(x, scheme.min, scheme.max)

"Alternate name for Greyscale()"
const Grayscale = Greyscale



"""
Grid processors convert a frame of the simulation into an RGB24 image for display.
Frames may hold one or multiple grids.
"""
abstract type GridProcessor end

"""
Grid processors that convert one grid to an image.
"""
abstract type SingleGridProcessor <: GridProcessor end

"""
Processors that convert multiple grids to an image.
"""
abstract type MultiGridProcessor <: GridProcessor end

"""
Convert a grid or named tuple of grids to an RGB24 image, using a GridProcessor
"""
function grid2image end

# grid2image(o, ruleset, grid, f)
# grid2image(o::ImageOutput, i::Integer) = grid2image(o, o[i], i)
# grid2image(o::ImageOutput, grid, i::Integer) = grid2image(o, Ruleset(), o[i], i)
# grid2image(o::ImageOutput, args...) = grid2image(processor(o), o, args...)
grid2image(o::ImageOutput, ruleset::AbstractRuleset, grid, i::Integer) =
    grid2image(processor(o), o, ruleset, grid, i)
grid2image(processor::GridProcessor, o::ImageOutput, ruleset, grid, i) =
    grid2image(processor::GridProcessor, minval(o), maxval(o), ruleset, grid, i)

""""
    ColorProcessor(; scheme=Greyscale(), zerocolor=nothing, maskcolor=nothing)

Converts output grids to a colorsheme.

## Arguments / Keyword Arguments
- `scheme`: a ColorSchemes.jl colorscheme.
- `zerocolor`: an `RGB24` color to use when values are zero, or `nothing` to ignore.
- `maskcolor`: an `RGB24` color to use when cells are masked, or `nothing` to ignore.
"""
@default_kw struct ColorProcessor{S,Z,M} <: SingleGridProcessor
    scheme::S    | Greyscale()
    zerocolor::Z | nothing
    maskcolor::M | nothing
end

scheme(processor::ColorProcessor) = processor.scheme
zerocolor(processor::ColorProcessor) = processor.zerocolor
maskcolor(processor::ColorProcessor) = processor.maskcolor

grid2image(p::ColorProcessor, minval, maxval,
           ruleset::AbstractRuleset, grid::AbstractArray, t) = begin
    img = fill(RGB24(0), size(grid))
    for i in CartesianIndices(grid)
        img[i] = if !(maskcolor(p) isa Nothing) && ismasked(mask(ruleset), i)
            maskcolor(p)
        else
            x = normalise(grid[i], minval, maxval)
            if !(zerocolor(p) isa Nothing) && x == zero(x)
                zerocolor(p)
            else
                rgb24(scheme(p), x)
            end
        end
    end
    img
end



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
@default_kw struct ThreeColorProcessor{C<:Tuple,Z,M} <: MultiGridProcessor
    colors::C    | (Red(), Green(), Blue())
    zerocolor::Z | nothing
    maskcolor::M | nothing
end

colors(processor::ThreeColorProcessor) = processor.colors
zerocolor(processor::ThreeColorProcessor) = processor.zerocolor
maskcolor(processor::ThreeColorProcessor) = processor.maskcolor

grid2image(p::ThreeColorProcessor, minval::Tuple, maxval::Tuple, ruleset,
           grids::NamedTuple, t) = begin
    img = fill(RGB24(0), size(first(grids)))
    ncols = length(colors(p))
    ngrids = length(grids)
    if !(ngrids == ncols == length(minval) == length(maxval))
        throw(ArgumentError("Number of grids ($ngrids), processor colors ($ncols), " *
            "minval ($(length(minval))) and maxival ($(length(maxval))) must be the same"))
    end
    for i in CartesianIndices(first(grids))
        img[i] = if !(maskcolor(p) isa Nothing) && ismasked(mask(ruleset), i)
            maskcolor(p)
        else
            xs = map((f, mi, ma) -> normalise(f[i], mi, ma), values(grids), minval, maxval)
            if !(zerocolor(p) isa Nothing) && all(map(x -> x .== zero(x), xs))
                zerocolor(p)
            else
                combinebands(colors(p), xs)
            end
        end
    end
    img
end


"""
LayoutProcessor(layout::Array, processors)
    LayoutProcessor(reshape(layout, length(layout), 1), processors)

## Arguments / Keyword arguments
- `layout`: A Vector or Matrix containing the keyes or numbers of grids in the locations to
  display them. `nothing`, `missing` or `0` values will be skipped.
- `processors`: tuple of SingleGridProcessor, one for each grid in the simulation.
  Can be `nothing` for unused grids.
"""
@default_kw struct LayoutProcessor{L<:AbstractMatrix,P} <: MultiGridProcessor
    layout::L     | throw(ArgumentError("must include an Array for the layout keyword"))
    processors::P | throw(ArgumentError("include a tuple of processors for each grid"))
end
# Convenience constructor to convert Vector input to a column Matrix
LayoutProcessor(layout::AbstractVector, processors) =
    LayoutProcessor(reshape(layout, length(layout), 1), processors)

layout(p::LayoutProcessor) = p.layout
processors(p::LayoutProcessor) = p.processors

grid2image(p::LayoutProcessor, minval::Tuple, maxval::Tuple, ruleset, grids::NamedTuple, t) = begin
    if !(length(grids) == length(minval) == length(maxval))
        throw(ArgumentError("Number of grids ($(length(grids))), minval ($(length(minval))) and maxval ($(length(maxval))) must be the same"))
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
        section = grid2image(processors(p)[n], minval[n], maxval[n], ruleset, grids[n], t)
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
        grid2image(processor, minval, maxval, ruleset, frame, t)
    end
    array = cat(images..., dims=3)
    FileIO.save(filename, array; kwargs...)
end

# Color manipulation tools

"""
    normalise(x, min, max)

Set a value to be between zero and one, before converting to Color.
min and max of `nothing` are assumed to be 0 and 1.
"""
normalise(x, minval::Number, maxval::Number) =
    min((x - minval) / (maxval - minval), oneunit(x))
normalise(x, minval::Number, maxval::Nothing) = (x - minval) / (onunit(minval) - minval)
normalise(x, minval::Nothing, maxval::Number) = min(x / maxval, oneunit(x))
normalise(x, minval::Nothing, maxval::Nothing) = x

"""
    scale(x, min, max)

Rescale a value between 0 and 1 to be between `min` and `max`.
This can be used to shrink the range of a colorsheme that is displayed.
min and max of `nothing` are assumed to be 0 and 1.
"""
scale(x, min, max) = x * (max - min) + min
scale(x, ::Nothing, max) = x * max
scale(x, min, ::Nothing) = x * (oneunit(min) - min) + min
scale(x, ::Nothing, ::Nothing) = x

"""
    rgb24(val)

Convert a number, tuple or color to an RGB24 value.
"""
rgb24(val::Number) = RGB24(val)
rgb24(vals::Tuple) = RGB24(vals...)
rgb24(val::Color) = RGB24(val)
rgb24(val::RGB24) = val
"""
    rgb24(scheme, val)

Convert a color scheme and value to an RGB24 value.
"""
rgb24(scheme, val) = RGB24(get(scheme, val))

"""
    combinebands(c::Tuple{Vararg{<:BandColor}, acc, xs)

Assign values to color bands given in any order, and output as RGB24.
"""
combinebands(colors, xs) = combinebands(colors, xs, (0.0, 0.0, 0.0))
combinebands(c::Tuple{Red,Vararg}, xs, acc) =
    combinebands(tail(c), tail(xs), (acc[1] + xs[1], acc[2], acc[3]))
combinebands(c::Tuple{Green,Vararg}, xs, acc) =
    combinebands(tail(c), tail(xs), (acc[1], acc[2] + xs[1], acc[3]))
combinebands(c::Tuple{Blue,Vararg}, xs, acc) =
    combinebands(tail(c), tail(xs), (acc[1], acc[2], acc[3] + xs[1]))
combinebands(c::Tuple{Nothing,Vararg}, xs, acc) =
    combinebands(tail(c), tail(xs), acc)
combinebands(c::Tuple{}, xs, acc) = RGB24(acc...)
