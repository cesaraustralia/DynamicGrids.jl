# Atomic opterations

const atomic_ops = ((:add!, :+), (:sub!, :-), (:min!, :min), (:max!, :max),
                    (:and!, :&), (:or!, :|), (:xor!, :xor))

# Methods for writing to a WritableGridData grid from . These are
# associative and commutative so that write order does not affect the result.
for (f, op) in atomic_ops
    @eval begin
        @propagate_inbounds ($f)(d::AbstractSimData, x, I...) = ($f)(first(d), x, I...)
        @propagate_inbounds ($f)(d::WritableGridData, x, I...) = ($f)(proc(d), d, x, I...)
        @propagate_inbounds function ($f)(::SingleCPU, d::WritableGridData, x, I...)
            @boundscheck checkbounds(dest(d), I...)
            @inbounds _setdeststatus!(d, x, I...)
            @inbounds dest(d)[I...] = ($op)(dest(d)[I...], x)
        end
        @propagate_inbounds function ($f)(proc::ThreadedCPU, d::WritableGridData, x, I...)
            lock(proc)
            ($f)(SingleCPU(), d, x, I...)
            unlock(proc)
        end
    end
end
