using Cairo, Gtk, Images, Graphics

"""
Shows output live in a Gtk window.
"""
@MinMax @ImageProc @Ok @FPS @Frames mutable struct GtkOutput{W,C} <: AbstractOutput{T}
    window::W
    canvas::C
end

is_running(o::GtkOutput) = o.running[1] && o.canvas.is_realized

"""
    GtkOutput(init)
Constructor for GtkOutput.

### Arguments:
- `frames::AbstractVector`: Vector of frames
- `args`: any additional arguments to be passed to the model rule

### Keyword Arguments:
- `fps`: frames per second
- `showmax_fps`: maximum displayed frames per second
"""
GtkOutput(frames::AbstractVector; fps=25, showmax_fps=fps, store=false, processor=Greyscale(), min=0, max=1) = begin
    timestamp = 0.0; tref = 0; tlast = 1; running = [false]

    canvas = Gtk.@GtkCanvas()
    window = Gtk.Window(canvas, "Cellular Automata")
    show(canvas)
    canvas.mouse.button1press = (widget, event) -> running[1] = false

    output = GtkOutput(frames[:], fps, showmax_fps, timestamp, tref, tlast, store, running, processor, min, max, window, canvas)
    show_frame(output, 1)
    output
end


show_frame(o::GtkOutput, frame::AbstractMatrix, t) = begin
    img = permutedims(process_image(o, frame, t))
    println(t)
    Gtk.@guarded Gtk.draw(o.canvas) do widget
        ctx = Gtk.getgc(o.canvas)
        Cairo.image(ctx, Cairo.CairoImageSurface(img), 0, 0, 
                    Graphics.width(ctx), Graphics.height(ctx))
    end
end
