using InteractBulma, InteractBase, WebIO, Observables, CSSUtil, Flatten, Images 

abstract type AbstractWebOutput{T} <: AbstractOutput{T} end

@Ok @FPS @Frames mutable struct WebInterface{P,Im,Ti} <: AbstractOutput{T}
    page::P
    image::Im
    t::Ti
end

build_range(lim::Tuple{Float64,Float64}) = lim[1]:(lim[2]-lim[1])/400:lim[2]
build_range(lim::Tuple{Int,Int}) = lim[1]:1:lim[2]

WebInterface(frames::AbstractVector, fps::Number, model, args...) = begin
    running = [false]
    init = deepcopy(frames[1])

    # Standard output and controls
    image = Observable{Any}(dom"div"(Images.Gray.(Array(frames[1]))))
    obs_fps = Observable{Int}(fps)
    t = Observable{Int}(1)
    timespan = Observable{Int}(1000)
    sim = button("sim")
    resume = button("resume")
    stop = button("stop")
    replay = button("replay")
    time_box = textbox("1000")
    timetext = Observable{Any}(dom"div"("0"))
    fps_slider = slider(1:200, label="FPS")
    basewidgets = hbox(sim, resume, stop, replay, vbox(dom"span"("Frames"), time_box), fps_slider)

    # Auto-generated model controls
    params = flatten(model.models)
    fnames = tagflatten(model.models, fieldname_tag)
    lims = tagflatten(model.models, Tags.limits)
    parents = tagflatten(Tuple, model.models, fieldparent_tag)
    attributes = broadcast((p, n) -> Dict(:title => "$p.$n"), parents, fnames)
    make_slider(p, lab, lim, attr) = slider(build_range(lim), label=string(lab), attributes=attr, value=p)
    sliders = broadcast(make_slider, params, fnames, lims, attributes)
    slider_obs = map((s...) -> s, observe.(sliders)...)
    modelwidgets = vbox(dom"span"("Model: "), hbox(sliders...))

    # Put it all together into a webpage
    page = dom"div"(vbox(hbox(image, timetext), basewidgets, modelwidgets))

    # Construct the interface output
    interface = WebInterface{typeof.((frames, obs_fps, 0.0, page, image, t))...}(
                            frames, obs_fps, 0.0, running, page, image, t)


    # Frame updating
    map!(t -> dom"div"(Images.Gray.(Array(frames[t]))), image, t)
    map!(t -> dom"div"(string(t)), timetext, t)

    # Control mappings
    map!(i -> i, obs_fps, observe(fps_slider))
    map!(t -> parse(Int, t), timespan, observe(time_box)) 
    on(sim -> sim!(interface, model, init, args...; time = timespan[]), observe(sim)) 
    on(x -> resume!(interface, model, args...; time = timespan[]), observe(resume))
    on(x -> replay(interface), observe(replay)) 
    on(observe(stop)) do x
        set_running(interface, false)
    end
    on(slider_obs) do s
        model.models = Flatten.reconstruct(model.models, s)
    end

    interface
end

set_time(o::AbstractWebOutput, t) = set_time(o.interface, t)
set_time(o::AbstractWebOutput, t) = set_time(o.interface, t)
is_async(o::AbstractWebOutput) = true

set_time(o::WebInterface, t) = o.t[] = t
is_async(o::WebInterface) = true

"""
    show_frame(output::WebOutput, t; fps=25.0)
Update plot for every specitfied interval
"""
show_frame(output::WebInterface, t) = set_time(output, t) # trigger the image redraw.
