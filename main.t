--[[

Prototype implementation of STOIL, STOKE for icestick LUTs

Author: Michael Mara, mmara@cs.stanford.edu

TODO: Better LUT value manipulation

TODO: Faster circuit manipulation

--]]
local stoil = require("stoil")
require("util")
local coreir = require("coreir")
local circuit = stoil.circuit
math.randomseed(123498)


local ss = table.shallowcopy(stoil.defaultSearchSettings)
ss.maxInternalNodes = 20
ss.weightSize = 0.01
ss.weightCritical = 10
ss.weightCorrect = 0.5
ss.totalIterations = 40000000
ss.iterationsBetweenRestarts = 4000000
ss.beta = 1.0
ss.lutChangeMass = 5
ss.inputSwapMass = 5

local settings = {}
settings["Add4_synth"] = ss
settings["Sub4_synth"] = ss

ss = table.shallowcopy(ss)
ss.iterationsBetweenRestarts = 1000000
settings["Add4"] = ss
settings["Sub4"] = ss

ss = table.shallowcopy(ss)
ss.maxInternalNodes = 30
ss.iterationsBetweenRestarts = 8000000
ss.weightCorrect = 0.25
settings["Add5_synth"] = ss
settings["Sub5_synth"] = ss

ss = table.shallowcopy(ss)
ss.iterationsBetweenRestarts = 1000000
settings["Add5"] = ss
settings["Sub5"] = ss

ss = table.shallowcopy(ss)
ss.maxInternalNodes = 100
ss.iterationsBetweenRestarts = 1000000
ss.weightCorrect = 0.0025
settings["Add8"] = ss
settings["Sub8"] = ss


ss = table.shallowcopy(ss)
ss.maxInternalNodes = 40
ss.iterationsBetweenRestarts = 4000000
ss.weightCorrect = 0.025
ss.lutChangeMass = 2
ss.inputSwapMass = 2

ss = table.shallowcopy(ss)
ss.maxInternalNodes = 20
ss.iterationsBetweenRestarts = 8000000
ss.weightCorrect = 1.0
settings["pop7"] = ss

ss = table.shallowcopy(ss)
ss.weightCorrect = 10.0
settings["mul3"] = ss
settings["mul2"] = ss

ss = table.shallowcopy(ss)
ss.maxInternalNodes = 80
settings["mul4"] = ss

ss = table.shallowcopy(ss)
ss.weightCorrect = 1.0
ss.maxInternalNodes = 40
settings["pop10"] = ss
settings["pop9"] = ss

ss = table.shallowcopy(ss)
ss.maxInternalNodes = 40
settings["pop15"] = ss
settings["pop16"] = ss



local function getFullTest(name, doSynth)
    local loadedCircuit = coreir.load("circuits/"..name..".json")
    local testSettings = {
        inputMin = 0,
        inputMax = math.pow(2,#loadedCircuit.inputs-2)-1,
        testCount = 32,
        validationCount = -1 -- If negative, use full range of inputs to generate validation
    }
    local tests, validation = stoil.testAndValidationSet(stoil.wrapCircuit(loadedCircuit), testSettings)
    local setName = name
    if doSynth then
        loadedCircuit = circuit.emptyCircuit(#loadedCircuit.inputs-2,#loadedCircuit.outputs)
        setName = setName.."_synth"
    end
    return loadedCircuit, tests, validation, settings[setName]
end


local function getHLSTest(name, func, inputBits, outputBits, tCount, extraTests)
    local circ = circuit.emptyCircuit(inputBits,outputBits)
    local testSettings = {
        inputMin = 0,
        inputMax = math.pow(2,inputBits)-1,
        testCount = tCount,
        validationCount = -1 -- If negative, use full range of inputs to generate validation
    }
    local tests, validation = stoil.testAndValidationSet(func, testSettings)
    if extraTests then
        for i,t in ipairs(extraTests) do
            local test = {}
            test.input = t[1]
            test.output = t[2]
            tests[#tests + 1] = test
        end
    end
    return circ, tests, validation, settings[name]
end

local function populationCount(input)
    local result = 0
    for i=1,32 do
        if hasbit(input, bit(i)) then
            result = result + 1
        end
    end
    return result
end

local function mul(bitCount)
    local maxVal = math.pow(2,bitCount)
    local function mult(input)
        local a = input % maxVal
        local b = (input - a)/ maxVal
        return a*b
    end
    return mult
end
local theName = "Sub8"
--local loadedCircuit, tests, validation, searchSettings = getFullTest(theName, false)
local hlsTestParams = {}
local pop10Tests = { {1023,10}, {1022,9}, {1021,9}, {511,9}, {510,8} } 
hlsTestParams["pop10"] = {func = populationCount, inbits = 10, outbits = 4, testCount = 16, extraTests = pop10Tests}
hlsTestParams["pop7"] = {func = populationCount, inbits = 7, outbits = 3, testCount = 16}
local mul4Tests = { {221,169}, {255,225}, {159,135} }
hlsTestParams["mul4"] = {func = mul(4), inbits = 8, outbits = 8, testCount = 16, extraTests = mul4Tests}
hlsTestParams["mul3"] = {func = mul(3), inbits = 6, outbits = 6, testCount = 16}
hlsTestParams["mul2"] = {func = mul(2), inbits = 4, outbits = 4, testCount = 16}
local hlsName = "mul4"
local hlsP = hlsTestParams[hlsName]
--theName = hlsName
local loadedCircuit, tests, validation, searchSettings = getHLSTest(hlsName,hlsP.func,hlsP.inbits,hlsP.outbits,hlsP.testCount, hlsP.extraTests)
local x = os.clock()
--local bestCircuit, bestCost, improved, correctCircuits = stoil.search(loadedCircuit, tests, validation, searchSettings)
local bestCircuit = stoil.tsearch(loadedCircuit, tests, validation, searchSettings, "out/best", "out/current")
print(string.format("elapsed time: %.2f\n", os.clock() - x))
--print("Best Cost: "..bestCost)
local cCirc, circType = circuit.createTerraCircuit(bestCircuit, searchSettings.maxInternalNodes)
cCirc():toGraphviz("out/final")
--circuit.createTerraCircuit(bestCircuit):toGraphviz("out/final"..i)

--
