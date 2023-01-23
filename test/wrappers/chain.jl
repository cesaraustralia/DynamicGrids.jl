using DynamicGrids, Test, BenchmarkTools, StaticArrays

using DynamicGrids: SimData, radius, rules, _readkeys, _writekeys, 
    applyrule, neighborhood, neighborhoodkey, Extent, ruletype

@testset "CellRule chain" begin

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

    chain = Chain(rule1, rule2, rule3, rule4)
    @test ruletype(chain) == CellRule
    @test _readkeys(chain) == (:a, :b, :d, :c)
    @test _writekeys(chain) == (:b, :c, :d, :e, :a)

    ruleset = Ruleset(chain)
    init = (a=agrid, b=bgrid, c=cgrid, d=dgrid, e=egrid)
    data = SimData(Extent(init=init, tspan=1:1), ruleset)

    @test radius(ruleset) == (b=0, c=0, d=0, e=0, a=0)

    @test applyrule(data, chain, (b=1, c=1, d=1, a=1), (1, 1)) ==
        (4, 6, 10, 3, 2)

    # @inferred applyrule(data, chain, (b=1, c=1, d=1, a=1), (1, 1))

    state = (b=1, c=1, d=1, a=1)
    ind = (1, 1)

    # This breaks with --inline=no
    # b = @benchmark applyrule($data, $chain, $state, $ind)
    # @test b.allocs == 0

    output = ArrayOutput(init; tspan=1:3)
    sim!(output, ruleset)

    @test output[2][:a] == [2 0 0  
                            0 0 4]
    @test output[3][:a] == [4 0 0  
                            0 0 8]

    @test output[2][:b] == [4 0 0  
                            0 0 8]
    @test output[3][:b] == [8 0  0  
                            0 0 16]

    @test output[2][:c] == [4 0 0  
                            0 0 8]
    @test output[3][:c] == [20 0 0  
                            0 0 40]

    @test output[3][:d] == [36 0 0  
                            0 0 72]
    @test output[3][:d] == [36 0 0  
                            0 0 72]

    @test output[2][:e] == [3 0 0  
                            0 0 6]
    @test output[3][:e] == [6 0  0  
                            0 0 12]

    @test isinferred(output, ruleset)
end


@testset "NeighborhoodRule, CellRule chain" begin

    nbrs = SA[1, 2, 3, 4, 6, 7, 8, 9]
    hood = Moore{1}(nbrs)
    hoodrule = Neighbors{:a,:a}(hood) do data, neighborhodhood, cell, I
        sum(neighborhodhood)
    end

    rule = Cell{Tuple{:a,:c},:b}() do data, (b, c), I
        b + c 
    end

    init = (
        a = [0 0 0 0 0
             0 0 0 0 0
             0 0 1 0 0
             0 0 0 0 0
             0 0 0 0 0], 
        b = [0 0 0 0 0
             0 0 0 0 0
             0 0 0 0 0
             0 0 0 0 0
             0 0 0 0 0], 
        c = [1 1 1 1 1
             1 1 1 1 1
             1 1 1 1 1
             1 1 1 1 1
             1 1 1 1 1]
    ) 

    chain = Chain(hoodrule, rule)
    @test radius(chain) === 1
    @test ruletype(chain) == NeighborhoodRule
    @test neighborhood(chain) == hood

    @test Tuple(neighbors(chain)) === (1, 2, 3, 4, 6, 7, 8, 9) 
    @test neighborhoodkey(chain) === :a
    @test rules(Base.tail(chain)) === (rule,)
    @test chain[1] === first(chain) === hoodrule
    @test chain[end] === last(chain) === rule
    @test length(chain) === 2
    @test iterate(chain) === (hoodrule, 2)
    @test firstindex(chain) === 1
    @test lastindex(chain) === 2

    ruleset = Ruleset(chain; opt=NoOpt())
    noopt_output = ArrayOutput(init; tspan=1:3)
    sim!(noopt_output, ruleset)
    @test isinferred(noopt_output, ruleset)
    
    ruleset = Ruleset(Chain(hoodrule, rule); opt=SparseOpt())
    sparseopt_output = ArrayOutput(init; tspan=1:3)
    sim!(sparseopt_output, ruleset; init=init)
    @test isinferred(sparseopt_output, ruleset)

    noopt_output[2][:a] == sparseopt_output[2][:a] ==
        [0 0 0 0 0
         0 1 1 1 0
         0 1 0 1 0
         0 1 1 1 0
         0 0 0 0 0] 
    noopt_output[2][:b] == sparseopt_output[2][:b] ==
        [1 1 1 1 1
         1 2 2 2 1
         1 2 1 2 1
         1 2 2 2 1
         1 1 1 1 1] 
    noopt_output[3][:a] == sparseopt_output[3][:a] ==
        [1 2 3 2 1
         2 2 4 2 2
         3 4 8 4 3
         2 2 4 2 2
         1 2 3 2 1]
    noopt_output[3][:b] == sparseopt_output[3][:b] ==
        [2 3 4 3 2
         3 3 5 3 3
         4 5 9 5 4
         3 3 5 3 3
         2 3 4 3 2]
end
