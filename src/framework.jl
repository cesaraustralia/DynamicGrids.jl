
""" 
Runs the whole simulation, passing the destination aray to 
the output for each time-step.
"""
sim!(source, model; output = TkOutput(source), time=1:10000, pause=0.0) = begin
    done = false
    dest = similar(source)
    for t in time
        # println(t)
        done = update_output(output, source, t, pause)
        !done || break

        automate!(dest, source, model, t) 
        source .= dest
    end
end

""" 
Runs the model once for the whole grid.
"""
automate!(dest, source, model, args...) = begin
    width, height = size(source)
    index = collect((col,row) for col in 1:width, row in 1:height)
    # Run the prekernel for every cell
    broadcast(prekernel, model, source, index, (source,), args...)
    # Run the kernel for every cell, the result sets the dest cell
    broadcast!(kernel, dest, model, source, index, (source,), args...)
end 

"""
Runs before the main kernel. Modifies the source array
that will be passed to kernel(). The return value is not used.
"""
function prekernel() end

"No prekernel, Return nothing"
prekernel(model, args...) = nothing

" The main kernel. The return value is written to the destination array."
function kernel() end

"No kernel, return the existing state."
kernel(model, args...) = state

