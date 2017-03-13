--[[

Prototype implementation of STOIL, STOKE for icestick LUTs

Author: Michael Mara, mmara@cs.stanford.edu

TODO: integrate https://github.com/silentbicycle/lunatest

TODO: Add graphviz support

TODO: JIT compile simulator

TODO: Better LUT value manipulation

TODO: Faster circuit manipulation

--]]
local stoil = require("stoil")
local circuit = stoil.circuit
local jdecoders = require("jcounter_decoder")
local fourBitDecoder,testInputs = jdecoders.fourBit()

local tests = stoil.createTestSuite(fourBitDecoder, testInputs)


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

for i=1,3 do circuit.deleteNode(fourBitDecoder, fourBitDecoder.internalNodes[1]) end
for i=1,10 do 
    print(searchSettings)
    print(fourBitDecoder)
    local bestCircuit, bestCost, improved, correctCircuits = stoil.search(fourBitDecoder, tests, {}, searchSettings)
    print("Best Cost: "..bestCost)
    circuit.toGraphviz(bestCircuit, "out/final"..i)
end

--
