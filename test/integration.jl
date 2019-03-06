using Blink, Cellular, Test, Gtk, Colors, ColorSchemes

# life glider sims


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

g0 = RGB24(0)
g1 = RGB24(1)
grey2 = [g0 g0 g0 g0 g0 g0;
         g0 g0 g0 g0 g0 g0;
         g1 g0 g0 g0 g1 g1;
         g1 g0 g0 g0 g0 g0;
         g0 g0 g0 g0 g0 g1;
         g0 g0 g0 g0 g0 g0]

l0 = get(ColorSchemes.leonardo, 0)
l1 = get(ColorSchemes.leonardo, 1)

leonardo2 = [l0 l0 l0 l0 l0 l0;
             l0 l0 l0 l0 l0 l0;
             l1 l0 l0 l0 l1 l1;
             l1 l0 l0 l0 l0 l0;
             l0 l0 l0 l0 l0 l1;
             l0 l0 l0 l0 l0 l0]


model = Models(Life())
output = ArrayOutput(init, 5)
sim!(output, model, init; tstop=5)

@testset "stored results match glider behaviour" begin
    @test output[3] == test
    @test output[5] == test2
end

@testset "converted results match glider behaviour" begin
    output2 = ArrayOutput(output)
    @test output2[3] == test
    @test output2[5] == test2
end

# Currently broken on travis, but not locally
if !haskey(ENV, "TRAVIS")
    @testset "REPLOutput{:block} works" begin
        output = REPLOutput{:block}(init; fps=100, store=true)
        sim!(output, model, init; tstop=2)
        fix_for_testing_hang_after_simulations = 0
        resume!(output, model; tadd=5)
        fix_for_testing_hang_after_simulations = 0
        @test output[3] == test
        @test output[5] == test2
        replay(output)
    end

    @testset "REPLOutput{:braile} works" begin output = REPLOutput{:braile}(init; fps=100, store=true)
        sim!(output, model, init; tstop=2)
        fix_for_testing_hang_after_simulations = 0
        resume!(output, model; tadd=3)
        fix_for_testing_hang_after_simulations = 0
        @test output[3] == test
        @test output[5] == test2
        replay(output)
    end

    @testset "BlinkOutput works" begin
        println("Start Blink tests")
        processor = Cellular.ColorSchemeProcessor(ColorSchemes.leonardo)
        output = Cellular.BlinkOutput(init, model; store=true, processor=processor) 
        sim!(output, model, init; tstop=2) 
        fix_for_testing_hang_after_simulations = 0
        sleep(1.5)
        resume!(output.interface, model; tadd=3)
        fix_for_testing_hang_after_simulations = 0
        sleep(1.5)
        @test output[3] == test
        @test output[5] == test2
        @test output.interface.image_obs[].children.tail[1] == leonardo2
        replay(output)
        fix_for_testing_hang_after_simulations = 0
        close(output.window)
    end

    @testset "GtkOutput works" begin
        println("Start Gtk tests")
        processor = Cellular.GrayscaleProcessor()
        output = GtkOutput(init; store=true) 
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
        output = GtkOutput(int) 
        Cellular.show_frame(output, 1)
        destroy(output.window)

        output = GtkOutput(flt) 
        Cellular.show_frame(output, 1)
        destroy(output.window)
    end
end
