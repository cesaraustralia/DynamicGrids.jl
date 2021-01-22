
"""
A `Rule` object contains the information required to apply some
logical rule to every cell of every timestep of a simulation.

Rules can be chained together sequentially into [`Ruleset`](@ref)s.

Rules are applied to the grid using the [`applyrule`](@ref) method:

```julia
@inline applyrule(data::SimData, rule::YourRule, state, index) =
```

Where `index` is a `Tuple` of `Int`, and `state` is a single value, or a `NamedTuple`
if multiple grids are requested. The `NamedTuple` keys will match the
keys in `R`, which is a type like `Tuple{:key1,:key1}` - note the names are user
specified, and should never be fixed by a `Rule` - they can be retrieved from the type
here as `A` and `B` :

```julia
applyrule(data::SimData, rule::YourCellRule{Tuple{R1,R2},Tuple{W1,W2}}, state, index) where {R1,R2,W1,W2}
```

By default the output is written to the current cell in the specified `W` write grid/s.
`Rule`s writing to multiple grids, simply return a `Tuple` in the order specified by
the `W` type params.

## Precalculation

[`precalcrule`](@ref) can be used to precalculate any fields that depend on the
timestep. Otherwise everything should be precalculated apon construction.

Retreive required information from [`SimData`](@ref) such as [`currenttime`](@ref)
or [`currentframe`](@ref). The return value is the updated rule.

```julia
precalcrule(rule::YourCellRule, data::SimData)
```

## Rule Performance

Rules may run many millions of times during a simulation. They need to be fast.

Some basic guidlines for writing rules are:
- Never allocate memory in a `Rule` if you can help it.
- Type stability is essential. [`isinferred`](@ref) is useful to check
  if your rule is type-stable.
- Using the `@inline` macro on `applyrule` can help force inlining your
  code into the simulation.
- Reading and writing from multiple grids is expensive due to additional load
  on fast cahce memory. Try to limit the number of grids you use.


"""
abstract type Rule{R,W} end

#= Default constructors for all Rules.
Sets both the read and write grids to `:_default`.

This strategy relies on a one-to-one relationship between fields
and type parameters, besides the initial `R` and `W` params.  =#

# No {R,W} with args or kw
function (::Type{T})(args...; kw...) where T<:Rule
    T{:_default_,:_default_}(args...; kw...)
end
# {R,W} with args
function (::Type{T})(args...) where T<:Rule{R,W} where {R,W}
    # _checkfields(T, args)
    T{map(typeof, args)...}(args...)
end
# Only R specified
function (::Type{T})(args...; kw...) where T<:Rule{R} where R
    T{R}(args...; kw...)
end


@generated function Base.keys(rule::Rule{R,W}) where {R,W}
    Expr(:tuple, QuoteNode.(union(_asiterable(W), _asiterable(R)))...)
end

@inline _writekeys(::Rule{R,W}) where {R,W} = W
@generated function _writekeys(::Rule{R,W}) where {R,W<:Tuple}
    Expr(:tuple, QuoteNode.(W.parameters)...)
end

@inline _readkeys(::Rule{R,W}) where {R,W} = R
@generated function _readkeys(::Rule{R,W}) where {R<:Tuple,W}
    Expr(:tuple, QuoteNode.(R.parameters)...)
end

# Define the constructor for generic rule reconstruction in Flatten.jl and Setfield.jl
function ConstructionBase.constructorof(::Type{T}) where T<:Rule{R,W} where {R,W}
    T.name.wrapper{R,W}
end

# Find the largest radius present in the passed in rules.
function radius(rules::Tuple{Vararg{<:Rule}})
    allkeys = Tuple(union(map(keys, rules)...))
    maxradii = Tuple(radius(rules, key) for key in allkeys)
    return NamedTuple{allkeys}(maxradii)
end
radius(rules::Tuple{}) = NamedTuple{(),Tuple{}}(())
# Get radius of specific key from all rules
radius(rules::Tuple{Vararg{<:Rule}}, key::Symbol) =
    reduce(max, radius(ru) for ru in rules if key in keys(ru); init=0)

radius(rule::Rule, args...) = 0


"""
A `Rule` that only writes and uses a state from single cell of the read grids,
and has its return value written back to the same cell(s).

This limitation can be useful for performance optimisation,
such as wrapping rules in [`Chain`](@ref) so that no writes occur between rules.


`CellRule` is defined with :

```julia
struct YourCellRule{R,W} <: CellRule{R,W} end
```

And applied as:

```julia
function applyrule(data::SimData, rule::YourCellRule{R,W}, state, index) where {R,W}
    state * 2
end
```

As the `index` is provided in `applyrule`, you can look up an [`aux`](@ref) array
using `aux(data, Val{:auxname}())[index...]` to access cell-specific variables for
your rule.

It's good to add a struct field to hold the `Val{:auxname}()` object instead of
using names directly, so that users can set the aux name themselves to suit the
scripting context.

"""
abstract type CellRule{R,W} <: Rule{R,W} end


"""
Abstract supertype for rules that manually write to the grid in any way.

Adds methods to [`applyrule!`](@ref).
"""
abstract type SetRule{R,W} <: Rule{R,W} end

"""
Abstract supertype for rules that can manually write to any cells of the
grid that they need to.

`SetCellRule` is applied with a method like:

```julia
function applyrule!(data::SimData, rule::YourSetCellRule, state, index)
     inc = 1
     add!(data, inc, index...)
     return nothing
end
```

Note the `!` bang - this method alters the state of `data`.

To update the grid, you can use atomic operators [`add!`](@ref), [`sub!`](@ref), 
[`min!`](@ref), [`max!`](@ref), and [`and!`](@ref), [`or!`](@ref) for `Bool`. 
These methods safely combined writes from all grid cells - directly using `setindex!` 
would cause bugs.

It there are multiple write grids, you will need to get the grid keys from
type parameters, here `W1` and `W2`:

```julia
function applyrule(data, rule::YourSetCellRule{R,Tuple{W1,W2}}, state, index) where {R,W1,W2}
     inc = 1
     add!(data[W1], inc, index...)
     add!(data[W2], 2inc, index...)
     return nothing
end
```
"""
abstract type SetCellRule{R,W} <: SetRule{R,W} end

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
offsets(rule::NeighborhoodRule) = offsets(neighborhood(rule))
kernel(rule::NeighborhoodRule) = kernel(neighborhood(rule))
positions(rule::NeighborhoodRule, args...) = positions(neighborhood(rule), args...)
neighborhoodkey(rule::NeighborhoodRule{R,W}) where {R,W} = R
# The first argument is for the neighborhood grid
neighborhoodkey(rule::NeighborhoodRule{<:Tuple{R1,Vararg},W}) where {R1,W} = R1
_buffer(rule::NeighborhoodRule) = _buffer(neighborhood(rule))
@inline _setbuffer(rule::NeighborhoodRule, _buffer) =
    @set rule.neighborhood = _setbuffer(rule.neighborhood, _buffer)
radius(rule::NeighborhoodRule, args...) = radius(neighborhood(rule))

"""
A Rule that only writes to its neighborhood.

[`positions`](@ref) and [`offsets`](@ref) are useful iterators for modifying
neighborhood values. Atomic 

`SetNeighborhood` rules must return a `Neighborhood` object from `neighborhood(rule)`.
By default this is `rule.neighborhood`. If this property exists, no interface methods 
are required.
"""
abstract type SetNeighborhoodRule{R,W} <: SetRule{R,W} end

neighborhood(rule::SetNeighborhoodRule) = rule.neighborhood
offsets(rule::SetNeighborhoodRule) = offsets(neighborhood(rule))
kernel(rule::SetNeighborhoodRule) = kernel(neighborhood(rule))
positions(rule::SetNeighborhoodRule, args...) = positions(neighborhood(rule), args...)
radius(rule::SetNeighborhoodRule, args...) = radius(neighborhood(rule))
neighborhoodkey(rule::SetNeighborhoodRule{R,W}) where {R,W} = R
neighborhoodkey(rule::SetNeighborhoodRule{<:Tuple{R1,Vararg},W}) where {R1,W} = R1


"""
A `Rule` applies to whole grids. This is used for operations that don't benefit from
having neighborhood buffering or looping over the grid handled for them, or any specific
optimisations. Best suited to simple functions like `rand`(write)` or using convolutions
from other packages like DSP.jl. They may also be useful for doing other custom things that
don't fit into the DynamicGrids.jl framework during the simulation.

Grid rules specify the grids they want and are sequenced just like any other grid.

```julia
struct YourSetGridRule{R,W} <: SetGridRule{R,W} end
```

And applied as:

```julia
function applyrule!(data::SimData, rule::YourSetGridRule{R,W}) where {R,W}
    rand!(data[W])
end
```
"""
abstract type SetGridRule{R,W} <: Rule{R,W} end


"""
    SetGrid{R,W}(f)

Apply a function `f` to fill whole grid/s.

```julia
rule = SetGrid{:a,:b}() do a, b
    b .= a
end
```

Never use assignment broadcast `.*=`, as the write grids `W` are not guarantieed to
have the same values as the read grids `R`. Always copy from a read
grid to a write grid manually.
"""
struct SetGrid{R,W,F} <: SetGridRule{R,W}
    "Function to apply to the read values"
    f::F
end
SetGrid{R,W}(; kwargs...) where {R,W} = _nofunctionerror(SetGrid)

@inline function applyrule!(data, rule::SetGrid{R,W}) where {R,W}
    rule.f(
        map(r -> source(getindex(data, r)), _asiterable(R))...,
        map(w -> source(getindex(data, w)), _asiterable(W))...,
    )
end


"""
    Cell(f)
    Cell{R,W}(f)

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
    rule = Cell{Tuple{:a,:b},:b}() do a, b
        a + b * y
    end
end
```
"""
struct Cell{R,W,F} <: CellRule{R,W}
    "Function to apply to the read values"
    f::F
end
Cell{R,W}(; kwargs...) where {R,W} = _nofunctionerror(Cell)

@inline function applyrule(data, rule::Cell, state, I)
    let rule=rule, state=state
        rule.f(_astuple(rule, state)...)
    end
end

"""
    Neighbors(f, neighborhood=Moor(1))
    Neighbors{R,W}(f, neighborhood=Moore())

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
struct Neighbors{R,W,F,N} <: NeighborhoodRule{R,W}
    "Function to apply to the neighborhood and read values"
    f::F
    "Defines the neighborhood of cells around the central cell"
    neighborhood::N
end
Neighbors{R,W}(; kwargs...) where {R,W} = _nofunctionerror(Neighbors)
Neighbors{R,W}(f; neighborhood=Moore(1)) where {R,W} =
    Neighbors{R,W}(f, neighborhood)

@inline function applyrule(data, rule::Neighbors, read, I)
    let hood=neighborhood(rule), rule=rule, read=_astuple(rule, read)
        rule.f(hood, read...)
    end
end

"""
    SetCell(f)
    SetCell{R,W}(f)

A [`SetCellRule`](@ref) to manually write to the array where you need to.
`f` is passed an indexable `data` object, and the index of the current cell,
followed by the required grid values for the index.

To update the grid, you can use: [`add!`](@ref), [`sub!`](@ref) for `Number`,
and [`and!`](@ref), [`or!`](@ref) for `Bool`. These methods safely combined
writes from all grid cells - directly using `setindex!` would cause bugs.

## Example

```julia
rule = let x = 10
    Set{Tuple{:a,:b},:b}() do data, I, a, b
        add!(data[:b], a^x, I...)
    end
end
```
The `let` block greatly improves performance.
"""
struct SetCell{R,W,F} <: SetCellRule{R,W}
    "Function to apply to data, index and read state arguments"
    f::F
end
SetCell{R,W}(; kwargs...) where {R,W} = _nofunctionerror(Set)

@inline function applyrule!(data, rule::SetCell, read, I)
    let data=data, I=I, rule=rule, read=_astuple(rule, read)
        rule.f(data, I, read...)
    end
end


"""
    SetNeighbors(f, neighborhood=Moor(1))
    SetNeighbors{R,W}(f, neighborhood=Moor(1))

A [`SetCellRule`](@ref) to manually write to the array with the specified 
neighborhood. Indexing outside the neighborhood is undefined behaviour.

Function `f` is passed an [`SimData`](@ref) object `data`, the specified 
neighborhood object and the index of the current cell, followed by the required 
grid values for the index. 

To update the grid, you can use: [`add!`](@ref), [`sub!`](@ref) for `Number`,
and [`and!`](@ref), [`or!`](@ref) for `Bool`. These methods can be safely combined
writes from all grid cells. 

Directly using `setindex!` is possible, but may cause bugs as multiple cells
may write to the same location in an unpredicatble order. As a rule, directly
setting a neighborhood index should only be done if it always sets the samevalue - 
then it can be guaranteed that any writes from othe grid cells reach the same result.

[`neighbors`](@ref), [`offsets`](@ref) and [`positions`](@ref) are useful methods for
`SetNeighbors` rules.

## Example

```julia
SetNeighbors{Tuple{:a,:b},:b}() do data, hood, I, a, b
    for pos in positions(hood)
        add!(data[:b], a^2, pos...)
    end
end
```
"""
struct SetNeighbors{R,W,F,N} <: SetNeighborhoodRule{R,W}
    "Function to apply to the data, index and read values"
    f::F
    "The neighborhood of cells around the central cell"
    neighborhood::N
end
SetNeighbors{R,W}(; kw...) where {R,W} = _nofunctionerror(SetNeighbors)
SetNeighbors{R,W}(f; neighborhood=Moore(1)) where {R,W} = SetNeighbors{R,W}(f, neighborhood)

@inline function applyrule!(data, rule::SetNeighbors, read, I)
    let data=data, hood=neighborhood(rule), I=I, rule=rule, read=_astuple(rule, read)
        rule.f(data, hood, I, read...)
    end
end


"""
    Convolution(f, neighborhood=Moor(1))
    Convolution{R,W}(f, neighborhood=Moor(1))

A `Rule` that runs a basic convolution kernel over the grid.

# Performance

_Always_ use StaticArrays.jl to define the kernel matrix.

Small radius convolutions in DynamicGrids.jl will be faster or comparable to using
DSP.jl or ImageConvolutions.jl. As the radius increases or grid size gets very large
these packages will be a lot faster.

But `Convolution` is convenient to chain into a simlulation, and combined with some other 
rules. It should perform reasonably well in all but very large simulations or very large 
kernels.

## Example

```julia
rule = Convolution(Kernel(SA[0.05 0.1 0.05; 0.1 0.4 0.1; 0.05 0.1 0.05]))
```
"""
struct Convolution{R,W,N} <: NeighborhoodRule{R,W}
    "The neighborhood of cells around the central cell"
    neighborhood::N
end
Convolution{R,W}(A::AbstractArray) where {R,W} = Convolution{R,W}(Kernel(SMatrix{size(A)...}(A)))
Convolution{R,W}(; neighborhood) where {R,W} = Convolution{R,W}(neighborhood)

@inline function applyrule(data, rule::Convolution, read, I)
    @inbounds neighbors(rule) ⋅ kernel(neighborhood(rule))
end

# Utils

@noinline _nofunctionerror(t) =
    throw(ArgumentError("No function passed to $t. Did you mean to use a do block?"))

# Check number of args passed in as we don't get a normal method
# error because of the splatted args in the default constructor.
# @generated function _checkfields(::Type{T}, args::A) where {T,A<:Tuple}
    # length(fieldnames(T)) == length(fieldnames(A)) ? :(nothing) : :(_fielderror(T, args))
# end

# @noinline function _fielderror(T, args)
    # throw(ArgumentError("$T has $(length(fieldnames(T))) fields: $(fieldnames(T)), you have used $(length(args))"))
# end
