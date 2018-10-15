" A matrix wrapper that allows min and max values other than zero and one. "
struct ScalableMatrix{T,M} <: AbstractMatrix{T}
    data::T
    min::M
    max::M
end

length(a::ScalableMatrix) = length(a.data)
size(a::ScalableMatrix) = size(a.data)
firstindex(a::ScalableMatrix) = firstindex(a.data)
lastindex(a::ScalableMatrix) = lastindex(a.data)
Base.@propagate_inbounds getindex(a::ScalableMatrix, I...) = getindex(a.data, I...)
Base.@propagate_inbounds setindex!(a::ScalableMatrix, x, I...) = setindex!(a.data, x, I...)
push!(a::ScalableMatrix, x) = push!(a.data, x)
show(io::IO, a::ScalableMatrix) = begin
    print(io, "min: ", a.min, " max: ", a.max, " ")
    show(io, a.data)
end

scale_frame(a::ScalableMatrix) = (a.data .- a.min) ./ (a.max - a.min)
