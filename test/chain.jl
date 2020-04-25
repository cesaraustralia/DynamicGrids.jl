using DynamicGrids, Test, BenchmarkTools

using DynamicGrids: SimData, radius, rules, readkeys, writekeys, 
    applyrule, sumneighbors, neighborhood, update_chainstate

@testset "CellRule chain" begin

    rule1 = Map(read=:a, write=:b) do a
        2a
    end

    rule2 = Map{Tuple{:b,:d},:c}() do b, d
        b + d
    end

    rule3 = Map(read=Tuple{:a,:c,:d}, write=Tuple{:d,:e}) do a, c, d
        a + c + d, 3a
    end

    rule4 = Map{Tuple{:a,:b,:c,:d},Tuple{:a,:b,:c,:d}}() do a, b, c, d
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
    @test readkeys(chain) == (:a, :b, :d, :c)
    @test writekeys(chain) == (:b, :c, :d, :e, :a)

    ruleset = Ruleset(chain)
    init = (a=agrid, b=bgrid, c=cgrid, d=dgrid, e=egrid)
    data = SimData(init, ruleset, 1)

    @test radius(ruleset) == (b=0, c=0, d=0, e=0, a=0)

    @test applyrule(chain, data, (b=1, c=1, d=1, a=1), (1, 1)) ==
        (b=4, c=6, d=10, e=3, a=2)

    @inferred applyrule(chain, data, (b=1, c=1, d=1, a=1), (1, 1))

    state = (b=1, c=1, d=1, a=1)
    ind = (1, 1)

    b = @benchmark applyrule($chain, $data, $state, $ind)
    @test b.allocs == 0

    output = ArrayOutput(init, 3)
    sim!(output, ruleset; init=init, tspan=(1, 3))

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

end

struct BlockRule{R,W} <: NeighborhoodRule{R,W,} end

DynamicGrids.neighborhood(::BlockRule) = RadialNeighborhood{1}()

DynamicGrids.applyrule(rule::BlockRule, data, state, index, buf) =
    sumneighbors(neighborhood(rule), buf, state)

@testset "NeighbourhoodRule, CellRule chain" begin
    blockrule = BlockRule{:a,:a}()

    rule = Map{Tuple{:a,:c},:b}() do b, c
        b + c 
    end

    init = (a = 
        [0 0 0 0 0
         0 0 0 0 0
         0 0 1 0 0
         0 0 0 0 0
         0 0 0 0 0], 
        b = 
        [0 0 0 0 0
         0 0 0 0 0
         0 0 0 0 0
         0 0 0 0 0
         0 0 0 0 0], 
        c = 
        [1 1 1 1 1
         1 1 1 1 1
         1 1 1 1 1
         1 1 1 1 1
         1 1 1 1 1]) 
    ruleset = Ruleset(Chain(blockrule, rule); opt=NoOpt())
    noopt_output = ArrayOutput(init, 3)
    @btime sim!($noopt_output, $ruleset; init=$init)
    
    ruleset = Ruleset(Chain(blockrule, rule); opt=SparseOpt())
    sparseopt_output = ArrayOutput(init, 3)
    @btime sim!($sparseopt_output, $ruleset; init=$init)

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
