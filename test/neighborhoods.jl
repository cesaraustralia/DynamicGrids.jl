using DynamicGrids, Test
import DynamicGrids: neighbors, SimData

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
@test neighbors(moore, nothing, buf, state) == 0
@test neighbors(vonneumann, nothing, buf, state) == 0

buf = [1 1 1
       1 0 1
       1 1 1]
state = buf[2, 2]
@test neighbors(moore, nothing, buf, state) == 8
@test neighbors(vonneumann, nothing, buf, state) == 4

buf = [1 1 1
       0 0 1
       0 0 1]
state = buf[2, 2]
@test neighbors(moore, nothing, buf, state) == 5
@test neighbors(vonneumann, nothing, buf, state) == 2


buf = [0 1 0 0 1
       0 0 1 0 0
       0 0 0 1 1 
       0 0 1 0 1 
       1 0 1 0 1]
state = buf[3, 3]
custom1 = CustomNeighborhood(((-1,-1), (2,-2), (2,2), (-1,2), (0,0)))
custom2 = CustomNeighborhood(((-1,-1), (0,-1), (1,-1), (2,-1), (0,0)))
layered = LayeredCustomNeighborhood((CustomNeighborhood((-1,1), (-2,2)), CustomNeighborhood((1,2), (2,2))))

@test neighbors(custom1, nothing, buf, state) == 2
@test neighbors(custom2, nothing, buf, state) == 0
@test neighbors(layered, nothing, buf, state) == (1, 2)
