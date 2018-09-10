using Cairo, Gtk, Images, Graphics

"""
Shows output live in a Gtk window.
Only available after running `using Gtk`
"""
@Ok @FPS @Frames mutable struct GtkOutput{W,C} <: AbstractOutput{T}
    window::W
    canvas::C
end

is_running(o::GtkOutput) = o.running[1] && o.canvas.is_realized

"""
    GtkOutput(init; fps=25.0)
Constructor for GtkOutput.

### Arguments:
- `frames::AbstractVector`: Vector of frames
- `args`: any additional arguments to be passed to the model rule

### Keyword Arguments:
- `fps`: frames per second
- `showmax_fps`: maximum displayed frames per second
"""
GtkOutput(frames::AbstractVector; fps=25, showmax_fps=100, store=false) = begin
    canvas = Gtk.@GtkCanvas()
    window = Gtk.Window(canvas, "Cellular Automata")
    show(canvas)
    running = [false]
    canvas.mouse.button1press = (widget, event) -> running[1] = false

    GtkOutput(frames[:], fps, showmax_fps, 0.0, 0, store, running, window, canvas)
end


"""
    show_frame(o::GtkOutput, t)
Send frame at time t to the canvas in a Gtk window.
"""
function show_frame(o::GtkOutput, t)
    if use_frame(o, t)
        img = process_image(o, o[curframe(o, t)])
        Gtk.@guarded Gtk.draw(o.canvas) do widget
            ctx = Gtk.getgc(o.canvas)
            Cairo.reset_transform(ctx)
            Cairo.image(ctx, img, 0, 0, Graphics.width(ctx), Graphics.height(ctx))
        end
    end
end

process_image(o::GtkOutput, frame) =
    Cairo.CairoImageSurface(convert(Matrix{UInt32}, frame) .* 0x00ffffff, Cairo.FORMAT_RGB24)
