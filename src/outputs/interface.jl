
"""
    extent(o::Output) => Extent

[`Output`](@ref) interface method. Return and [`Extent`](@ref) object.
"""
function extent end

"""
    isrunning(o::Output) => Bool

[`Output`](@ref) interface method.

Check if the output is running. Prevents multiple versions of `sim!` 
running on the same output for asynchronous outputs.
"""
function isrunning end

"""
    isasync(o::Output) => Bool

[`Output`](@ref) interface method.

Check if the output should run asynchonously. Default is `false`.
"""
function isasync end

"""
    isastored(o::Output) => Bool

[`Output`](@ref) interface method.

Check if the output is storing each frame, or just the the current one. Default is `true`.
"""
function isstored end

"""
    isshowable(o::Output, f::Int) => Bool

[`Output`](@ref) interface method.

Check if the output can be shown visually, where f is the frame number. Default is `false`.
"""
function isshowable end

"""
    initialise!(o::Output)

[`Output`](@ref) interface method.

Initialise the output at the start of the simulation.
"""
function initialise! end

"""
    finalise!(o::Output, data::AbstractSimData)

[`Output`](@ref) interface method.

Finalise the output at the end of the simulation.
"""
function finalise! end

"""
    frameindex(o::Output, data::AbstractSimData)

[`Output`](@ref) interface method.

Get the index of the current frame in the output.
Every frame has an index of 1 if the simulation isn't stored.
"""
function frameindex end

"""
    delay(o::Output, f::Int) => nothing

[`GraphicOutput`](@ref) interface method.

Delay the simulations to match some `fps` rate. The default for outputs not 
`<: GraphicOutput` is to do nothing and continue.
"""
function delay end

"""
    showframe(o::Output, data::AbstractSimData)
    showframe(frame::NamedTuple, o::Output, data::AbstractSimData)
    showframe(frame::AbstractArray, o::Output, data::AbstractSimData)

[`GraphicOutput`](@ref) interface method.

Display the grid/s somehow in the output, if it can do that.
"""
function showframe end

"""
    storeframe!(o::Output, data::AbstractSimData)

Store the current simulaiton frame in the output.
"""
function storeframe! end

"""
    graphicconfig(output::GraphicOutput) => GraphicConfig

[`GraphicOutput`](@ref) interface method. Return an [`GraphicConfig`](@ref) object. 
"""
function graphicconfig end

"""
    fps(o::Output) => Real

[`GraphicOutput`](@ref) interface method.

Get the frames per second the output will run at. The default
is `nothing` - the simulation runs at full speed.
"""
function fps end

"""
    setfps!(o::Output, x)

[`GraphicOutput`](@ref) interface method.

Set the frames per second the output will run at.
"""
function setfps! end

"""
    initalisegraphics(o::Output, data::AbstractSimData)

[`GraphicOutput`](@ref) interface method.

Initialise the output graphics at the start of the simulation, if it has graphics.
"""
function initialisegraphics end

"""
    finalisegraphics(o::Output, data::AbstractSimData)

[`GraphicOutput`](@ref) interface method.

Finalise the output graphics at the end of the simulation, if it has graphics.
"""
function finalisegraphics end

"""
    imageconfig(output::ImageOutput) => ImageConfig

[`ImageOutput`](@ref) interface method. Return an [`ImageConfig`](@ref) object. 
"""
function imageconfig end

"""
    showimage(image::AbstractArray, o::ImageOutput)
    showimage(image::AbstractArray, o::ImageOutput, data::AbstractSimData)

ImageOutput interface method.

Display an image generated from the grid, a required method for all [`ImageOutput`](@ref).
"""
function showimage end

"""
    grid_to_image!(o::ImageOutput, data::SimData)
    grid_to_image!(imbuf, imgen::ImageGenerator, o::ImageOutput, data::SimData, grids)

Convert a grid or `NamedRuple` of grids to an `ARGB32` image, using an 
[`ImageGenerator`](@ref).

Generated pixels are written to the image buffer matrix.
"""
function grid_to_image! end

"""
    to_rgb(val) => ARGB32
    to_rgb(scheme, val) => ARGB32

[`ImageOutput`](@ref) interface method.

Display an image generated from the grid, a required method for all [`ImageOutput`](@ref).

Custom grid object will need to add methods for converting the object to a color,
```julia
to_rgb(::ObjectScheme, obj::CustomObj) = ...`
```

For use with other colorschemes, a method that calls `get` with a `Real` value
obtained from the object will be required:

```julia
to_rgb(scheme, obj::CustomObj) = ARGB32(get(scheme, real_from_obj(obj)))
```
"""
function to_rgb end
