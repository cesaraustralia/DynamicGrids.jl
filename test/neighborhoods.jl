import Cellular: neighbors

@testset "neighborhoods sum surrounding values correctly" begin
    global init = setup([0 0 0 1 1 1;
                         1 0 1 1 0 1;
                         0 1 1 1 1 1;
                         0 1 0 0 1 0;
                         0 0 0 0 1 1;
                         0 1 0 1 1 0])

    moore = RadialNeighborhood(typ=:moore, radius=1, overflow=Wrap())
    vonneumann = RadialNeighborhood(typ=:vonneumann, radius=1, overflow=Wrap())
    rotvonneumann = RadialNeighborhood(typ=:rotvonneumann, radius=1, overflow=Wrap())
    custom = CustomNeighborhood(((-1,-1), (-1,2), (0,0)), Wrap())
    multi = MultiCustomNeighborhood(multi=(((-1,1), (-3,2)), ((1,2), (2,2))), overflow=Wrap())
    global state = 0
    global t = 1

    data = Cellular.FrameData(init, deepcopy(init), 1, 1, 1, ())

    @test neighbors(moore, nothing, data, state, (6, 2)) == 0
    @test neighbors(vonneumann, nothing, data, state, (6, 2)) == 0
    @test neighbors(rotvonneumann, nothing, data, state, (6, 2)) == 0

    @test neighbors(moore, nothing, data, state, (2, 5)) == 8
    @test neighbors(vonneumann, nothing, data, state, (2, 5)) == 4
    @test neighbors(rotvonneumann, nothing, data, state, (2, 5)) == 4

    @test neighbors(moore, nothing, data, state, (4, 4)) == 5
    @test neighbors(vonneumann, nothing, data, state, (4, 4)) == 2
    @test neighbors(rotvonneumann, nothing, data, state, (4, 4)) == 3

    @test neighbors(custom, nothing, data, state, (1, 1)) == 0
    @test neighbors(custom, nothing, data, state, (3, 3)) == 1
    @test neighbors(multi, nothing, data, state, (1, 1)) == [1, 2]

end
