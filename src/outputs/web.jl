using InteractBulma, InteractBase, WebIO, Observables, CSSUtil

@Ok @FPS @Frames mutable struct WebInterface{P,Im,Ti} <: AbstractOutput{T}
    page::P
    image::Im
    t::Ti
    WebInterface(frames, fps, timestamp, ok, running, page, image, t) = 
        new(frames, fps, timestamp, ok, running, page, image, t)
end

WebInterface(frames::AbstractVector, fps::Number, model) = begin
    ok = [true]
    running = [false]
    init = deepcopy(frames[1])

    image = Observable{Any}(dom"div"([Images.Gray.(frames[1])]))
    obs_fps = Observable{Int}(fps)
    t = Observable{Int}(1)
    timespan = Observable{Int}(100)
    sim = button("sim")
    resume = button("resume")
    stop = button("stop")
    replay = button("replay")
    time_box = textbox("1")
    fps_slider = slider(1:60, label="FPS")
    page = dom"div"(vbox(image, hbox(sim, resume, stop, replay, fps_slider, time_box)))

    interface = WebInterface{typeof.((frames, obs_fps, time(), page, image, t))...}(frames, obs_fps, time(), ok, running, page, image, t)

    map!(t -> dom"div"([Images.Gray.(frames[t])]), image, t)
    map!(i -> i, obs_fps, observe(fps_slider))
    map!(timespan, observe(time_box)) do t
        parse(Int, t)
    end
    on(observe(sim)) do x
        sim!(interface, model, init; time = 100)
    end
    on(observe(resume)) do x
        resume!(interface, model; time = 100)
    end
    on(observe(replay)) do x
        replay(interface)
    end
    on(x -> set_ok(interface, false), observe(stop))

    interface
end

abstract type AbstractWebOutput{T} <: AbstractOutput{T} end

length(o::AbstractWebOutput) = length(o.interface)
size(o::AbstractWebOutput) = size(o.interface)
endof(o::AbstractWebOutput) = endof(o.interface)
getindex(o::AbstractWebOutput, i) = getindex(o.interface, i)
setindex!(o::AbstractWebOutput, x, i) = setindex!(o.interface, x, i)
push!(o::AbstractWebOutput, x) = push!(o.interface, x)
append!(o::AbstractWebOutput, x) = append!(o.interface, x)
clear(o::AbstractWebOutput) = clear(o.interface)
store_frame(o::AbstractWebOutput, frame) = store_frame(o.interface, frame)
initialize(o::AbstractWebOutput) = set_ok(o.interface, true)
is_ok(o::AbstractWebOutput) = is_ok(o.interface)
set_ok(o::AbstractWebOutput, x) = set_ok(o.interface, x) 
is_running(o::AbstractWebOutput) = is_running(o.interface)
set_running(o::AbstractWebOutput, x) = set_running(o.interface, x) 
set_time(o::AbstractWebOutput, t) = set_time(o.interface, t)

set_time(o::WebInterface, t) = o.t[] = t
initialize(o::WebInterface) = set_ok(o, true)

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
