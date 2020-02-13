"""
Rules that involved the interaction between two grids

Applied using [`applyinteraction](@ref) and [`applyinteraction!](@ref).
"""
abstract type Interaction{Writekeys,Readkeys} <: Rule end

@generated Base.keys(rule::Interaction{W,R}) where {W,R} =
    Expr(:tuple, QuoteNode.(union(_asiterable(W), _asiterable(R)))...)
writekeys(::Interaction{W,R}) where {W,R} = W
@generated writekeys(::Interaction{W,R}) where {W<:Tuple,R} =
    Expr(:tuple, QuoteNode.(W.parameters)...)
readkeys(::Interaction{W,R}) where {W,R} = R
@generated readkeys(::Interaction{W,R}) where {W,R<:Tuple} =
    Expr(:tuple, QuoteNode.(R.parameters)...)

_asiterable(x::Symbol) = (x,)
_asiterable(x::Type{<:Tuple}) = x.parameters

# Default constructor for just the Keys type param where all args have type parameters
(::Type{T})(args...) where T<:Interaction{W,R} where {W,R} =
    T{typeof.(args)...}(args...)

# Define the constructor for generic rule reconstruction in Flatten.jl and Setfield.jl
ConstructionBase.constructorof(::Type{T}) where T<:Interaction{W,R} where {W,R} =
    T{W,R}

show(io::IO, rule::I) where I <: Interaction{W,R} where {W,R} = begin
    indent = get(io, :indent, "")
    printstyled(io, indent, Base.nameof(typeof(rule)); color=:red)
    printstyled(io, indent, string("{", W, ",", R, "}"); color=:red)
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
abstract type CellInteraction{W,R} <: Interaction{W,R} end

"""
Rules that conditionally apply to particular cells, but may not write
to every cell in the grid. Analogous to [`PartialRule`](@ref).
"""
abstract type PartialInteraction{W,R} <: Interaction{W,R} end

"""
Interactions that use a neighborhood and write to the current cell,
analagous to [`NeighborhoodRule`](@ref).
"""
abstract type NeighborhoodInteraction{W,R} <: Interaction{W,R} end

neighborhood(interaction::NeighborhoodInteraction) = interaction.neighborhood

"""
Interactions that write to a neighborhood, analogous to [`PartialNeighborhoodRule`](@ref).
"""
abstract type PartialNeighborhoodInteraction{W,R} <: PartialInteraction{W,R} end

neighborhood(interaction::PartialInteraction) = interaction.neighborhood
