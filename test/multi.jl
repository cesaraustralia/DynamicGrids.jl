using DynamicGrids, Test


struct Double <: AbstractCellRule end
applyrule(rule::Double, data, state, index) = state * 2

struct Squared <: AbstractCellRule end
applyrule(rule::Squared, data, state, index) = state^2


init = [(1,2), (3,4);
        (4,3), (2,1)]

ruleset = MultiRuleset(shared=(Double(),), specific=(Double, Squared), init=init)

