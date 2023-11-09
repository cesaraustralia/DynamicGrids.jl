module DynamicGridsMakieExt

using DynamicGrids, Makie

const MAX_COLUMNS = 3
const DG = DynamicGrids

"""
    MakieOutput <: GraphicOutput

    MakieOutput(init; tspan, kw...)
    MakieOutput(f, init; tspan, kw...)

An output that is displayed using Makie.jl.

# Arguments:

- `f`: a function that plots a simulation frame into a layout. It is passed three arguments:
    `layout`, `frame` and `tstep` where layout is a `GridLayout` or whatever was passed to
    the `layout` keyword. `frames` are an observable of an object matching `init` that will
    be filled will values and updated as the simulation progresses. `tstep` is an observable
    of the timestep of the simulation, updated as it runs. If no function is passed, `image!`
    is used with a new `Axis` and the first layer of the simulation frame.
- `init`: initialisation `AbstractArray` or `NamedTuple` of `AbstractArray`.

# Keywords
- `ruleset`: a `Ruleset` to use in simulations
- `extrainit`: A `Dict{String,Any}` of alternate `init` objects that can be selected in the interface.
- `fig`: a makie `Figure`, `Figure()` by default.
- `layout`: a makie layout, `GridLayout(fig[1:4, 1])` by default.
- `inputgrid`: a makie layout to hold controls `GridLayout(fig[5, 1])` by default.
- `sim_kw`: keywords to pass to `sim!`.
$(DynamicGrids.GRAPHICOUTPUT_KEYWORDS)

life = Life()
output = MakieOutput(rand(Bool, 200, 300); tspan=1:10, ruleset=Ruleset(life)) do layout, frame, t
    axis = Axis(layout[1, 1])
    image!(axis, frame; )
end


# Example

```julia
using DynamicGrids
using GLMakie

# Define a rule, basic game of life
ruleset = Ruleset(Life())
# And the time-span for it to run
tspan = 1:100

# Run with default visualisation
output = MakieOutput(rand(Bool, 200, 300); tspan, ruleset, fps=10)

# Create our own plots with Makie.jl
output = MakieOutput(rand(Bool, 200, 300); tspan, ruleset) do layout, frame, t
    image!(Axis(layout[1, 1]), frame; interpolate=false, colormap=:inferno)
end

```
"""
function DynamicGrids.MakieOutput(f::Function, init::Union{NamedTuple,AbstractArray}; extent=nothing, store=false, kw...)
    # We have to handle some things manually as we are changing the standard output frames
    extent = extent isa Nothing ? DG.Extent(; init=init, kw...) : extent
    # Build simulation frames from the output of `f` for empty frames
    if store
        frames = [deepcopy(init) for _ in DG.tspan(extent)]
    else
        frames = [deepcopy(init)]
    end

    return MakieOutput(; frames, running=false, extent, store, f, kw...)
end
DynamicGrids.MakieOutput(init::Union{NamedTuple,AbstractArray}; kw...) =
    DynamicGrids.MakieOutput(_plot!, init; kw...)
# Most defaults are passed in from the generic ImageOutput constructor
function DynamicGrids.MakieOutput(;
    frames, running, extent, ruleset,
    extrainit=Dict(),
    throttle=0.1,
    interactive=true,
    fig=Figure(),
    layout=GridLayout(fig[1:4, 1]),
    inputgrid=GridLayout(fig[5, 1]),
    f=_plot!,
    graphicconfig=nothing,
    simdata=nothing,
    sim_kw=(;),
    slider_kw=(;),
    kw...
)
    graphicconfig = if isnothing(graphicconfig)
        DynamicGrids.GraphicConfig(; kw...)
    end
    # Observables that update during the simulation
    t_obs = Observable{Int}(1)
    frame_obs = Observable{Any}(nothing)

    # Page and output construction
    output = MakieOutput(
        frames, running, extent, graphicconfig, ruleset, fig, nothing, frame_obs, t_obs
    )
    simdata = DynamicGrids.initdata!(simdata, output, extent, ruleset)

    # Widgets
    controlgrid = GridLayout(inputgrid[1, 1])
    slidergrid = GridLayout(inputgrid[2, 1])
    _add_control_widgets!(fig, controlgrid, output, simdata, ruleset, extrainit, sim_kw)
    if interactive
        attach_sliders!(fig, ruleset; grid=slidergrid, throttle, slider_kw)
    end

    # Set up plot with the first frame
    if keys(simdata) == (:_default_,)
        frame_obs[] = DynamicGrids.gridview(first(DynamicGrids.grids(simdata)))
    else
        frame_obs[] = map(DynamicGrids.gridview, DynamicGrids.grids(simdata))
    end
    f(layout, frame_obs, t_obs)

    return output
end

_plot!(l, f::Observable, t) = _plot!(l, f[], f, t)
_plot!(l, A::AbstractArray, f::Observable, t) = _plot_array!(l, A, f, t)
function _plot!(l, ::NamedTuple, f::Observable, t)
    A = lift(f) do nt
        first(f)
    end
    _plot_array!(l, first(f[]), A, t)
end

function _plot_array!(l, ::AbstractArray{<:Any,2}, f::Observable, t)
    axis = Axis(l[1, 1]; aspect=1)
    hidedecorations!(axis)
    image!(axis, f; interpolate=false, colormap=:viridis)
end
function _plot_array!(l, ::AbstractArray{<:Any,3}, f::Observable, t)
    axis = Axis(l[1, 1]; aspect=1)
    hidedecorations!(axis)
    volume!(axis, f; colormap=:viridis)
end

# # Base interface
Base.display(o::MakieOutput) = display(o.fig)

# # DynamicGrids interface
DynamicGrids.isasync(o::MakieOutput) = true
DynamicGrids.ruleset(o::MakieOutput) = o.ruleset
function DynamicGrids.showframe(frame::NamedTuple, o::MakieOutput, data)
    # Update simulation image, makeing sure any errors are printed in the REPL
    try
        # println("writing frame to observable")
        if keys(frame) == (:_default_,)
            o.frame_obs[] = first(frame)
        else
            o.frame_obs[] = frame
        end
        # println("notifying frame observable")
        # println("notifying time observable")
        o.t_obs[] = DG.currentframe(data)
        notify(o.t_obs)
    catch e
        println(stdout, String(e)[1:10])
    end
    return nothing
end

function attach_sliders!(f::Function, fig, model::AbstractModel; grid=fig, kw...)
    attach_sliders!(fig, model; kw..., f=f)
end
function attach_sliders!(fig, model::AbstractModel;
    ncolumns=nothing, submodel=Nothing, throttle=0.1, obs=nothing, f=identity,
    slider_kw=(;), grid=GridLayout(fig[2, 1]),
)
    length(DynamicGrids.params(model)) == 0 && return

    # sliderbox = if submodel === Nothing
        # objpercol = 3
    slidergrid, slider_obs = param_sliders!(fig, model; grid, slider_kw)
        # _in_columns(sliders, ncolumns, objpercol)
    # else
        # objpercol = 1
        # sliders, slider_obs = group_sliders(f, model, submodel, obs, throttle)
        # _in_columns(sliders, ncolumns, objpercol)
    # end

    isnothing(slider_obs) && return nothing

    # Combine sliders
    combined_obs = lift((s...) -> s, slider_obs...)
    if length(slider_obs) > 0
        on(combined_obs) do values
            try
                model[:val] = stripunits(model, values)
            catch e
                println(stdout, e)
            end
        end
    end

    return slidergrid
end

function param_sliders!(fig, model::AbstractModel; grid=fig, throttle=0.1, slider_kw=(;))
    length(DynamicGrids.params(model)) == 0 && return nothing, nothing

    model1 = Model(parent(model))
    labels = if haskey(model1, :label)
        map(model1[:label], model1[:fieldname]) do n, fn
            n === nothing ? fn : n
        end
    else
        model1[:fieldname]
    end
    values = withunits(model1)
    ranges = if haskey(model1, :range)
        withunits(model1, :range)
    elseif haskey(model1, :bounds)
        _makerange.(withunits(model1, :bounds), values)
    else
        _makerange.(Ref(nothing), values)
    end

    descriptions = if haskey(model, :description)
        model[:description]
    else
        map(x -> "", values)
    end

    # Set mouse hover text
    # attributes = map(model[:component], labels, descriptions) do p, n, d
    #     desc = d == "" ? "" : string(": ", d)
    #     Dict(:title => "$p.$n $desc")
    # end

    height = 8
    slider_specs = map(values, labels, ranges) do startvalue, l, range
        (label=string(l), range, startvalue, height)
    end
    sg = SliderGrid(fig, slider_specs...)
    # Manually force label height
    map(sg.labels, sg.valuelabels) do l, vl
        l.height[] = vl.height[] = height
    end
    grid[1, 1] = sg

    slider_obs = map(x -> x.value, sg.sliders)

    return sg, slider_obs
end

function _add_control_widgets!(
    fig, grid, o::Output, simdata::AbstractSimData, ruleset::Ruleset, extrainit, sim_kw
)
    # We use the init dropdown for the simulation init, even if we don't
    # show the dropdown because it only has 1 option.
    extrainit[:init] = deepcopy(DynamicGrids.init(o))

    # Buttons
    grid[1, 1] = sim = Button(fig; label="sim")
    grid[1, 2] = resume = Button(fig; label="resume")
    grid[1, 3] = stop = Button(fig; label="stop")
    grid[1, 4] = fps_slider = Slider(fig; range=1:200, startvalue=DynamicGrids.fps(o))
    grid[1, 5] = init_dropdown = Menu(fig; options=Tuple.(collect(pairs(extrainit))), prompt="Choose init...")
    grid[2, 1:4] = time_slider = Slider(fig; startvalue=o.t_obs[], range=(1:length(DG.tspan(o))), horizontal=true)
    grid[2, 5] = time_display = Textbox(fig; stored_string=string(first(DG.tspan(o))))

    on(o.t_obs) do f
        time_display.displayed_string[] = string(DG.tspan(o)[f])
    end
    # Control mappings. Make errors visible in the console.
    on(sim.clicks) do _
        if DG.isrunning(o)
            @info "there is already a simulation running"
            return nothing
        end
        try
            Base.invokelatest() do
                sim!(o, ruleset; init=init_dropdown.selection[], sim_kw...)
            end
        catch e
            println(stdout, e)
        end
    end
    on(resume.clicks) do _
        try
            !DG.isrunning(o) && resume!(o, ruleset; tstop=last(DG.tspan(o)))
        catch e
            println(e)
        end
    end
    on(stop.clicks) do _
        try
            DG.setrunning!(o, false)
        catch e
            println(stdout, e)
        end
    end
    on(fps_slider.value) do fps
        try
            DG.setfps!(o, fps)
            DG.settimestamp!(o, o.t_obs[])
        catch e
            println(stdout, e)
        end
    end
    on(time_slider.value) do val
        try
            if val < o.t_obs[]
                println(stdout, "resetting time...")
                DG.setrunning!(o, false)
                sleep(0.1)
                DG.setstoppedframe!(output, val)
                DG.resume!(o; tstop=last(DG.tspan(o)))
            end
        catch e
            println(stdout, e)
        end
    end

    on(o.t_obs) do val
        set_close_to!(time_slider, val)
    end

    return nothing
end


# Widget buliding

function _makerange(bounds::Tuple, val::T) where T
    SLIDER_STEPS = 100
    b1, b2 = map(T, bounds)
    step = (b2 - b1) / SLIDER_STEPS
    return b1:step:b2
end
function _makerange(bounds::Tuple, val::T) where T<:Integer
    b1, b2 = map(T, bounds)
    return b1:b2
end
function _makerange(bounds::Nothing, val)
    SLIDER_STEPS = 100
    return if val == zero(val)
        LinRange(-oneunit(val), oneunit(val), SLIDER_STEPS)
    else
        LinRange(zero(val), 2 * val, SLIDER_STEPS)
    end
end
function _makerange(bounds::Nothing, val::Int)
    return if val == zero(val)
        -oneunit(val):oneunit(val)
    else
        zero(val):2val
    end
end
_makerange(bounds, val) = error("Can't make a range from Param bounds of $val")

function _in_columns(grid, objects, ncolumns, objpercol)
    nobjects = length(objects)
    nobjects == 0 && return hbox()

    if ncolumns isa Nothing
        ncolumns = max(1, min(MAX_COLUMNS, (nobjects - 1) ÷ objpercol + 1))
    end
    npercol = (nobjects - 1) ÷ ncolumns + 1
    cols = collect(objects[(npercol * (i - 1) + 1):min(nobjects, npercol * i)] for i in 1:ncolumns)
    for (i, col) in enumerate(cols)
        colgrid = GridLayout(grid[i, 1])
        for slider in col

        end
    end
end

end
