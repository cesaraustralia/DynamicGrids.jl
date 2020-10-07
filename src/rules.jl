
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
function (::Type{T})(args...) where T<:Rule
    _checkfields(T, args)
    T{:_default_,:_default_,map(typeof, args)...}(args...)
end
# R,W but no kwargs
function (::Type{T})(args...) where T<:Rule{R,W} where {R,W}
    _checkfields(T, args)
    T{map(typeof, args)...}(args...)
end
# No R,W but kwargs
(::Type{T})(; read=:_default_, write=:_default_, kwargs...) where T<:Rule =
    T{read,write}(; kwargs...)
# R,W and kwargs passed through to FieldDefaults.jl.
# This means @default should be used for rule defaults, never @default_kw
# or this will be overwritten, but also not work as it wont handle R,W.
function (::Type{T})(; kwargs...) where T<:Rule{R,W} where {R,W}
    args = FieldDefaults.insert_kwargs(kwargs, T)
    T{map(typeof, args)...}(args...)
end

# Check number of args passed in as we don't get a normal method error with the 
# splatted args in the default constructors.
_checkfields(T, args) = length(fieldnames(T)) == length(args) || 
    throw(ArgumentError("$T has $(length(fieldnames(T))) fields: $(fieldnames(T)), you have used $(length(args))"))

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
A Rule that only writes and uses a state from single cell of the read grids, 
and has its return value written back to the same cell(s). 

This limitation can be useful for performance optimisation,
such as wrapping rules in [`Chain`](@ref) so that no writes occur between rules.


`CellRule` is applied with the method:

```julia
applyrule(data::SimData, rule::YourCellRule, state, I)
```

As the cell index is provided in `applyrule`, you can look up an [`aux`](@ref) array
using `aux(data)[:auxname][I...]` to access cell-specific parameters for your rule.
"""
abstract type CellRule{R,W} <: Rule{R,W} end

"""
`ManualRule` is the supertype for rules that manually write to whichever cells of the 
grid that they choose, instead of automatically updating every cell with their output.

`ManualRule` is applied with the method:

```julia
applyrule!(data::SimData, rule::YourManualRule, state, I)
```

Note the `!` bang - this method alters the state of `data`.

Updates to the destination grids data are performed manually by
`data[:key][I...] += x`, or `data[I...] += x` if no grid names are used. 

Direct assignments with `=` will produce bugs, as the same grid cell may 
also be written to elsewhere.

Updating the block status of [`SparseOpt`](@ref) is handled automatically on write.
"""
abstract type ManualRule{R,W} <: Rule{R,W} end

"""
A Rule that only accesses a neighborhood centered around the current cell.
`NeighborhoodRule` is applied with the method:

```julia
applyrule(data::SimData, rule::YourNeighborhoodRule, state, I)
```

`NeighborhoodRule` must have a `neighborhood` field, that holds
a [`Neighborhood`](@ref) object. `neighbors(rule)` returns an iterator 
over the surrounding cell pattern defined by the `Neighborhood`.

For each cell in the grids the neighborhood buffer will be updated
for use in the `applyrule` method, managed to minimise array reads.

This allows memory optimisations and the use of BLAS routines on the
neighborhood buffer for [`Moore`](@ref) neighborhoods. It also means
that and no bounds checking is required in neighborhood code.

For neighborhood rules with multiple read grids, the first is always
the one used for the neighborhood, the others are passed in as additional 
state for the cell. Any grids can be written to, but only for the current cell.
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

ManualNeighborhood rules must return their radius with a `radius()` method, although
by default this will be called on the result of `neighborhood(rule)`.

TODO: performance optimisations with a neighborhood buffer,
simular to [`NeighborhoodRule`](@ref) but for writing.
"""
abstract type ManualNeighborhoodRule{R,W} <: ManualRule{R,W} end

neighbors(rule::ManualNeighborhoodRule) = neighbors(neighborhood(rule))
neighborhood(rule::ManualNeighborhoodRule) = rule.neighborhood
neighborhoodkey(rule::ManualNeighborhoodRule{R,W}) where {R,W} = R
neighborhoodkey(rule::ManualNeighborhoodRule{<:Tuple{R1,Vararg},W}) where {R1,W} = R1


"""
    Cell{R,W}(f)
    Cell(f; read, write)

A [`CellRule`](@ref) that applies a function `f` to the
`read` grid cells and returns the `write` cells.

Especially convenient with `do` notation.

## Example

Set the cells of grid `:c` to the sum of `:a` and `:b`:

```julia
simplerule = Cell() do a, b
    a + b
end
```

If you need to use multiple grids (a and b), use the `read`
and `write` arguments. If you want to use external variables,
wrap the whole thing in a `let` block, for performance.

```julia
rule = let y = y
    rule = Cell(read=(a, b), write=b) do a, b
        a + b * y 
    end
end
```
"""
@flattenable @description struct Cell{R,W,F} <: CellRule{R,W}
    # Field | Flatten | Description
    f::F    | false    | "Function to apply to the read values"
end
Cell(f; read=:_default_, write=read) = Cell{read,write}(f)
Cell(; kwargs...) = _nofunctionerror(Cell)

@noinline _nofunctionerror(T) = 
    throw(ArgumentError("No function passed to $T. did you mean to use a `do` block?"))

@inline applyrule(data, rule::Cell, state, I) =
    let (rule, read) = (rule, state)
        rule.f(astuple(rule, state)...)
    end

astuple(rule::Rule, state) = astuple(readkeys(rule), state)
astuple(::Tuple, state) = state
astuple(::Symbol, state) = (state,)

"""
    Neighbors(f, neighborhood)
    Neighbors{R,W}(f, neighborhood)
    Neighbors(f; read=:_default_, write=read, neighborhood=Moore()) 

A [`NeighborhoodRule`](@ref) that receives a neighbors object for the first 
`read` grid and the passed in neighborhood, followed by the cell values for 
the required grids, as with [`Cell`](@ref).

Returned value(s) are written to the `write`/`W` grid. 

As with all [`NeighborhoodRule`](@ref), you do not have to check bounds at 
grid edges, that is handled for you internally.

Using [`SparseOpt`](@ref) may improve neighborhood performance 
when zero values are common and can be safely ignored.

## Example

```julia
rule = let x = 10
    Neighbors{Tuple{:a,:b},:b}() do hood, a, b
        data[:b][I...] = a + b^x
    end
end
```

The `let` block may improve performance.
"""
@flattenable @description struct Neighbors{R,W,F,N} <: NeighborhoodRule{R,W}
    # Field         | Flatten | Description
    f::F            | false   | "Function to apply to the neighborhood and read values"
    neighborhood::N | true    | ""
end
Neighbors(f; read=:_default_, write=read, neighborhood=Moore(1)) = 
    Neighbors{read,write}(f, neighborhood)
Neighbors(; kwargs...) = _nofunctionerror(Neighbors)

@inline applyrule(data, rule::Neighbors, read, I) =
    let hood=neighborhood(rule), rule=rule, read=astuple(rule, read)
        rule.f(hood, read...)
    end

"""
    Manual(f; read=:_default_, write=read) 
    Manual{R,W}(f)

A [`ManualRule`](@ref) to manually write to the array where you need to. 
`f` is passed an indexable `data` object, and the index of the current cell, 
followed by the required grid values for the index.

## Example

```julia
rule = let x = 10
    Manual{Tuple{:a,:b},:b}() do data, I, a, b
        data[:b][I...] = a + b^x
    end
end
```
The `let` block greatly improves performance.
"""
@flattenable @description struct Manual{R,W,F} <: ManualRule{R,W}
    # Field | Flatten | Description
    f::F    | false   | "Function to apply to the data, index and read values"
end
Manual(f; read=:_default_, write=read) = Manual{read,write}(f)
Manual(; kwargs...) = _nofunctionerror(Manual)

@inline applyrule!(data, rule::Manual, read, I) =
    let data=data, I=I, rule=rule, read=astuple(rule, read)
        rule.f(data, I, read...)
    end

"""
    method(rule)

Get the method of a `Cell`, `Neighbors`, or `Manual` rule.
"""
method(rule::Union{Cell,Neighbors,Manual}) = rule.f
