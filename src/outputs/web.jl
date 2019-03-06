using Interact, InteractBase, InteractBulma, AssetRegistry, Flatten, Images

import InteractBase: WidgetTheme, libraries


# Custom css theme
struct WebTheme <: WidgetTheme end

const css_key = AssetRegistry.register(joinpath(dirname(pathof(Cellular)), "../assets/web.css"))

libraries(::WebTheme) = vcat(libraries(Bulma()), [css_key])


"Web outputs, such as BlinkOutput and MuxServer"
abstract type AbstractWebOutput{T} <: AbstractOutput{T} end


" The backend interface for BlinkOuput and MuxServer"
@MinMax @ImageProc @Ok @FPS @Frames mutable struct WebInterface{P,IM,TI,S,SO} <: AbstractOutput{T}
    page::P
    image_obs::IM
    t_obs::TI
    summaries::S
    summary_obs::SO
end

"""
    WebInterface(frames::AbstractVector, model, args...; fps=25, showmax_fps=fps, store=false,
             processor=GreyscaleProcessor(), min=0, max=1, theme=WebTheme())
"""
WebInterface(frames::AbstractVector, model, args...; fps=25, showmax_fps=fps, store=false,
             processor=GreyscaleProcessor(), min=0, max=1, theme=WebTheme(), summaries=(), extrainit=Dict()) = begin

    # settheme!(theme)

    init = deepcopy(frames[1])

    # Standard output and controls
    image_obs = Observable{Any}(dom"div"())

    timedisplay = Observable{Any}(dom"div"("0"))
    t_obs = Observable{Int}(1)
    map!(timedisplay, t_obs) do t
        dom"div"(string(t))
    end

    timespan_obs = Observable{Int}(1000)
    timespan_text = textbox("1000")
    map!(timespan_obs, observe(timespan_text)) do ts
        parse(Int, ts)
    end

    extrainit[:init] = init
    init_drop = dropdown(extrainit, value=init, label="Init")

    sim = button("sim")
    resume = button("resume")
    stop = button("stop")
    replay = button("replay")

    buttons = store ? (sim, resume, stop, replay) : (sim, resume, stop)
    fps_slider = slider(1:200, value=fps, label="FPS")
    basewidgets = hbox(buttons..., vbox(dom"span"("Frames"), timespan_text), fps_slider, init_drop)

    modelsliders = build_sliders(model)


    # Construct the interface object
    timestamp = 0.0; tref = 0; tlast = 1; running = false
    initialize!.(summaries)
    summary_obs = [Observable{Any}(nothing) for s in summaries]

    # Put it all together into a webpage
    page = vbox(hbox(image_obs, summary_obs...), timedisplay, basewidgets, modelsliders)

    interface = WebInterface{typeof.((frames, fps, timestamp, tref, processor, min, page,
                                      image_obs, t_obs, summaries, summary_obs))...}(
                             frames, fps, showmax_fps, timestamp, tref, tlast, store, running,
                             processor, min, max, page, image_obs, t_obs, summaries, summary_obs)

    update_summaries(interface, init, 0)

    # Initialise image
    image_obs[] = web_image(interface, frames[1], 1)

    # Control mappings
    on(observe(sim)) do _
        sim!(interface, model, init_drop[], args...; tstop = timespan_obs[])
    end
    on(observe(resume)) do _
        resume!(interface, model, args...; tadd = timespan_obs[])
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

    interface
end

build_sliders(model) = begin
    params = flatten(model.models)
    fnames = fieldnameflatten(model.models)
    lims = metaflatten(model.models, FieldMetadata.limits)
    parents = parentflatten(Tuple, model.models)
    descriptions = metaflatten(Vector, model.models, FieldMetadata.description)
    attributes = broadcast((p, n, d) -> Dict(:title => "$p.$n: $d"), parents, fnames, descriptions)

    make_slider(val, lab, lims, attr) = slider(build_range(lims); label=string(lab), value=val, attributes=attr)
    sliders = broadcast(make_slider, params, fnames, lims, attributes)
    slider_obs = map((s...) -> s, observe.(sliders)...)
    on(slider_obs) do s
        model.models = Flatten.reconstruct(model.models, s)
    end

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

    vbox(slider_groups...)
end

build_range(lim::Tuple{Float64,Float64}) = lim[1]:(lim[2]-lim[1])/400:lim[2]
build_range(lim::Tuple{Int,Int}) = lim[1]:1:lim[2]

is_async(o::WebInterface) = true

web_image(interface, frame, t) = dom"div"(process_frame(interface, frame, t))

show_frame(o::WebInterface, frame, t) = begin
    o.image_obs[] = web_image(o, frame, t)
    o.t_obs[] = t
    update_summaries(o, frame, t)
end

update_summaries(output, frame, t) =
    for (i, s) in enumerate(output.summaries)
        output.summary_obs[i][] = summary_graphic(s, output, frame, t)
    end

initialize!(o::WebInterface, args...) = initialize!.(o.summaries)

function summary_graphic end
