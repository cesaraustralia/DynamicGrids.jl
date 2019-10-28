abstract type Interaction{Keys} <: Rule end

keys(::Interaction{Keys}) where Keys = Keys

# Provide a constructor for generic rule reconstruction in Flatten.jl and Setfield.jl
ConstructionBase.constructorof(::Type{T}) where T<:AbstractInteracton{Keys} where Keys = 
    T{Keys} 
