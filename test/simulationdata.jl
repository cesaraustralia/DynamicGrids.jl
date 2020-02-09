using DynamicGrids, Test

init = [1 1 1 1 1 1 1
        1 1 1 1 1 1 1
        1 1 1 1 1 1 1
        1 1 1 1 1 1 1
        1 1 1 1 1 1 1
        1 1 1 1 1 1 1]

ruleset = Ruleset()
starttime = 1
radius = 3

simdata = DynamicGrids.SimData(ruleset, init, starttime, radius)

# TODO some tests
