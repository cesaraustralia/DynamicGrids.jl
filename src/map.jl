"""
A [`CellRule`](@ref) that applies a function `f` to the
`read` grid cells and returns the `write` cells.

## Example

"""
@description @flattenable struct Map{R,W,F} <: CellRule{R,W}
    # Field | Flatten | Description
    f::F    | false   | "Function to apply to the target values"
end
"""
    Map(f; read, write)

Map function f with cell values from read grid(s), write grid(s)
"""
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
