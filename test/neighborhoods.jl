using CellularAutomataBase, Test
import CellularAutomataBase: neighbors, SimData

init = [0 0 0 1 1 1;
        1 0 1 1 0 1;
        0 1 1 1 1 1;
        0 1 0 0 1 0;
        0 0 0 0 1 1;
        0 1 0 1 1 0]

moore = RadialNeighborhood(1)
vonneumann = VonNeumannNeighborhood()
t = 1

buf = [0 0 0
       0 1 0
       0 0 0]
state = buf[2, 2]
data = SimData(init, nothing, nothing, buf, state, nothing, 0, 0, 1)
@test neighbors(moore, nothing, data, state, nothing) == 0
@test neighbors(vonneumann, nothing, data, state, nothing) == 0

buf = [1 1 1
       1 0 1
       1 1 1]
state = buf[2, 2]
data = SimData(init, nothing, nothing, buf, nothing, nothing, 0, 0, 1)
@test neighbors(moore, nothing, data, state, nothing) == 8
@test neighbors(vonneumann, nothing, data, state, nothing) == 4

buf = [1 1 1
       0 0 1
       0 0 1]
state = buf[2, 2]
data = SimData(init, nothing, nothing, buf, nothing, nothing, 0, 0, 1)
@test neighbors(moore, nothing, data, state, nothing) == 5
@test neighbors(vonneumann, nothing, data, state, nothing) == 2


buf = [0 1 0 0 1
       0 0 1 0 0
       0 0 0 1 1 
       0 0 1 0 1 
       1 0 1 0 1]
state = buf[3, 3]
data = SimData(init, nothing, nothing, buf, nothing, nothing, 0, 0, 1)
custom1 = CustomNeighborhood(((-1,-1), (2,-2), (2,2), (-1,2), (0,0)))
custom2 = CustomNeighborhood(((-1,-1), (0,-1), (1,-1), (2,-1), (0,0)))
layered = LayeredCustomNeighborhood((((-1,1), (-2,2)), ((1,2), (2,2))))

@test neighbors(custom1, nothing, data, state, nothing) == 2
@test neighbors(custom2, nothing, data, state, nothing) == 0
@test neighbors(layered, nothing, data, state, nothing) == (1, 2)
