using DynamicGrids, FieldDefaults, FieldMetadata, Test
import DynamicGrids: applyrule, applyinteraction!, applyinteraction, 
                     Interaction, @Image, @Graphic, @Output
import FieldMetadata: @description, description, @limits, limits,
                      @flattenable, flattenable, default

struct Double <: CellRule end
applyrule(rule::Double, data, state, index) = state * 2

struct Predation{Keys} <: CellInteraction{Keys} end
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
sim!(output, ruleset; init=init, tspan=(1, 20))

# Color processor runs
@Image @Graphic @Output mutable struct TestImageOutput{} <: ImageOutput{T} end
processor=DynamicGrids.ThreeColor(colors=(DynamicGrids.Blue(), DynamicGrids.Red()))
imageoutput = TestImageOutput(init; processor=processor, minval=(0, 0), maxval=(1000, 100), store=true)
DynamicGrids.showframe(::TestImageOutput, ::AbstractSimData, args...) = nothing 
sim!(imageoutput, ruleset; init=init, tspan=(1, 20))

output[20] == imageoutput[20]
