"""
    TextConfig

    TextConfig(; kw...)
    TextConfig(face, namepixels, namepos, timepixels, timepos, fcolor, bcolor)

Text configuration for printing timestep and grid name on the image.

# Arguments / Keywords

- `font`: A `FreeTypeAbstraction.FTFont`, or a `String` with the font name to look for. The `FTFont` may load more quickly.
- `namepixels` and `timepixels`: the pixel size of the font.
- `timepos` and `namepos`: tuples that set the label positions, in `Int` pixels.
- `fcolor` and `bcolor`: the foreground and background colors, as `ARGB32`.
"""
struct TextConfig{F,NPi,NPo,TPi,TPo,FC,BC}
    face::F
    namepixels::NPi
    namepos::NPo
    timepixels::TPi
    timepos::TPo
    fcolor::FC
    bcolor::BC
end
function TextConfig(;
    font=autofont(), namepixels=12, timepixels=12,
    namepos=(3timepixels + namepixels, timepixels),
    timepos=(2timepixels, timepixels),
    fcolor=ARGB32(1.0), bcolor=ZEROCOL,
)
    if font isa FreeTypeAbstraction.FTFont
	    face = font
    elseif font isa AbstractString
        face = FreeTypeAbstraction.findfont(font)
        face isa Nothing && _fontnotfounderror(font)
    else
        _fontnotstring(font)
    end
    TextConfig(face, namepixels, namepos, timepixels, timepos, fcolor, bcolor)
end

@noinline _fontnotstring(font) = throw(ArgumentError("font $font is not a String"))

@noinline _fontnotfounderror(font) =
    throw(ArgumentError(
        """
        Font "$font" wasn't be found in this system. Specify an existing font name 
        with the `font` keyword, or use `text=nothing` to display no text."
        """
    ))
@noinline _nodefaultfonterror(font) =
    error(
        """
        Your system does not contain the default font $font. Specify an existing font 
        name `String` with the keyword-argument `font`, for the `Output` or `ImageConfig`.
        """
    )

# isbits(FreeTypeAbstraction.FTFont) == false,
# hence isassigned can tell whether the cache has been initialized
const _default_font_ref = Ref{FreeTypeAbstraction.FTFont}()

function autofont()
    if isassigned(_default_font_ref)
        return _default_font_ref[]
    else
        names = if Sys.islinux()
            ("cantarell", "sans-serif", "Bookman")
        else
            ("arial", "sans-serif")
        end
        for name in names
            face = FreeTypeAbstraction.findfont(name)
            if face isa FreeTypeAbstraction.FTFont
                _default_font_ref[] = face
                return face
            end
        end
        _nodefaultfonterror(names)
    end
end

function set_default_font(font)
	_default_font_ref[] = font
end

# Render time `name` and `t` as text onto the image, following config settings.
function _rendertime! end

function _rendertext!(img, config::TextConfig, name, t)
    _rendername!(img, config::TextConfig, name)
    _rendertime!(img, config::TextConfig, t)
    img
end
_rendertext!(img, config::Nothing, name, t) = nothing

# Render `name` as text on the image following config settings.
function _rendername!(img, config::TextConfig, name)
    renderstring!(img, name, config.face, config.namepixels, config.namepos...;
        fcolor=config.fcolor, bcolor=config.bcolor
    )
    img
end
_rendername!(img, config::TextConfig, name::Nothing) = img
_rendername!(img, config::Nothing, name) = img
_rendername!(img, config::Nothing, name::Nothing) = img

# Render time `t` as text on the image following config settings.
function _rendertime!(img, config::TextConfig, t)
    renderstring!(img, string(t), config.face, config.timepixels, config.timepos...;
        fcolor=config.fcolor, bcolor=config.bcolor
    )
    img
end
_rendertime!(img, config::Nothing, t) = img
_rendertime!(img, config::TextConfig, t::Nothing) = img
_rendertime!(img, config::Nothing, t::Nothing) = img
