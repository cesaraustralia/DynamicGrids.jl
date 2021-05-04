# Atomic opterations

const atomic_ops = ((:add!, :+), (:sub!, :-), (:min!, :min), (:max!, :max),
                    (:and!, :&), (:or!, :|), (:xor!, :xor))

# Methods for writing to a WritableGridData grid from . These are
# associative and commutative so that write order does not affect the result.
for (f, op) in atomic_ops
    @eval begin
        @propagate_inbounds ($f)(d::AbstractSimData, x, I...) = ($f)(first(d), x, I...)
        @propagate_inbounds ($f)(d::WritableGridData{<:Any,R}, x, I...) where R = ($f)(d, proc(d), x, I...)
        @propagate_inbounds function ($f)(d::WritableGridData{<:Any,R}, ::Processor, x, I...) where R
            @boundscheck checkbounds(dest(d), I...)
            @inbounds _setdeststatus!(d, x, I...)
            @inbounds dest(d)[I...] = ($op)(dest(d)[I...], x)
        end
        @propagate_inbounds function ($f)(
            d::WritableGridData{<:Any,R}, proc::Union{ThreadedCPU,CPUGPU}, x, I...
        ) where R
            lock(proc)
            ($f)(d, SingleCPU(), x, I...)
            unlock(proc)
        end
    end
end
