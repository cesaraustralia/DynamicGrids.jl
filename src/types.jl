"""
A rule contains all the information required to run a rule in a cellular
simulation, given an initial array. Rules can be chained together sequentially.

The output of the rule for an AbstractRule is allways written to the current cell in the grid.
"""
abstract type AbstractRule end

"""
AbstractPartialRule is for rules that manually write to whichever cells of the grid
that they choose, instead of updating every cell with their output.

Updates to the destination array (`dest(data)`) must be performed manually, while
the source array can be accessed with `source(data)`.

The dest array is copied from the source prior to running the `applyrule!` method.
"""
abstract type AbstractPartialRule <: AbstractRule end

"""
A Rule That only accesses a neighborhood, defined by its radius distance from the current cell.

For each cell a buffer will be populated containing the neighborhood cells, accessible with
`buffer(data)`. This allows memory optimisations and the use of BLAS routines on the neighborhood. 
It also means that and no bounds checking is required.

`AbstractNeighborhoodRule` must read only from the state variable and the 
neighborhood_buffer array, and never manually write to the `dest(data)` array. 
Its return value is allways written to the central cell.

Custom Neighborhood rules must return their radius with a `radius()` method.
"""
abstract type AbstractNeighborhoodRule <: AbstractRule end

"""
A Rule that only writes to its neighborhood, defined by its radius distance from the current point.
TODO: should this exist?

Custom PartialNeighborhood rules must return their radius with a `radius()` method.
"""
abstract type AbstractPartialNeighborhoodRule <: AbstractPartialRule end

"""
A Rule that only writes and accesses a single cell: its return value is the new
value of the cell. This limitation can be useful for performance optimisations.

Accessing the `data.source` and `data.dest` arrays directly is not guaranteed to have
correct results, and should not be done.
"""
abstract type AbstractCellRule <: AbstractRule end


"""
Singleton types for choosing the grid overflow rule used in
[`inbounds`](@ref). These determine what is done when a neighborhood
or jump extends outside of the grid.
"""
abstract type AbstractOverflow end

"Wrap cords that overflow boundaries back to the opposite side"
struct WrapOverflow <: AbstractOverflow end

"Remove coords that overflow boundaries"
struct RemoveOverflow <: AbstractOverflow end


abstract type AbstractRuleset end

"""
    Ruleset(rules...; init=nothing, overflow=RemoveOverflow(), cellsize=1, timestep=1)

A container for holding a sequence of AbstractRule, an init
array and other simulaiton details.
"""
mutable struct Ruleset{R,I,O<:AbstractOverflow,C<:Number,T<:Number,M} <: AbstractRuleset
    rules::R
    init::I
    overflow::O
    cellsize::C
    timestep::T
    min::M
    max::M
end
Ruleset(args...; init=nothing, overflow=RemoveOverflow(), cellsize=1, timestep=1, 
        min=nothing, max=nothing) = 
    Ruleset{typeof.((args, init, overflow, cellsize, timestep, min))...
           }(args, init, overflow, cellsize, timestep, min, max)
