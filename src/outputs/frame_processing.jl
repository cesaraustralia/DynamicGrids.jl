"""
Frame processors convert frame data into RGB24 images
They can be passed as `procesor` keyword argument to outputs that have an image display.

To add new processor, define a type that inherits from AbstractFrameProcessor
and a [`frametoimage`](@ref) method:
```julia
frametoimage(p::YourProcessor, output, frame, t) = some_rbg_image
```
"""
abstract type AbstractFrameProcessor end

struct HasProcessor end
struct NoProcessor end

hasprocessor(o::O) where O = :processor in fieldnames(O) ? HasProcessor() : NoProcessor()


"""
Convert frame matrix to RGB24, using any AbstractFrameProcessor
"""
function frametoimage end
@inline frametoimage(o::AbstractOutput, frame::AbstractArray, t) =
    frametoimage(hasprocessor(o), o::AbstractOutput, frame::AbstractArray, t)
@inline frametoimage(::HasProcessor, o::AbstractOutput, frame::AbstractArray, t) =
    frametoimage(o.processor, o, frame, t)
@inline frametoimage(::NoProcessor, o::AbstractOutput, frame::AbstractArray, t) =
    frametoimage(GreyscaleProcessor(), o, frame, t)


"""
Converts output frames to a greyscale images
"""
struct GreyscaleProcessor <: AbstractFrameProcessor end
const GrayscaleProcessor = GreyscaleProcessor

@inline frametoimage(p::GreyscaleProcessor, o::AbstractOutput, frame::AbstractArray, t) = 
    RGB24.(frame)

""""
Converts output frames to a greyscale image with the chosen color for zeros.
Usefull for separating low values from actual zeros

# Arguments
`zerocolor`: RGB24 or a value that will be converted to RGB24 by the RGB24() constructor.
"""
struct GreyscaleZerosProcessor{C} <: AbstractFrameProcessor
    zerocolor::C
end
const GrayscaleZerosProcessor = GreyscaleZerosProcessor

@inline frametoimage(p::GreyscaleZerosProcessor, o::AbstractOutput, frame::AbstractArray, t) =
    map(x -> x == zero(x) ? RGB24(p.zerocolor) : RGB24(x), frame)

""""
Converts output frames to a colorsheme.
# Arguments
`scheme`: a ColorSchemes.jl colorscheme.
"""
struct ColorSchemeProcessor{S} <: AbstractFrameProcessor
    scheme::S
end

@inline frametoimage(p::ColorSchemeProcessor, o::AbstractOutput, frame::AbstractArray, t) =
    RGB24.(get(p.scheme, frame))

""""
Converts frame to a colorshceme image with the chosen color for zeros.
Usefull for separating low values from actual zeros

# Arguments
`scheme`: a ColorSchemes.jl colorscheme.
`zerocolor`: RGB24 or a value that will be converted to RGB24 by the RGB24() constructor.
"""
struct ColorSchemeZerosProcessor{S,C} <: AbstractFrameProcessor
    scheme::S
    zerocolor::C
end

@inline frametoimage(p::ColorSchemeZerosProcessor, o::AbstractOutput, frame::AbstractArray, t) =
    map(x -> x == zero(x) ? RGB24(p.zerocolor) : RGB24(get(p.scheme, x)), frame)

"""
    savegif(filename::String, output::AbstractOutput)
Write the output array to a gif.
Saving very large gifs may trigger a bug in imagemagick.
"""
savegif(filename::String, o::AbstractOutput; kwargs...) = savegif(filename, o::AbstractOutput, 0, 1; kwargs...)
savegif(filename::String, o::AbstractOutput, ruleset::AbstractRuleset; kwargs...) =
    savegif(filename, o, minval(ruleset), maxval(ruleset); kwargs...)
savegif(filename::String, o::AbstractOutput, minval, maxval; kwargs...) = begin
    frames = normaliseframe.(o, minval, maxval)
    images = frametoimage.(Ref(o), frames, collect(firstindex(o):lastindex(o)))
    array = cat(images..., dims=3)
    FileIO.save(filename, array; kwargs...)
end

