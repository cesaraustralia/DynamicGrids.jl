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


buf = [0 1 0 0 1 
       0 0 1 0 0
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
