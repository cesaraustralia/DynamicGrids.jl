using DynamicGrids, Test, Adapt
using DynamicGrids: SimData

output = ArrayOutput(BitArray(rand(Bool, 10, 10));
    tspan=1:10,
    mask=BitArray(rand(Bool, 10, 10)),
    aux=(aux1=BitArray(rand(Bool, 10, 10)),),
)

rs1 = Ruleset(Life(); opt=NoOpt()) 
rs2 = Ruleset(Life(); opt=SparseOpt())
sd1 = SimData(output, rs1)
sd2 = SimData(output, rs2)
Adapt.adapt(Array, rs1)
Adapt.adapt(Array, rs2)
b_sd1 = Adapt.adapt(Array, sd1)
b_sd2 = Adapt.adapt(Array, sd2)
@test b_sd2.extent.init._default_ isa Array
@test b_sd2.extent.mask isa Array
@test b_sd2.extent.aux.aux1 isa Array
@test parent(b_sd2.grids[:_default_].source) isa Array
@test parent(b_sd2.grids[:_default_].dest) isa Array
@test parent(b_sd2.grids[:_default_].optdata.sourcestatus) isa Array
@test Adapt.adapt(Array, output)[1] isa Array
