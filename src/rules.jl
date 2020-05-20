
"""
A rule contains all the information required to run a rule in a
simulation, given an initial array. Rules can be chained together sequentially.

By default the output of the rule for a Rule is automatically written to the current
cell in the grid.

Rules are applied to the grid using the [`applyrule`](@ref) method.
"""
abstract type Rule{R,W} end


#=
Default constructors for all rules.
Sets both the read and write grids to `:_default`.

This strategy relies on a one-to-one relationship
between all fields and their type parameters, besides
the initial `R`, `W` etc fields.
=#

# No R,W params and no kwargs
(::Type{T})(args...) where T<:Rule =
    T{:_default_,:_default_,map(typeof, args)...}(args...)
# R,W but no kwargs
(::Type{T})(args...) where T<:Rule{R,W} where {R,W} =
    T{typeof.(args)...}(args...)
# No R,W but kwargs
(::Type{T})(; read=:_default_, write=:_default_, kwargs...) where T<:Rule =
    T{read,write}(; kwargs...)
# R,W and kwargs passed through to FieldDefaults.jl.
# This means @default should be used for rule defaults, never @default_kw
# or this will be overwritten, but also not work as it wont handle R,W.
(::Type{T})(; kwargs...) where T<:Rule{R,W} where {R,W} = begin
    args = FieldDefaults.insert_kwargs(kwargs, T)
    T{map(typeof, args)...}(args...)
end

@generated Base.keys(rule::Rule{R,W}) where {R,W} =
    Expr(:tuple, QuoteNode.(union(asiterable(W), asiterable(R)))...)

@inline writekeys(::Rule{R,W}) where {R,W} = W
@generated writekeys(::Rule{R,W}) where {R,W<:Tuple} =
    Expr(:tuple, QuoteNode.(W.parameters)...)

@inline readkeys(::Rule{R,W}) where {R,W} = R
@generated readkeys(::Rule{R,W}) where {R<:Tuple,W} =
    Expr(:tuple, QuoteNode.(R.parameters)...)

keys2vals(keys::Tuple) = map(Val, keys)
keys2vals(key::Symbol) = Val(key)

asiterable(x::Symbol) = (x,)
asiterable(x::Type{<:Tuple}) = x.parameters
asiterable(x::Tuple) = x

# Define the constructor for generic rule reconstruction in Flatten.jl and Setfield.jl
ConstructionBase.constructorof(::Type{T}) where T<:Rule{R,W} where {R,W} =
    T.name.wrapper{R,W}

"""
A Rule that only writes and accesses a single cell: its return value is the new
value of the cell(s). This limitation can be useful for performance optimisation,
such as wrapping rules in [`Chain`](@ref) so that no writes occur between rules.

Accessing `source(data)` and `dest(data)` arrays directly from CellRule
is not guaranteed to have correct results, and should not be done.
"""
abstract type CellRule{R,W} <: Rule{R,W} end

"""
PartialRule is for rules that manually write to whichever cells of the grid
that they choose, instead of automatically updating every cell with their output.

Updates to the destination grids data must be performed manually by
`data[:key] = x`. Updating block status is handled automatically on write.
"""
abstract type PartialRule{R,W} <: Rule{R,W} end

"""
A Rule that only accesses a neighborhood centered around the current cell.
NeighborhoodRule is applied with the method:

```julia
applyrule(rule::Life, data, state, index, buffer)
```

For each cell a neighborhood buffer will be populated containing the
neighborhood cells, and passed to `applyrule` in the rule neighborhood.

This allows memory optimisations and the use of BLAS routines on the
neighborhood buffer for [`RadialNeighborhood`](@ref). It also means
that and no bounds checking is required in neighborhood code.

`neighbors(hood)` returns an iterator over the buffer that is generic to
any neigborhood type - Custom shapes as well as square radial neighborhoods.
A Neighborhood can also be used directly as an iterator..

For neighborhood rules with multiple read grids, the first is the one
used for the neighborhood, the others are passed in as additional state 
for the central cell.
"""
abstract type NeighborhoodRule{R,W} <: Rule{R,W} end

neighbors(rule::NeighborhoodRule) = neighbors(neighborhood(rule))
neighborhood(rule::NeighborhoodRule) = rule.neighborhood
neighborhoodkey(rule::NeighborhoodRule{R,W}) where {R,W} = R
# The first argument is for the neighborhood grid
neighborhoodkey(rule::NeighborhoodRule{<:Tuple{R1,Vararg},W}) where {R1,W} = R1


"""
A Rule that only writes to its neighborhood, defined by its radius distance from the
current point.

PartialNeighborhood rules must return their radius with a `radius()` method, although
by default this will be called on the result of `neighborhood(rule)`.

TODO: performance optimisations with a neighborhood buffer,
simular to [`NeighborhoodRule`](@ref) but for writing.
"""
abstract type PartialNeighborhoodRule{R,W} <: PartialRule{R,W} end

neighbors(rule::PartialNeighborhoodRule) = neighbors(neighborhood(rule))
neighborhood(rule::PartialNeighborhoodRule) = rule.neighborhood
neighborhoodkey(rule::PartialNeighborhoodRule{R,W}) where {R,W} = R
neighborhoodkey(rule::PartialNeighborhoodRule{<:Tuple{R1,Vararg},W}) where {R1,W} = R1
