using DynamicGrids, Test
import DynamicGrids: applyrule, applyinteraction!

struct Double <: AbstractCellRule end
applyrule(rule::Double, data, state, index) = state * 2

struct Squared <: AbstractCellRule end
applyrule(rule::Squared, data, state, index) = state^2

struct Product{Keys} <: AbstractInteraction{Keys} end
applyinteraction!(::Product, data, (state1, state2), index) = 
    data[1][index...] = state1 * state2 

struct Swap{Keys} <: AbstractInteraction{Keys} end
applyinteraction!(::Swap, data, (state1, state2), index) = begin
    data[1][index...] = state2
    data[2][index...] = state1
end

preyarray = [0 0 1; 0 1 1]
predatorarray = [0 0 0; 0 0 1]

init = (prey = preyarray, predator = predatorarray)

output = ArrayOutput(init, 5)
ruleset = MultiRuleset(rulesets=(prey=Ruleset(Squared()), 
                                 predator=Ruleset(Squared())
                                ),
                       interactions=(Swap{(:prey, :predator)}(), Product{(:prey, :predator)}())
                      )
# ruleset.rulesets
# init

# msd = DynamicGrids.MultiSimData(map((rs, i) -> SimData(rs, i, 1), ruleset.rulesets, init),
             # DynamicGrids.interactions(ruleset))
# typeof(msd)

# Display ideas
# output(init; show=Combine((:prey, :predator), (:red, :green)))
# output(init; show=Layout([:prey :predator; :superpredator nothing]))

sim!(output, ruleset; init=init)
