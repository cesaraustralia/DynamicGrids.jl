using REPL

abstract type CharStyle end
struct Block <: CharStyle end
struct Braile <: CharStyle end

"""
    REPLOutput <: GraphicOutput

    REPLOutput(init; tspan, kw...)

An output that is displayed directly in the REPL. It can either store or discard
simulation frames.

# Arguments:

- `init`: initialisation `AbstractArray` or `NamedTuple` of `AbstractArray`.

# Keywords

- `color`: a color from Crayons.jl
- `cutoff`: `Real` cutoff point to display a full or empty cell. Default is `0.5`
- `style`: `CharStyle` `Block()` or `Braile()` printing. `Braile` uses 1/4 the screen space of `Block`.

$GRAPHICOUTPUT_KEYWORDS

e `GraphicConfig` object can be also passed to the `graphicconfig` keyword, and other keywords will be ignored.
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
    if store(graphicconfig)
        append!(frames, _zerogrids(init(extent), length(tspan(extent))-1))
    end
    REPLOutput(frames, running, extent, graphicconfig, color, style, cutoff)
end

function showframe(frame::AbstractArray, o::REPLOutput, data::AbstractSimData)
    _print_to_repl((0, 0), o.color, _replframe(o, frame, currentframe(data)))
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

# Block size constants to calculate the frame size as 
# braile pixels are half the height and width of block pixels
const YBRAILE = 4
const XBRAILE = 2
const YBLOCK = 2
const XBLOCK = 1

_chartype(o::REPLOutput) = _chartype(o.style)
_chartype(s::Braile) = YBRAILE, XBRAILE, brailize
_chartype(s::Block) = YBLOCK, XBLOCK, blockize

function _replframe(o, frame::AbstractArray{<:Any,1}, currentframe)
    ystep, xstep, charfunc = _chartype(o)
    # Limit output area to available terminal size.
    dispy, dispx = displaysize(stdout)

    offset = 0
    rnge = max(1, xstep * offset):min(length(frame))
    f = currentframe
    nrows = min(f, dispy) 
    # For 1D we show all the rows every time
    tlen = length(tspan(o))
    rowstrings = map(f - nrows + 1:f) do i
        framewindow1 = view(Adapt.adapt(Array, frames(o)[i]), rnge) 
        framewindow2 = if i == tlen
            framewindow1
        else
            view(Adapt.adapt(Array, frames(o)[i]), rnge) 
        end
        charfunc(PermutedDimsArray(hcat(framewindow1, framewindow2), (2, 1)), o.cutoff)
    end
    return join(rowstrings, "\n")
end
function _replframe(o, frame::AbstractArray{<:Any,2}, currentframe)
    ystep, xstep, charfunc = _chartype(o)

    # Limit output area to available terminal size.
    dispy, dispx = displaysize(stdout)

    youtput, xoutput = outputsize = size(frame)
    yoffset, xoffset = (0, 0)

    yrange = max(1, ystep * yoffset):min(youtput, ystep * (dispy + yoffset - 1))
    xrange = max(1, xstep * xoffset):min(xoutput, xstep * (dispx + xoffset - 1))
    framewindow = view(Adapt.adapt(Array, frame), yrange, xrange) # TODO make this more efficient on GPU
    return charfunc(framewindow, o.cutoff)
end
function _replframe(o, frame::AbstractArray{<:Any,N}, currentframe) where N
    slice = view(frame, :, :, ntuple(_ -> 1, N-2)...)
    _replframe(o, slice, currentframe)
end
