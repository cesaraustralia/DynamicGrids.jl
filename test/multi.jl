using DynamicGrids, Test
import DynamicGrids: applyrule, applyinteraction!, Interaction

struct Double <: AbstractCellRule end
applyrule(rule::Double, data, state, index) = state * 2

struct Flat <: AbstractCellRule end
applyrule(rule::Flat, data, state, index) = state

struct Predation{Keys} <: Interaction{Keys} end
Predation(; prey=:prey, predator=:predator) = Predation{(prey, predator)}()
applyinteraction!(::Predation, data, (prey, predator), index) = begin
    caught = prey / 10
    conversion = 0.1
    data[1][index...] -= caught 
    data[2][index...] += caught * 0.1
end

preyarray = [10.0 20.0 10.0; 20.0 10.0 10.0]
predatorarray = [2.0 2.0 2.0; 2.0 2.0 1.0]

init = (prey = preyarray, predator = predatorarray)

output = ArrayOutput(init, 5)
rulesets=(prey=Ruleset(Double()), predator=Ruleset(Flat()))
interactions=((Predation(prey=:prey, predator=:predator),)) 
ruleset = MultiRuleset(rulesets=rulesets, interactions=interactions; init=init)

output = ArrayOutput(init, 5)
sim!(output, ruleset; init=init)


# ruleset.rulesets
# init

# msd = DynamicGrids.MultiSimData(map((rs, i) -> SimData(rs, i, 1), ruleset.rulesets, init),
             # DynamicGrids.interactions(ruleset))
# typeof(msd)

# Display ideas
# output(init; show=Combine((:prey, :predator), (:red, :green)))
# output(init; show=Layout([:prey :predator; :superpredator nothing]))
