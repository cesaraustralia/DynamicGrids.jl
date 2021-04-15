
"""
    Rule

A `Rule` object contains the information required to apply an
`applyrule` method to every cell of every timestep of a simulation.


The [`applyrule`](@ref) method follows the form:

```julia
@inline applyrule(data::SimData, rule::YourRule, state, I::Tuple{Int,Int}) = ...
```

Where `I` is the cell index, and `state` is a single value, or a `NamedTuple`
if multiple grids are requested. the [`SimData`](@ref) object can be used to access 
current timestep and other simulation data and metadata.

Rules can be updated from the original rule before each timestep, in [`modifyrule`](@ref):

```julia
modifyrule(rule::YourRule, data::SimData) = ...
```

Rules can also be run in sequence, as a `Tuple` or in a [`Ruleset`](@ref)s.

DynamicGrids guarantees that:

- `modifyrule` is run once for every rule for every timestep.
    The result is passed to `applyrule`, but not retained after that.
- `applyrule` is run once for every rule, for every cell, for every timestep, unless an
    optimisation like `SparseOpt` is enable to skips empty cells.
- the output of running a rule for any cell does not affect the input of the
    same rule running anywhere else in the grid.
- rules later in the sequence are passed grid state updated by the earlier rules.
- masked areas and wrapped or removed boundary regions are updated between all rules and 
    timesteps.

## Multiple grids

The `NamedTuple` keys will match the grid keys in `R`, which is a type like 
`Tuple{:key1,:key1}`. Note the names are user-specified, and should never be fixed by a `Rule`.

Read grid names be retrieved from the type here as `R1` and `R2`, while write grids are `W1` and `W2`.

```julia
applyrule(data::SimData, rule::YourCellRule{Tuple{R1,R2},Tuple{W1,W2}}, state, I) where {R1,R2,W1,W2}
```

By default the output is written to the current cell in the specified `W` write grid/s.
`Rule`s writing to multiple grids, simply return a `Tuple` in the order specified by
the `W` type params.

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
- Use a graphical profiler, like ProfileView.jl, to check your rules overall
    performance when run with `sim!`.
"""
abstract type Rule{R,W} end

# Rules are also traits - because we use wrapper rules
ruletype(::Rule) = Rule

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
    RuleWrapper <: Rule

A `Rule` that wraps other rules, altering their behaviour or how they are run.
"""
abstract type RuleWrapper{R,W} <: Rule{R,W} end

"""
    Cellrule <: Rule

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
function applyrule(data::SimData, rule::YourCellRule{R,W}, state, I) where {R,W}
    state * 2
end
```

As the index `I` is provided in `applyrule`, you can use it to look up [`Aux`](@ref) data. 
"""
abstract type CellRule{R,W} <: Rule{R,W} end

ruletype(::CellRule) = CellRule

"""
    SetRule <: Rule

Abstract supertype for rules that manually write to the grid in some way.

These must define methods of [`applyrule!`](@ref).
"""
abstract type SetRule{R,W} <: Rule{R,W} end

ruletype(::SetRule) = SetRule

"""
    SetCellRule <: Rule

Abstract supertype for rules that can manually write to any cells of the
grid that they need to.

`SetCellRule` is applied with a method like this, that simply adds 1 to the current cell:

```julia
function applyrule!(data::SimData, rule::YourSetCellRule, state, I)
    add!(data, 1, I...)
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
function applyrule(data, rule::YourSetCellRule{R,Tuple{W1,W2}}, state, I) where {R,W1,W2}
     add!(data[W1], 1, I...)
     add!(data[W2], 2, I...)
     return nothing
end
```

DynamicGrids guarantees that:

- values written to anywhere on the grid do not affect other cells in
    the same rule at the same timestep.
- values written to anywhere on the grid are available to the next rule in the
    sequence, or the next timestep.
- if atomic operators are always used, race conditions will not occur on any hardware.
"""
abstract type SetCellRule{R,W} <: SetRule{R,W} end

ruletype(::SetCellRule) = SetCellRule

"""
    NeighborhoodRule <: Rule

A Rule that only accesses a neighborhood centered around the current cell.
`NeighborhoodRule` is applied with the method:

```julia
applyrule(data::SimData, rule::YourNeighborhoodRule, state, I::Tuple{Int,Int})
```

`NeighborhoodRule` must have a `neighborhood` method or field, that holds
a [`Neighborhood`](@ref) object. `neighbors(rule)` returns an iterator
over the surrounding cell pattern defined by the `Neighborhood`.

For each cell in the grids the neighborhood buffer will be updated
for use in the `applyrule` method, managed to minimise array reads.

This allows memory optimisations and the use of high-perforance routines on the
neighborhood buffer. It also means that and no bounds checking is required in
neighborhood code.

For neighborhood rules with multiple read grids, the first is always
the one used for the neighborhood, the others are passed in as additional
state for the cell. Any grids can be written to, but only for the current cell.
"""
abstract type NeighborhoodRule{R,W} <: Rule{R,W} end

ruletype(::NeighborhoodRule) = NeighborhoodRule

neighbors(rule::NeighborhoodRule) = neighbors(neighborhood(rule))
neighborhood(rule::NeighborhoodRule) = rule.neighborhood
offsets(rule::NeighborhoodRule) = offsets(neighborhood(rule))
kernel(rule::NeighborhoodRule) = kernel(neighborhood(rule))
kernelproduct(rule::NeighborhoodRule) = kernelproduct(neighborhood(rule))
positions(rule::NeighborhoodRule, args...) = positions(neighborhood(rule), args...)
neighborhoodkey(rule::NeighborhoodRule{R,W}) where {R,W} = R
# The first argument is for the neighborhood grid
neighborhoodkey(rule::NeighborhoodRule{<:Tuple{R1,Vararg},W}) where {R1,W} = R1
_buffer(rule::NeighborhoodRule) = _buffer(neighborhood(rule))
@inline _setbuffer(rule::NeighborhoodRule, _buffer) =
    @set rule.neighborhood = _setbuffer(rule.neighborhood, _buffer)
radius(rule::NeighborhoodRule, args...) = radius(neighborhood(rule))

"""
    SetNeighborhoodRule <: SetRule

A [`SetRule`](@ref) that only writes to its neighborhood, and does not need to bounds-check.

[`positions`](@ref) and [`offsets`](@ref) are useful iterators for modifying
neighborhood values. 

`SetNeighborhoodRule` rules must return a [`Neighborhood`](@ref) object from the function 
`neighborhood(rule)`. By default this is `rule.neighborhood`. If this property exists, 
no interface methods are required.
"""
abstract type SetNeighborhoodRule{R,W} <: SetRule{R,W} end

ruletype(::SetNeighborhoodRule) = SetNeighborhoodRule

neighborhood(rule::SetNeighborhoodRule) = rule.neighborhood
offsets(rule::SetNeighborhoodRule) = offsets(neighborhood(rule))
kernel(rule::SetNeighborhoodRule) = kernel(neighborhood(rule))
positions(rule::SetNeighborhoodRule, args...) = positions(neighborhood(rule), args...)
radius(rule::SetNeighborhoodRule, args...) = radius(neighborhood(rule))
neighborhoodkey(rule::SetNeighborhoodRule{R,W}) where {R,W} = R
neighborhoodkey(rule::SetNeighborhoodRule{<:Tuple{R1,Vararg},W}) where {R1,W} = R1


"""
    SetGridRule <: Rule

A `Rule` applies to whole grids. This is used for operations that don't benefit from
having neighborhood buffering or looping over the grid handled for them, or any specific
optimisations. Best suited to simple functions like `rand!(grid)` or using convolutions
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

ruletype(::SetGridRule) = SetGridRule

"""
    SetGrid{R,W}(f)

Apply a function `f` to fill whole grid/s.

## Example

This example sets grid `a` to equal grid `b`:

```julia
rule = SetGrid{:a,:b}() do a, b
    b .= a
end
```
"""
struct SetGrid{R,W,F} <: SetGridRule{R,W}
    "Function to apply to the read values"
    f::F
end
SetGrid{R,W}(; kw...) where {R,W} = _nofunctionerror(SetGrid)

@inline function applyrule!(data, rule::SetGrid{R,W}) where {R,W}
    let data = data, rule=rule
        read = map(r -> source(getindex(data, r)), _asiterable(R))
        write = map(w -> source(getindex(data, w)), _asiterable(W))
        rule.f(read..., write...)
    end
end


"""
    Call <: CellRule

    Cell(f)
    Cell{R,W}(f)

A [`CellRule`](@ref) that applies a function `f` to the `R` grid value, 
or `Tuple` of values, and returns the `W` grid value or `Tuple` of values.

Especially convenient with `do` notation.

## Example

Double the cell value in grid `:a`:

```julia
simplerule = Cell{Tuple{:a}() do a
    2a
end
```

If you need to use multiple grids (a and b), use the `R`
and `W` type parameters. If you want to use external variables,
wrap the whole thing in a `let` block, for performance. This
rule sets the new value of `b` to the value of `a` to `b` times scalar `y`:

```julia
rule = let y = y
    rule = Cell{Tuple{:a,:b},:b}() do (a, b)
        a + b * y
    end
end
```
"""
struct Cell{R,W,F} <: CellRule{R,W}
    "Function to apply to the R grid values"
    f::F
end
Cell{R,W}(; kw...) where {R,W} = _nofunctionerror(Cell)

@inline function applyrule(data, rule::Cell, read, I)
    let rule=rule, read=read
        rule.f(read)
    end
end

"""
    Neighbors <: NeighborhoodRule

    Neighbors(f, neighborhood=Moor(1))
    Neighbors{R,W}(f, neighborhood=Moore())

A [`NeighborhoodRule`](@ref) that receives a [`Neighborhood`](@ref) object 
for the first `R` grid, followed by the cell value/s for the required grids, 
as with [`Cell`](@ref).

Returned value(s) are written to the `W` grid/s.

As with all [`NeighborhoodRule`](@ref), you do not have to check bounds at
grid edges, that is handled for you internally.

Using [`SparseOpt`](@ref) may improve neighborhood performance
when a specific value (often zero) is common and can be safely ignored.

## Example

Runs the game of life on grid `:a`:

```julia
const sum_states = (0, 0, 1, 0, 0, 0, 0, 0, 0), 
                   (0, 0, 1, 1,  0, 0, 0, 0, 0)
life = Neighbors{:a}(Moore(1)) do hood, a
    sum_states[a + 1][sum(hood) + 1]
end
```
"""
struct Neighbors{R,W,F,N} <: NeighborhoodRule{R,W}
    "Function to apply to the neighborhood and R grid values"
    f::F
    "Defines the neighborhood of cells around the central cell"
    neighborhood::N
end
Neighbors{R,W}(; kw...) where {R,W} = _nofunctionerror(Neighbors)
Neighbors{R,W}(f; neighborhood=Moore(1)) where {R,W} =
    Neighbors{R,W}(f, neighborhood)

@inline function applyrule(data, rule::Neighbors, read, I)
    let rule=rule, hood=neighborhood(rule), read=read
        rule.f(hood, read)
    end
end

"""
    SetCell <: SetCellRule

    SetCell(f)
    SetCell{R,W}(f)

A [`SetCellRule`](@ref) to manually write to the array where you need to.
`f` is passed a [`SimData`](@ref) object, the grid state or `Tuple` of grid 
states for the cell and a `Tuple{Int,Int}` index of the current cell.

To update the grid, you can use: [`add!`](@ref), [`sub!`](@ref) for `Number`,
and [`and!`](@ref), [`or!`](@ref) for `Bool`. These methods safely combined
writes from all grid cells - directly using `setindex!` would cause bugs.

## Example

Choose a destination cell and if it is in the grid, update it based on the 
state of both grids:

```julia
rule = SetCell{Tuple{:a,:b},:b}() do data, (a, b), I 
    dest = your_dest_pos_func(I)
    if isinbounds(data, dest)
        destval = your_dest_val_func(a, b)
        add!(data[:b], destval, dest...)
    end
end
```
"""
struct SetCell{R,W,F} <: SetCellRule{R,W}
    "Function to apply to data, index and read grid values"
    f::F
end
SetCell{R,W}(; kw...) where {R,W} = _nofunctionerror(Set)

@inline function applyrule!(data, rule::SetCell, read, I)
    let data=data, rule=rule, read=read, I=I
        rule.f(data, read, I)
    end
end


"""
    SetNeighbors <: SetNeighborhoodRule

    SetNeighbors(f, neighborhood=Moor(1))
    SetNeighbors{R,W}(f, neighborhood=Moor(1))

A [`SetCellRule`](@ref) to manually write to the array with the specified
neighborhood. Indexing outside the neighborhood is undefined behaviour.

Function `f` is passed four arguments: a [`SimData`](@ref) object, the specified
[`Neighborhood`](@ref) object, the grid state or `Tuple` of grid states for the cell, 
and the `Tuple{Int,Int}` index of the current cell.

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

This example adds a value to all neighbors:

```julia
rule = SetNeighbors{:a}() do data, neighborhood, a, I
    add_to_neighbors = your_func(a)
    for pos in positions(neighborhood)
        add!(data[:b], add_to_neighbors, pos...)
    end
end
```
"""
struct SetNeighbors{R,W,F,N} <: SetNeighborhoodRule{R,W}
    "Function to apply to the data, index and R grid values"
    f::F
    "The neighborhood of cells around the central cell"
    neighborhood::N
end
SetNeighbors{R,W}(; kw...) where {R,W} = _nofunctionerror(SetNeighbors)
SetNeighbors{R,W}(f; neighborhood=Moore(1)) where {R,W} = SetNeighbors{R,W}(f, neighborhood)

@inline function applyrule!(data, rule::SetNeighbors, read, I)
    let data=data, hood=neighborhood(rule), rule=rule, read=read, I=I
        rule.f(data, hood, read, I)
    end
end


"""
    Convolution <: NeighborhoodRule

    Convolution(kernel::AbstractArray)
    Convolution{R,W}(kernel::AbstractArray)

A [`NeighborhoodRule`](@ref) that runs a convolution kernel over the grid.

`kernel` must be a square matrix.

## Performance

Small radius convolutions in DynamicGrids.jl will be comparable or even faster than using
DSP.jl or ImageConvolutions.jl. As the radius increases these packages will be a lot faster.

But `Convolution` is convenient to chain into a simulation, and combined with some other
rules. It should perform reasonably well with all but very large kernels.

## Example

```julia 
rule = Convolution([0.05 0.1 0.05; 0.1 0.4 0.1; 0.05 0.1 0.05])
```
"""
struct Convolution{R,W,N} <: NeighborhoodRule{R,W}
    "The neighborhood of cells around the central cell"
    neighborhood::N
end
Convolution{R,W}(A::AbstractArray) where {R,W} = Convolution{R,W}(Kernel(SMatrix{size(A)...}(A)))
Convolution{R,W}(; neighborhood) where {R,W} = Convolution{R,W}(neighborhood)

@inline applyrule(data, rule::Convolution, read, I) = kernelproduct(neighborhood(rule))

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
