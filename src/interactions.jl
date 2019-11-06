"""
Rules that involved the interaction between
two grids
"""
abstract type Interaction{Keys} <: Rule end

Base.keys(::Interaction{Keys}) where Keys = Keys

# Provide a constructor for generic rule reconstruction in Flatten.jl and Setfield.jl
ConstructionBase.constructorof(::Type{T}) where T<:Interaction{Keys} where Keys = 
    T{Keys} 

abstract type CellInteraction{Keys} <: Interaction{Keys} end

abstract type PartialInteraction{Keys} <: Interaction{Keys} end

"""
Interactions that use a neighborhood and write to the current cell.
"""
abstract type NeighborhoodInteraction{Keys} <: Interaction{Keys} end

neighborhood(interaction::NeighborhoodInteraction) = interaction.neighborhood 

"""
Interactions that write to a neighborhood.
"""
abstract type PartialNeighborhoodInteraction{Keys} <: PartialInteraction{Keys} end

neighborhood(interaction::PartialInteraction) = interaction.neighborhood 
