"""
    AbstractKernelNeighborhood <: Neighborhood

Abstract supertype for kernel neighborhoods.

These can wrap any other neighborhood object, and include a kernel of
the same length and positions as the neighborhood.
"""
abstract type AbstractKernelNeighborhood{R,N,L,H} <: Neighborhood{R,N,L} end

neighbors(hood::AbstractKernelNeighborhood) = neighbors(neighborhood(hood))
offsets(::Type{<:AbstractKernelNeighborhood{<:Any,<:Any,<:Any,H}}) where H = offsets(H)
positions(hood::AbstractKernelNeighborhood, I::Tuple) = positions(neighborhood(hood), I)

"""
    kernel(hood::AbstractKernelNeighborhood) => iterable

Returns the kernel object, an array or iterable matching the length
of the neighborhood.
"""
function kernel end
kernel(hood::AbstractKernelNeighborhood) = hood.kernel

"""
    neighborhood(x) -> Neighborhood

Returns a neighborhood object.
"""
function neighborhood end
neighborhood(hood::AbstractKernelNeighborhood) = hood.neighborhood

"""
    kernelproduct(hood::AbstractKernelNeighborhood)
    kernelproduct(hood::Neighborhood, kernel)

Take the vector dot produce of the neighborhood and the kernel,
without recursion into the values of either. Essentially `Base.dot`
without recursive calls on the contents, as these are rarely what is
intended.
"""
function kernelproduct(hood::AbstractKernelNeighborhood)
    kernelproduct(neighborhood(hood), kernel(hood))
end
function kernelproduct(hood::Neighborhood{<:Any,<:Any,L}, kernel) where L
    sum = zero(first(hood))
    @simd for i in 1:L
        @inbounds sum += hood[i] * kernel[i]
    end
    return sum
end
function kernelproduct(hood::Window{<:Any,<:Any,L}, kernel) where L
    sum = zero(first(hood))
    @simd for i in 1:L
        @inbounds sum += _window(hood)[i] * kernel[i]
    end
    return sum
end

"""
    Kernel <: AbstractKernelNeighborhood

    Kernel(neighborhood, kernel)

Wrap any other neighborhood object, and includes a kernel of
the same length and positions as the neighborhood.
"""
struct Kernel{R,N,L,H,K} <: AbstractKernelNeighborhood{R,N,L,H}
    neighborhood::H
    kernel::K
end
Kernel(A::AbstractMatrix) = Kernel(Window(A), A)
function Kernel(hood::H, kernel::K) where {H<:Neighborhood{R,N,L},K} where {R,N,L}
    length(hood) == length(kernel) || _kernel_length_error(hood, kernel)
    Kernel{R,N,L,H,K}(hood, kernel)
end
function Kernel{R,N,L}(hood::H, kernel::K) where {R,N,L,H<:Neighborhood{R,N,L},K}
    Kernel{R,N,L,H,K}(hood, kernel)
end

function _kernel_length_error(hood, kernel)
    throw(ArgumentError("Neighborhood length $(length(hood)) does not match kernel length $(length(kernel))"))
end

function setwindow(n::Kernel{R,N,L,<:Any,K}, win) where {R,N,L,K}
    hood = setwindow(neighborhood(n), win)
    return Kernel{R,N,L,typeof(hood),K}(hood, kernel(n))
end

