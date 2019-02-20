using Blink, Cellular, Test, Gtk, Colors

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

image2 = [RGB24(0) RGB24(0) RGB24(0) RGB24(0) RGB24(0) RGB24(0);
          RGB24(0) RGB24(0) RGB24(0) RGB24(0) RGB24(0) RGB24(0);
          RGB24(1) RGB24(0) RGB24(0) RGB24(0) RGB24(1) RGB24(1);
          RGB24(1) RGB24(0) RGB24(0) RGB24(0) RGB24(0) RGB24(0);
          RGB24(0) RGB24(0) RGB24(0) RGB24(0) RGB24(0) RGB24(1);
          RGB24(0) RGB24(0) RGB24(0) RGB24(0) RGB24(0) RGB24(0)]

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
    println("Start blink tests")
    output = Cellular.BlinkOutput(init, model; store=true) 
    sim!(output, model, init; tstop=2) 
    fix_for_testing_hang_after_simulations = 0
    sleep(1.5)
    resume!(output.interface, model; tadd=3)
    fix_for_testing_hang_after_simulations = 0
    sleep(1.5)
    @test output[3] == test
    @test output[5] == test2
    @test output.interface.image_obs[].children.tail[1] == image2
    replay(output)
    fix_for_testing_hang_after_simulations = 0
    close(output.window)
end

@testset "GtkOutput works" begin
    output = GtkOutput(init; store=true) 
    sim!(output, model, init; tstop=2) 
    resume!(output, model; tadd=3)
    @test output[3] == test
    @test output[5] == test2
    replay(output)
    destroy(output.window)
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
