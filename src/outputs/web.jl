using InteractBulma, InteractBase, WebIO, Observables, CSSUtil, Flatten, Images

abstract type AbstractWebOutput{T} <: AbstractOutput{T} end

@Ok @FPS @Frames mutable struct WebInterface{P,Im,Ti} <: AbstractOutput{T}
    page::P
    image::Im
    t::Ti
end
build_range(lim::Tuple{Float64,Float64}) = lim[1]:(lim[2]-lim[1])/400:lim[2]
build_range(lim::Tuple{Int,Int}) = lim[1]:1:lim[2]

WebInterface(frames::AbstractVector, fps::Number, showmax_fps::Number, store, model, args...) = begin
    init = deepcopy(frames[1])

    # Standard output and controls
    image = Observable{Any}(dom"div"(Images.Gray.(Array(frames[1]))))
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

    # Construct the interface object
    timestamp = 0.0; tref = 0; running = [false]
    interface = WebInterface{typeof.((frames, fps, timestamp, tref, page, image, t))...}(
                             frames, fps, showmax_fps, timestamp, tref, store, running, page, image, t)

    # Frame updates when t changes
    map!(image, t) do t
        dom"div"(Images.Gray.(Array(frames[curframe(interface, t)])))
    end

    # Control mappings
    map!(timespan, observe(time_box)) do t
        parse(Int, t)
    end
    map!(timetext, t) do t
        dom"div"(string(t)) 
    end
    on(observe(sim)) do _
        sim!(interface, model, init, args...; time = timespan[])
    end
    on(observe(resume)) do _
        resume!(interface, model, args...; time = timespan[]) 
    end
    on(observe(replay)) do _
        replay(interface) 
    end
    on(observe(stop)) do _
        set_running(interface, false)
    end
    on(observe(fps_slider)) do fps
        interface.fps = fps 
        set_timestamp(interface, interface.t[])
    end
    on(slider_obs) do s
        model.models = Flatten.reconstruct(model.models, s) 
    end

    interface
end

set_time(o::WebInterface, t) = o.t[] = t
is_async(o::WebInterface) = true
show_frame(o::WebInterface, t) = 
    if use_frame(o, t)
        set_time(o, t) # trigger the image redraw.
    end
