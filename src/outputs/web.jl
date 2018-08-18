using InteractBulma, InteractBase, WebIO, Observables, CSSUtil

abstract type AbstractWebOutput{T} <: AbstractOutput{T} end

@Ok @FPS @Frames mutable struct WebInterface{P,Im,Ti} <: AbstractOutput{T}
    page::P
    image::Im
    t::Ti
    WebInterface(frames, fps, timestamp, ok, running, page, image, t) = 
        new(frames, fps, timestamp, ok, running, page, image, t)
end

build_range(lim::Tuple{Float64,Float64}) = lim[1]:(lim[2]-lim[1])/400:lim[2]
build_range(lim::Tuple{Int,Int}) = lim[1]:1:lim[2]

WebInterface(frames::AbstractVector, fps::Number, model) = begin
    ok = [true]
    running = [false]
    init = deepcopy(frames[1])

    # Standard output and controls
    image = Observable{Any}(dom"div"([Images.Gray.(frames[1])]))
    obs_fps = Observable{Int}(fps)
    t = Observable{Int}(1)
    timespan = Observable{Int}(1000)
    sim = button("sim")
    resume = button("resume")
    stop = button("stop")
    replay = button("replay")
    time_box = textbox("1000")
    timetext = Observable{Any}(dom"div"("0"))
    fps_slider = slider(1:60, label="FPS")
    basewidgets = hbox(sim, resume, stop, replay, vbox(dom"span"("Frames"), time_box), fps_slider)

    # Auto-generated model controls
    params = flatten(model.models)
    fnames = metaflatten(model.models, fieldname_meta)
    lims = metaflatten(model.models, MetaFields.limits)
    parents = metaflatten(Tuple, model.models, fieldparent_meta)
    attributes = broadcast((p, n) -> Dict(:title => "$p.$n"), parents, fnames)
    make_slider(p, lab, lim, attr) = slider(build_range(lim), label=string(lab), attributes=attr, value=p)
    sliders = broadcast(make_slider, params, fnames, lims, attributes)
    slider_obs = map((s...) -> s, observe.(sliders)...)
    modelwidgets = vbox(dom"span"("Model: "), hbox(sliders...))

    # Put it all together into a webpage
    page = dom"div"(vbox(hbox(image, timetext), basewidgets, modelwidgets))

    # Construct the interface output
    interface = WebInterface{typeof.((frames, obs_fps, time(), page, image, t))...}(
                            frames, obs_fps, time(), ok, running, page, image, t)


    # Frame updating
    map!(t -> dom"div"([Images.Gray.(frames[t])]), image, t)
    map!(t -> dom"div"(string(t)), timetext, t)

    # Control mappings
    map!(i -> i, obs_fps, observe(fps_slider))
    map!(t -> parse(Int, t), timespan, observe(time_box)) 
    on(sim -> sim!(interface, model, init; time = timespan[]), observe(sim)) 
    on(x -> resume!(interface, model; time = timespan[]), observe(resume))
    on(x -> replay(interface), observe(replay)) 
    on(observe(stop)) do x
        set_ok(interface, false)
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
initialize(o::WebInterface) = set_ok(o, true)
is_async(o::WebInterface) = true

delay(::HasFPS, output::WebInterface) = begin
    sleep(max(0.0, output.timestamp + 1/output.fps.val - time()))
    output.timestamp = time()
end

"""
    show_frame(output::WebOutput, t; fps=25.0)
Update plot for every specitfied interval
"""
function show_frame(output::WebInterface, t; fps=0.1)
    # This will trigger the image redraw.
    set_time(output, t)

    delay(output)
    is_ok(output)
end
