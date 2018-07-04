"""
Simulation outputs are decoupled from simulation behaviour and can be used interchangeably.
These outputs inherit from AbstractOutput.

Types that extend AbstractOutput define their own method for [`show_frame`](@ref).
"""
abstract type AbstractOutput end

"""
    store_frame(output::AbstractOutput, frame, t, pause)
Copies the current frame to the frames array.
"""
store_frame(output::AbstractOutput, frame) = push!(output.frames, deepcopy(frame))

"""
    show_frame(output::AbstractOutput, t; pause=0.1)
"""
show_frame(output::AbstractOutput, t; pause=0.1) = true

"""
    replay(output::AbstractOutput; pause=0.1) = begin
Show a simulation again.
"""
replay(output::AbstractOutput; pause=0.1) =
    for (t, frame) in enumerate(output.frames)
        show_frame(output, t; pause=pause)
    end

"""
    (T::Type{AbstractOutput})(output::F; kwargs...)
Constructor to swap output type for replays in a different mode
"""
(::Type{T})(output::AbstractOutput; kwargs...) where T <: AbstractOutput = begin
    # length(output.frames) == 0 && return T(eltype(output.frames)([]); kwargs...)
    new_output = T(output.frames[1]; kwargs...)
    append!(new_output.frames, output.frames)
    new_output
end

is_ok(output) = output.ok[1]
set_ok(output, val) = output.ok[1] = val

"""
A simple array output that stores each step of the simulation in an array of arrays.
"""
struct ArrayOutput{F} <: AbstractOutput
    "An array that holds each frame of the simulation"
    frames::Array{F,1}
end
"""
    ArrayOutput(init)
Constructor for ArrayOutput
### Arguments
- init : the initialisation array
"""
ArrayOutput(init::F) where F <: AbstractArray = ArrayOutput{F}([])

"""
A wrapper for [`ArrayOutput`](@ref) that is displayed as asccii blocks in the REPL.
"""
struct REPLOutput{F} <: AbstractOutput
    frames::Array{F,1}
end

"""
    REPLOutput(init)
Constructor for REPLOutput
### Arguments
- init: The initialisation array
"""
REPLOutput(init::F) where F <: AbstractArray = REPLOutput{F}([])

"""
    show_frame(output::REPLOutput, t; pause=0.1)
Extends show_frame from [`ArrayOuput`](@ref) by also printing to the REPL.
"""
show_frame(output::REPLOutput, t; pause=0.1) = begin
    # Print the frame to the REPL as blocks
    Terminal.put([0,0], repl_frame(output.frames[t]))
    sleep(pause)
    true
end

"""
    Base.show(io::IO, output::REPLOutput)
Print the last frame of a simulation in the REPL.
"""
Base.show(io::IO, output::REPLOutput) = begin
    println(io, typeof(output))
    length(output.frames) == 0 || print(repl_frame(output.frames[end]))
end

function repl_frame(frame)
    # Limit output area to available terminal size.
    displayheight, displaywidth = displaysize(Base.STDOUT)
    height, width = min.(size(frame), (displayheight*2, displaywidth-8))

    out = String("")
    for i = 1:2:height
        out *= "\t"
        # Two line pers character
        for j = 1:width
            top = frame[i,j] > 0.5
            bottom = frame[i+1,j] > 0.5
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
struct GtkOutput{F,W,C,D} <: AbstractOutput
    frames::Array{F,1}
    window::W
    canvas::C
    scaling::Int
    ok::D
end

"""
    GtkOutput(init; scaling = 2)
Constructor for GtkOutput.
- `init::AbstractArray`: the same `init` array that will also be passed to sim!()
"""
GtkOutput(init::F; scaling = 2) where F <: AbstractArray = begin
    canvas = @GtkCanvas()
    @guarded draw(canvas) do widget
        ctx = getgc(canvas)
        scale(ctx, scaling, scaling)
    end
    window = GtkWindow(canvas, "Cellular Automata")
    show(canvas)

    ok = [true]
    signal_connect(window, "mouse-down-event") do widget, event
        ok[1] = false
    end
    # canvas.mouse.button1press = (canvas, x, y) -> (ok[1] = false)
    GtkOutput(F[], window, canvas, scaling, ok)
end

"""
    show_frame(output::GtkOutput, t; pause=0.1)
Send current frame to the canvas in a Gtk window.
"""
function show_frame(output::GtkOutput, t; pause=0.1)
    img = process_image(output, output.frame[t])
    canvas = output.canvas
    @guarded draw(output.canvas) do widget
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

@require FileIO begin

    using FixedPointNumbers
    using Colors
    import FileIO.save

    save(filename::AbstractString, output::ArrayOutput; kwargs...) = begin
        f = output.frames
        a = reshape(reduce(hcat, f), size(f[1])..., length(f))
        save("test.gif", vcat(output.frames))
    end

end

@require Plots begin
    using Plots

    """
    A Plots.jl Output to plot cells as a heatmap in any Plots backend. Some backends
    (such as plotly) may be very slow to refresh. Others like gr() should be fine.
    `using Plots` must be called for this to be available.
    """
    struct PlotsOutput{F,P,T} <: AbstractOutput
        frames::Array{F,1}
        plot::P
        interval::T
    end

    """
        PlotsOutput(init)
    Constructor for GtkOutput.
    - `init::AbstractArray`: the `init` array that will also be passed to sim!()
    """
    PlotsOutput(init::F; interval = 1) where F <: AbstractArray = begin
        p = heatmap(init, aspect_ratio=:equal)
        display(p)
        PlotsOutput(F[], p, interval)
    end

    """
        show_frame(output::PlotsOutput, t; pause=0.1)
    Update plot for every specified interval
    """
    function show_frame(output::PlotsOutput, t; pause=0.1)
        rem(t, output.interval) == 0 || return true
        heatmap!(output.plot, output.frames[t])
        display(output.plot)
        true
    end
end
