using DynamicGrids, FieldDefaults, FieldMetadata, Test
import DynamicGrids: applyrule, applyrule!, applyrule, 
                     Rule, readkeys, writekeys, @Image, @Graphic, @Output

struct Double{R,W} <: CellRule{R,W} end
applyrule(rule::Double, data, state, index) = state * 2

struct Predation{R,W} <: CellRule{R,W} end
Predation(; prey=:prey, predator=:predator) = 
    Predation{Tuple{predator,prey},Tuple{prey,predator}}()
applyrule(::Predation, data, (predators, prey), index) = begin
    caught = prey * 0.02 * predators
    conversion = 0.2
    mortality = 0.1
    prey = max(prey - caught, zero(prey)) 
    predators = predators + caught * 0.1 - predators * mortality
    # Output order is the reverse of input to test that can work
    prey, predators
end

preyarray = rand(300, 300) .* 20
predatorarray = rand(300, 300) .* 2 
init = (prey=preyarray, predator=predatorarray)

rulesets=(prey=Ruleset(), predator=Ruleset());
predation = Predation(; prey=:prey, predator=:predator)
@test writekeys(predation) == (:prey, :predator)
@test readkeys(predation) == (:predator, :prey)
@test keys(predation) == (:prey, :predator)
@inferred writekeys(predation)
@inferred readkeys(predation)
@inferred keys(predation)
ruleset = Ruleset(; 
   rulesets=rulesets, 
   interactions=(Double{:prey,:prey}(), predation,), 
   init=init,
)

output = ArrayOutput(init, 20)
sim!(output, ruleset; init=init, tspan=(1, 20))

# TODO test output

# Color processor runs
@Image @Graphic @Output mutable struct TestImageOutput{} <: ImageOutput{T} end
processor=DynamicGrids.ThreeColorProcessor(colors=(DynamicGrids.Blue(), DynamicGrids.Red()))
imageoutput = TestImageOutput(init; processor=processor, minval=(0, 0), maxval=(1000, 100), store=true)
DynamicGrids.showgrid(::TestImageOutput, ::DynamicGrids.AbstractSimData, args...) = nothing 
sim!(imageoutput, ruleset; init=init, tspan=(1, 20))

@test output[20] == imageoutput[20]
