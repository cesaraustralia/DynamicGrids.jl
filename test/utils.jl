using DynamicGrids, Test
using DynamicGrids: inbounds, isinbounds, _cyclic_index, SimData, _unwrap, ismasked

@testset "boundary boundary checks are working" begin
    @testset "inbounds with Remove() returns index and false for an boundaryed index" begin
        @test inbounds((1, 1), (4, 5), Remove()) == ((1,1),true)
        @test inbounds((2, 3), (4, 5), Remove()) == ((2,3),true)
        @test inbounds((4, 5), (4, 5), Remove()) == ((4,5),true)
        @test inbounds((-3, -100), (4, 5), Remove()) == ((-3,-100),false)
        @test inbounds((0, 0), (4, 5), Remove()) == ((0,0),false)
        @test inbounds((2, 3), (3, 2), Remove()) == ((2,3),false)
        @test inbounds((2, 3), (1, 4), Remove()) == ((2,3),false)
        @test inbounds((200, 300), (2, 3), Remove()) == ((200,300),false)
    end
    @testset "inbounds with Wrap() returns new index and true for an boundaryed index" begin
        @test inbounds((-2,3), (10, 10), Wrap()) == ((8,3),true)
        @test inbounds((2,0), (10, 10), Wrap()) == ((2,10),true)
        @test inbounds((22,0), (10, 10), Wrap()) == ((2,10),true)
        @test inbounds((-22,0), (10, 10), Wrap()) == ((8,10),true)
    end
    @testset "isinbounds" begin
        @test isinbounds((4, 5), (4, 5)) == true
        @test isinbounds((200, 300), (2, 3)) == false
        @test isinbounds((-22,0), (10, 10)) == false
    end
    @testset "boundscheck objects" begin
        output = ArrayOutput(zeros(Int, 10, 10); tspan=1:10)
        sd = SimData(output.extent, Ruleset())
        @test inbounds((5, 5), sd) == ((5, 5), true)
        @test inbounds((5, 5), first(sd)) == ((5, 5), true)
        @test inbounds((12, 5), sd) == ((12, 5), false)
        sd_wrap = SimData(output.extent, Ruleset(; boundary=Wrap()))
        @test inbounds((5, 5), sd_wrap) == ((5, 5), true)
        @test inbounds((12, 5), sd_wrap) == ((2, 5), true)
        @test inbounds((12, 5), first(sd_wrap)) == ((2, 5), true)
    end
end

@testset "isinferred" begin
    @testset "unstable conditional" begin
        rule = let threshold = 20
            Cell() do x
                x > 1 ? 2 : 0.0
            end
        end
        output = ArrayOutput(rand(Int, 10, 10); tspan=1:10)
        @test_throws ErrorException isinferred(output, rule)
    end

    @testset "return type" begin
        rule = Neighbors{:a,:a}(Moore{1}(zeros(Bool, 3, 3))) do hood, x
            round(Int, x + sum(hood))
        end
        output = ArrayOutput((a=rand(Int, 10, 10),); tspan=1:10)
        @test isinferred(output, rule)
        output = ArrayOutput((a=rand(Bool, 10, 10),); tspan=1:10)
        @test_throws ErrorException isinferred(output, rule)
    end

    @testset "let blocks" begin
        a = 0.7
        rule = SetCell() do data, x, I
            add!(first(data), round(Int, a + x), I...)
        end
        output = ArrayOutput(zeros(Int, 10, 10); tspan=1:10)
        @test_throws ErrorException isinferred(output, Ruleset(rule))
        a = 0.7
        rule = let a = a
            SetCell() do data, x, I
                add!(first(data), round(Int, a), I...)
            end
        end
        output = ArrayOutput(zeros(Int, 10, 10); tspan=1:10)
        @test isinferred(output, Ruleset(rule))
    end

end

@testset "ismasked" begin
    output = ArrayOutput(zeros(2, 2); mask=Bool[1 0; 0 1], tspan=1:10)
    sd = SimData(output.extent, Ruleset())
    @test ismasked(sd, 1, 2) == true
    @test ismasked(sd, 2, 2) == false
    output_nomask = ArrayOutput(zeros(2, 2); tspan=1:10)
    sd = SimData(output_nomask.extent, Ruleset())
    @test ismasked(sd, 1, 2) == false
end

@testset "unwrap" begin
    @test _unwrap(1) == 1
    @test _unwrap(Val(:a)) == :a
    @test _unwrap(Aux(:a)) == :a
    @test _unwrap(Grid(:a)) == :a
    @test _unwrap(Aux{:x}) == :x
    @test _unwrap(Grid{:x}) == :x
    @test _unwrap(Val{:x}) == :x
end
