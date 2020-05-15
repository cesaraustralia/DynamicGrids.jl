using DynamicGrids, Test
using DynamicGrids: inbounds, isinbounds

@testset "boundary overflow checks are working" begin
    @testset "inbounds with RemoveOverflow() returns index and false for an overflowed index" begin
        @test inbounds((1, 1), (4, 5), RemoveOverflow()) == ((1,1),true)
        @test inbounds((2, 3), (4, 5), RemoveOverflow()) == ((2,3),true)
        @test inbounds((4, 5), (4, 5), RemoveOverflow()) == ((4,5),true)
        @test isinbounds((4, 5), (4, 5), RemoveOverflow()) == true
        @test inbounds((-3, -100), (4, 5), RemoveOverflow()) == ((-3,-100),false)
        @test inbounds((0, 0), (4, 5), RemoveOverflow()) == ((0,0),false)
        @test inbounds((2, 3), (3, 2), RemoveOverflow()) == ((2,3),false)
        @test inbounds((2, 3), (1, 4), RemoveOverflow()) == ((2,3),false)
        @test inbounds((200, 300), (2, 3), RemoveOverflow()) == ((200,300),false)
        @test isinbounds((200, 300), (2, 3), RemoveOverflow()) == false
    end
    @testset "inbounds with WrapOverflow() returns new index and true for an overflowed index" begin
        @test inbounds((-2,3), (10, 10), WrapOverflow()) == ((8,3),true)
        @test inbounds((2,0), (10, 10), WrapOverflow()) == ((2,10),true)
        @test inbounds((22,0), (10, 10), WrapOverflow()) == ((2,10),true)
        @test inbounds((-22,0), (10, 10), WrapOverflow()) == ((8,10),true)
        @test isinbounds((-22,0), (10, 10), WrapOverflow()) == true
    end
    
end

@testset "isinferred" begin
    @test isinferred(Ruleset(Life(); init=rand(Bool, 10, 10)))
end
