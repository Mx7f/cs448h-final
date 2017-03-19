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
require("util")
local coreir = require("coreir")
local circuit = stoil.circuit

local loadedCircuit = coreir.load("circuits/Add4.json")
local testSettings = {
    inputMin = 0,
    inputMax = 255,
    testCount = 16,
    validationCount = -1 -- If negative, use full range of inputs to generate validation
}
local tests, validation = stoil.testAndValidationSet(stoil.wrapCircuit(loadedCircuit), testSettings)

for k,v in pairs(validation) do 
    print(v.input) 
    print(v.output)
end

local searchSettings = stoil.defaultSearchSettings
searchSettings.maxInternalNodes = 20
searchSettings.weightSize = 0.01

print(circuit.runCircuitInTerra(loadedCircuit,17))

print("Before search")

--for i=1,3 do circuit.deleteNode(fourBitDecoder, fourBitDecoder.internalNodes[1]) end
for i=1,10 do 
    local x = os.clock()
    local bestCircuit, bestCost, improved, correctCircuits = stoil.search(loadedCircuit, tests, validation, searchSettings)
    print(string.format("elapsed time: %.2f\n", os.clock() - x))
    print("Best Cost: "..bestCost)
    circuit.toGraphviz(bestCircuit, "out/final"..i)
end

--
