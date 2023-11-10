# Makie Output
mutable struct MakieOutput{T,Fr<:AbstractVector{T},E,GC,RS<:Ruleset,Fi,A,PM,TI} <: GraphicOutput{T,Fr}
    frames::Fr
    running::Bool 
    extent::E
    graphicconfig::GC
    ruleset::RS
    fig::Fi
    axis::A
    frame_obs::PM
    t_obs::TI
end
MakieOutput(args...; kw...) = error("Run `using GLMakie` or `using WGLMakie` to use MakieOutput") 
