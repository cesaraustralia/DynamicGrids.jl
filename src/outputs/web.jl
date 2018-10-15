using Interact, 
      InteractBase,
      InteractBulma,
      Flatten, 
      Images

import InteractBase: WidgetTheme, libraries

struct WebTheme <: WidgetTheme end

const css_path = joinpath(dirname(pathof(Cellular)), "assets/web.css")

libraries(::WebTheme) = vcat(libraries(Bulma()), [css_path])


abstract type AbstractWebOutput{T} <: AbstractOutput{T} end

@Ok @FPS @Frames mutable struct WebInterface{P,Im,Ti} <: AbstractOutput{T}
    page::P
    image::Im
    t::Ti
end
build_range(lim::Tuple{Float64,Float64}) = lim[1]:(lim[2]-lim[1])/400:lim[2]
build_range(lim::Tuple{Int,Int}) = lim[1]:1:lim[2]

web_image(interface, frame) = dom"div"(process_image(interface, permutedims(scale_frame(frame), (2,1))))

WebInterface(frames::AbstractVector, model, args...; fps=25, showmax_fps=fps, store=false, theme=WebTheme()) = begin

    settheme!(theme)

    init = deepcopy(frames[1])

    # Standard output and controls
    image_obs = Observable{Any}(dom"div"())
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
    fnames = fieldnameflatten(model.models)
    lims = metaflatten(model.models, FieldMetadata.limits)
    parents = parentflatten(Tuple, model.models)
    # attributes = broadcast((p, n) -> Dict(:title => "$p.$n"), parents, fnames) , attributes=attr
    make_slider(p, lab, lim) = slider(build_range(lim); label=string(lab), value=p)
    sliders = broadcast(make_slider, params, fnames, lims)
    slider_obs = map((s...) -> s, observe.(sliders)...)
    modelwidgets = vbox(dom"span"("Model: "), vbox(sliders...))

    # Put it all together into a webpage
    page = vbox(hbox(image_obs, timetext), basewidgets, modelwidgets)

    # Construct the interface object
    timestamp = 0.0; tref = 0; running = [false]
    interface = WebInterface{typeof.((frames, fps, timestamp, tref, page, image_obs, t))...}(
                             frames, fps, showmax_fps, timestamp, tref, store, running, page, image_obs, t)

    # Frame updates when t changes
    map!(image_obs, t) do t
        web_image(interface, frames[curframe(interface, t)])
    end

    image_obs[] = web_image(interface, interface.frames[1])

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

is_async(o::WebInterface) = true
set_time(o::WebInterface, t) = o.t[] = t
show_frame(o::WebInterface, t) = set_time(o, t) # trigger the image redraw.
