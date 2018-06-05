abstract type AbstractOutput end 

process(source, output) = convert(Array{UInt32, 2}, source) .* 0x00ffffff

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
        img = process(source, output)
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
        img = process(source, GifOutput{Array{typeof(source)}}([]))
        GifOutput{Array{typeof(img)}}(Array([img]))
    end

    function update_output(output::GifOutput, source, t, pause)
        push!(output.frames, process(source, output))
    end

    save(filename::AbstractString, output::GifOutput) = begin
        save(filname, output.frames)
    end

end


# function sim(source::Array{I,2}, rule) where I
#     c = canvas(UserUnit)
#     win = Window(c)

#     zr = Signal(ZoomRegion(source))
#     zoomsigs = init_zoom_scroll(c, zr)
#     imgsig = map(zr) do r
#         cv = r.currentview
#         view(source, UnitRange{Int}(cv.y), UnitRange{Int}(cv.x))
#     end
#     redraw = draw(c, imgsig) do cnvs, image
#         copy!(cnvs, image)
#         # canvas adopts the indices of the zoom region. That way if we
#         # zoom in further, we select the correct region.
#         set_coordinates(cnvs, value(zr))
#     end

#     done = false
#     last = time()
#     f = 1
#     dest = similar(source)
#     showall(win)

#     while !done
#         t = time()
#         if (t-last) > 2
#             println("$(f/(t-last)) FPS")
#             last = t; f = 0
#         end
#         automate!(dest, source, rule)
#         source .= dest
#         push!(zr, ZoomRegion(source))
#         f += 1
#         sleep(0.0001)
#     end
# end
