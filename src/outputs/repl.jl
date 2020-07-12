using REPL

function __init__()
    global terminal
    terminal = REPL.Terminals.TTYTerminal(get(ENV, "TERM", Base.Sys.iswindows() ? "" : "dumb"), stdin, stdout, stderr)
end

abstract type CharStyle end
struct Block <: CharStyle end
struct Braile <: CharStyle end

"""
    REPLOutput(init; tspan, fps=25.0, store=false, color=:white, cutoff=0.5 style=Block())

An output that is displayed directly in the REPL. It can either store or discard
simulation frames.

### Arguments:
- `init`: initialisation Array or NamedTuple of arrays.

### Keyword Arguments:
- `tspan`: `AbstractRange` timespan for the simulation
- `fps::Real`: frames per second to display the simulation
- `store::Bool`: whether ot store the simulation frames for later use
- `color`: a color from Crayons.jl
- `cutoff::Real`: the cutoff point to display a full or empty cell. Default is `0.5`
- `style::CharStyle`: `Block()` or `Braile()` style printing. `Braile` uses 1/4 the screen space.

```julia
REPLOutput(init)
```
The default option is `:block`.
"""
mutable struct REPLOutput{T,F<:AbstractVector{T},E,GC,Co,St,Cu} <: GraphicOutput{T}
    frames::F
    running::Bool
    extent::E
    graphicconfig::GC
    color::Co  
    style::St 
    cutoff::Cu
end
REPLOutput(; frames, running, extent, graphicconfig,
           color=:white, cutoff=0.5, style=Block(), kwargs...) =
    REPLOutput(frames, running, extent, graphicconfig, color, style, cutoff) 

showframe(frame::NamedTuple, o::REPLOutput, data::SimData, f, t) = 
    showframe(first(frame), o, data, f, t)
showframe(frame::AbstractArray, o::REPLOutput, data::SimData, f, t) = begin
    # Print the frame
    put((0, 0), o.color, replframe(o, frame))
    # Print the timestamp in the top right corner
    put((0, 0), o.color, string("Time $t"))
end

# Terminal commands
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
    yoffset, xoffset = (0, 0)

    yrange = max(1, ystep * yoffset):min(youtput, ystep * (dispy + yoffset - 1))
    xrange = max(1, xstep * xoffset):min(xoutput, xstep * (dispx + xoffset - 1))
    f(view(Array(frame), yrange, xrange), o.cutoff)
end
