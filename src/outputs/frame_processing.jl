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


"""
Convert frame matrix to RGB24, using any AbstractFrameProcessor
"""
function frametoimage end

@inline frametoimage(o::AbstractImageOutput, args...) = frametoimage(processor(o), o, args...)
@inline frametoimage(o::AbstractImageOutput, args...) = frametoimage(processor(o), o, args...)
@inline frametoimage(o::AbstractImageOutput, ruleset::AbstractRuleset, frame, t) = 
    frametoimage(processor(o), o, ruleset, normaliseframe(ruleset, frame), t)
@inline frametoimage(processor, o::AbstractImageOutput, ruleset::AbstractRuleset, frame, t) = 
    frametoimage(processor, o, frame, t) 

struct Greyscale end
const Grayscale = Greyscale


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

ColorProcessor(; scheme=GreyScale(), zerocolor=nothing, maskcolor=nothing) = 
    ColorProcessor(scheme, zerocolor, maskcolor)


frametoimage(p::ColorProcessor, o::AbstractImageOutput, ruleset::AbstractRuleset, frame, t) = begin
    img = similar(frame, RGB24)
    for i in CartesianIndices(frame)
        x = frame[i]
        img[i] = if !(p.maskcolor isa Nothing) && ismasked(mask(ruleset), i) 
            p.maskcolor
        elseif !(p.zerocolor isa Nothing) && x == zero(x) 
            p.zerocolor
        elseif p.scheme isa Greyscale
            RGB24(x)
        elseif p.scheme isa ColorSchemes.ColorScheme
            RGB24(get(p.scheme, x))
        end
    end
    img
end

"""
    savegif(filename::String, output::AbstractOutput)
Write the output array to a gif.
Saving very large gifs may trigger a bug in imagemagick.
"""
savegif(filename::String, o::AbstractOutput; kwargs...) = savegif(filename, o::AbstractOutput, 0, 1; kwargs...)
savegif(filename::String, o::AbstractOutput, ruleset::AbstractRuleset; kwargs...) = begin
    images = frametoimage.(Ref(o), Ref(ruleset), frames(o), collect(firstindex(o):lastindex(o)))
    array = cat(images..., dims=3)
    FileIO.save(filename, array; kwargs...)
end

