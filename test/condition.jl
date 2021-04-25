using DynamicGrids, Test, Dates
using DynamicGrids: ruletype

@testset "RunIf" begin
    @testset "CellRule" begin
        rule = Cell{:a,:a}() do a
            10a
        end
        condition = RunIf(rule) do data, state, index
            state < 3oneunit(state)
        end

        init = (a=[1 2 3; 0 4 -1],)
        @test radius(condition) == (a=0)
        @test ruletype(condition) == CellRule
        @test ruletype(condition) == CellRule

        output = ArrayOutput(init; tspan=1:3)
        sim!(output, condition)

        @test output[2][:a] == [10 20 3; 0 4 -10]
        @test output[3][:a] == [10 20 3; 0 4 -100]
    end
    @testset "NeighborhoodRule" begin
        neighborsrule = Neighbors{:a,:a}(Moore{1}()) do hood, a
            sum(hood)
        end
        condition = RunIf(neighborsrule) do data, state, index
            state == 1
        end

        init = (a=[0 0 0 0; 
                   0 1 0 0; 
                   1 0 1 0; 
                   0 0 0 1],)
        @test radius(condition) == (a=1)
        @test ruletype(condition) == NeighborhoodRule

        output = ArrayOutput(init; tspan=1:3)
        sim!(output, condition)

        @test output[2][:a] == [0 0 0 0; 
                                0 2 0 0; 
                                1 0 2 0; 
                                0 0 0 1]
        @test output[3][:a] == [0 0 0 0; 
                                0 2 0 0; 
                                2 0 2 0; 
                                0 0 0 2]

        # @test isinferred(output, condition)
    end
end

@testset "RunAt" begin
    rule = Cell{:a,:a}(a -> a + 1)
    timedrule1 = Cell{:a,:a}(a -> 4a)
    timedrule2 = Cell{:a,:a}(a -> a ÷ 2)
    runatrule = RunAt(timedrule1, timedrule2; times=DateTime(2001, 3):Month(2):DateTime(2001, 5))

    init = (a=[1 2 3; 0 4 -5],)
    @test radius(runatrule) == 0
    @test length(runatrule) == 2
    @test runatrule[1] === timedrule1
    @test runatrule[2] === timedrule2
    @test Tuple(rule for rule in runatrule) == rules(runatrule)
    @test Base.tail(runatrule) == RunAt(timedrule2; times=DateTime(2001, 3):Month(2):DateTime(2001, 5))
    @test firstindex(runatrule) === 1
    @test lastindex(runatrule) === 2

    output = ArrayOutput(init; tspan=DateTime(2001,1):Month(1):DateTime(2001,5))
    sim!(output, rule, runatrule)

    @test output[2][:a] == [2 3 4; 1 5 -4]
    @test output[3][:a] == [6 8 10; 4 12 -6]
    @test output[4][:a] == [7 9 11; 5 13 -5]
    @test output[5][:a] == [16 20 24; 12 28 -8]
end
