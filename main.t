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

local loadedCircuit = coreir.load("circuits/Add8.json")
local testSettings = {
    inputMin = 0,
    inputMax = math.pow(2,16)-1,
    testCount = 64,
    validationCount = -1 -- If negative, use full range of inputs to generate validation
}
local tests, validation = stoil.testAndValidationSet(stoil.wrapCircuit(loadedCircuit), testSettings)



local searchSettings = stoil.defaultSearchSettings
searchSettings.maxInternalNodes = 50
searchSettings.weightSize = 0.01
searchSettings.weightCritical = 10
searchSettings.weightCorrect = 0.005
searchSettings.totalIterations = 1000000000
searchSettings.iterationsBetweenRestarts = 100000000
searchSettings.beta = 1.0
searchSettings.lutChangeMass = 5
searchSettings.inputSwapMass = 5


loadedCircuit = circuit.emptyCircuit(16,9)
print("Before search")
math.randomseed(123498)
--for i=1,3 do circuit.deleteNode(fourBitDecoder, fourBitDecoder.internalNodes[1]) end

--loadedCircuit = circuit.emptyCircuit(8,5)
for i=1,10 do 
    local x = os.clock()
    --local bestCircuit, bestCost, improved, correctCircuits = stoil.search(loadedCircuit, tests, validation, searchSettings)
    local bestCircuit = stoil.tsearch(loadedCircuit, tests, validation, searchSettings)
    print(string.format("elapsed time: %.2f\n", os.clock() - x))
    --print("Best Cost: "..bestCost)
    local cCirc, circType = circuit.createTerraCircuit(bestCircuit, searchSettings.maxInternalNodes)
    cCirc():toGraphviz("out/final"..i)
    --circuit.createTerraCircuit(bestCircuit):toGraphviz("out/final"..i)
end

--
