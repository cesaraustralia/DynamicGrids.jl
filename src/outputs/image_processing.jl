"""
Frame processors convert frame data into RGB24 images
They can be passed as `procesor` keyword argument to outputs that have an image display.

To add new processor, define a type that inherits from AbstractFrameProcessor
and a [`process_image`](@ref) method:
```julia
process_image(p::YourType, output, frame, t) = some_rbg_image
```
"""
abstract type AbstractFrameProcessor end

"Converts frame to a greyscale image"
struct Greyscale <: AbstractFrameProcessor end
const Grayscale = Greyscale


""""
Converts frame to a greyscale image with the chosen color for zeros. 
Usefull for separating low values from actual zeros
"""
struct ColorZeros{C} <: AbstractFrameProcessor
    color::C
end


""" 
Convert frame matrix to RGB24, using any AbstractFrameProcessor
$METHODLIST
""" 
function process_image end
process_image(o, frame, t) = process_image(has_processor(o), o, frame, t)
process_image(::HasProcessor, o, frame, t) = process_image(o.processor, o, frame, t)
process_image(::NoProcessor, o, frame, t) = process_image(Greyscale(), o, frame, t)

process_image(p::Greyscale, o, frame, t) = RGB24.(normalize_frame(o, frame)) 

process_image(p::ColorZeros, o, frame, t) = 
    map(x -> x == zero(x) ? RGB24(p.color) : RGB24(x), normalize_frame(o, frame))


normalize_frame(o, a::AbstractArray) = normalize_frame(has_minmax(o), o, a)
normalize_frame(::HasMinMax, o, a::AbstractArray) = normalize_frame(a, o.min, o.max)
normalize_frame(::NoMinMax, o, a::AbstractArray) = a
normalize_frame(a::AbstractArray, minval::Number, maxval::Number) = 
    min.((a .- minval) ./ (maxval - minval), one(eltype(a)))

"""
    savegif(filename::String, output::AbstractOutput)
Write the output array to a gif.
Saving very large gifs may trigger a bug in imagemagick.
"""
savegif(filename::String, o::AbstractOutput; kwargs...) =
    FileIO.save(filename, cat(process_image.(Ref(o), o, collect(1:lastindex(o)))..., dims=3); kwargs...)
