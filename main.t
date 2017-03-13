--[[

Prototype implementation of STOIL, STOKE for icestick LUTs

Author: Michael Mara, mmara@cs.stanford.edu

TODO: integrate https://github.com/silentbicycle/lunatest

TODO: Add graphviz support

TODO: JIT compile simulator

TODO: Better LUT value manipulation

TODO: Faster circuit manipulation

--]]
require("stoil")

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
toGraphviz(fourBitDecoder, "default")
print("fourBitDecoder")
--printGraph(deepCopy(fourBitDecoder))

local tests = createTestSuite(fourBitDecoder, jcounterStates)

for i=1,#tests do
    print(tests[i].input..", "..tests[i].output)
end


print(runCircuit(fourBitDecoder,12))


local searchSettings = {
    addMass = 1,
    deleteMass = 1,
    inputSwapMass = 1,
    lutChangeMass = 1,
    totalIterations = 200000,
    iterationsBetweenRestarts = 200000,
    maxInternalNodes = 6,
    minInternalNodes = 0,
    beta = 1.0,
    weightCorrect = 3.0,
    weightCritical = 1.0,
    weightSize = 1.0
}
print("Before search")
--for i=1,3 do setLUTValue(fourBitDecoder.internalNodes[i], 0) end

for i=1,3 do deleteNode(fourBitDecoder, fourBitDecoder.internalNodes[1]) end
for i=1,10 do 
    local bestCircuit, bestCost, improved, correctCircuits = stochasticSearch(fourBitDecoder, tests, {}, searchSettings)
    print("Best Cost: "..bestCost)
    toGraphviz(bestCircuit, "out/final"..i)
end

--
