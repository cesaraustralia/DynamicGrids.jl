using Revise
using Cellular
using CuArrays

model = Models(Life())
init = round.(Int64, max.(0.0, rand(-2.0:0.1:1.0, 701,501)))
init = CuArray(init)
# output = ArrayOutput(init) 
output = REPLOutput{:block}(init, store=false; fps=1000, color=:red)
# output = GtkOutput(output; fps=400, store=false) 
sim!(output, model, init; time=10000)

# resume!(output, model; time=1000)
# replay(output)
