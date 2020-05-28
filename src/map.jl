"""
    Cell{R,W}(f)
    Cell(f; read, write)

A [`CellRule`](@ref) that applies a function `f` to the
`read` grid cells and returns the `write` cells.

Especially convenient with `do` notation.

## Example

Set the cells of grid `:c` to the sum of `:a` and `:b`.
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
    f::F    | true    | "Function to apply to the read values"
end
Cell(f; read=:_default_, write=read) = Cell{read,write}(f)

@inline applyrule(rule::Cell, data::SimData, read, index) =
    let (rule, read) = (rule, read)
        rule.f(astuple(rule, read)...)
    end
const Map = Cell

astuple(rule::Rule, read) = astuple(readkeys(rule), read)
astuple(::Tuple, read) = read
astuple(::Symbol, read) = (read,)

"""
Neighbors(f; read=:_default_, write=read, neighborhood=RadialNeighborhood()) 
    Neighbors{R,W}(f)

A [`NeighborhoodRule`](@ref) that receives a neighbors object for the first 
`read` grid and the passed in neighborhood, followed by the cell values for 
the reqquired grids, as with [`Cell`](@ref).

Returned value(s) are written to the `write`/`W` grid.

## Example

```julia
rule = let x = 10
    Neighbors{Tuple{:a,:b},:b}() do hood, a, b
        data[:b][index...] = a + b^x
    end
end
```
"""
@flattenable @description struct Neighbors{R,W,F,N} <: NeighborhoodRule{R,W}
    # Field         | Flatten | Description
    f::F            | true    | "Function to apply to the neighborhood and read values"
    neighborhood::N | true    | ""
end
Neighbors(f; read=:_default_, write=read, neighborhood=RadialNeighborhood{1}()) = 
    Neighbors{read,write}(f, neighborhood)

@inline applyrule(rule::Neighbors, data::SimData, read, index) =
    let hood=neighborhood(rule), rule=rule, read=astuple(rule, read)
        rule.f(hood, read...)
    end

"""
    Manual(f; read=:_default_, write=read) 
    Manual{R,W}(f)

A [`ManualRule`](@ref) to manually write to the array where you need to. 
`f` is passed an indexable `data` object, and the index of the current cell, 
followed by the requirement grid values for the index.

## Example

```julia
rule = let x = 10
    Manual{Tuple{:a,:b},:b}() do data, index, a, b
        data[:b][index...] = a + b^x
    end
end
```
"""
@flattenable @description struct Manual{R,W,F} <: ManualRule{R,W}
    # Field | Flatten | Description
    f::F    | true    | "Function to apply to the data, index and read values"
end
Manual(f; read=:_default_, write=read) = Manual{read,write}(f)

@inline applyrule!(rule::Manual, data::SimData, read, index) =
    let data=data, index=index, rule=rule, read=astuple(rule, read)
        rule.f(data, index, read...)
    end
