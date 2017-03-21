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


local time = os.clock()
local errorCost = 0
for i=0,100 do
    for _,test in ipairs(validation) do
        errorCost = errorCost + hammingDistance(test.output, stoil.runCircuit(loadedCircuit, test.input))
    end
end
print(string.format("elapsed time: %.5f", os.clock() - time))
print("Lua simulate "..tostring(errorCost))


local tCircuitGen,tCircuitType = circuit.createTerraCircuit(loadedCircuit)
local tCirc = tCircuitGen()
loadedCircuit = circuit.terraCircuitToLuaCircuit(tCirc)
circuit.toGraphviz(loadedCircuit, "roundtrip")
local tSet = circuit.createTerraTestSet(validation)
errorCost = 0
time = os.clock()
for i=0,100 do
    errorCost = errorCost + tCirc:hammingErrorOnTestSet(tSet)
end
print(string.format("elapsed time: %.5f", os.clock() - time))
print("Terra simulate "..tostring(errorCost))

local searchSettings = stoil.defaultSearchSettings
searchSettings.maxInternalNodes = 100
searchSettings.weightSize = 0.01
searchSettings.weightCritical = 1
searchSettings.weightCorrect = 0.00001
searchSettings.totalIterations = 100000000
searchSettings.iterationsBetweenRestarts = 10000000
searchSettings.beta = 0.01

print("Before search")
math.randomseed(123498)
--for i=1,3 do circuit.deleteNode(fourBitDecoder, fourBitDecoder.internalNodes[1]) end
for i=1,10 do 
    local x = os.clock()
    --local bestCircuit, bestCost, improved, correctCircuits = stoil.search(loadedCircuit, tests, validation, searchSettings)
    local bestCircuit = stoil.tsearch(loadedCircuit, tests, validation, searchSettings)
    print(string.format("elapsed time: %.2f\n", os.clock() - x))
    --print("Best Cost: "..bestCost)
    circuit.toGraphviz(bestCircuit, "out/final"..i)
end

--
