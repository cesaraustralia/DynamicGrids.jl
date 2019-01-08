using Interact,
      InteractBase,
      InteractBulma,
      AssetRegistry,
      Flatten,
      Images

import InteractBase: WidgetTheme, libraries

struct WebTheme <: WidgetTheme end

const css_key = AssetRegistry.register(joinpath(dirname(pathof(Cellular)), "../assets/web.css"))

libraries(::WebTheme) = vcat(libraries(Bulma()), [css_key])


abstract type AbstractWebOutput{T} <: AbstractOutput{T} end

@MinMax @Ok @FPS @Frames mutable struct WebInterface{P,Im,Ti,M} <: AbstractOutput{T}
    page::P
    image_obs::Im
    t_obs::Ti
end
build_range(lim::Tuple{Float64,Float64}) = lim[1]:(lim[2]-lim[1])/400:lim[2]
build_range(lim::Tuple{Int,Int}) = lim[1]:1:lim[2]

WebInterface(frames::AbstractVector, model, args...; fps=25, showmax_fps=fps, store=false, min=0, max=1, theme=WebTheme()) = begin

    settheme!(theme)

    init = deepcopy(frames[1])

    # Standard output and controls
    image_obs = Observable{Any}(dom"div"())
    t_obs = Observable{Int}(1)
    timespan = Observable{Int}(1000)
    sim = button("sim")
    resume = button("resume")
    stop = button("stop")
    replay = button("replay")
    timespan_box = textbox("1000")
    timedisplay = Observable{Any}(dom"div"("0"))
    fps_slider = slider(1:200, label="FPS")
    buttons = store ? (sim, resume, stop, replay) : (sim, resume, stop)
    basewidgets = hbox(buttons..., vbox(dom"span"("Frames"), timespan_box), fps_slider)

    # Auto-generated model controls
    params = flatten(model.models)
    fnames = fieldnameflatten(model.models)
    lims = metaflatten(model.models, FieldMetadata.limits)
    parents = parentflatten(Tuple, model.models)
    descriptions = metaflatten(Vector, model.models, FieldMetadata.description)
    attributes = broadcast((p, n, d) -> Dict(:title => "$p.$n: $d"), parents, fnames, descriptions)

    make_slider(val, lab, lims, attr) = slider(build_range(lims); label=string(lab), value=val, attributes=attr)
    sliders = broadcast(make_slider, params, fnames, lims, attributes)
    slider_obs = map((s...) -> s, observe.(sliders)...)

    group_title = nothing
    slider_groups = []
    group_items = []
    for i in 1:length(params)
        parent = parents[i]
        if group_title != parent
            group_title == nothing || push!(slider_groups, dom"div"(group_items...))
            group_items = Any[dom"h2"(string(parent))]
            group_title = parent
        end
        push!(group_items, sliders[i])
    end
    push!(slider_groups, dom"h2"(group_items...))

    modelsliders = vbox(slider_groups...)

    # Put it all together into a webpage
    page = vbox(hbox(image_obs, timedisplay), basewidgets, modelsliders)

    # Construct the interface object
    timestamp = 0.0; tref = 0; tlast = 1; running = [false]
    interface = WebInterface{typeof.((frames, fps, timestamp, tref, min, page, image_obs, t_obs))...}(
                             frames, fps, showmax_fps, timestamp, tref, tlast, store, running, min, max, page, image_obs, t_obs)

    # Initialise image
    image_obs[] = web_image(interface, frames[1])

    # # Control mappings
    map!(timespan, observe(timespan_box)) do ts
        parse(Int, ts)
    end
    map!(timedisplay, t_obs) do t
        dom"div"(string(t))
    end

    on(observe(sim)) do _
        sim!(interface, model, init, args...; tstop = timespan[])
    end
    on(observe(resume)) do _
        resume!(interface, model, args...; tadd = timespan[])
    end
    on(observe(replay)) do _
        replay(interface)
    end
    on(observe(stop)) do _
        set_running!(interface, false)
    end
    on(observe(fps_slider)) do fps
        interface.fps = fps
        set_timestamp!(interface, interface.t_obs[])
    end
    on(slider_obs) do s
        model.models = Flatten.reconstruct(model.models, s)
    end

    interface
end

is_async(o::WebInterface) = true

show_frame(o::WebInterface, frame, t) = begin
    o.image_obs[] = web_image(o, frame)
    o.t_obs[] = t
end

web_image(interface, frame) = dom"div"(process_image(interface, frame))
