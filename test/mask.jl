using DynamicGrids, Test

init = [1.0 4.0 7.0;
        2.0 5.0 8.0;
        3.0 6.0 9.0]

mask = Bool[0 1 0;
            0 1 1;
            1 1 0]

output = ArrayOutput(init, 2)

struct DoNothingRule <: AbstractRule end
DynamicGrids.applyrule(::DoNothingRule, data, state, args...) = state

rules = Ruleset(DoNothingRule(); init=init, mask=mask)

sim!(output, rules; tstop=2)

@test output[1] == [1.0 4.0 7.0;
                    2.0 5.0 8.0;
                    3.0 6.0 9.0]

@test output[2] == [0.0 4.0 0.0;
                    0.0 5.0 8.0;
                    3.0 6.0 0.0]
