using DynamicGrids, Test
using DynamicGrids: normaliseframe, isshowable, curframe, allocateframes!, storeframe!, simdata

init = [10.0 11.0;
        0.0   5.0]

output = ArrayOutput(init, false)
ruleset = Ruleset(; minval=0.0, maxval=10.0)

@test curframe(output, 5) == 5 
@test isshowable(output, 5) == false

update = [8.0 15.0;
          2.0  9.0]

@test length(output) == 1
push!(output, update)
@test length(output) == 2
@test output[2] == update

allocateframes!(output, init, 3:5)

@test length(output) == 5
@test firstindex(output) == 1
@test lastindex(output) == 5
@test size(output) == (5,)

@test output[3] != update
data = simdata(ruleset, update)
storeframe!(output, data, 3)
@test output[3] == update

output2 = ArrayOutput(output, false)
@test length(output2) == 5
@test output2[3] == update

normed = normaliseframe(ruleset, output[1])
@test normed == [1.0 1.0
                 0.0 0.5]
