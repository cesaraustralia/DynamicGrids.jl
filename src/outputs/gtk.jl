"""
Shows output live in a Gtk window.

Only available after running `using Gtk`
"""
@Ok @FPS @Frames mutable struct GtkOutput{W,C} <: AbstractOutput{T}
    window::W
    canvas::C
end


is_ok(output::GtkOutput) = output.ok[1] && output.canvas.is_realized
initialize(output::GtkOutput) = set_ok(output, true)

"""
    GtkOutput(init; fps=25.0)
Constructor for GtkOutput.
- `init::AbstractArray`: the same `init` array that will also be passed to sim!()
"""
GtkOutput(frames::AbstractVector; fps=25.0) = begin
    canvas = @GtkCanvas()
    window = GtkWindow(canvas, "Cellular Automata")
    show(canvas)
    ok = [true]
    running = [false]
    canvas.mouse.button1press = (widget,event) -> ok[1] = false

    GtkOutput(frames[:], fps, time(), ok, running, window, canvas)
end

"""
    show_frame(output::GtkOutput, t)
Send current frame to the canvas in a Gtk window.
"""
function show_frame(output::GtkOutput, t)
    img = process_image(output, output[t])
    canvas = output.canvas
    @guarded draw(canvas) do widget
        copy!(canvas, img)
    end
    delay(output)
    is_ok(output)
end
