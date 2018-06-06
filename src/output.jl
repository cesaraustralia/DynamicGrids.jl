abstract type AbstractOutput end 

"""
Converts an array to an image format.
"""
image_process(source, output) = convert(Array{UInt32, 2}, source) .* 0x00ffffff

"""
    update_output(output, source, t, pause)
Called from the simulation to pass the next frame to the output 
"""
function update_output end

@require Tk begin

    using Cairo

    struct TkOutput{W,C,CR,D} <: AbstractOutput
        w::W
        c::C
        cr::CR
        done::D
    end

    TkOutput(source; scaling = 2) = begin
        m, n = size(source)
        w = Tk.Toplevel("Cellular Automata", n, m)
        c = Tk.Canvas(w)
        done = [false]
        Tk.pack(c, expand = true, fill = "both")
        c.mouse.button1press = (c, x, y) -> (done[1] = true)
        cr = getgc(c)
        scale(cr, scaling, scaling)
        TkOutput(w, c, cr, done)
    end

    function update_output(output::TkOutput, source, t, pause)
        img = image_process(source, output)
        set_source_surface(output.cr, CairoRGBSurface(img), 0, 0)
        paint(output.cr)
        Tk.reveal(output.c)
        sleep(pause)
        output.done[1]
    end
end

@require FileIO begin

    import FileIO.save

    struct GifOutput{A} <: AbstractOutput
        frames::A
    end

    GifOutput(source) = begin
        img = image_process(source, GifOutput{Array{typeof(source)}}([]))
        GifOutput{Array{typeof(img)}}(Array([img]))
    end

    function update_output(output::GifOutput, source, t, pause)
        push!(output.frames, image_process(source, output))
    end

    save(filename::AbstractString, output::GifOutput) = begin
        save(filname, output.frames)
    end

end
