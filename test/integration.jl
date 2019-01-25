using Cellular, Test

@testset "life glider stored properly all outputs" begin

    init =  [0 0 0 0 0 0;
             0 0 0 0 0 0;
             0 0 0 0 0 0;
             0 0 0 1 1 1;
             0 0 0 0 0 1;
             0 0 0 0 1 0]
                   
    test =  [0 0 0 0 0 0;
             0 0 0 0 0 0;
             0 0 0 0 1 1;
             0 0 0 1 0 1;
             0 0 0 0 0 1;
             0 0 0 0 0 0]

    test2 = [0 0 0 0 0 0;
             0 0 0 0 0 0;
             1 0 0 0 1 1;
             1 0 0 0 0 0;
             0 0 0 0 0 1;
             0 0 0 0 0 0]

    model = Models(Life())
    output = ArrayOutput(init, 5)
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

    # Image magick is failing... don't load Blink
    # @testset "BlinkOutput works" begin
    #     using Blink
    #     output = Cellular.BlinkOutput(init, model, store=true) 
    #     sim!(output, model, init; tstop=2) 
    #     sleep(1.5)
    #     resume!(output, model; tadd=3)
    #     sleep(1.5)
    #     @test_broken output[3] == test
    #     @test_broken output[5] == test2
    #     replay(output)
    #     close(output.window)
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

end


@testset "Float output" begin

    flt = [0.0 0.0 0.0 0.1 0.0 0.0;
           0.0 0.3 0.0 0.0 0.6 0.0;
           0.2 0.0 0.2 0.1 0.0 0.6;
           0.0 0.0 0.0 1.0 1.0 1.0;
           0.0 0.3 0.3 0.7 0.8 1.0;
           0.0 0.0 0.0 0.0 1.0 0.6]

    int = [0 0 0 0 0 0;
           0 0 0 0 0 0;
           0 0 0 0 0 0;
           0 0 0 1 1 1;
           0 0 0 0 0 1;
           0 0 0 0 1 0]

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
