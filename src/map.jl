"""
    Map{R,W}(f)
    Map(f; read, write)

A [`CellRule`](@ref) that applies a function `f` to the
`read` grid cells and returns the `write` cells.

Especially convenient with `do` notation.

## Example

Set the cells of grid `:c` to the sum of `:a` and `:b`.
```julia
rule = Map{Tuple{:a,:b},:c}() do a, b
    a + b 
end
```
"""
@description @flattenable struct Map{R,W,F} <: CellRule{R,W}
    # Field | Flatten | Description
    f::F    | false   | "Function to apply to the target values"
end
Map(f; read, write) = Map{read,write}(f)

@inline applyrule(rule::Map{R,W}, data::SimData, read, index) where {R<:Tuple,W} = begin
    let (rule, read) = (rule, read)
        rule.f(read...)
    end
end
@inline applyrule(rule::Map{R,W}, data::SimData, read, index) where {R,W} = begin
    let (rule, read) = (rule, read)
        rule.f(read)
    end
end
