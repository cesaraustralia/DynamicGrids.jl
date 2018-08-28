
function sensitivity(model, init; time=1000, reps=100)
    output = ArrayOutput(init)
    sim!(output, model, init)
    for i = 1:reps-1  
        update = ArrayOutput(init)
        output .+= sim!(output, model, init)
    end
    x = output ./ reps
    ArrayOutput(x)
end
