"""
Frame processors convert frame data into RGB24 images
They can be passed as `procesor` keyword argument to outputs that have an image display.

To add new processor, define a type that inherits from AbstractFrameProcessor
and a [`process_frame`](@ref) method:
```julia
process_frame(p::YourType, output, frame, t) = some_rbg_image
```
"""
abstract type AbstractFrameProcessor end

struct HasProcessor end
struct NoProcessor end

has_processor(o::O) where O = :processor in fieldnames(O) ? HasProcessor() : NoProcessor()


""" 
Convert frame matrix to RGB24, using any AbstractFrameProcessor
$METHODLIST
""" 
function process_frame end
@inline process_frame(o, frame, t) = process_frame(has_processor(o), o, frame, t)
@inline process_frame(::HasProcessor, o, frame, t) = process_frame(o.processor, o, frame, t)
@inline process_frame(::NoProcessor, o, frame, t) = process_frame(GreyscaleProcessor(), o, frame, t)


"Converts frame to a greyscale image"
struct GreyscaleProcessor <: AbstractFrameProcessor end
const GrayscaleProcessor = GreyscaleProcessor

@inline process_frame(p::GreyscaleProcessor, o, frame, t) = RGB24.(normalize_frame(o, frame)) 

""""
Converts frame to a greyscale image with the chosen color for zeros. 
Usefull for separating low values from actual zeros
"""
struct GreyscaleZerosProcessor{C} <: AbstractFrameProcessor
    zerocolor::C
end
const GrayscaleZerosProcessor = GreyscaleZerosProcessor

@inline process_frame(p::GreyscaleZerosProcessor, o, frame, t) = 
    map(x -> x == zero(x) ? RGB24(p.zerocolor) : RGB24(x), normalize_frame(o, frame))

""""
Converts frame to a greyscale image with the chosen color for zeros. 
Usefull for separating low values from actual zeros
"""
struct ColorSchemeProcessor{S} <: AbstractFrameProcessor
    scheme::S
end

@inline process_frame(p::ColorSchemeProcessor, o, frame, t) = get(p.scheme, normalize_frame(o, frame)) 

struct ColorSchemeZerosProcessor{S,C} <: AbstractFrameProcessor
    scheme::S
    zerocolor::C
end

@inline process_frame(p::ColorSchemeZerosProcessor, o, frame, t) =  
    map(x -> x == zero(x) ? RGB24(p.zerocolor) : get(p.scheme, x), normalize_frame(o, frame))


@inline normalize_frame(o, a::AbstractArray) = normalize_frame(has_minmax(o), o, a)
@inline normalize_frame(::HasMinMax, o, a::AbstractArray) = normalize_frame(a, o.min, o.max)
@inline normalize_frame(::NoMinMax, o, a::AbstractArray) = a
@inline normalize_frame(a::AbstractArray, minval::Number, maxval::Number) = 
    min.((a .- minval) ./ (maxval - minval), one(eltype(a)))

"""
    savegif(filename::String, output::AbstractOutput)
Write the output array to a gif.
Saving very large gifs may trigger a bug in imagemagick.
"""
savegif(filename::String, o::AbstractOutput; kwargs...) =
    FileIO.save(filename, cat(process_frame.(Ref(o), o, collect(1:lastindex(o)))..., dims=3); kwargs...)
