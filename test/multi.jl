using DynamicGrids, FieldDefaults, FieldMetadata, Test
import DynamicGrids: applyrule, applyinteraction!, applyinteraction, 
                     Interaction, readkeys, writekeys, @Image, @Graphic, @Output
import FieldMetadata: @description, description, @limits, limits,
                      @flattenable, flattenable, default

struct Double <: CellRule end
applyrule(rule::Double, data, state, index) = state * 2

struct Predation{W,R} <: CellInteraction{W,R} end
Predation(; prey=:prey, predator=:predator) = Predation{Tuple{prey,predator},Tuple{predator,prey}}()
applyinteraction(::Predation, data, (predators, prey), index) = begin
    caught = prey * 0.02 * predators
    conversion = 0.2
    mortality = 0.1
    max(prey - caught, zero(prey)), predators + caught * 0.1 - predators * mortality
end

preyarray = rand(300, 300) .* 20
predatorarray = rand(300, 300) .* 2 
init = (prey=preyarray, predator=predatorarray)

rulesets=(prey=Ruleset(Double()), predator=Ruleset());
predation = Predation(; prey=:prey, predator=:predator)
@test writekeys(predation) == (:prey, :predator)
@test readkeys(predation) == (:predator, :prey)
@test keys(predation) == (:prey, :predator)
@inferred writekeys(predation)
@inferred readkeys(predation)
@inferred keys(predation)
ruleset = MultiRuleset(rulesets=rulesets, interactions=(predation,); init=init)

output = ArrayOutput(init, 20)
sim!(output, ruleset; init=init, tspan=(1, 20))

# TODO test output

# Color processor runs
@Image @Graphic @Output mutable struct TestImageOutput{} <: ImageOutput{T} end
processor=DynamicGrids.ThreeColorProcessor(colors=(DynamicGrids.Blue(), DynamicGrids.Red()))
imageoutput = TestImageOutput(init; processor=processor, minval=(0, 0), maxval=(1000, 100), store=true)
DynamicGrids.showgrid(::TestImageOutput, ::AbstractSimData, args...) = nothing 
sim!(imageoutput, ruleset; init=init, tspan=(1, 20))

output[20] == imageoutput[20]
