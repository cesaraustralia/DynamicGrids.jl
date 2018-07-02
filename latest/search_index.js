var documenterSearchIndex = {"docs": [

{
    "location": "index.html#",
    "page": "Cellular",
    "title": "Cellular",
    "category": "page",
    "text": ""
},

{
    "location": "index.html#Cellular",
    "page": "Cellular",
    "title": "Cellular",
    "category": "module",
    "text": "Cellular provides a framework for building grid based simulations. Everything can be customised and added to, but there are some central idea that define how a Cellular simulation works: models, rules and neighborhoods. For input and output of data their are  init arrays and outputs. \n\nModels hold the configuration for a simulation, and trigger a specific rule method  that operates on each of the cells in the grid. See AbstractModel and  rule. Rules often trigger neighbors methods that sum surrounding cell  neighborhoods (AbstractNeighborhood), such as Moore and Von Neumann neighborhoods.\n\nOutputs are ways of storing of viewing the simulation, and can be used interchangeably  depending on your needs. See AbstractOutput.\n\nThe inititialisation array may be any AbstractArray, containing whatever initialisation data is required to start the simulation. Most rules work on two-dimensional arrays, but one-dimensional  arrays are also use for some cellular automata. \n\nA typical simulation is run with a script like:\n\ninit = my_array\nmodel = Life()\noutput = REPLOutput(init)\n\nsim!(output, model, init)\n\nMultiple models can be passed to  sim!() in a tuple, and each of their rules will be run for the whole grid in sequence.\n\nsim!(output, (model1, model2), init)\n\n\n\n"
},

{
    "location": "index.html#Cellular.jl-1",
    "page": "Cellular",
    "title": "Cellular.jl",
    "category": "section",
    "text": "Cellular"
},

{
    "location": "index.html#Example-1",
    "page": "Cellular",
    "title": "Example",
    "category": "section",
    "text": "This example runs a game of life simulation, and uses the REPLOutput to print the  frame directly in the REPL. You could instead use output = GtkOutput(init) for animation.using Cellular\n\n# Build a random starting grid\ninit = round.(Int8, max.(0.0, rand(-2.0:0.1:1.0, 70,70)))\n\n# Use the default game of life model\nmodel = Life()\n\n# Use an output that shows the cellular automata in the REPL\noutput = REPLOutput(init)\n\nsim!(output, model, init; time=1:5)More life-like examples (gleaned from CellularAutomata.jl):# Morley\nsim!(output, Life(b=[3,6,8], s=[2,4,5]), init; pause=0.1)\n\n# 2x2\nsim!(output, Life(b=[3,6], s=[1,2,5]), init; pause=0.05)\n\n# Dimoeba\ninit1 = round.(Int8, max.(0.0, rand(70,70)))\nsim!(output, Life(b=[3,5,6,7,8], s=[5,6,7,8]), init1; pause=0.1)\n\n## No death\nsim!(output, Life(b=[3], s=[0,1,2,3,4,5,6,7,8]), init; pause=0.1)\n\n## 34 life\nsim!(output, Life(b=[3,4], s=[3,4]), init; pause=0.1)\n\n# Replicator\ninit2 = round.(Int8, max.(0.0, rand(70,70)))\ninit2[:, 1:30] .= 0\ninit2[21:50, :] .= 0\nsim!(output, Life(b=[1,3,5,7], s=[1,3,5,7]), init2; pause=0.1)"
},

{
    "location": "index.html#Models-and-rules-1",
    "page": "Cellular",
    "title": "Models and rules",
    "category": "section",
    "text": "Models define simulation behaviour. They hold data relevant to the simulation, and trigger dispatch of particular rule methods. Models can be chained together arbitrarily to make composite simulations."
},

{
    "location": "index.html#Cellular.AbstractModel",
    "page": "Cellular",
    "title": "Cellular.AbstractModel",
    "category": "type",
    "text": "abstract AbstractModel\n\nA model contains all the information required to run a rule in a cellular  simulation, given an initialised array. Models can be chained together in any order.\n\nThe output of the rule for an AbstractModel is written to the current cell in the grid.\n\n\n\n"
},

{
    "location": "index.html#Cellular.AbstractPartialModel",
    "page": "Cellular",
    "title": "Cellular.AbstractPartialModel",
    "category": "type",
    "text": "abstract AbstractPartialModel\n\nAn abstract type for models that do not write to every cell of the grid, for efficiency.\n\nThere are two main differences with AbstractModel. AbstractPartialModel requires initialisation of the destination array before each timestep, and the output of  the rule is not written to the grid but done manually.\n\n\n\n"
},

{
    "location": "index.html#Cellular.AbstractLife",
    "page": "Cellular",
    "title": "Cellular.AbstractLife",
    "category": "type",
    "text": "abstract AbstractLife <: Cellular.AbstractModel\n\nTriggers dispatch on rule  for game of life simulations. Models that extend this should replicate the fields for Life.\n\n\n\n"
},

{
    "location": "index.html#Cellular.Life",
    "page": "Cellular",
    "title": "Cellular.Life",
    "category": "type",
    "text": "Game-of-life style cellular automata. \n\n\n\n"
},

{
    "location": "index.html#Types-and-Constructors-1",
    "page": "Cellular",
    "title": "Types and Constructors",
    "category": "section",
    "text": "AbstractModel\nAbstractPartialModel\nAbstractLife\nLife"
},

{
    "location": "index.html#Cellular.rule",
    "page": "Cellular",
    "title": "Cellular.rule",
    "category": "function",
    "text": "function rule(model, state, index, t, source, dest, args...)\n\nRules alter cell values based on their current state and other cells, often neighbors. Most rules return a value to be written to the current cell, except rules for models inheriting from AbstractPartialModel.  These must write to the dest array directly.\n\nArguments:\n\nmodel : AbstractModel \nstate: the value of the current cell\nindex: a (row, column) tuple of Int for the current cell coordinates\nt: the current time step\nsource: the whole source array. Not to be written to\ndest: the whole destination array. To be written to for AbstractPartialModel.\nargs: additional arguments passed through from user input to sim!\n\n\n\nrule(model::AbstractLife, state, args...)\n\nRule for game-of-life style cellular automata.\n\nThe cell becomes active if it is empty and the number of neightbors is a number in  the b array, and remains active the cell is active and the number of neightbors is  in the s array.\n\nReturns: boolean\n\n\n\n"
},

{
    "location": "index.html#Cellular.rule-Tuple{Cellular.AbstractLife,Any,Vararg{Any,N} where N}",
    "page": "Cellular",
    "title": "Cellular.rule",
    "category": "method",
    "text": "rule(model::AbstractLife, state, args...)\n\nRule for game-of-life style cellular automata.\n\nThe cell becomes active if it is empty and the number of neightbors is a number in  the b array, and remains active the cell is active and the number of neightbors is  in the s array.\n\nReturns: boolean\n\n\n\n"
},

{
    "location": "index.html#Methods-1",
    "page": "Cellular",
    "title": "Methods",
    "category": "section",
    "text": "rule\nrule(model::AbstractLife, state, args...)"
},

{
    "location": "index.html#Neighborhoods-1",
    "page": "Cellular",
    "title": "Neighborhoods",
    "category": "section",
    "text": "Neighborhoods define a pattern of cells surrounding the current cell,  and how they are combined to update the value of the current cell."
},

{
    "location": "index.html#Cellular.AbstractNeighborhood",
    "page": "Cellular",
    "title": "Cellular.AbstractNeighborhood",
    "category": "type",
    "text": "abstract AbstractNeighborhood\n\nAbstract type to extend to a neighborhood\n\n\n\n"
},

{
    "location": "index.html#Cellular.AbstractRadialNeighborhood",
    "page": "Cellular",
    "title": "Cellular.AbstractRadialNeighborhood",
    "category": "type",
    "text": "abstract AbstractRadialNeighborhood{T} <: Cellular.AbstractNeighborhood\n\nAbstract type to extend RadialNeighborhoods\n\n\n\n"
},

{
    "location": "index.html#Cellular.RadialNeighborhood",
    "page": "Cellular",
    "title": "Cellular.RadialNeighborhood",
    "category": "type",
    "text": "struct RadialNeighborhood{T, O} <: Cellular.AbstractRadialNeighborhood{T}\n\nRadial neighborhoods calculate the surrounding neighborood from the radius around the central cell, with a number of variants. \n\nThey can be constructed with: RadialNeighborhood{:moore,Skip}(1,Skip()) but the keyword  constructor should be preferable.\n\nradius\nThe \'radius\' of the neighborhood is the distance to the edge from the center cell. A neighborhood with radius 1 is 3 cells wide.\n\noverflow\nAbstractOverflow. Determines how co-ordinates outside of the grid are handled\n\n\n\n"
},

{
    "location": "index.html#Cellular.RadialNeighborhood-Tuple{}",
    "page": "Cellular",
    "title": "Cellular.RadialNeighborhood",
    "category": "method",
    "text": "RadialNeighborhood(;typ = :moore, radius = 1, overflow = Skip)\n\nThe radial neighborhood constructor with defaults.\n\nThis neighborhood can be used for one-dimensional, Moore, von Neumann or  Rotated von Neumann neigborhoods, and may have a radius of any integer size.\n\nKeyword Arguments\n\ntyp : A Symbol from :onedim, :moore, :vonneumann or :rotvonneumann. Default: :moore\nradius: Int. Default: 1\noverflow: AbstractOverflow. Default: Skip()\n\n\n\n"
},

{
    "location": "index.html#Cellular.AbstractCustomNeighborhood",
    "page": "Cellular",
    "title": "Cellular.AbstractCustomNeighborhood",
    "category": "type",
    "text": "abstract AbstractCustomNeighborhood <: Cellular.AbstractNeighborhood\n\nCustom neighborhoods are tuples of custom coordinates in relation to the central point of the current cell. They can be any arbitrary shape or size.\n\n\n\n"
},

{
    "location": "index.html#Cellular.CustomNeighborhood",
    "page": "Cellular",
    "title": "Cellular.CustomNeighborhood",
    "category": "type",
    "text": "struct CustomNeighborhood{H, O} <: Cellular.AbstractCustomNeighborhood\n\nAllows completely arbitrary neighborhood shapes by specifying each coordinate specifically.\n\nneighbors\nA tuple of tuples of Int (or an array of arrays of Int, etc), contains 2-D coordinates relative to the central point\n\noverflow\nAbstractOverflow. Determines how co-ordinates outside of the grid are handled\n\n\n\n"
},

{
    "location": "index.html#Cellular.MultiCustomNeighborhood",
    "page": "Cellular",
    "title": "Cellular.MultiCustomNeighborhood",
    "category": "type",
    "text": "struct MultiCustomNeighborhood{H, O} <: Cellular.AbstractCustomNeighborhood\n\nSets of custom neighborhoods that can have separate rules for each set.\n\nmultineighbors\nA tuple of tuple of tuples of Int (or an array of arrays of arrays of Int, etc), contains 2-D coordinates relative to the central point.\n\ncc\nA vector the length of the base multineighbors tuple, for intermediate storage\noverflow\nAbstractOverflow. Determines how co-ordinates outside of the grid are handled\n\n\n\n"
},

{
    "location": "index.html#Types-and-Constructors-2",
    "page": "Cellular",
    "title": "Types and Constructors",
    "category": "section",
    "text": "AbstractNeighborhood\nAbstractRadialNeighborhood\nRadialNeighborhood\nRadialNeighborhood(;typ = :moore, radius = 1, overflow = Skip)\nAbstractCustomNeighborhood\nCustomNeighborhood\nMultiCustomNeighborhood"
},

{
    "location": "index.html#Cellular.neighbors",
    "page": "Cellular",
    "title": "Cellular.neighbors",
    "category": "function",
    "text": "neighbors(hood::AbstractNeighborhood, state, index, t, source, args...)\n\nChecks all cells in neighborhood and combines them according to the particular neighborhood type.\n\n\n\nneighbors(hood::AbstractRadialNeighborhood{:onedim}, state, index, t, source, args...)\n\nSums single dimension radial neighborhoods. Commonly used by Wolfram.\n\n\n\nneighbors(hood::AbstractRadialNeighborhood, state, index, t, source, args...)\n\nSums 2-dimensional radial Nieghborhoods. Specific shapes like Moore and Von Neumann are determined by inhood, as this method is general.\n\n\n\nneighbors(hood::AbstractCustomNeighborhood, state, index, t, source, args...)\n\nSum a single custom neighborhood.\n\n\n\nneighbors(hood::MultiCustomNeighborhood, state, index, t, source, args...)\n\nSum multiple custom neighborhoods separately.\n\n\n\n"
},

{
    "location": "index.html#Cellular.neighbors-Tuple{Cellular.AbstractRadialNeighborhood{:onedim},Any,Any,Any,Any,Vararg{Any,N} where N}",
    "page": "Cellular",
    "title": "Cellular.neighbors",
    "category": "method",
    "text": "neighbors(hood::AbstractRadialNeighborhood{:onedim}, state, index, t, source, args...)\n\nSums single dimension radial neighborhoods. Commonly used by Wolfram.\n\n\n\n"
},

{
    "location": "index.html#Cellular.neighbors-Tuple{Cellular.AbstractRadialNeighborhood,Any,Any,Any,Any,Vararg{Any,N} where N}",
    "page": "Cellular",
    "title": "Cellular.neighbors",
    "category": "method",
    "text": "neighbors(hood::AbstractRadialNeighborhood, state, index, t, source, args...)\n\nSums 2-dimensional radial Nieghborhoods. Specific shapes like Moore and Von Neumann are determined by inhood, as this method is general.\n\n\n\n"
},

{
    "location": "index.html#Cellular.inhood",
    "page": "Cellular",
    "title": "Cellular.inhood",
    "category": "function",
    "text": "inhood(n::AbstractRadialNeighborhood{:moore}, p, q, row, col)\n\nCheck cell is inside a Moore neighborhood. Always returns true.\n\n\n\ninhood(n::AbstractRadialNeighborhood{:vonneumann}, p, q, row, col)\n\nCheck cell is inside a Vonn-Neumann neighborhood, returning a boolean.\n\n\n\ninhood(n::AbstractRadialNeighborhood{:rotvonneumann}, p, q, row, col)\n\nCheck cell is inside a Rotated Von-Neumann neighborhood, returning a boolean.\n\n\n\n"
},

{
    "location": "index.html#Cellular.neighbors-Tuple{Cellular.AbstractCustomNeighborhood,Any,Any,Any,Any,Vararg{Any,N} where N}",
    "page": "Cellular",
    "title": "Cellular.neighbors",
    "category": "method",
    "text": "neighbors(hood::AbstractCustomNeighborhood, state, index, t, source, args...)\n\nSum a single custom neighborhood.\n\n\n\n"
},

{
    "location": "index.html#Cellular.neighbors-Tuple{Cellular.MultiCustomNeighborhood,Any,Any,Any,Any,Vararg{Any,N} where N}",
    "page": "Cellular",
    "title": "Cellular.neighbors",
    "category": "method",
    "text": "neighbors(hood::MultiCustomNeighborhood, state, index, t, source, args...)\n\nSum multiple custom neighborhoods separately.\n\n\n\n"
},

{
    "location": "index.html#Methods-2",
    "page": "Cellular",
    "title": "Methods",
    "category": "section",
    "text": "neighbors\nneighbors(hood::AbstractRadialNeighborhood{:onedim}, state, index, t, source, args...)\nneighbors(hood::AbstractRadialNeighborhood, state, index, t, source, args...)\ninhood\nneighbors(hood::AbstractCustomNeighborhood, state, index, t, source, args...)\nneighbors(hood::MultiCustomNeighborhood, state, index, t, source, args...)"
},

{
    "location": "index.html#Cellular.sim!",
    "page": "Cellular",
    "title": "Cellular.sim!",
    "category": "function",
    "text": "sim!(output, model, init, args...; time=1:1000, pause=0.0)\n\nRuns the whole simulation, passing the destination aray to  the passed in output for each time-step.\n\nArguments\n\noutput: An AbstractOutput to store frames or display them on the screen.\nmodel: A single AbstractModel or a tuple of models that will each be run in sequence.\ninit: The initialisation array. \nargs: Any additional user defined args are passed through to rule and  neighbors methods.\n\nKeyword Arguments\n\ntime: Any Iterable of Number. Default: 1:1000\npause: A Number that specifies the pause beteen frames in seconds. Default: 0.0\n\n\n\n"
},

{
    "location": "index.html#Simulations-1",
    "page": "Cellular",
    "title": "Simulations",
    "category": "section",
    "text": "sim!"
},

{
    "location": "index.html#Output-1",
    "page": "Cellular",
    "title": "Output",
    "category": "section",
    "text": ""
},

{
    "location": "index.html#Cellular.AbstractOutput",
    "page": "Cellular",
    "title": "Cellular.AbstractOutput",
    "category": "type",
    "text": "abstract AbstractOutput\n\nSimulation outputs are decoupled from simulation behaviour and can be used interchangeably. These outputs inherit from AbstractOutput.\n\nTypes that extend AbstractOutput define their own method for update_output.\n\n\n\n"
},

{
    "location": "index.html#Cellular.AbstractArrayOutput",
    "page": "Cellular",
    "title": "Cellular.AbstractArrayOutput",
    "category": "type",
    "text": "abstract AbstractArrayOutput <: Cellular.AbstractOutput\n\nAbstract type parent for array outputs.\n\n\n\n"
},

{
    "location": "index.html#Cellular.ArrayOutput",
    "page": "Cellular",
    "title": "Cellular.ArrayOutput",
    "category": "type",
    "text": "struct ArrayOutput{A} <: Cellular.AbstractArrayOutput\n\nA simple array output that stores each step of the simulation in an array of arrays.\n\nframes\nAn array that holds each frame of the simulation\n\n\n\n"
},

{
    "location": "index.html#Cellular.ArrayOutput-Tuple{Any}",
    "page": "Cellular",
    "title": "Cellular.ArrayOutput",
    "category": "method",
    "text": "ArrayOutput(init)\n\nConstructor for ArrayOutput\n\nArguments\n\ninit : the initialisation array\n\n\n\n"
},

{
    "location": "index.html#Cellular.REPLOutput",
    "page": "Cellular",
    "title": "Cellular.REPLOutput",
    "category": "type",
    "text": "struct REPLOutput{A} <: Cellular.AbstractArrayOutput\n\nA wrapper for ArrayOutput that is displayed as asccii blocks in the REPL.\n\narray_output\n\n\n\n"
},

{
    "location": "index.html#Cellular.REPLOutput-Tuple{Any}",
    "page": "Cellular",
    "title": "Cellular.REPLOutput",
    "category": "method",
    "text": "REPLOutput(init)\n\nConstructor for REPLOutput\n\nArguments\n\ninit: The initialisation array\n\n\n\n"
},

{
    "location": "index.html#Cellular.GtkOutput",
    "page": "Cellular",
    "title": "Cellular.GtkOutput",
    "category": "type",
    "text": "struct GtkOutput{W, C, D} <: Cellular.AbstractOutput\n\nPlot output live to a Gtk window.\n\nwindow\ncanvas\nscaling\nok\n\n\n\n"
},

{
    "location": "index.html#Cellular.GtkOutput-Tuple{Any}",
    "page": "Cellular",
    "title": "Cellular.GtkOutput",
    "category": "method",
    "text": "GtkOutput(init; scaling = 2)\n\nConstructor for GtkOutput.\n\ninit::AbstractArray: the same init array that will also be passed to sim!()\n\n\n\n"
},

{
    "location": "index.html#Cellular.PlotsOutput",
    "page": "Cellular",
    "title": "Cellular.PlotsOutput",
    "category": "type",
    "text": "struct PlotsOutput{P} <: Cellular.AbstractOutput\n\nA Plots.jl Output to plot cells as a heatmap in any Plots backend. Some backends (such as plotly) may be very slow to refresh. Others like gr() should be fine. using Plots must be called for this to be available.\n\nplot\n\n\n\n"
},

{
    "location": "index.html#Cellular.PlotsOutput-Tuple{Any}",
    "page": "Cellular",
    "title": "Cellular.PlotsOutput",
    "category": "method",
    "text": "Plots(init)\n\nConstructor for GtkOutput.\n\ninit::AbstractArray: the init array that will also be passed to sim!()\n\n\n\n"
},

{
    "location": "index.html#Types-and-Constructors-3",
    "page": "Cellular",
    "title": "Types and Constructors",
    "category": "section",
    "text": "AbstractOutput\nAbstractArrayOutput\nArrayOutput\nArrayOutput(init)\nREPLOutput\nREPLOutput(init)\nGtkOutput\nGtkOutput(init; scaling = 2)\nPlotsOutput\nPlotsOutput(init)"
},

{
    "location": "index.html#Cellular.update_output",
    "page": "Cellular",
    "title": "Cellular.update_output",
    "category": "function",
    "text": "update_output(output, frame, t, pause)\n\nMethods that update the output with the current frame, for timestep t.\n\n\n\n"
},

{
    "location": "index.html#Cellular.update_output-Tuple{Cellular.AbstractArrayOutput,Any,Any,Any}",
    "page": "Cellular",
    "title": "Cellular.update_output",
    "category": "method",
    "text": "update_output(output::AbstractArrayOutput, frame, t, pause)\n\nCopies the current frame unchanged to the storage array\n\n\n\n"
},

{
    "location": "index.html#Cellular.update_output-Tuple{Cellular.REPLOutput,Any,Any,Any}",
    "page": "Cellular",
    "title": "Cellular.update_output",
    "category": "method",
    "text": "update_output(output::REPLOutput, frame, t, pause)\n\nExtends update_output from ArrayOuput by also printing to the REPL.\n\n\n\n"
},

{
    "location": "index.html#Cellular.update_output-Tuple{Cellular.GtkOutput,Any,Any,Any}",
    "page": "Cellular",
    "title": "Cellular.update_output",
    "category": "method",
    "text": "update_output(output::GtkOutput, frame, t, pause)\n\nSend current frame to the canvas in a Gtk window.\n\n\n\n"
},

{
    "location": "index.html#Cellular.update_output-Tuple{Cellular.PlotsOutput,Any,Any,Any}",
    "page": "Cellular",
    "title": "Cellular.update_output",
    "category": "method",
    "text": "update_output(output::PlotsOutput, frame, t, pause)\n\n\n\n"
},

{
    "location": "index.html#Methods-3",
    "page": "Cellular",
    "title": "Methods",
    "category": "section",
    "text": "update_output\nupdate_output(output::AbstractArrayOutput, frame, t, pause)\nupdate_output(output::REPLOutput, frame, t, pause)\nupdate_output(output::GtkOutput, frame, t, pause)\nupdate_output(output::PlotsOutput, frame, t, pause)"
},

{
    "location": "index.html#Cellular.AbstractOverflow",
    "page": "Cellular",
    "title": "Cellular.AbstractOverflow",
    "category": "type",
    "text": "abstract AbstractOverflow\n\nSingleton types for choosing the grid overflow rule used in inbounds. These determine what is done when a neighborhood  or jump extends outside of the grid.\n\n\n\n"
},

{
    "location": "index.html#Cellular.Wrap",
    "page": "Cellular",
    "title": "Cellular.Wrap",
    "category": "type",
    "text": "struct Wrap <: Cellular.AbstractOverflow\n\nWrap cords that overflow to the opposite side\n\n\n\n"
},

{
    "location": "index.html#Cellular.Skip",
    "page": "Cellular",
    "title": "Cellular.Skip",
    "category": "type",
    "text": "struct Skip <: Cellular.AbstractOverflow\n\nSkip coords that overflow boundaries\n\n\n\n"
},

{
    "location": "index.html#Overflow-1",
    "page": "Cellular",
    "title": "Overflow",
    "category": "section",
    "text": "Your grids have edges. When neighborhood or spotting activities overflow past edge,  you need a rule for deciding what to do.AbstractOverflow\nWrap\nSkip"
},

{
    "location": "index.html#Customisation-1",
    "page": "Cellular",
    "title": "Customisation",
    "category": "section",
    "text": "Functions listed can be overridden or have methods added to them to modify simulation behaviour. Preferably create your own types of Model, Neighborhood or Output, and add methods for functions that dispatch on those types. If your new times and methods add useful functionality, consider making it publicly available by making pull request, or creating your own package that depends on Cellular.jl.These are some more low-level functions you may also want to understand, if not actually modify extend."
},

{
    "location": "index.html#Cellular.broadcast_rules!",
    "page": "Cellular",
    "title": "Cellular.broadcast_rules!",
    "category": "function",
    "text": "broadcast_rules!(models, source, dest, index, t, args...)\n\nRuns the rule(s) for each cell in the grid, dependin on the model(s) passed in.  For [AbstractModel] the returned values are written to the dest grid,  while for AbstractPartialModel the grid is  pre-initialised to zero and rules manually populate the dest grid.\n\nReturns a tuple containing the source and dest arrays for the next iteration.\n\n\n\n"
},

{
    "location": "index.html#Cellular.inbounds",
    "page": "Cellular",
    "title": "Cellular.inbounds",
    "category": "function",
    "text": "inbounds(x, max, overflow)\n\nCheck grid boundaries for a single coordinate and max value or a tuple  of coorinates and max values.\n\nReturns a tuple containing the coordinate(s) followed by a boolean true  if the cell is in bounds, false if not.\n\nOverflow of type Skip returns the coordinate and false to skip  coordinates that overflow outside of the grid.  Wrap returns a tuple with the current position or it\'s  wrapped equivalent, and true as it is allways in-bounds.\n\n\n\n"
},

{
    "location": "index.html#Cellular.process_image",
    "page": "Cellular",
    "title": "Cellular.process_image",
    "category": "function",
    "text": "process_image(frame, output)\n\nConverts an array to an image format.\n\n\n\n"
},

{
    "location": "index.html#Framework-1",
    "page": "Cellular",
    "title": "Framework",
    "category": "section",
    "text": "broadcast_rules!\ninboundsprocess_image"
},

]}
