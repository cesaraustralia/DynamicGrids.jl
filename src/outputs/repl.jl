using REPL

function __init__()
    global terminal
    terminal = REPL.Terminals.TTYTerminal(get(ENV, "TERM", Base.Sys.iswindows() ? "" : "dumb"), stdin, stdout, stderr)
end

abstract type AbstractCharStyle end
struct Block <: AbstractCharStyle end
struct Braile <: AbstractCharStyle end

"""
An output that is displayed directly in the REPL. It can either store or discard
simulation frames.

### Arguments:
- `frames`: Single init array or vector of arrays

### Keyword Arguments:
- `fps::Real`: frames per second to run at
- `showfps::Real`: maximum displayed frames per second
- `store::Bool`: store frames or not
- `color`: a color from Crayons.jl
- `cutoff::Real`: the cutoff point to display a full or empty cell. Default is `0.5`

To choose the display type can pass `:braile` or `:block` to the constructor:
```julia
REPLOutput{:block}(init)
```
The default option is `:block`.
"""
@Graphic @Output mutable struct REPLOutput{Co,Cu,CS} <: AbstractGraphicOutput{T}
    displayoffset::Array{Int}
    color::Co
    cutoff::Cu
    style::CS
end

REPLOutput(frames::AbstractVector; fps=25, showfps=fps, store=false, 
           color=:white, cutoff=0.5, style=:block) where X = begin
    timestamp = 0.0 
    tref = 0 
    tlast = 1 
    running = false
    displayoffset = [1, 1]
    REPLOutput(frames, running, fps, showfps, timestamp, tref, tlast, store, displayoffset, color, cutoff, style)
end


initialize!(o::REPLOutput, args...) = begin
    o.displayoffset .= (1, 1)
    # @async movedisplay(o)
    o.timestamp = time()
end

isasync(o::REPLOutput) = false

showframe(frame::AbstractArray, o::REPLOutput, t) = begin 
    # Print the frame
    put((0,0), o.color, replframe(o, frame)) 
    # Print the timestamp in the top right corner
    put((0,0), o.color, string(t)) 
end


savepos(buf::IO=terminal.out_stream) = print(buf, "\x1b[s")
restorepos(buf::IO=terminal.out_stream) = print(buf, "\x1b[u")
movepos(buf::IO, c=(0,0)) = print(buf, "\x1b[$(c[2]);$(c[1])H")
cursor_hide(buf::IO=terminal.out_stream) = print(buf, "\x1b[?25l")
cursor_show(buf::IO=terminal.out_stream) = print(buf, "\x1b[?25h")

function put(pos, color::Crayon, str::String)
    buf = terminal.out_stream
    savepos(buf)
    cursor_hide(buf)
    movepos(buf, pos)
    print(buf, color)
    print(buf, str)
    cursor_show(buf)
    restorepos(buf)
end
put(pos, c::Symbol, s::String) = put(pos, Crayon(foreground=c), s)


const YBRAILE = 4
const XBRAILE = 2
const YBLOCK = 2
const XBLOCK = 1

chartype(o::REPLOutput) = chartype(o.style)
chartype(s::Braile) = YBRAILE, XBRAILE, brailize
chartype(s::Block) = YBLOCK, XBLOCK, blockize

replframe(o, frame) = begin
    ystep, xstep, f = chartype(o)
    
    # Limit output area to available terminal size.
    dispy, dispx = displaysize(stdout)
    youtput, xoutput = outputsize = size(frame)
    yoffset, xoffset = o.displayoffset

    yrange = max(1, ystep * yoffset):min(youtput, ystep * (dispy + yoffset - 1))
    xrange = max(1, xstep * xoffset):min(xoutput, xstep * (dispx + xoffset - 1))
    f(view(Array(frame), yrange, xrange), o.cutoff)
end

# const XSCROLL = 4
# const YSCROLL = 8
# const PAGESCROLL = 40

# movedisplay(o) =
#     while is_running(o)
#         c = REPLGamesBase.readKey()
#         c == "Up"      && move_y!(o, -YSCROLL)
#         c == "Down"    && move_y!(o, YSCROLL)
#         c == "Left"    && move_x!(o, -XSCROLL)
#         c == "Right"   && move_x!(o, XSCROLL)
#         c == "PgUp"    && move_y!(o, -PAGESCROLL)
#         c == "PgDown"  && move_y!(o, PAGESCROLL)
#         c == "Ctrl-C"  && set_running!(o, false)
#     end

# move_y!(o::REPLOutput{:block}, n) = move_y!(n, XBLOCK)
# move_x!(o::REPLOutput{:block}, n) = move_x!(n, XBLOCK)
# move_y!(o::REPLOutput{:braile}, n) = move_y!(n, XBRAILE)
# move_x!(o::REPLOutput{:braile}, n) = move_x!(n, XBRAILE)
# move_y!(n, yscale) = begin
#     dispy, _ = displaysize(stdout)
#     y = size(o[1], 1)
#     o.displayoffset[1] = max(0, min(y ÷ yscale - dispy, o.displayoffset[1] + n))
# end
# move_x!(n, xscale) = begin
#     _, dispx = displaysize(stdout)
#     x = size(o[1], 2)
#     o.displayoffset[2] = max(0, min(x ÷ xscale - dispx, o.displayoffset[2] + n))
# end
