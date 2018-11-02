using Revise, 
      Cellular,
      Test
import Cellular: rule, rule!, neighbors, normalize_frame

struct TestModel <: AbstractModel end
struct TestPartial <: AbstractPartialModel end 
struct TestPartialWrite <: AbstractPartialModel end

rule(::TestModel, data, state, index, args...) = 0
rule!(::TestPartial, data, state, index, args...) = 0
rule!(::TestPartialWrite, data, state, index, args...) = data.dest[index[1], 2] = 0
setup(x) = x

# For manual testing on CUDA
# using CuArrays
# setup(x) = CuArray(x)


@testset "boundary overflow checks are working" begin
    @testset "inbounds with Skip() returns index and false for an overflowed index" begin
        @test Cellular.inbounds((1, 1), (4, 5), Skip()) == ((1,1),true)
        @test Cellular.inbounds((2, 3), (4, 5), Skip()) == ((2,3),true)
        @test Cellular.inbounds((4, 5), (4, 5), Skip()) == ((4,5),true)
        @test Cellular.inbounds((-3, -100), (4, 5), Skip()) == ((-3,-100),false)
        @test Cellular.inbounds((0, 0), (4, 5), Skip()) == ((0,0),false)
        @test Cellular.inbounds((2, 3), (3, 2), Skip()) == ((2,3),false)
        @test Cellular.inbounds((2, 3), (1, 4), Skip()) == ((2,3),false)
        @test Cellular.inbounds((200, 300), (2, 3), Skip()) == ((200,300),false)
    end
    @testset "inbounds with Wrap() returns new index and true for an overflowed index" begin
        @test Cellular.inbounds((-2,3), (10, 10), Wrap()) == ((8,3),true)
        @test Cellular.inbounds((2,0), (10, 10), Wrap()) == ((2,10),true)
        @test Cellular.inbounds((22,0), (10, 10), Wrap()) == ((2,10),true)
        @test Cellular.inbounds((-22,0), (10, 10), Wrap()) == ((8,10),true)
    end
end

@testset "Scalable Matrix" begin

    global init = setup([-1 0 1 2 3;
                          0 1 2 3 4;
                          1 2 3 4 5;
                          2 3 4 5 6])

    sm = ScalableMatrix(init, -1, 6)
    normalized = normalize_frame(sm)
    @test maximum(normalized) == 1.0
    @test minimum(normalized) == 0.0

end

@testset "builds indices matrix" begin
    @test broadcastable_indices([1 2 3; 3 4 5]) == [(1, 1) (1, 2) (1, 3); (2, 1) (2, 2) (2, 3)] 
end


global init  = setup([0 1 1 0;
                      0 1 1 0;
                      0 1 1 0;
                      0 1 1 0;
                      0 1 1 0])

@testset "a rule that returns zero gives zero outputs" begin
    final = setup([0 0 0 0;
                   0 0 0 0;
                   0 0 0 0;
                   0 0 0 0;
                   0 0 0 0])

    global model = Models(TestModel())
    global output = ArrayOutput(init)
    sim!(output, model, init; time=10)
    @test output[10] == final
end

@testset "an partial rule that just returns zero does nothing" begin
    global model = Models(TestPartial())
    global output = ArrayOutput(init)
    sim!(output, model, init; time=10)
    @test output[1] == init
    @test output[10] == init
end

@testset "a partial rule that writes to dest affects output" begin
    final = setup([0 0 1 0;
                   0 0 1 0;
                   0 0 1 0;
                   0 0 1 0;
                   0 0 1 0])

    global model = Models(TestPartialWrite())
    global output = ArrayOutput(init)
    sim!(output, model, init; time=10)
    @test output[1] == init
    @test output[2] == final
    @test output[10] == final

end

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

    data = Cellular.ModelData(1, init, deepcopy(init), 1)

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

@testset "life glider does its thing" begin

    global init = setup([0 0 0 0 0 0;
                         0 0 0 0 0 0;
                         0 0 0 0 0 0;
                         0 0 0 1 1 1;
                         0 0 0 0 0 1;
                         0 0 0 0 1 0])

    global test = setup([0 0 0 0 0 0;
                         0 0 0 0 0 0;
                         0 0 0 0 1 1;
                         0 0 0 1 0 1;
                         0 0 0 0 0 1;
                         0 0 0 0 0 0])

    global test2 = setup([0 0 0 0 0 0;
                          0 0 0 0 0 0;
                          1 0 0 0 1 1;
                          1 0 0 0 0 0;
                          0 0 0 0 0 1;
                          0 0 0 0 0 0])

    global model = Models(Life())
    global output = ArrayOutput(init)
    # Run half as sim
    sim!(output, model, init; time=3)
    # The resume for second half
    resume!(output, model; time=3)

    @testset "stored results match glider behaviour" begin
        @test output[3] == test
        @test output[5] == test2
    end

    @testset "converted results match glider behaviour" begin
        output = ArrayOutput(output)
        @test output[3] == test
        @test output[5] == test2
        replay(output)
    end

    @testset "REPLOutput{:block} works" begin
        output = REPLOutput{:block}(init; fps=100, store=true)
        sim!(output, model, init; time=2)
        aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa = 0
        sleep(0.5)
        resume!(output, model; time=5)
        aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa = 0
        sleep(0.5)
        @test output[3] == test
        @test output[5] == test2
        replay(output)
    end

    @testset "REPLOutput{:braile} works" begin
        output = REPLOutput{:braile}(init; fps=100, store=true)
        sim!(output, model, init; time=2)
        aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa = 0
        sleep(0.5)
        resume!(output, model; time=3)
        aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa = 0
        sleep(0.5)
        @test output[3] == test
        @test output[5] == test2
        replay(output)
    end

    @testset "BlinkOutput works" begin
        using Blink
        output = Cellular.BlinkOutput(init, model, store=true) 
        sim!(output, model, init; time=2) 
        sleep(1.5)
        resume!(output, model; time=3)
        sleep(1.5)
        @test output[3] == test
        @test output[5] == test2
        replay(output)
        close(output.window)
    end

    @testset "GtkOutput works" begin
        using Gtk
        output = GtkOutput(init, store=true) 
        sim!(output, model, init; time=2) 
        resume!(output, model; time=3)
        @test output[3] == test
        @test output[5] == test2
        replay(output)
        destroy(output.window)
    end

    # Works but not set up for travis yet
    # @testset "Plots output works" begin
    #     using Plots
    #     plotlyjs()
    #     output = PlotsOutput(init)
    #     sim!(output, model, init; time=2)
    #     resume!(output, model; time=5)
    #     @test output[3] == test
    #     @test output[5] == test2
    #     replay(output)
    # end
end


@testset "Float output" begin

    global flt = setup([0.0 0.0 0.0 0.1 0.0 0.0;
                        0.0 0.3 0.0 0.0 0.6 0.0;
                        0.2 0.0 0.2 0.1 0.0 0.6;
                        0.0 0.0 0.0 1.0 1.0 1.0;
                        0.0 0.3 0.3 0.7 0.8 1.0;
                        0.0 0.0 0.0 0.0 1.0 0.6])

    global int = setup([0 0 0 0 0 0;
                        0 0 0 0 0 0;
                        0 0 0 0 0 0;
                        0 0 0 1 1 1;
                        0 0 0 0 0 1;
                        0 0 0 0 1 0])

    @testset "GtkOutput works" begin
        using Gtk
        output = GtkOutput(int) 
        Cellular.process_image(output, output[1])
        Cellular.show_frame(output, 1)
        destroy(output.window)

        output = GtkOutput(flt) 
        Cellular.process_image(output, output[1])
        Cellular.show_frame(output, 1)
        destroy(output.window)
    end
end
