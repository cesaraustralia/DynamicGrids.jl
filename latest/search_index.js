var documenterSearchIndex = {"docs": [

{
    "location": "index.html#",
    "page": "Introduction",
    "title": "Introduction",
    "category": "page",
    "text": ""
},

{
    "location": "index.html#Cellular",
    "page": "Introduction",
    "title": "Cellular",
    "category": "module",
    "text": "Cellular provides a framework for building grid based simulations. Everything can be customised, but there are a few central idea that define how a Cellular simulation works: models, output, and init arrays. \n\nThe typical simulation is run with the command:\n\nmodel = Life()\n\nsim!(output, model, init)\n\nMultiple models can be passed to  sim!() in a tuple.\n\nsim!(output, (model1, model2), init)\n\nThe init array may be any AbstractArray, containing some whatever initialisation data is required. Most rules two-dimensional arrays, but one dimensional arrays are also use for  some Cellular automata. model and outputs can be types defined in Cellular, in  packages that extend Cellular, or custom types.\n\nExported types and methods\n\nAbstractArrayOutput\nAbstractCustomNeighborhood\nAbstractInPlaceModel\nAbstractLife\nAbstractModel\nAbstractNeighborhood\nAbstractOutput\nAbstractOverflow\nAbstractRadialNeighborhood\nArrayOutput\nCustomNeighborhood\nLife\nMultiCustomNeighborhood\nREPLOutput\nRadialNeighborhood\nSkip\nWrap\nautomate!\ninbounds\nshow\nsim!\n\n\n\n"
},

{
    "location": "index.html#Cellular.jl-1",
    "page": "Introduction",
    "title": "Cellular.jl",
    "category": "section",
    "text": "Cellular"
},

{
    "location": "index.html#Example-1",
    "page": "Introduction",
    "title": "Example",
    "category": "section",
    "text": "This example runs a game of life simulation, and uses the REPLOutput to print the final  frame directly in the REPL. You could intsead use output = TkOutput(init) for live animation.using Cellular\n\n# Build a random starting grid\ninit = round.(Int8, max.(0.0, rand(-2.0:0.1:1.0, 30,70)))\n\n# Use the default game of life model\nmodel = Life()\n\n# Use at output that shows life in the REPL\noutput = REPLOutput(init)\n\nsim!(output, model, init; time=1:5)These are some more life-like examples (gleaned from CellularAutomata.jl)# Morley\nsim!(output, Life(B=[3,6,8],S=[2,4,5]), init)\n\n# 2x2\nsim!(output, Life(B=[3,6],S=[1,2,5]), init)\n\n# Replicator\nsim!(output, Life(B=[1,3,5,7], S=[1,3,5,7]), init)\n\n# Dimoeba\nsim!(output, Life(B=[3,5,6,7,8], S=[5,6,7,8]), init)\n\n## No death\nsim!(output, Life(B=[3], S=[0,1,2,3,4,5,6,7,8]), init)\n\n## 34 life\nsim!(output, Life(B=[3,4], S=[3,4]), init)"
},

{
    "location": "index.html#Cellular.AbstractModel",
    "page": "Introduction",
    "title": "Cellular.AbstractModel",
    "category": "type",
    "text": "A module contains all the data required to run a rule in a cellular  simulation. Models can be chained together in any order or length.\n\nThe output of the rule for a default modules is written to the current cell in the grid.\n\n\n\n"
},

{
    "location": "index.html#Cellular.AbstractInPlaceModel",
    "page": "Introduction",
    "title": "Cellular.AbstractInPlaceModel",
    "category": "type",
    "text": "The output of In-place modules is ignored, instead they manually update cells. This is the best options for modules that only update a subset of cells.\n\n\n\n"
},

{
    "location": "index.html#Cellular.AbstractLife",
    "page": "Introduction",
    "title": "Cellular.AbstractLife",
    "category": "type",
    "text": "abstract AbstractLife <: Cellular.AbstractModel\n\nTriggers dispatch on rule  for game of life simulations. Models that extend this should replicate the fields for Life.\n\n\n\n"
},

{
    "location": "index.html#Cellular.Life",
    "page": "Introduction",
    "title": "Cellular.Life",
    "category": "type",
    "text": "struct Life{N, B, S} <: Cellular.AbstractLife\n\nGame of life style cellular automata.\n\nFields:\n\nneighborhood::AbstractNeighborhood: The default is a :moore  RadialNeighborhood with Wrap overflow \nb: Array or Tuple of integers to match neighbors when cell is empty Default = [3] \ns: Array, Tuple or Iterable of integers to match neighbors when cell is full. The default is [2,3]\n\n\n\n"
},

{
    "location": "index.html#Models-and-rules-1",
    "page": "Introduction",
    "title": "Models and rules",
    "category": "section",
    "text": "Models define modelling behaviour. They hold data  relevant to the simulation, and trigger dispatch of particular rule methods. Models can be chained together arbitrarily to make composite simulations.AbstractModel\nAbstractInPlaceModel\nAbstractLife\nLife"
},

{
    "location": "index.html#Cellular.AbstractNeighborhood",
    "page": "Introduction",
    "title": "Cellular.AbstractNeighborhood",
    "category": "type",
    "text": "abstract AbstractNeighborhood\n\nNeighborhoods define the behaviour towards the cells surrounding the current cell.\n\n\n\n"
},

{
    "location": "index.html#Cellular.AbstractRadialNeighborhood",
    "page": "Introduction",
    "title": "Cellular.AbstractRadialNeighborhood",
    "category": "type",
    "text": "abstract AbstractRadialNeighborhood{T} <: Cellular.AbstractNeighborhood\n\nRadial neighborhoods calculate the neighborood in a loop from simple rules base of the radius of cells around the central cell.\n\n\n\n"
},

{
    "location": "index.html#Cellular.RadialNeighborhood",
    "page": "Introduction",
    "title": "Cellular.RadialNeighborhood",
    "category": "type",
    "text": "struct RadialNeighborhood{T, O} <: Cellular.AbstractRadialNeighborhood{T}\n\nradius\noverflow\n\n\n\n"
},

{
    "location": "index.html#Cellular.AbstractCustomNeighborhood",
    "page": "Introduction",
    "title": "Cellular.AbstractCustomNeighborhood",
    "category": "type",
    "text": "Custom neighborhoods are tuples of custom coordinates in relation to the central point of the current cell. They can be any arbitrary shape or size.\n\nabstract AbstractCustomNeighborhood <: Cellular.AbstractNeighborhood\n\n\n\n"
},

{
    "location": "index.html#Cellular.CustomNeighborhood",
    "page": "Introduction",
    "title": "Cellular.CustomNeighborhood",
    "category": "type",
    "text": "struct CustomNeighborhood{H, O} <: Cellular.AbstractCustomNeighborhood\n\nneighbors\noverflow\n\n\n\n"
},

{
    "location": "index.html#Cellular.MultiCustomNeighborhood",
    "page": "Introduction",
    "title": "Cellular.MultiCustomNeighborhood",
    "category": "type",
    "text": "Multi custom neighborhoods are sets of custom neighborhoods that can have separate rules for each set. cc is a vector used to store the output of these rules.\n\nstruct MultiCustomNeighborhood{H, O} <: Cellular.AbstractCustomNeighborhood\n\nmultineighbors\ncc\noverflow\n\n\n\n"
},

{
    "location": "index.html#Neighborhoods-1",
    "page": "Introduction",
    "title": "Neighborhoods",
    "category": "section",
    "text": "Some rules require neighborhoods as a field of the model. Neighborhoods define the  pattern of cells that surrounds the current cell, and how they are summed to set  the value of the current cell in a model. Neighborhoods are generally not used in AbstractInPlaceModel.AbstractNeighborhood\nAbstractRadialNeighborhood\nRadialNeighborhood\nAbstractCustomNeighborhood\nCustomNeighborhood\nMultiCustomNeighborhood"
},

{
    "location": "index.html#Cellular.AbstractOverflow",
    "page": "Introduction",
    "title": "Cellular.AbstractOverflow",
    "category": "type",
    "text": "Singleton for selection overflow rules. These determine what is  done when a neighborhood or jump extends outside the grid.\n\n\n\n"
},

{
    "location": "index.html#Cellular.Wrap",
    "page": "Introduction",
    "title": "Cellular.Wrap",
    "category": "type",
    "text": "Wrap()\n\nWrap cords that overflow to the opposite side \n\n\n\n"
},

{
    "location": "index.html#Cellular.Skip",
    "page": "Introduction",
    "title": "Cellular.Skip",
    "category": "type",
    "text": "Skip()\n\nSkip coords that overflow boundaries \n\n\n\n"
},

{
    "location": "index.html#Overflow-1",
    "page": "Introduction",
    "title": "Overflow",
    "category": "section",
    "text": "Your grids have edges. When neighborhood or spotting activities overflow past edge,  you need a rule for deciding what to do.AbstractOverflow\nWrap\nSkip"
},

{
    "location": "index.html#Cellular.sim!",
    "page": "Introduction",
    "title": "Cellular.sim!",
    "category": "function",
    "text": "sim!(output, model, init, args; time, pause)\n\n\nRuns the whole simulation, passing the destination aray to  the passed in output for each time-step.\n\nArguments\n\nmodel: a single module or tuple of modules AbstractModel\n\n\n\n"
},

{
    "location": "index.html#Simulations-1",
    "page": "Introduction",
    "title": "Simulations",
    "category": "section",
    "text": "sim!"
},

{
    "location": "index.html#Cellular.AbstractOutput",
    "page": "Introduction",
    "title": "Cellular.AbstractOutput",
    "category": "type",
    "text": "abstract AbstractOutput\n\nSimulation outputs can be used interchangeably as they are decoupled  from the simulation behaviour. Outputs should inherit from AbstractOutput.\n\nAll types extending AbstractOutput should have their own method of update_output.\n\n\n\n"
},

{
    "location": "index.html#Cellular.AbstractArrayOutput",
    "page": "Introduction",
    "title": "Cellular.AbstractArrayOutput",
    "category": "type",
    "text": "abstract AbstractArrayOutput <: Cellular.AbstractOutput\n\nOutput subtype for arrays\n\n\n\n"
},

{
    "location": "index.html#Cellular.ArrayOutput",
    "page": "Introduction",
    "title": "Cellular.ArrayOutput",
    "category": "type",
    "text": "struct ArrayOutput{A} <: Cellular.AbstractArrayOutput\n\nSimple array output: creates an array of frames.\n\nframes\n\n\n\n"
},

{
    "location": "index.html#Cellular.REPLOutput",
    "page": "Introduction",
    "title": "Cellular.REPLOutput",
    "category": "type",
    "text": "struct REPLOutput{A} <: Cellular.AbstractArrayOutput\n\nAn array output that is printed as asccii blocks in the REPL.\n\nframes\n\n\n\n"
},

{
    "location": "index.html#Base.show",
    "page": "Introduction",
    "title": "Base.show",
    "category": "function",
    "text": "show(io, output)\n\n\nPrint the last frame of a simulation in the REPL.\n\n\n\n"
},

{
    "location": "index.html#Output-1",
    "page": "Introduction",
    "title": "Output",
    "category": "section",
    "text": "AbstractOutput\nAbstractArrayOutput\nArrayOutput\nREPLOutputCustom show() methods are available for some outputs.Base.show"
},

{
    "location": "index.html#Customisation-1",
    "page": "Introduction",
    "title": "Customisation",
    "category": "section",
    "text": "These functions (and those already listed) can all be overridden to change simulation behaviour. Preferably create your own type of Model, Neighborhood or Output,  and add methods of these functions that dispatch on those types. If your new times and methods add broadly useful functionality, consider making it publicly available by making pull request, or creating your own package that depends on Cellular.jl."
},

{
    "location": "index.html#Cellular.rule",
    "page": "Introduction",
    "title": "Cellular.rule",
    "category": "function",
    "text": "rule(model, state, index, t, source, args)\n\n\nRules for altering cell values\n\nArguments:\n\nrule::AbstractModel: \nstate: value of the current cell\nindex: row, column coordinate tuple for the current cell\nt: current time step\nsource: the whole source array\nargs: additional arguments passed through from user input to sim!\n\n\n\nrule(model::AbstractLife, state, args...) = begin\n\nRule for game-of-life style cellular automata.\n\nCell value is flipped if cell is empty and the bumber of neightbors is in  the b array, or if the cell is full and the bumber of neightbors is in the s array.\n\nOnly the model and state arguments are used.\n\nReturns: boolean.\n\n\n\n"
},

{
    "location": "index.html#Cellular.broadcastrules!",
    "page": "Introduction",
    "title": "Cellular.broadcastrules!",
    "category": "function",
    "text": "broadcastrules!(models::Tuple{T,Vararg}, source, dest, index, t, args...) where {T<:AbstractModel}\n\nBroadcast rule over each cell in the grid, for each module.  Returned values are written to the dest grid.\n\n\n\nbroadcastrules!(models::Tuple{T,Vararg}, source, dest, index, t, args...) where {T<:AbstractInPlaceModel}\n\nAbstractInPlaceModel Broadcasts rules for each cell in the grid, for each module.  Rules must manually write to the source array. return values are ignored.\n\n\n\n"
},

{
    "location": "index.html#Cellular.automate!",
    "page": "Introduction",
    "title": "Cellular.automate!",
    "category": "function",
    "text": "automate!(models::Tuple, source, dest, t, args...) = begin\n\nRuns the rules over the whole grid, for each module in sequence.\n\n\n\n"
},

{
    "location": "index.html#Framework-1",
    "page": "Introduction",
    "title": "Framework",
    "category": "section",
    "text": "rule\nbroadcastrules!\nautomate!"
},

{
    "location": "index.html#Cellular.neighbors",
    "page": "Introduction",
    "title": "Cellular.neighbors",
    "category": "function",
    "text": "neighbors(h::AbstractNeighborhood, state, index, t, source, args...) = begin\n\nChecks all cells in neighborhood and combines them according to the particular neighborhood rule.\n\nneighbors(h, state, index, t, source, args)\n\ndefined at Cellular/src/neighborhoods.jl:72.\n\nneighbors(h, state, index, t, source, args)\n\ndefined at Cellular/src/neighborhoods.jl:74.\n\nneighbors(h, state, index, t, source, args)\n\ndefined at Cellular/src/neighborhoods.jl:85.\n\nneighbors(h, state, index, t, source, args)\n\ndefined at Cellular/src/neighborhoods.jl:101.\n\nneighbors(h, state, index, t, source, args)\n\ndefined at Cellular/src/neighborhoods.jl:104.\n\n\n\n"
},

{
    "location": "index.html#Cellular.inbounds",
    "page": "Introduction",
    "title": "Cellular.inbounds",
    "category": "function",
    "text": "inbounds(xs::Tuple, maxs::Tuple, overflow)\n\nCheck grid boundaries for two coordinates. \n\nReturns a 3-tuple of coords and a boolean. True means the cell is in bounds, false it is not.\n\n\n\ninbounds(x::Number, max::Number, overflow::Skip)\n\nSkip coordinates that overflow outside of the grid.\n\n\n\ninbounds(x::Number, max::Number, overflow::Skip)\n\nSwap overflowing coordinates to the other side.\n\n\n\n"
},

{
    "location": "index.html#Cellular.inhood",
    "page": "Introduction",
    "title": "Cellular.inhood",
    "category": "function",
    "text": "inhood(n::AbstractRadialNeighborhood{T}, p, q, row, col)\n\nCheck cell is inside a radial neighborhood, returning a boolean.\n\n\n\n"
},

{
    "location": "index.html#Neighborhoods-2",
    "page": "Introduction",
    "title": "Neighborhoods",
    "category": "section",
    "text": "neighbors\ninbounds\ninhood"
},

{
    "location": "index.html#Cellular.update_output",
    "page": "Introduction",
    "title": "Cellular.update_output",
    "category": "function",
    "text": "update_output(output, frame, t, pause)\n\nMethods that update the output with the current frame, for timestep t.\n\nupdate_output(output, frame, t, pause)\n\ndefined at Cellular/src/output.jl:74.\n\n\n\n"
},

{
    "location": "index.html#Cellular.process_image",
    "page": "Introduction",
    "title": "Cellular.process_image",
    "category": "function",
    "text": "process_image(frame, output)\n\n\nConverts an array to an image format.\n\n\n\n"
},

{
    "location": "index.html#Output-2",
    "page": "Introduction",
    "title": "Output",
    "category": "section",
    "text": "update_output\nprocess_image"
},

]}
