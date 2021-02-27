using DynamicGrids, Test

using DynamicGrids: SimData, radius, rules, applyrule, neighborhood, neighborhoodkey, Extent

@testset "CellRule RunIf" begin

    rule = Cell{:a,:a}() do a
        10a
    end
    condition = RunIf(rule) do data, state, index
        state < 3oneunit(state)
    end

    init = (a=[1 2 3; 0 4 -1],)
    @test radius(condition) == (a=0)

    output = ArrayOutput(init; tspan=1:3)
    sim!(output, condition)

    @test output[2][:a] == [10 20 3; 0 4 -10]
    @test output[3][:a] == [10 20 3; 0 4 -100]

    # @test isinferred(output, condition)
end
