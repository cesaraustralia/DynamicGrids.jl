"""
Frame processors convert frame data into RGB24 images
They can be passed as `procesor` keyword argument to outputs that have an image display.

To add new processor, define a type that inherits from AbstractFrameProcessor
and a [`processframe`](@ref) method:
```julia
processframe(p::YourType, output, frame, t) = some_rbg_image
```
"""
abstract type AbstractFrameProcessor end

struct HasProcessor end
struct NoProcessor end

hasprocessor(o::O) where O = :processor in fieldnames(O) ? HasProcessor() : NoProcessor()


""" 
Convert frame matrix to RGB24, using any AbstractFrameProcessor
$METHODLIST
""" 
function processframe end
@inline processframe(o, frame, t) = processframe(hasprocessor(o), o, frame, t)
@inline processframe(::HasProcessor, o, frame, t) = processframe(o.processor, o, frame, t)
@inline processframe(::NoProcessor, o, frame, t) = processframe(GreyscaleProcessor(), o, frame, t)


"Converts frame to a greyscale image"
struct GreyscaleProcessor <: AbstractFrameProcessor end
const GrayscaleProcessor = GreyscaleProcessor

@inline processframe(p::GreyscaleProcessor, o, frame, t) = RGB24.(normalizeframe(o, frame)) 

""""
Converts frame to a greyscale image with the chosen color for zeros. 
Usefull for separating low values from actual zeros
"""
struct GreyscaleZerosProcessor{C} <: AbstractFrameProcessor
    zerocolor::C
end
const GrayscaleZerosProcessor = GreyscaleZerosProcessor

@inline processframe(p::GreyscaleZerosProcessor, o, frame, t) = 
    map(x -> x == zero(x) ? RGB24(p.zerocolor) : RGB24(x), normalizeframe(o, frame))

""""
Converts frame to a greyscale image with the chosen color for zeros. 
Usefull for separating low values from actual zeros
"""
struct ColorSchemeProcessor{S} <: AbstractFrameProcessor
    scheme::S
end

@inline processframe(p::ColorSchemeProcessor, o, frame, t) = get(p.scheme, normalizeframe(o, frame)) 

struct ColorSchemeZerosProcessor{S,C} <: AbstractFrameProcessor
    scheme::S
    zerocolor::C
end

@inline processframe(p::ColorSchemeZerosProcessor, o, frame, t) =  
    map(x -> x == zero(x) ? RGB24(p.zerocolor) : get(p.scheme, x), normalizeframe(o, frame))


@inline normalizeframe(o, a::AbstractArray) = normalizeframe(hasminmax(o), o, a)
@inline normalizeframe(::HasMinMax, o, a::AbstractArray) = normalizeframe(a, o.min, o.max)
@inline normalizeframe(::NoMinMax, o, a::AbstractArray) = a
@inline normalizeframe(a::AbstractArray, minval::Number, maxval::Number) = 
    min.((a .- minval) ./ (maxval - minval), one(eltype(a)))

"""
    savegif(filename::String, output::AbstractOutput)
Write the output array to a gif.
Saving very large gifs may trigger a bug in imagemagick.
"""
savegif(filename::String, o::AbstractOutput; kwargs...) =
    FileIO.save(filename, cat(processframe.(Ref(o), o, collect(1:lastindex(o)))..., dims=3); kwargs...)
