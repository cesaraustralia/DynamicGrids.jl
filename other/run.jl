using Revise
using Cellular
using Dispersal
using Crayons
using CuArrays
using GPUArrays
using CUDAnative
using StaticArrays

# using InteractBulma, Observables, CSSUtil, WebIO , Blink # using Blink # using Mux # using Flatten
using Gtk
# using CLArrays
# using FileIO # using ImageView using ArchGDAL
using ArchGDAL
function readtiff(file)
    img = ArchGDAL.registerdrivers() do
        ArchGDAL.read(file) do dataset
            ArchGDAL.read(dataset)
        end
    end
    # Scale values to a maximum of 1.0 img ./= maximum(img)
    # Remove values below 0.0
    img .= max.(0.0, img)
    # Transpose: fix until ArchGDAL does this automatically (soon)
    img = img[:,:,1]'
end
# cropaust(x) = x[950:952, 3100:3103] # Australia
cropaust(x) = x[950:1350, 3100:3600] # Australia
population = readtiff("/home/raf/CESAR/Raster/population_density.tif")
growth = readtiff("/home/raf/CESAR/Raster/limited_growth_2016_01.tif")
human = cropaust(population) # foot = readtiff("/home/raf/CESAR/human_footprint_cea_project.tif") # Dispersal.HudginsDispersalGrid(init, suit, human)
init = zeros(Int64, size(human))
init[24, 354] = 1
init = CuArray(init)
human = CuArray(human) 
growth_monthly = typeof(human)[]
for i = 1:9
    push!(growth_monthly, cropaust(readtiff("/home/raf/CESAR/Raster/limited_growth_2016_0$i.tif")))
end
for i = 10:12
    # ydiff, xdiff = outputsize .- dispsize
    push!(growth_monthly, cropaust(readtiff("/home/raf/CESAR/Raster/limited_growth_2016_$i.tif")))
end
import Dispersal: pressure
suit = growth_monthly[1]
suitlay = SuitabilityLayer(growth_monthly[1]) # SuitabilitySequence(growth_monthly)
humanlay = HumanLayer(human) # SuitabilitySequence(growth_monthly)
suitseq = SuitabilitySequence((growth_monthly...,), 30) # SuitabilitySequence(growth_monthly)
hood = DispersalNeighborhood(; f=exponential, radius=3, init=init)
hood = cudaconvert(hood)


# x = hood
# fields = (x.f, x.param, cudaconvert(CuArray(x.kernel)), x.cellsize, x.radius, x.overflow)
# hood = DispersalNeighborhood{:inwards, typeof.(fields)...}(fields...)

randomstate = GPUArrays.cached_state(init)
localdisp = InwardsLocalDispersal(neighborhood=hood)
humandisp = HumanDispersal()
jumpdisp = JumpDispersal()
layers = suitseq
# model = Models(humandisp, localdisp)
# model = Models(jumpdisp, localdisp)
# model = Models(humandisp)
model = Models(localdisp)
# model = Models(jumpdisp)
# model = Models(HudginsDispersal())

# Blink.AtomShell.@dot output.window webContents.setZoomFactor(1.7)
# output = Cellular.BlinkOutput(init, model, layers, randomstate)
# output = Cellular.MuxServer(init, model; port=8000)
# output = GtkOutput(init; fps=1000) 
# output = REPLOutput{:braile}(init; fps=800, color=Crayon(foreground=:red, background=:white, bold=true))
output = ArrayOutput(init) 
# sim!(output, model, init, layers, randomstate; time=10)
# @btime sim!($output, $model, $init, $layers, $randomstate; time=1000) 
# model = Models(Life(b=(3,5,6,7,8), s=(5,5,6,7,8)))
output = REPLOutput{:block}(init; fps=1000, color=:blue, store=false)

sim!(output, model, init, layers, randomstate; time=50000)
