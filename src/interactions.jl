"""
Rules that involved the interaction between
two grids
"""
abstract type Interaction{Keys} <: AbstractRule end

Base.keys(::Interaction{Keys}) where Keys = Keys

# Provide a constructor for generic rule reconstruction in Flatten.jl and Setfield.jl
ConstructionBase.constructorof(::Type{T}) where T<:Interaction{Keys} where Keys = 
    T{Keys} 

abstract type CellInteraction{Keys} <: AbstractRule end

abstract type PartialInteraction{Keys} <: AbstractRule end

"""
Interactions that use a neighborhood
"""
abstract type NeighborhoodInteraction{Keys} <: Interaction{Keys} end
