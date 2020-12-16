using DynamicGrids, Test
using DynamicGrids: inbounds, isinbounds, _cyclic_index

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
        rule = SetCell() do data, index, x
            add!(first(data), round(Int, a + x), index...)
        end
        output = ArrayOutput(zeros(Int, 10, 10); tspan=1:10)
        @test_throws ErrorException isinferred(output, Ruleset(rule))
        a = 0.7
        rule = let a = a
            SetCell() do data, index, x
                add!(first(data), round(Int, a), index...)
            end
        end
        output = ArrayOutput(zeros(Int, 10, 10); tspan=1:10)
        @test isinferred(output, Ruleset(rule))
    end

end
