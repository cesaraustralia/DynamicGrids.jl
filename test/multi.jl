using DynamicGrids, Test
using DynamicGrids: Shared, Specific, Combined
using StaticArrays

struct Double <: AbstractCellRule end
applyrule(rule::Double, data, state, index) = state * 2

struct Squared <: AbstractCellRule end
applyrule(rule::Squared, data, state, index) = state^2


init = SVector.([(1,2) (3,4); (4,3) (2,1)])

output = ArrayOutput(init, 5)
ruleset = Ruleset(Shared(Double()), Specific{:index}(Squared()); init=init)
ruleset = Ruleset(Shared(Double()); init=init)

@LVector (1, 2) (:young, :old)

sim!(output, ruleset)

init[1] .* 5
