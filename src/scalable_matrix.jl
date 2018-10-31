" A matrix wrapper that allows min and max values other than zero and one. "
struct ScalableMatrix{T,M} <: AbstractMatrix{T}
    data::T
    min::M
    max::M
end

size(a::ScalableMatrix) = size(a.data)
Base.@propagate_inbounds getindex(a::ScalableMatrix, I...) = getindex(a.data, I...)
Base.@propagate_inbounds setindex!(a::ScalableMatrix, v, I...) = setindex!(a.data, v, I...)
firstindex(a::ScalableMatrix) = firstindex(a.data)
lastindex(a::ScalableMatrix) = lastindex(a.data)
length(a::ScalableMatrix) = length(a.data)
interate(a::ScalableMatrix) = interate(a.data)
axes(a::ScalableMatrix) = axes(a.data)
push!(a::ScalableMatrix, x) = push!(a.data, x)
IndexStyle(a::ScalableMatrix) = IndexStyle(a.data) 
show(io::IO, a::ScalableMatrix) = begin
    print(io, "min: ", a.min, " max: ", a.max, " ")
    show(io, a.data)
end

normalize_frame(a::ScalableMatrix) = (a.data .- a.min) ./ (a.max - a.min)
