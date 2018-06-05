
sim!(source, model, output, timestep; pause=0.0) = begin
    t = zero(timestep)
    done = false
    dest = similar(source)
    while !done
        done = update_output(output, source, t, pause)
        automate!(dest, source, model, t) 
        source .= dest
        t = t + timestep
        println(t)
    end
end

automate!(dest, source, model, args...) = begin
    width, height = size(source)
    ind = collect((col,row) for col in 1:width, row in 1:height)
    broadcast(prekernel, source, model, ind, (source,), args...)
    broadcast!(kernel, dest, source, model, ind, (source,), args...)
end 

kernel(state, model, args...) = begin
    cc = neighbors(model.neighborhood, model, state, args...)
    rule(model, state, cc, args...)
end

prekernel(model, state, ind, dest, args...) = nothing
