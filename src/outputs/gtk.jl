using Cairo, Gtk, Images, Graphics

"""
Shows output live in a Gtk window.
Only available after running `using Gtk`
"""
@Ok @FPS @Frames mutable struct GtkOutput{W,C} <: AbstractOutput{T}
    window::W
    canvas::C
end

is_running(output::GtkOutput) = output.running[1] && output.canvas.is_realized

"""
    GtkOutput(init; fps=25.0)
Constructor for GtkOutput.
- `frames::AbstractArray`: Vector of frames
"""
GtkOutput(frames::AbstractVector; fps=25.0) = begin
    canvas = Gtk.@GtkCanvas()
    window = Gtk.Window(canvas, "Cellular Automata")
    show(canvas)
    running = [false]
    canvas.mouse.button1press = (widget, event) -> running[1] = false

    GtkOutput(frames[:], fps, 0.0, running, window, canvas)
end

"""
    show_frame(output::GtkOutput, t)
Send current frame to the canvas in a Gtk window.
"""
function show_frame(output::GtkOutput, t)
    img = process_image(output, output[t])
    Gtk.@guarded Gtk.draw(output.canvas) do widget
        ctx = Gtk.getgc(output.canvas)
        Cairo.reset_transform(ctx)
        Cairo.image(ctx, img, 0, 0, Graphics.width(ctx), Graphics.height(ctx))
    end
end

process_image(output::GtkOutput, frame) =
    Cairo.CairoImageSurface(convert(Matrix{UInt32}, frame), Cairo.FORMAT_RGB24)
