using DynamicGrids, Test, Dates
using DynamicGrids: applyrule, ruletype, _readkeys, _writekeys, SimData

@testset "Combine" begin
    rule1 = Cell{:a,:b}() do data, a, I
        2a
    end

    rule2 = Cell{Tuple{:b,:d},:c}() do data, (b, d), I
        b + d
    end

    rule3 = Cell{Tuple{:a,:c,:d},Tuple{:d,:e}}() do data, (a, c, d), I
        a + c + d, 3a
    end

    rule4 = Cell{Tuple{:a,:b,:c,:d},Tuple{:a,:b,:c,:d}}() do data, (a, b, c, d), I
        2a, 2b, 2c, 2d
    end

    # These aren't actually used yet, they just build SimData
    agrid = [1 0 0
             0 0 2]
    bgrid = [0 0 0
             0 0 0]
    cgrid = [0 0 0
             0 0 0]
    dgrid = [0 0 0
             0 0 0]
    egrid = [0 0 0
             0 0 0]

    combinedrule = Combine(sum, rule1, rule2, rule3, rule4)
    @test ruletype(combinedrule) == CellRule
    @test _readkeys(combinedrule) == (:a, :b, :d, :c)
    @test _writekeys(combinedrule) == (:b, :c, :d, :e, :a)

    ruleset = Ruleset(combinedrule)
    init = (a=agrid, b=bgrid, c=cgrid, d=dgrid, e=egrid)
    data = SimData(Extent(init=init, tspan=1:1), ruleset)

    @test radius(ruleset) == (b=0, c=0, d=0, e=0, a=0)
    @test applyrule(data, combinedrule, (b=1, c=2, d=3, a=4), (1, 1)) == (10, 8, 15, 12, 8)
end
