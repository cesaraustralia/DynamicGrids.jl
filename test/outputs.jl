using DynamicGrids, Test
using DynamicGrids: isshowable, gridindex, storegrid!, SimData

init = [10.0 11.0;
        0.0   5.0]

output = ArrayOutput(init)
ruleset = Ruleset(Life())

@test gridindex(output, 5) == 5 
@test isshowable(output, 5) == false

# Test pushing new frames to an output
update = [8.0 15.0;
          2.0  9.0]
@test length(output) == 1
push!(output, update)
@test length(output) == 2
@test output[2] == update

# Test creting a new output from an existing output
output2 = ArrayOutput(output)
@test length(output2) == 2
@test output2[2] == update
