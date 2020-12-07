
"""
    isrunning(o::Output)

Check if the output is running. Prevents multiple versions of `sim!` 
running on the same output for asynchronous outputs.
"""
function isrunning end

"""
    isasync(o::Output)

Check if the output should run asynchonously.

Default is `false`.
"""
function isasync end

"""
    isastored(o::Output)

Check if the output is storing each frame, or just the the current one.

Default is `true`.
"""
function isstored end

"""
    isshowable(o::Output, f::Int)

Check if the output can be shown visually, where f is the frame number.

Default is `false`.
"""
function isshowable end

"""
    initialise!(o::Output)

Initialise the output.
"""
function initialise! end

"""
    finalise!(o::Output, data::AbstractSimData)

Finalise the output.
"""
function finalise! end

"""
    initalisegraphics(o::Output, data::AbstractSimData)

Initialise the output graphics, if it has graphics.
"""
function finalisegraphics end

"""
    finalisegraphics(o::Output, data::AbstractSimData)

Finalise the output graphics, if it has graphics.
"""
function finalisegraphics end

"""
    delay(o::Output, f::Int)

`Graphic` outputs delay the simulations to match some `fps` rate.
Other outputs just do nothing and continue.
"""
function delay end

"""
    showframe(frame::NamedTuple, o::Output, data::AbstractSimData)
    showframe(frame::AbstractArray, o::Output, data::AbstractSimData)

Display the grid/s somehow in the output, if it can do that.
"""
function showframe end

"""
    frameindex(o::Output, data::AbstractSimData)

Get the index of the current frame in the output.

Every frame has an index of 1 if the simulation isn't stored.
"""
function frameindex end

"""
    storeframe!(o::Output, data::AbstractSimData)

Store the current simulaiton frame in the output.
"""
function storeframe! end


"""
    fps(o::Output)

Get the frames per second the output will run at. The default
is `nothing` - the simulation runs at full speed.
"""
function fps end


"""
    setfps!(o::Output, x)

Set the frames per second the output will run at. Only affects [`GraphicOutput`](@ref).
"""
function setfps! end
