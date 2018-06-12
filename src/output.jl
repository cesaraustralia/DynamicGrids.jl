abstract type AbstractOutput end 

"""
Converts an array to an image format.
"""
image_process(frame, output) = convert(Array{UInt32, 2}, frame) .* 0x00ffffff

"""
    update_output(output, frame, t, pause)
Called from the simulation to pass the next frame to the output 
"""
function update_output end

"""
Simple array output: creates an array of frames.
"""
struct ArrayOutput{A} <: AbstractOutput
    frames::Array{A,1}
end
ArrayOutput(source) = ArrayOutput{typeof(source)}([])

" Copies the current frame array unchanged to the stored array "
update_output(output::ArrayOutput, frame, t, pause) = begin
    push!(output.frames, deepcopy(frame))
    true
end


@require Tk begin
    using Cairo

    struct TkOutput{W,C,CR,D} <: AbstractOutput
        w::W
        c::C
        cr::CR
        ok::D
    end

    TkOutput(frame; scaling = 2) = begin
        m, n = size(frame)
        w = Tk.Toplevel("Cellular Automata", n, m)
        c = Tk.Canvas(w)
        ok = [true]
        Tk.pack(c, expand = true, fill = "both")
        c.mouse.button1press = (c, x, y) -> (ok[1] = false)
        cr = getgc(c)
        scale(cr, scaling, scaling)
        TkOutput(w, c, cr, ok)
    end

    function update_output(output::TkOutput, frame, t, pause)
        img = image_process(frame, output)
        set_source_surface(output.cr, CairoRGBSurface(img), 0, 0)
        paint(output.cr)
        Tk.reveal(output.c)
        sleep(pause)
        output.ok[1]
    end
end

@require FileIO begin

    import FileIO.save

    struct GifOutput{A} <: AbstractOutput
        frames::A
    end

    GifOutput(frame) = begin
        img = image_process(frame, GifOutput{Array{typeof(frame)}}([]))
        GifOutput{Array{typeof(img)}}(Array([img]))
    end

    function update_output(output::GifOutput, frame, t, pause)
        push!(output.frames, image_process(frame, output))
        true
    end

    save(filename::AbstractString, output::GifOutput) = begin
        save(filname, output.frames)
    end

end
