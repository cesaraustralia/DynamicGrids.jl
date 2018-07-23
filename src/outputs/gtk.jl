"Shows output live in a Gtk window."
@Ok @Frames struct GtkOutput{W,C} <: AbstractOutput{T}
    window::W
    canvas::C
    scaling::Int
end


is_ok(output::GtkOutput) = output.ok[1] && output.canvas.is_realized
initialize(output::GtkOutput) = set_ok(output, true)

"""
    GtkOutput(init; scaling = 2)
Constructor for GtkOutput.
- `init::AbstractArray`: the same `init` array that will also be passed to sim!()
"""
GtkOutput(frames::AbstractVector; scaling=2) = begin
    canvas = @GtkCanvas()
    @guarded draw(canvas) do widget
        ctx = Gtk.getgc(canvas)
        Cairo.scale(ctx, scaling, scaling)
    end
    window = GtkWindow(canvas, "Cellular Automata")
    show(canvas)
    ok = [true]
    canvas.mouse.button1press = (widget,event) -> ok[1] = false

    GtkOutput(frames[:], ok, window, canvas, scaling)
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
        ctx = Gtk.getgc(canvas)
        set_source_surface(ctx, CairoRGBSurface(img), 0, 0)
        paint(ctx)
    end

    sleep(pause)
    is_ok(output)
end

