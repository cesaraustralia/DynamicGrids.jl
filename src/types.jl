"""
A model contains all the information required to run a rule in a cellular
simulation, given an initialised array. Models can be chained together in any order.

The output of the rule for an AbstractModel is allways written to the current cell in the grid.
"""
abstract type AbstractModel end

"""
An abstract type for models that do not write to every cell of the grid.

Updates to the destination array (`data.dest`) must be performed manually. The destination array is 
copied from the source prior to running the rule! method, which can be quicker than writing each cell 
individually and potentially produce more succinct formulations.
"""
abstract type AbstractPartialModel <: AbstractModel end

"""
A Model That only accesses a neighborhood, defined by its radius distance from the current point. 

The models neighborhood_buffer field will be populated with a matrix containing the 
neighborhood cells, so that BLAS routines and other optimised matrix algebra may be performed
on the neighborhood, and no bounds checking is required. 

It must read only from the state variable and the neighborhood_buffer array, and never manually write to the 
`data.dest` array. Its return value is allways written to the central cell.
"""
abstract type AbstractNeighborhoodModel <: AbstractModel end

"""
A Model That only accesses a neighborhood, defined by its radius distance from the current point.

It must read only from the models neighborhood_buffer array, 
and manually write to the `data.dest` array.

Neighborhood models must return their neighborhood radius with a radius() method.
"""
abstract type AbstractPartialNeighborhoodModel <: AbstractPartialModel end

"""
A Model that only writes and accesses a single cell: its return value is the new 
value of the cell. This limitation can be useful for performance optimisations. 

Accessing the `data.source` and `data.dest` arrays directly is not guaranteed to have 
correct results, and should not be done.
"""
abstract type AbstractCellModel <: AbstractModel end


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



""" 
    Models(models...; init=[], cellsize=1, timestep=1)

A mutable container for holding chains immutable models, an initialisation
array and other simulaiton details.
"""
mutable struct Models{M,I,O<:AbstractOverflow,C<:Number,T<:Number} 
    models::M
    init::I
    overflow::O
    cellsize::C
    timestep::T
end
Models(args...; init=nothing, overflow=RemoveOverflow(), cellsize=1, timestep=1) = 
    Models{typeof.((args, init, overflow, cellsize, timestep))...}(args, init, overflow, cellsize, timestep)
