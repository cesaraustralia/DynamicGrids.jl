"A wrapper for [`ArrayOutput`](@ref) that is displayed as asccii blocks in the REPL."
@Ok @Frames struct REPLOutput{} <: AbstractOutput{T} 
    displayoffset::Array{Int}
end
REPLOutput(frames::AbstractVector) = REPLOutput(frames[:], [true], [1,1])


initialize(output::REPLOutput) = begin
    set_ok(output, true)
    output.displayoffset .= (1, 1)
    # @async movedisplay(output)
end

movedisplay(output) = begin
    while is_ok(output)
        c = Terminal.readKey()
        c in ["Up"]      && move_y!(output, -1)
        c in ["Down"]    && move_y!(output, 1)
        c in ["Left"]    && move_x!(output, -1)
        c in ["Right"]   && move_x!(output, 1)
        c in ["PgUp"]    && move_y!(output, -10)
        c in ["PgDown"]  && move_y!(output, 10)
        c == '\x1b'      && set_ok(output, false)
        c in ["Ctrl-C"]  && set_ok(output, false)
    end
end

move_y!(output, n) = begin
    dispy, dispx = displaysize(Base.STDOUT)
    y, x = size(output[1])
    output.displayoffset[1] = max(0, min(y-2dispy, output.displayoffset[1] + 2n))
end
move_x!(output, n) = begin
    dispy, dispx = displaysize(Base.STDOUT)
    y, x = size(output[1])
    output.displayoffset[2] = max(0, min(x-(dispx-8), output.displayoffset[2] + 2n))
end

"""
    show_frame(output::REPLOutput, t; pause=0.1)
Extends show_frame from [`ArrayOuput`](@ref) by also printing to the REPL.
"""
show_frame(output::REPLOutput, t; pause=0.1) = begin
    try
        Terminal.put([0,0], repl_frame(output, t))
    catch err
        set_ok(output, false)
        throw(err)
    end
    sleep(pause)
    is_ok(output)
end

"""
    Base.show(io::IO, output::REPLOutput)
Print the last frame of a simulation in the REPL.
"""
Base.show(io::IO, output::REPLOutput) = begin
    println(io, typeof(output))
    length(output) == 0 || print(repl_frame(output[end]))
end

function repl_frame(output, t)
    frame = output[t]
    # Limit output area to available terminal size.
    dispy, dispx = dispsize = displaysize(Base.STDOUT)
    youtput, xoutput = outputsize = size(frame)
    yoffset, xoffset = output.displayoffset

    yrange = max(1, yoffset):2:min(youtput-1, 2dispy + yoffset - 1)
    xrange = max(1, xoffset):1:min(xoutput, dispx - 8 + xoffset - 1)

    out = String("")
    for y = yrange 
        out *= "\t"
        for x = xrange
            top = frame[y, x] > 0.5
            bottom = frame[y + 1, x] > 0.5
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
