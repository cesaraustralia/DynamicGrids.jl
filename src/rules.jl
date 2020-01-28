"""
A rule contains all the information required to run a rule in a cellular
simulation, given an initial array. Rules can be chained together sequentially.

The output of the rule for an Rule is allways written to the current cell in the grid.
"""
abstract type Rule end

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


"""
PartialRule is for rules that manually write to whichever cells of the grid
that they choose, instead of updating every cell with their output.

Updates to the destination array (`dest(data)`) must be performed manually, while
the source array can be accessed with `source(data)`.

The dest array is copied from the source prior to running the `applyrule!` method.
"""
abstract type PartialRule <: Rule end

"""
A Rule That only accesses a neighborhood, defined by its radius distance from the current cell.

For each cell a neighborhood buffer will be populated containing the neighborhood cells,
and passed to `applyrule` as an extra argmuent: `applyrule(rule, data, state, index, buffer)`.
This allows memory optimisations and the use of BLAS routines on the neighborhood buffer
for [`RadialNeighborhood`](@ref). It also means that and no bounds checking is required in
neighborhood code, a major performance gain.

`NeighborhoodRule` should read only from the state variable and the neighborhood
buffer array. The return value is written to the central cell for the next grid frame.
"""
abstract type NeighborhoodRule <: Rule end

neighborhood(rule::NeighborhoodRule) = rule.neighborhood

"""
A Rule that only writes to its neighborhood, defined by its radius distance from the current point.
TODO: should this exist?

Custom PartialNeighborhood rules must return their radius with a `radius()` method.
"""
abstract type PartialNeighborhoodRule <: PartialRule end

neighborhood(rule::PartialNeighborhoodRule) = rule.neighborhood

"""
A Rule that only writes and accesses a single cell: its return value is the new
value of the cell. This limitation can be useful for performance optimisations.

Accessing the `data.source` and `data.dest` arrays directly is not guaranteed to have
correct results, and should not be done.
"""
abstract type CellRule <: Rule end
