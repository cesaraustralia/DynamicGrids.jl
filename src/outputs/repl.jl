using REPL

abstract type CharStyle end
struct Block <: CharStyle end
struct Braile <: CharStyle end

"""
    REPLOutput(init; tspan, aux=nothing, mask=nothing, padval=zero(eltype(init)), 
        fps=25.0, store=false, color=:white, cutoff=0.5, style=Block())

An output that is displayed directly in the REPL. It can either store or discard
simulation frames.

### Arguments:
- `init`: initialisation Array or NamedTuple of arrays.

### Keyword Arguments:
- `tspan`: `AbstractRange` timespan for the simulation
- `mask`: `BitArray` for defining cells that will/will not be run.
- `aux`: `NamedTuple` of arbitrary input data. Use `get(data, Aux(:key), I...)` 
  to access from a `Rule` in a type-stable way.
- `padval`: padding value for grids with neighborhood rules. The default is `zero(eltype(init))`.
- `fps`: `Real` frames per second to display the simulation
- `store`: `Bool` whether ot store the simulation frames for later use
- `color`: a color from Crayons.jl
- `cutoff`: `Real` cutoff point to display a full or empty cell. Default is `0.5`
- `style`: `CharStyle` `Block()` or `Braile()` printing. `Braile` uses 1/4 the screen space of `Block`.

```julia
REPLOutput(init)
```
The default option is `:block`.
"""
mutable struct REPLOutput{T,F<:AbstractVector{T},E,GC,Co,St,Cu} <: GraphicOutput{T,F}
    frames::F
    running::Bool
    extent::E
    graphicconfig::GC
    color::Co
    style::St
    cutoff::Cu
end
function REPLOutput(;
    frames, running, extent, graphicconfig,
    color=:white, cutoff=0.5, style=Block(), kw...
)
    REPLOutput(frames, running, extent, graphicconfig, color, style, cutoff)
end

function showframe(frame::AbstractArray, o::REPLOutput, data::AbstractSimData)
    # Print the frame
    _print_to_repl((0, 0), o.color, _replframe(o, frame))
    # Print the timestamp in the top right corner
    _print_to_repl((0, 0), o.color, string("Time $(currenttime(data))"))
end

# Terminal commands
_savepos(io::IO=terminal.out_stream) = print(io, "\x1b[s")
_restorepos(io::IO=terminal.out_stream) = print(io, "\x1b[u")
_movepos(io::IO, c=(0,0)) = print(io, "\x1b[$(c[2]);$(c[1])H")
_cursor_hide(io::IO=terminal.out_stream) = print(io, "\x1b[?25l")
_cursor_show(io::IO=terminal.out_stream) = print(io, "\x1b[?25h")

_print_to_repl(pos, c::Symbol, s::String) = _print_to_repl(pos, Crayon(foreground=c), s)
function _print_to_repl(pos, color::Crayon, str::String)
    io = terminal.out_stream
    _savepos(io)
    _cursor_hide(io)
    _movepos(io, pos)
    print(io, color)
    print(io, str)
    _cursor_show(io)
    _restorepos(io)
end


const YBRAILE = 4
const XBRAILE = 2
const YBLOCK = 2
const XBLOCK = 1

function _replframe(o, frame)
    ystep, xstep, f = _chartype(o)

    # Limit output area to available terminal size.
    dispy, dispx = displaysize(stdout)
    youtput, xoutput = outputsize = size(frame)
    yoffset, xoffset = (0, 0)

    yrange = max(1, ystep * yoffset):min(youtput, ystep * (dispy + yoffset - 1))
    xrange = max(1, xstep * xoffset):min(xoutput, xstep * (dispx + xoffset - 1))
    window = view(adapt(Array, frame), yrange, xrange)
    f(window, o.cutoff)
end

_chartype(o::REPLOutput) = _chartype(o.style)
_chartype(s::Braile) = YBRAILE, XBRAILE, brailize
_chartype(s::Block) = YBLOCK, XBLOCK, blockize
