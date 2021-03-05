using DynamicGrids, Test, Dates

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

@testset "CellRule RunAt" begin

    rule = Cell{:a,:a}(a -> a + 1)
    runatrule = RunAt(Cell{:a,:a}(a -> 2a); times=DateTime(2001, 3):Month(2):DateTime(2001, 5))

    init = (a=[1 2 3; 0 4 -5],)
    @test radius(runatrule) == 0

    output = ArrayOutput(init; tspan=DateTime(2001,1):Month(1):DateTime(2001,5))
    sim!(output, rule, runatrule)

    @test output[2][:a] == [2 3 4; 1 5 -4]
    @test output[3][:a] == [6 8 10; 4 12 -6]
    @test output[4][:a] == [7 9 11; 5 13 -5]
    @test output[5][:a] == [16 20 24; 12 28 -8]
end
