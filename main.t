--[[

Prototype implementation of STOIL, STOKE for icestick LUTs

Author: Michael Mara, mmara@cs.stanford.edu

TODO: integrate https://github.com/silentbicycle/lunatest

TODO: Add graphviz support

TODO: JIT compile simulator

TODO: Better LUT value manipulation

TODO: Faster circuit manipulation

--]]

require("bithelpers")
require("simulation")
require("tablehelpers")

require("circuit")

require("stochasticsearch")

local fourBitDecoder = emptyGraph(4,3)

local regularInputs = table.slice(fourBitDecoder.inputs, 1, 4)

local jcounterStates = {0, 1, 3, 7, 15, 14, 12, 8}
local js = jcounterStates

local onesLUT = setBits({js[2], js[4], js[6], js[8]})

local outputWires1 = getInputWires(fourBitDecoder.outputs[1])

addLUTNode(fourBitDecoder, regularInputs, outputWires1[1], onesLUT)


local twosLUT = setBits({js[3], js[4], js[7], js[8]})
local outputWires2 = getInputWires(fourBitDecoder.outputs[2])
addLUTNode(fourBitDecoder, regularInputs, outputWires2[1], twosLUT)

local foursLUT = setBits({js[5], js[6], js[7], js[8]})
local outputWires3 = getInputWires(fourBitDecoder.outputs[3])
addLUTNode(fourBitDecoder, regularInputs, outputWires3[1], foursLUT)

print("fourBitDecoder")
--printGraph(deepCopy(fourBitDecoder))

local tests = createTestSuite(fourBitDecoder, jcounterStates)

for i=1,#tests.input do
    print(tests.input[i]..", "..tests.output[i])
end


print(runCircuit(fourBitDecoder,12))


local searchSettings = {
    addMass = 1,
    deleteMass = 1,
    inputSwapMass = 1,
    lutChangeMass = 1,
    totalIterations = 1000000,
    iterationsBetweenRestarts = 100000,
    beta = 1.0,
    weightCorrect = 1.0,
    weightCritical = 1.0,
    weightSize = 1.0
}
print("Before search")
local bestCircuit, bestCost, improved, correctCircuits = stochasticSearch(fourBitDecoder, tests, {}, searchSettings)
bestCost = 0
print("Best Cost: "..bestCost)
--
