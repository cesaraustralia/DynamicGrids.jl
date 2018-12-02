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
REPLOutput{X}(frames::AbstractVector; fps=25, showmax_fps=fps, store=false, color=:white) where X =
    REPLOutput{X,typeof.((frames, fps, 0.0, 0, color))...}(
               frames, fps, showmax_fps, 0.0, 0, store, [false], [1,1], color)

initialize!(o::REPLOutput, args...) = begin
    o.displayoffset .= (1, 1)
    @async movedisplay(o)
    o.timestamp = time()
end

is_async(o::REPLOutput) = true

show_frame(o::REPLOutput, frame, t) = begin 
    REPLGamesBase.put([0,0], o.color, replframe(o, normalize_frame(frame))) 
    REPLGamesBase.put([0,0], o.color, string(t)) 
end


const YBRAILE = 4
const XBRAILE = 2
const YBLOCK = 2
const XBLOCK = 1
const XSCROLL = 4
const YSCROLL = 8
const PAGESCROLL = 40

replframe(o::REPLOutput{:braile}, frame) = replframe(o, frame, YBRAILE, XBRAILE, brailize)
replframe(o::REPLOutput{:block}, frame) = replframe(o, frame, YBLOCK, XBLOCK, blockize)
replframe(o, frame, ystep, xstep, f) = begin
    # Limit output area to available terminal size.
    dispy, dispx = displaysize(stdout)
    youtput, xoutput = outputsize = size(frame)
    yoffset, xoffset = o.displayoffset

    yrange = max(1, ystep * yoffset):min(youtput, ystep * (dispy + yoffset - 1))
    xrange = max(1, xstep * xoffset):min(xoutput, xstep * (dispx + xoffset - 1))
    let frame=frame, yrange=yrange, xrange=xrange
        f(view(Array(frame), yrange, xrange), 0.5)
    end
end

movedisplay(o) =
    while is_running(o)
        c = REPLGamesBase.readKey()
        c == "Up"      && move_y!(o, -YSCROLL)
        c == "Down"    && move_y!(o, YSCROLL)
        c == "Left"    && move_x!(o, -XSCROLL)
        c == "Right"   && move_x!(o, XSCROLL)
        c == "PgUp"    && move_y!(o, -PAGESCROLL)
        c == "PgDown"  && move_y!(o, PAGESCROLL)
        c in ["Ctrl-C"]  && set_running(o, false)
    end

move_y!(o::REPLOutput{:block}, n) = move_y!(n, XBLOCK)
move_x!(o::REPLOutput{:block}, n) = move_x!(n, XBLOCK)
move_y!(o::REPLOutput{:braile}, n) = move_y!(n, XBRAILE)
move_x!(o::REPLOutput{:braile}, n) = move_x!(n, XBRAILE)
move_y!(n, yscale) = begin
    dispy, _ = displaysize(stdout)
    y = size(o[1], 1)
    o.displayoffset[1] = max(0, min(y ÷ yscale - dispy, o.displayoffset[1] + n))
end
move_x!(n, xscale) = begin
    _, dispx = displaysize(stdout)
    x = size(o[1], 2)
    o.displayoffset[2] = max(0, min(x ÷ xscale - dispx, o.displayoffset[2] + n))
end


