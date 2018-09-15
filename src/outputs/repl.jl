"""
A simple output that is displayed directly in the REPL.

### Arguments:
- `frames::AbstractVector`: Vector of frames

### Keyword Arguments:
- `fps`: frames per second
- `showmax_fps`: maximum displayed frames per second
- `store::Bool`: save frames or not
- `color`: a color name symbol from Crayons.jl

Pass `:braile` or `:block` to the constructor:
```julia
REPLOutput{:block}(init)
```
"""
@premix struct SubType{X} end
@Ok @FPS @Frames @SubType mutable struct REPLOutput{C} <: AbstractOutput{T}
    displayoffset::Array{Int}
    color::C
end
REPLOutput{X}(frames::AbstractVector; fps=25, showmax_fps=100, store=false, color=:white) where X =
    REPLOutput{X,typeof.((frames, fps, 0.0, 0, color))...}(
               frames, fps, showmax_fps, 0.0, 0, store, [false], [1,1], color)

initialize(o::REPLOutput, args...) = begin
    o.displayoffset .= (1, 1)
    @async movedisplay(o)
    o.timestamp = time()
end

is_async(o::REPLOutput) = true

"""
    show_frame(o::REPLOutput, t)
Extends show_frame from [`ArrayOuput`](@ref) by also printing to the REPL.
"""
show_frame(o::REPLOutput, t) = begin
    out = replshow(o, curframe(o, t)) 
    REPLGamesBase.put([0,0], o.color, out) 
    REPLGamesBase.put([0,0], o.color, string(t)) 
end

replshow(o::REPLOutput{:braile}, t) = replframe(o, t, 4, 2, brailize)
replshow(o::REPLOutput{:block}, t) = replframe(o, t, 2, 1, blockize)

function replframe(o, i, ystep, xstep, f)
    frame = o[i]
    # Limit output area to available terminal size.
    dispy, dispx = dispsize = displaysize(stdout)
    youtput, xoutput = outputsize = size(frame)
    yoffset, xoffset = o.displayoffset

    yrange = max(1, ystep * yoffset):min(youtput, ystep * (dispy + yoffset - 1))
    xrange = max(1, xstep * xoffset):min(xoutput, xstep * (dispx + xoffset - 1))
    let frame=frame, yrange=yrange, xrange=xrange
        f(Array(frame), 0.5, yrange, xrange)
    end
end


movedisplay(o) =
    while is_running(o)
        c = REPLGamesBase.readKey()
        c == "Up"      && move_y!(o, -1)
        c == "Down"    && move_y!(o, 1)
        c == "Left"    && move_x!(o, -1)
        c == "Right"   && move_x!(o, 1)
        c == "PgUp"    && move_y!(o, -10)
        c == "PgDown"  && move_y!(o, 10)
        c in ["Ctrl-C"]  && set_running(o, false)
    end

move_y!(o::REPLOutput{:block}, n) = begin
    dispy, dispx = displaysize(stdout)
    y, x = size(o[1])
    o.displayoffset[1] = max(0, min(y ÷ 2 - dispy, o.displayoffset[1] + 4n))
end
move_x!(o::REPLOutput{:block}, n) = begin
    dispy, dispx = displaysize(stdout)
    y, x = size(o[1])
    o.displayoffset[2] = max(0, min(x - dispx, o.displayoffset[2] + 8n))
end
move_y!(o::REPLOutput{:braile}, n) = begin
    dispy, dispx = displaysize(stdout)
    y, x = size(o[1])
    o.displayoffset[1] = max(0, min(y ÷ 4 - dispy, o.displayoffset[1] + 4n))
end
move_x!(o::REPLOutput{:braile}, n) = begin
    dispy, dispx = displaysize(stdout)
    y, x = size(o[1])
    o.displayoffset[2] = max(0, min(x ÷ 2 - dispx, o.displayoffset[2] + 8n))
end


