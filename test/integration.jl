@testset "life glider stored properly all outputs" begin

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
    global output = ArrayOutput(init, 5)
    sim!(output, model, init; tstop=5)

    @testset "stored results match glider behaviour" begin
        @test output[3] == test
        @test output[5] == test2
    end

    @testset "converted results match glider behaviour" begin
        output = ArrayOutput(output)
        @test output[3] == test
        @test output[5] == test2
    end

    @testset "REPLOutput{:block} works" begin
        output = REPLOutput{:block}(init; fps=100, store=true)
        sim!(output, model, init; tstop=2)
        aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa = 0
        sleep(0.5)
        resume!(output, model; tadd=5)
        aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa = 0
        sleep(0.5)
        @test output[3] == test
        @test output[5] == test2
        replay(output)
    end

    @testset "REPLOutput{:braile} works" begin
        output = REPLOutput{:braile}(init; fps=100, store=true)
        sim!(output, model, init; tstop=2)
        aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa = 0
        sleep(0.5)
        resume!(output, model; tadd=3)
        aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa = 0
        sleep(0.5)
        @test output[3] == test
        @test output[5] == test2
        replay(output)
    end

    # @testset "BlinkOutput works" begin
        # using Blink
        # output = Cellular.BlinkOutput(init, model, store=true) 
        # sim!(output, model, init; tstop=2) 
        # sleep(1.5)
        # resume!(output, model; tadd=3)
        # sleep(1.5)
        # @test output[3] == test
        # @test output[5] == test2
        # replay(output)
        # close(output.window)
    # end

    @testset "GtkOutput works" begin
        using Gtk
        output = GtkOutput(init, store=true) 
        sim!(output, model, init; tstop=2) 
        resume!(output, model; tadd=3)
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
    #     sim!(output, model, init; tstop=2)
    #     resume!(output, model; tadd=5)
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
