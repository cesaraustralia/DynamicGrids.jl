using Adapt,
      CUDA,
      Flatten,
      KernelAbstractions

export CuGPU

struct CuGPU{X} <: Processor end
CuGPU() = CuGPU{32}()

Adapt.adapt_structure(to, x::Union{SimData,GridData,Rule}) =
    Flatten.modify(A -> adapt(to, A), x, CuArray, SArray)

proc_setup(::CuGPU, obj) = Flatten.modify(CuArray, obj, Array, SArray)

function copyto_output!(outgrid, grid, proc::CuGPU)
    src = adapt(Array, source(grid))
    copyto!(outgrid, CartesianIndices(outgrid), src, CartesianIndices(outgrid))
    return nothing
end

function maprule!(
    wgrids::Union{<:GridData{Y,X,R},Tuple{<:GridData{Y,X,R},Vararg}},
    simdata, ::CuGPU{N}, opt, args...
) where {Y,X,R,N}
    kernel! = cu_rule_kernel!(CUDADevice(),N)
    # kernel! = cu_rule_kernel!(KernelAbstractions.CPU(),1)
    kernel!(wgrids, simdata, args...; ndrange=gridsize(simdata)) |> wait
end
# For method ambiguity
function maprule!(
    wgrids::Union{<:GridData{Y,X,R},Tuple{<:GridData{Y,X,R},Vararg}},
    simdata, proc::CuGPU, opt, rule::NeedsBuffer, args...
) where {Y,X,R}
    grid = simdata[neighborhoodkey(rule)]
    _maybecopystatus!(grid, opt)
    mapneighborhoodrule!(wgrids, simdata, grid, proc, opt, rule, args...)
    return nothing
end

@inline function mapneighborhoodrule!(
    wgrids, simdata, grid::GridData{Y,X,R}, proc::CuGPU{N}, opt, args...
) where {Y,X,R,N}
    kernel! = cu_neighborhood_kernel!(CUDADevice(),N)
    # kernel! = cu_neighborhood_kernel!(KernelAbstractions.CPU(),1)
    # n = indtoblock.(gridsize(simdata), 4r) .- 1
    n = gridsize(simdata) .- 1
    kernel!(wgrids, simdata, grid, opt, args..., ndrange=n) |> wait
    return nothing
end

@kernel function cu_neighborhood_kernel!(
    wgrids, data, grid::GridData{Y,X,R}, opt, rule::NeedsBuffer, args...
) where {Y,X,R}
    I, J = @index(Global, NTuple) 
    src = parent(source(grid))
    @inbounds buf = view(src, I:I+2R, J:J+2R)
    bufrule = setbuffer(rule, buf)
    rule_kernel!(wgrids, data, bufrule, args..., I, J)
    nothing
end

# Kernels that run for every cell
@kernel function cu_rule_kernel!(wgrids, simdata, rule::Rule, rkeys, rgrids, wkeys)
    i, j = @index(Global, NTuple)
    readval = readgrids(rkeys, rgrids, i, j)
    writeval = applyrule(simdata, rule, readval, (i, j))
    writegrids!(wgrids, writeval, i, j)
    nothing
end
# Kernels that run for every cell
@kernel function cu_rule_kernel!(wgrids, simdata, rule::ManualRule, rkeys, rgrids, wkeys)
    i, j = @index(Global, NTuple)
    readval = readgrids(rkeys, rgrids, i, j)
    applyrule!(simdata, rule, readval, (i, j))
    nothing
end

function maybemask!(wgrid::WritableGridData{Y,X}, proc::GPU, mask::AbstractArray) where {Y,X}
    # TODO
end


# @kernel function applyrule_kernel!(
#     simdata::SimData, grid::GridData{Y,X,1}, rule::NeighborhoodRule,
#     rkeys, rgrids, wkeys, wgrids, src, dst
# ) where {Y,X}
#     gi, gj = @index(Group, NTuple)
#     i, j = @index(Local,  NTuple)
#     N = @uniform groupsize()[1]
#     M = @uniform groupsize()[2]
#     # +1 to avoid bank conflicts on shared memory
#     tile = @localmem eltype(src) 8, 8
#     for n in 1:4 
#         b = ((i - 1) & 1)
#         k = 4b + n
#         l = 2j + b - 1
#         @inbounds tile[k, l] = src[(gi-1) * N + k, (gi-1) * N + l]
#     end
#     @synchronize
#     # Manually calculate global indexes
#     # Later on we need to pivot the group index
#     I = (gi-1) * N + i
#     J = (gj-1) * M + j
#     @inbounds buf = view(tile, i:i+2, j:j+2)
#     bufrule = setbuffer(rule, buf)
#     readval = readgrids(rkeys, rgrids, I, J)
#     writeval = applyrule(simdata, bufrule, readval, (I, J))
#     writegrids!(wgrids, writeval, I, J)
#     nothing
# end

for (f, op) in atomic_ops
    atomic_f = Symbol(:atomic_, f)
    @eval begin
        @propagate_inbounds function ($f)(::CuGPU, d::WritableGridData{Y,X,R}, x, I...) where {Y,X,R}
            A = parent(dest(d))
            i = Base._to_linear_index(A, (I .+ R)...)
            ($f)(A, i)
        end
        @propagate_inbounds function ($f)(A::CUDA.CuDeviceArray, x, i) where {Y,X,R}
            ($atomic_f)(pointer(A, i), x)
        end
    end
end
