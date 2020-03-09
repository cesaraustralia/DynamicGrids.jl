# abstract type PartialRule <: Rule end


"""
A rule contains all the information required to run a rule in a 
simulation, given an initial array. Rules can be chained together sequentially.

By default the output of the rule for a Rule is automatically written to the current 
cell in the grid.

Rules are applied to the grid using the [`applyrule`](@ref) method.
"""
abstract type Rule{R,W} end

"""
Default constructor for all rules. 
"""
(::Type{T})(args...) where T<:Rule = T{:_default_,:_default_}(args...) 

show(io::IO, rule::R) where R <: Rule = begin
    indent = get(io, :indent, "")
    printstyled(io, indent, Base.nameof(typeof(rule)); color=:red)
    if nfields(rule) > 0
        printstyled(io, " :\n"; color=:red)
        for fn in fieldnames(R)
            if fieldtype(R, fn) <: Union{Number,Symbol,String}
                println(io, indent, "    ", fn, " = ", repr(getfield(rule, fn)))
            else
                # Avoid printing arrays etc. Just show the type.
                println(io, indent, "    ", fn, " = ", fieldtype(R, fn))
            end
        end
    end
end

@generated Base.keys(rule::Rule{R,W}) where {R,W} =
    Expr(:tuple, QuoteNode.(union(_asiterable(W), _asiterable(R)))...)
    
writekeys(::Rule{R,W}) where {R,W} = W
@generated writekeys(::Rule{R,W}) where {R,W<:Tuple} =
    Expr(:tuple, QuoteNode.(W.parameters)...)

readkeys(::Rule{R,W}) where {R,W} = R
@generated readkeys(::Rule{R,W}) where {R<:Tuple,W} =
    Expr(:tuple, QuoteNode.(R.parameters)...)

_asiterable(x::Symbol) = (x,)
_asiterable(x::Type{<:Tuple}) = x.parameters

# Default constructor for just the Keys type param where all args have type parameters
(::Type{T})(args...) where T<:Rule{R,W} where {R,W} =
    T{typeof.(args)...}(args...)

# Define the constructor for generic rule reconstruction in Flatten.jl and Setfield.jl
ConstructionBase.constructorof(::Type{T}) where T<:Rule{R,W} where {R,W} =
    T{R,W}

show(io::IO, rule::I) where I <: Rule{R,W} where {R,W} = begin
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

For each cell a neighborhood buffer will be populated containing the neighborhood cells,
and passed to `applyrule` as an extra argmuent: `applyrule(rule, data, state, index, buffer)`.
This allows memory optimisations and the use of BLAS routines on the neighborhood buffer
for [`RadialNeighborhood`](@ref). It also means that and no bounds checking is required in
neighborhood code, a major performance gain.

NeighborhoodRule is applied with the method:

```julia
applyrule(rule::Life, data, state, index, buffer) =
```

`neighbors(buffer)` returns an iterator over the buffer that is generic to 
any neigborhood type - Custom shapes as well as square radial neighborhoods.

`NeighborhoodRule` should read only from the state variable and the neighborhood
buffer array. The return value is written to the central cell for the next grid frame.
"""
abstract type NeighborhoodRule{R,W,N} <: Rule{R,W} end

neighborhood(rule::NeighborhoodRule) = rule.neighborhood
neighborhoodkey(rule::NeighborhoodRule{R,W,N}) where {R,W,N} = N


"""
A Rule that only writes to its neighborhood, defined by its radius distance from the 
current point.

PartialNeighborhood rules must return their radius with a `radius()` method, although
by default this will be called on the result of `neighborhood(rule)`.

TODO: performance optimisations with a neighborhood buffer, 
simular to [`NeighborhoodRule`](@ref) but for writing.
"""
abstract type PartialNeighborhoodRule{R,W} <: PartialRule{R,W} end

neighborhood(rule::PartialRule) = rule.neighborhood


"""
A [`CellRule`](@ref) that applies a function `f` to the
`read` grid cells and returns the `write` cells.

## Example

"""
@description @flattenable struct Map{R,W,F} <: Rule{R,W}
    # Field | Flatten | Description
    f::F    | false   | "Function to apply to the target values"
end
"""
    Map(f; write, read)

    Map function f with cell values from read grid(s), write grid(s)
"""
Map{R,W}(f::F) where {R,W,F} = Map{R,W,F}(f)
Map(f; write, read) = Map{write,read}(f)

@generated applyrule!(rule::Map{R,W}, data, read, index) where {R,W} =
    if R <: Tuple
        :(rule.f(read...))
    else
        :(rule.f(read))
    end

