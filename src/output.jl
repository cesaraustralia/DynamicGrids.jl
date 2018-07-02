"""
Simulation outputs are decoupled from simulation behaviour and can be used interchangeably.
These outputs inherit from AbstractOutput.

Types that extend AbstractOutput define their own method for [`update_output`](@ref).
"""
abstract type AbstractOutput end

"""
    update_output(output, frame, t, pause)
Methods that update the output with the current frame, for timestep t.
"""
function update_output end

is_ok(output) = output.ok[1]
set_ok(output, val) = output.ok[1] = val

"""
Abstract type parent for array outputs.
"""
abstract type AbstractArrayOutput <: AbstractOutput end

"""
A simple array output that stores each step of the simulation in an array of arrays.
"""
struct ArrayOutput{A} <: AbstractArrayOutput
    "An array that holds each frame of the simulation"
    frames::Array{A,1}
end
"""
    ArrayOutput(init)
Constructor for ArrayOutput
### Arguments
- init : the initialisation array
"""
ArrayOutput(init) = ArrayOutput{typeof(init)}([])

"""
    update_output(output::AbstractArrayOutput, frame, t, pause)
Copies the current frame unchanged to the storage array
"""
update_output(output::AbstractArrayOutput, frame, t, pause) = begin
    frames = get_frames(output)
    push!(frames, deepcopy(frame))
    true
end

get_frames(output::AbstractArrayOutput) = output.frames


"""
A wrapper for [`ArrayOutput`](@ref) that is displayed as asccii blocks in the REPL.
"""
struct REPLOutput{A} <: AbstractArrayOutput
    array_output::A
end

"""
    REPLOutput(init)
Constructor for REPLOutput
### Arguments
- init: The initialisation array
"""
REPLOutput(init) = begin
    array_output = ArrayOutput(init)
    REPLOutput{typeof(array_output)}(array_output)
end

"""
    update_output(output::REPLOutput, frame, t, pause)
Extends update_output from [`ArrayOuput`](@ref) by also printing to the REPL.
"""
update_output(output::REPLOutput, frame, t, pause) = begin
    update_output(output.array_output, frame, t, pause)
    Terminal.clear_screen()
    Terminal.put([0,0], repl_frame(get_frames(output)[end]))
    sleep(pause)
    true
end

get_frames(output::REPLOutput) = get_frames(output.array_output)

"""
    Base.show(io::IO, output::REPLOutput)
Print the last frame of a simulation in the REPL.
"""
Base.show(io::IO, output::REPLOutput) = begin
    println(io, typeof(output))

    frames = get_frames(output)
    length(frames) == 0 && return

    print(repl_frame(frames[end]))
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

@require Gtk begin
    using Cairo
    """
    Plot output live to a Gtk window. `using Gtk` is required for this to be
    available, and both Gtk and Cario must be installed.
    """
    struct GtkOutput{W,C,D} <: AbstractOutput
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
    GtkOutput(init; scaling = 2) = begin
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
        GtkOutput(window, canvas, scaling, ok)
    end

    """
        update_output(output::GtkOutput, frame, t, pause)
    Send current frame to the canvas in a Gtk window.
    """
    function update_output(output::GtkOutput, frame, t, pause)
        img = process_image(frame, output)
        canvas = output.canvas
        @guarded draw(output.canvas) do widget
            ctx = getgc(canvas)
            set_source_surface(ctx, CairoRGBSurface(img), 0, 0)
            paint(ctx)
        end

        println("frame", t)
        sleep(pause)
        is_ok(output)
    end
end

"""
    process_image(frame, output)
Converts an array to an image format.
"""
process_image(frame, output) = convert(Array{UInt32, 2}, frame) .* 0x00ffffff

@require FileIO begin

    using FixedPointNumbers
    using Colors
    import FileIO.save

    save(filename::AbstractString, output::ArrayOutput; kwargs...) = begin
        f = frames(output)
        a = reshape(reduce(hcat, f), size(f[1])..., length(f))
        save("test.gif", vcat(frames(output)))
    end

end

@require Plots begin
    using Plots

    """
    A Plots.jl Output to plot cells as a heatmap in any Plots backend. Some backends
    (such as plotly) may be very slow to refresh. Others like gr() should be fine.
    `using Plots` must be called for this to be available.
    """
    struct PlotsOutput{P} <: AbstractOutput
        plot::P
    end

    """
        Plots(init)
    Constructor for GtkOutput.
    - `init::AbstractArray`: the `init` array that will also be passed to sim!()
    """
    PlotsOutput(init) = begin
        p = heatmap(init, aspect_ratio=:equal)
        display(p)
        PlotsOutput{typeof(p)}(p)
    end

    """
        update_output(output::PlotsOutput, frame, t, pause)
    """
    function update_output(output::PlotsOutput, frame, t, pause)
        heatmap!(output.plot, frame)
        display(output.plot)
        true
    end
end
