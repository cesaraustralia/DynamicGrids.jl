using DynamicGrids, Test

init = [0.0 4.0 0.0
        0.0 5.0 8.0
        3.0 6.0 0.0]

mask = Bool[0 1 0
            0 1 1
            1 1 0]

struct AddOneRule{R,W} <: Rule{R,W} end
DynamicGrids.applyrule(::AddOneRule, data, state, args...) = state + 1

rules = Ruleset(AddOneRule{:_default_,:_default_}(); init=init, mask=mask)

output = ArrayOutput(init, 3)
sim!(output, rules; tspan=(1, 3))

@test output[1] == [0.0 4.0 0.0
                    0.0 5.0 8.0
                    3.0 6.0 0.0]
@test output[2] == [0.0 5.0 0.0
                    0.0 6.0 9.0
                    4.0 7.0 0.0]
@test output[3] == [0.0 6.0 0.0
                    0.0 7.0 10.0
                    5.0 8.0 0.0]
