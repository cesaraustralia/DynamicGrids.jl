using Test, DynamicGrids, WGLMakie

# Just run it and check it ran every frame

output = MakieOutput(rand(Bool, 200, 300); tspan=1.0:3.0, ruleset=Ruleset()) do obj
    image!(Axis(obj.layout[1, 1]), obj.frame; interpolate=false, color=:inferno)
end

# Redirect stdout to collect the frame printing
original_stdout = stdout
rd, wr = redirect_stdout()

# We cant click the "run" button but we can run it manually
sim!(output; printframe=true);

# Test the output is what was expected
@test readline(rd) == "frame: 1, time: 1.0"
@test readline(rd) == "frame: 2, time: 2.0"
@test readline(rd) == "frame: 3, time: 3.0"

redirect_stdout(original_stdout)
