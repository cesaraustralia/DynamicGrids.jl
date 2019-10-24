abstract type AbstractInteraction{Keys} end

keys(::AbstractInteraction{Keys}) where Keys = Keys

# (::Type{T(args...) where T<:AbstactInteraction, Keys} = T{Keys,typeof.(args)...}(args...)

# Provide a constructor for generic rule reconstruction
# ConstructionBase.constructorof(::Type{T}) where T<:AbstractInteracton{Keys} where Keys = Interactive{Keys} 

# val(rm::abstraInteraction) = rm.val


show(io::IO, interaction::AbstractInteraction{Keys}) where Keys = begin
    indent = get(io, :indent, "")
    printstyled(io, indent, Base.nameof(typeof(interaction)); color=:red)
    printstyled(io, indent, Keys; color=:yellow)
    if nfields(interaction) > 0
        printstyled(io, " :\n"; color=:red)
        for fn in fieldnames(typeof(interaction))
            println(io, indent, "    ", fn, " = ", repr(getfield(interaction, fn)))
        end
    end
end
