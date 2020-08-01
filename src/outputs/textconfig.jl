"""
    TextConfig(; font::String, namepixels=14, timepixels=14,
               namepos=(timepixels+namepixels, timepixels),
               timepos=(timepixels, timepixels),
               fcolor=ARGB32(1.0), bcolor=ARGB32(RGB(0.0), 1.0),)
    TextConfig(face, namepixels, namepos, timepixels, timepos, fcolor, bcolor)

Text configuration for printing timestep and grid name on the image.

# Arguments

- `namepixels` and `timepixels`: set the pixel size of the font. 
- `timepos` and `namepos`: tuples that set the label positions, in pixels.
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
TextConfig(; font, namepixels=12, timepixels=12,
           namepos=(3timepixels + namepixels, timepixels),
           timepos=(2timepixels, timepixels),
           fcolor=ARGB32(1.0), bcolor=ARGB32(RGB(0.0), 1.0),
          ) = begin
    face = FreeTypeAbstraction.findfont(font)
    face isa Nothing && throw(ArgumentError("Font $font can not be found in this system"))
    TextConfig(face, namepixels, namepos, timepixels, timepos, fcolor, bcolor)
end

"""
    rendertext!(img, config::TextConfig, name, t)

Render time `name` and `t` as text onto the image, following config settings.
"""
rendertext!(img, config::TextConfig, name, t) = begin
    rendername!(img, config::TextConfig, name)
    rendertime!(img, config::TextConfig, t)
end
rendertext!(img, config::Nothing, name, t) = nothing

"""
    rendername!(img, config::TextConfig, name)

Render `name` as text on the image following config settings.
"""
rendername!(img, config::TextConfig, name) =
    renderstring!(img, name, config.face, config.namepixels, config.namepos...;
                  fcolor=config.fcolor, bcolor=config.bcolor)
rendername!(img, config::TextConfig, name::Nothing) = nothing
rendername!(img, config::Nothing, name) = nothing
rendername!(img, config::Nothing, name::Nothing) = nothing

"""
    rendertime!(img, config::TextConfig, t)

Render time `t` as text on the image following config settings.
"""
rendertime!(img, config::TextConfig, t) =
    renderstring!(img, string(t), config.face, config.timepixels, config.timepos...;
                  fcolor=config.fcolor, bcolor=config.bcolor)
rendertime!(img, config::Nothing, t) = nothing
rendertime!(img, config::TextConfig, t::Nothing) = nothing
rendertime!(img, config::Nothing, t::Nothing) = nothing
