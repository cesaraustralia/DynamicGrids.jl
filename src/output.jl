"""
Simulation outputs are decoupled from simulation behaviour and can be used interchangeably.
These outputs inherit from AbstractOutput.

Types that extend AbstractOutput define their own method for [`show_frame`](@ref).
"""
abstract type AbstractOutput{T} <: AbstractVector{T} end

# """
    # (T::Type{AbstractOutput})(output::T; kwargs...)
# Constructor to swap output type for replays in a different output mode.
# """
# (::Type{T})(output::AbstractOutput, args...; kwargs...) where T <: AbstractOutput = begin
    # length(output) == 0 && return T(eltype(output)[], args...; kwargs...)
    # new_output = T(output.frames, args...; kwargs...)
    # new_output
# end

(::Type{T})(init::I, args...; kwargs...) where T <: AbstractOutput where I <: AbstractMatrix =
    T(I[], args...; kwargs...)

length(o::AbstractOutput) = length(o.frames)
size(o::AbstractOutput) = size(o.frames)
endof(o::AbstractOutput) = endof(o.frames)
getindex(o::AbstractOutput, i) = getindex(o.frames, i)
setindex!(o::AbstractOutput, x, i) = setindex!(o.frames, x, i)
push!(o::AbstractOutput, x) = push!(o.frames, x)
append!(o::AbstractOutput, x) = append!(o.frames, x)

""" 
    savegif(filename::String, output::AbstractOutput; fps=30)
Write the output array to a gif. 
Saving very large gifs may trigger a bug in imagemagick.
"""
savegif(filename::String, output::AbstractOutput; fps=30) = begin
    # Merge vector of matrices into a 3 dim array and save
    FileIO.save(filename, Gray.(cat(3, output...)); fps=fps)
end
clear(output::AbstractOutput) = deleteat!(output.frames, 1:length(output))
initialize(output::AbstractOutput) = nothing

"""
    store_frame(output::AbstractOutput, frame, t, pause)
Copies the current frame to the frames array.
"""
store_frame(output::AbstractOutput, frame) = push!(output, deepcopy(frame))

"""
    show_frame(output::AbstractOutput, t; pause=0.1)
"""
show_frame(output::AbstractOutput, t; pause=0.1) = true

"""
    replay(output::AbstractOutput; pause=0.1) = begin
Show the simulation again. You can also use this to show a sequence 
run with a different output type.
### Example
```julia
replay(REPLOutput(output); pause=0.1)
```
"""
replay(output::AbstractOutput; pause=0.1) = begin
    initialize(output)
    println("start")
    for (t, frame) in enumerate(output)
        show_frame(output, t; pause=pause)
    end
end

is_ok(output) = output.ok[1]
set_ok(output, val) = output.ok[1] = val

@premix struct Frames{T}
    "An array that holds each frame of the simulation"
    frames::Vector{T}
end

"""
A simple array output that stores each step of the simulation in an array of arrays.
"""
@Frames struct ArrayOutput{} <: AbstractOutput{T} end
ArrayOutput(frames::AbstractVector) = ArrayOutput(frames[:])

"""
A wrapper for [`ArrayOutput`](@ref) that is displayed as asccii blocks in the REPL.
"""
@Frames struct REPLOutput{} <: AbstractOutput{T} 
    displayoffset::Array{Int}
    ok::Array{Bool}
end
REPLOutput(frames::AbstractVector) = REPLOutput(frames[:], [1,1], [true])


initialize(output::REPLOutput) = begin
    set_ok(output, true)
    output.displayoffset .= (1, 1)
    # @async movedisplay(output)
end

movedisplay(output) = begin
    while is_ok(output)
        c = Terminal.readKey()
        c in ["Up"]      && move_y!(output, -1)
        c in ["Down"]    && move_y!(output, 1)
        c in ["Left"]    && move_x!(output, -1)
        c in ["Right"]   && move_x!(output, 1)
        c in ["PgUp"]    && move_y!(output, -10)
        c in ["PgDown"]  && move_y!(output, 10)
        c == '\x1b'      && set_ok(output, false)
        c in ["Ctrl-C"]  && set_ok(output, false)
    end
end

move_y!(output, n) = begin
    dispy, dispx = displaysize(Base.STDOUT)
    y, x = size(output[1])
    output.displayoffset[1] = max(0, min(y-2dispy, output.displayoffset[1] + 2n))
end
move_x!(output, n) = begin
    dispy, dispx = displaysize(Base.STDOUT)
    y, x = size(output[1])
    output.displayoffset[2] = max(0, min(x-(dispx-8), output.displayoffset[2] + 2n))
end

"""
    show_frame(output::REPLOutput, t; pause=0.1)
Extends show_frame from [`ArrayOuput`](@ref) by also printing to the REPL.
"""
show_frame(output::REPLOutput, t; pause=0.1) = begin
    try
        Terminal.put([0,0], repl_frame(output, t))
    catch err
        set_ok(output, false)
        throw(err)
    end
    sleep(pause)
    is_ok(output)
end

"""
    Base.show(io::IO, output::REPLOutput)
Print the last frame of a simulation in the REPL.
"""
Base.show(io::IO, output::REPLOutput) = begin
    println(io, typeof(output))
    length(output) == 0 || print(repl_frame(output[end]))
end

function repl_frame(output, t)
    frame = output[t]
    # Limit output area to available terminal size.
    dispy, dispx = dispsize = displaysize(Base.STDOUT)
    youtput, xoutput = outputsize = size(frame)
    yoffset, xoffset = output.displayoffset

    yrange = max(1, yoffset):2:min(youtput-1, 2dispy + yoffset - 1)
    xrange = max(1, xoffset):1:min(xoutput, dispx - 8 + xoffset - 1)

    out = String("")
    for y = yrange 
        out *= "\t"
        for x = xrange
            top = frame[y, x] > 0.5
            bottom = frame[y + 1, x] > 0.5
            if top
                out *= bottom ? "█" : "▀"
            else
                out *= bottom ? "▄" : " "
            end
        end
        out *= "\n"
    end
    out *= "\n\n"
end

"""
Plot output live to a Gtk window.
"""
@Frames struct GtkOutput{W,C,D} <: AbstractOutput{T}
    window::W
    canvas::C
    scaling::Int
    ok::D
end


is_ok(output::GtkOutput) = output.ok[1] && output.canvas.is_realized
initialize(output::GtkOutput) = set_ok(output, true)

"""
    GtkOutput(init; scaling = 2)
Constructor for GtkOutput.
- `init::AbstractArray`: the same `init` array that will also be passed to sim!()
"""
GtkOutput(frames::T; scaling=2) where T <: AbstractVector = begin
    canvas = @GtkCanvas()
    @guarded draw(canvas) do widget
        ctx = Gtk.getgc(canvas)
        Cairo.scale(ctx, scaling, scaling)
    end
    window = GtkWindow(canvas, "Cellular Automata")
    show(canvas)

    ok = [true]

    canvas.mouse.button1press = (widget,event) -> ok[1] = false
    canvas.mouse.button1press = (widget,event) -> ok[1] = false

    GtkOutput(frames[:], window, canvas, scaling, ok)
end

"""
    show_frame(output::GtkOutput, t; pause=0.1)
Send current frame to the canvas in a Gtk window.
"""
function show_frame(output::GtkOutput, t; pause=0.1)
    img = process_image(output, output[t])
    canvas = output.canvas
    @guarded draw(output.canvas) do widget
        # canvas.draw.scaling == scaling || Cairo.scale(ctx, scaling, scaling)
        ctx = getgc(canvas)
        set_source_surface(ctx, CairoRGBSurface(img), 0, 0)
        paint(ctx)
    end

    sleep(pause)
    is_ok(output)
end

"""
    process_image(output,  )
Converts an array to an image format.
"""
process_image(output, frame) = convert(Array{UInt32, 2}, frame) .* 0x00ffffff


@require Plots begin
    using Plots

    """
    A Plots.jl Output to plot cells as a heatmap in any Plots backend. Some backends
    (such as plotly) may be very slow to refresh. Others like gr() should be fine.
    `using Plots` must be called for this to be available.
    """
    @Frames struct PlotsOutput{T,P,I} <: AbstractOutput{T}
        plot::P
        interval::I
    end

    """
        PlotsOutput(frames)
    Constructor for GtkOutput.
    ### Arguments
    - `frames::AbstractArray`: vector of `frames` 

    ### Keyword arguments
    - `aspec_ratio` : passed to the plots heatmap, default is :equal
    - `kwargs` : extra keyword args to modify the heatmap
    """
    PlotsOutput(frames::T; interval=1, aspect_ratio=:equal, kwargs...) where T <: AbstractVector = begin
        p = heatmap(; aspect_ratio=aspect_ratio, kwargs...)
        PlotsOutput(frames[:], p, interval)
    end

    initialize(output::PlotsOutput) = begin
        set_ok(true)
        display(output.plot)
    end

    """
        show_frame(output::PlotsOutput, t; pause=0.1)
    Update plot for every specified interval
    """
    function show_frame(output::PlotsOutput, t; pause=0.1)
        rem(t, output.interval) == 0 || return true
        heatmap!(output.plot, output[t])
        display(output.plot)
        true
    end
end
