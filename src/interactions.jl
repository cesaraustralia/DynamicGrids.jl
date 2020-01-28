"""
Rules that involved the interaction between two grids

Applied using [`applyinteraction](@ref) and [`applyinteraction!](@ref).
"""
abstract type Interaction{Keys} <: Rule end

Base.keys(::Interaction{Keys}) where Keys = Keys

# Default constructor for just the Keys type param where all args have type parameters
(::Type{T})(args...) where T<:Interaction{Keys} where Keys =
    T{typeof.(args)...}(args...)

# Define the constructor for generic rule reconstruction in Flatten.jl and Setfield.jl
ConstructionBase.constructorof(::Type{T}) where T<:Interaction{Keys} where Keys =
    T{Keys}

show(io::IO, rule::I) where I <: Interaction = begin
    indent = get(io, :indent, "")
    printstyled(io, indent, Base.nameof(typeof(rule)); color=:red)
    printstyled(io, indent, string("{", keys(rule), "}"); color=:red)
    if nfields(rule) > 0
        printstyled(io, " :\n"; color=:red)
        for fn in fieldnames(I)
            if fieldtype(I, fn) <: Union{Number,Symbol,String}
                println(io, indent, "    ", fn, " = ", repr(getfield(rule, fn)))
            else
                # Avoid prining arrays etc. Just show the type.
                println(io, indent, "    ", fn, " = ", fieldtype(I, fn))
            end
        end
    end
end


"""
Cell by cell interaction, analogous to [`CellRule`](@ref).
"""
abstract type CellInteraction{Keys} <: Interaction{Keys} end

"""
Rules that conditionally apply to particular cells, but may not write
to every cell in the grid. Analogous to [`PartialRule`](@ref).
"""
abstract type PartialInteraction{Keys} <: Interaction{Keys} end

"""
Interactions that use a neighborhood and write to the current cell,
analagous to [`NeighborhoodRule`](@ref).
"""
abstract type NeighborhoodInteraction{Keys} <: Interaction{Keys} end

neighborhood(interaction::NeighborhoodInteraction) = interaction.neighborhood

"""
Interactions that write to a neighborhood, analogous to [`PartialNeighborhoodRule`](@ref).
"""
abstract type PartialNeighborhoodInteraction{Keys} <: PartialInteraction{Keys} end

neighborhood(interaction::PartialInteraction) = interaction.neighborhood
