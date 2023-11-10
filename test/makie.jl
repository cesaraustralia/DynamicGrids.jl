using DynamicGrids
using WGLMakie

# Just run it

life = Life()
output = MakieOutput(rand(Bool, 200, 300); tspan=1:10, ruleset=Ruleset(life)) do layout, frame, t
    image!(Axis(layout[1, 1]), frame; interpolate=false, color=:inferno)
end

# We cant click the "run" button but we can run it manually
sim!(output, life; printframe=true)
