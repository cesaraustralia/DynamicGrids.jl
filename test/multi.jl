using DynamicGrids, Test
import DynamicGrids: applyrule, applyinteraction!, applyinteraction,  Interaction

struct Double <: AbstractCellRule end
applyrule(rule::Double, data, state, index) = state * 2

struct Predation{Keys} <: Interaction{Keys} end
Predation(; prey=:prey, predator=:predator) = Predation{(prey, predator)}()
applyinteraction(::Predation, data, (prey, predators), index) = begin
    caught = prey * 0.02 * predators
    conversion = 0.2
    mortality = 0.1
    max(prey - caught, zero(prey)), predators + caught * 0.1 - predators * mortality
end

preyarray = rand(300, 300) .* 20
predatorarray = rand(300, 300) .* 2 
init = (prey=preyarray, predator=predatorarray)

output = ArrayOutput(init, 20)
rulesets=(prey=Ruleset(Double()), predator=Ruleset());
interactions=(Predation(prey=:prey, predator=:predator),) 
ruleset = MultiRuleset(rulesets=rulesets, interactions=interactions; init=init)

using DynamicGridsGtk
processor=DynamicGrids.ThreeColor(colors=(DynamicGrids.Blue(), DynamicGrids.Red()))
output = GtkOutput(init; processor=processor, minval=(0, 0), maxval=(1000, 100), store=true)
sim!(output, ruleset; init=init, tspan=(1, 60), fps=50)


# ruleset.rulesets
# init

# msd = DynamicGrids.MultiSimData(map((rs, i) -> SimData(rs, i, 1), ruleset.rulesets, init),
             # DynamicGrids.interactions(ruleset))
# typeof(msd)

# Display ideas
# output(init; processor=ThreeColor((:prey, :predator), (:red, :green)))
# output(init; processor=Layout([:prey :predator; :superpredator nothing]))
