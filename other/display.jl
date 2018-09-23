using Revise
using Cellular
using Dispersal
using Crayons
using CuArrays
using GPUArrays
using CUDAnative
using StaticArrays 
using InteractBulma, Observables, CSSUtil, WebIO , Blink
using Blink using Mux using Flatten
using Gtk

# using CLArrays
# using FileIO
# using ImageView

init = zeros(Float32, size(human))
init[24, 354] = 1.0f0
# init = zeros(Int32, size(human))
# init[24, 354] = 1
init = CuArray(init)
layers = (suitlay, humanlay)
@time precalc = Dispersal.hudgins_precalc(init, suit, human)
precalc
output = ArrayOutput(init)
model = Models(HudginsDispersal())
@time sim!(output, model, init, layers, precalc; time=3)

using Blink
Blink.AtomShell.@dot output.window webContents.setZoomFactor(1.7)
output = Cellular.BlinkOutput(init, model)
output = Cellular.MuxServer(init, model; port=8000)
output = GtkOutput(init; fps=1000, store=true) 
output = GtkOutput(output; fps=500, store=true) 
output = REPLOutput{:braile}(init; fps=800, color=Crayon(foreground=:red, background=:white, bold=true))
output = REPLOutput{:block}(init; fps=300, color=:red, store=false)
output = ArrayOutput(init) 
sim!(output, model, init, layers; time=20)
randomstate = GPUArrays.cached_state(init)
sim!(output, model, init, layers, randomstate; time=10)
@btime sim!($output, $model, $init, $layers, $randomstate; time=1000) 
model = Models(Life(b=(3,5,6,7,8), s=(5,5,6,7,8)))


using BenchmarkTools
using ProfileView
using Profile
output = ArrayOutput(init)

Profile.clear()
@profile sim!(output, model, init, layers; time=1000)
ProfileView.view()


(typeof(model.models[1]),)
m = first(methods(Cellular.rule, (typeof(model.models[1]),)))
Base.uncompressed_ast(m)

ff(a::Int, b::Float64) = true
    

wsize = 10

# centre mean = 0, sd = 1
function normalise(x) {
  x = x - mean(x) # centre
  X = x / std(x)
}

# create grid of area suitable land cover per cell
land_cover = array(rep(c(1,0),each=wsize^2/2), dim=c(wsize,wsize))
land_cover = normalise(land_cover)
land_cover

# create human population number layer
human = array(1:wsize^2, dim=c(wsize,wsize))
human = normalise(human)

# initialise pest pop layer (max = 1 when fully infested)
init = zeros(wsize, wsize)
init[1,1] = 1
pop = initial


# build distance array, km
d = array(dim=c(wsize,wsize,wsize,wsize))
for(i  in 1:nrow(d)){
  for(j  in 1:ncol(d)){
    for(ii in 1:nrow(d)){
      for(jj in 1:ncol(d)){
        d[i,j,ii,jj] =  sqrt((i-ii)^2+(j-jj)^2)
      }
    }
  }
}

# build f(Z) array
f = array(dim=c(wsize,wsize,wsize,wsize))
for(i  in 1:dim(f)[1]){
  for(j  in 1:dim(f)[2]){
    for(ii in 1:dim(f)[3]){
      for(jj in 1:dim(f)[4]){
        # coefficients from table 1
        ZI =
          -0.8438*land_cover[ii,jj] + # km2
          -0.1378*human[ii,jj] # km-2
        f[i,j,ii,jj] = 2*1.1248*exp(ZI)/(1+exp(ZI))
      }
    }
  }
}
f[2,1,,]

# build T array (proportion of pests dispersing from cell i,j to ii,jj)
t = array(dim=c(wsize,wsize,wsize,wsize))
for(i  in 1:dim(t)[1]){
  for(j  in 1:dim(t)[2]){
    for(ii in 1:dim(t)[3]){
      for(jj in 1:dim(t)[4]){
        # equation 1
        t[i,j,ii,jj] =
          exp(-d[i,j,ii,jj]*f[i,j,ii,jj])/
          sum(exp(-d[i,j,,]*f[i,j,,]))
      }
    }
  }
}
t[1,1,,]
