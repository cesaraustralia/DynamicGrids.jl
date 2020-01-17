"""
Rules that involved the interaction between two grids

Applied using [`applyinteraction](@ref) and [`applyinteraction!](@ref).
"""
abstract type Interaction{Keys} <: Rule end

Base.keys(::Interaction{Keys}) where Keys = Keys

# Default constructor for just the Keys type param where all args have type parameters
(::Type{T})(args...) where T<:Interaction{Keys} where Keys =
    T{Keys,typeof,(args)...}(args...)

# Define the constructor for generic rule reconstruction in Flatten.jl and Setfield.jl
ConstructionBase.constructorof(::Type{T}) where T<:Interaction{Keys} where Keys =
    T{Keys}

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
