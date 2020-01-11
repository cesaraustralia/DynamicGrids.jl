using DynamicGrids, Test
import DynamicGrids: sumneighbors, SimData

init = [0 0 0 1 1 1;
        1 0 1 1 0 1;
        0 1 1 1 1 1;
        0 1 0 0 1 0;
        0 0 0 0 1 1;
        0 1 0 1 1 0]

moore = RadialNeighborhood{1}()
vonneumann = VonNeumannNeighborhood()
t = 1

buf = [0 0 0
       0 1 0
       0 0 0]
state = buf[2, 2]
@test sumneighbors(moore, buf, state) == 0
@test sumneighbors(vonneumann, buf, state) == 0

buf = [1 1 1
       1 0 1
       1 1 1]
state = buf[2, 2]
@test sumneighbors(moore, buf, state) == 8
@test sumneighbors(vonneumann, buf, state) == 4

buf = [1 1 1
       0 0 1
       0 0 1]
state = buf[2, 2]
@test sumneighbors(moore, buf, state) == 5
@test sumneighbors(vonneumann, buf, state) == 2


buf = [0 1 0 0 1 0 0 1 0 0
       0 0 0 1 1 
       0 0 1 0 1 
       1 0 1 0 1]
state = buf[3, 3]
custom1 = CustomNeighborhood(((-1,-1), (2,-2), (2,2), (-1,2), (0,0)))
custom2 = CustomNeighborhood(((-1,-1), (0,-1), (1,-1), (2,-1), (0,0)))
layered = LayeredCustomNeighborhood((CustomNeighborhood((-1,1), (-2,2)), CustomNeighborhood((1,2), (2,2))))

@test sumneighbors(custom1, buf, state) == 2
@test sumneighbors(custom2, buf, state) == 0
@test sumneighbors(layered, buf, state) == (1, 2)

using DynamicGrids, DynamicGridsGtk, ColorSchemes, Colors

const DEAD = 1
const ALIVE = 2
const BURNING = 3

# Define the Rule struct
struct ForestFire{N,PC,PR} <: NeighborhoodRule
    neighborhood::N
    prob_combustion::PC
    prob_regrowth::PR
end
ForestFire(; neighborhood=RadialNeighborhood{1}(), prob_combustion=0.0001, prob_regrowth=0.01) =
    ForestFire(neighborhood, prob_combustion, prob_regrowth)

# Define the `applyrule` method
@inline DynamicGrids.applyrule(rule::ForestFire, data, state::Integer, index, hood_buffer) =
    if state == ALIVE
        if BURNING in DynamicGrids.neighbors(rule, hood_buffer)
            BURNING
        else
            rand() <= rule.prob_combustion ? BURNING : ALIVE
        end
    elseif state in BURNING
        DEAD
    else
        rand() <= rule.prob_regrowth ? ALIVE : DEAD
    end

# Set up the init array, ruleset and output (using a Gtk window)
init = fill(ALIVE, 400, 400)
windyhood = CustomNeighborhood((1,1), (1,2), (1,3), (2,1), (3,1))
ruleset = Ruleset(ForestFire(; neighborhood=windyhood); init=init)
output = GtkOutput(init; store=true, fps=25, minval=DEAD, maxval=BURNING,
                   processor=ColorProcessor(scheme=ColorSchemes.rainbow, zerocolor=RGB24(0.0)))

# Run the simulation
sim!(output, ruleset; tspan=(1, 200))

# Save the output aas a gif
windyhood = CustomNeighborhood((1,1), (1,2), (1,3), (2,1), (3,1))
ruleset = Ruleset(ForestFire(; neighborhood=windyhood); init=init)
savegif("windy_forestfire.gif", output)
