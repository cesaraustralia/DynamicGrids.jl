"""
    CopyTo <: CellRule

    CopyTo{W}(from)
    CopyTo{W}(; from)

A simple rule that copies aux array slices to a grid over time.
This can be used for comparing simulation dynamics to aux data dynamics.
"""
struct CopyTo{W,F} <: CellRule{Tuple{},W}
    "An Aux or Grid key for data source or a single value"
    from::F
end
CopyTo(from) = CopyTo{DEFAULT_KEY}(from)
CopyTo(; from) = CopyTo{DEFAULT_KEY}(from)
CopyTo{W}(from) where W = CopyTo{W,typeof(from)}(from)
CopyTo{W}(; from) where W = CopyTo{W,typeof(from)}(from)

ConstructionBase.constructorof(::Type{<:CopyTo{W}}) where W = CopyTo{W}

DynamicGrids.applyrule(data, rule::CopyTo, state, I) = get(data, rule.from, I)
DynamicGrids.applyrule(data, rule::CopyTo{W}, state, I) where W <: Tuple =
    ntuple(i -> get(data, rule.from, I), length(_asiterable(W)))
