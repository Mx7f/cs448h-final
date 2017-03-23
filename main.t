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
ss.maxInternalNodes = 400
ss.totalIterations = 400000000
ss.iterationsBetweenRestarts = 1000000
ss.weightCorrect  = 1.0
ss.weightCritical = 0.0
ss.weightSize = 1.0
ss.lutChangeMass = 2
ss.inputSwapMass = 2
settings["SBOX"] = ss

ss = table.shallowcopy(ss)
ss.weightCritical = 1.0
ss.weightSize = 0.01
ss.lutChangeMass = 5
ss.inputSwapMass = 5
ss.iterationsBetweenRestarts = 1000000
settings["Add5"] = ss
settings["Sub5"] = ss

ss = table.shallowcopy(ss)
ss.maxInternalNodes = 40
ss.iterationsBetweenRestarts = 16000000
ss.weightCorrect = 0.05
settings["Add6_synth"] = ss
settings["Sub6_synth"] = ss

ss = table.shallowcopy(ss)
ss.iterationsBetweenRestarts = 2000000
settings["Add6"] = ss
settings["Sub6"] = ss

ss = table.shallowcopy(ss)
ss.maxInternalNodes = 60
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
settings["mul3i2"] = ss
ss = table.shallowcopy(ss)
ss.maxInternalNodes = 40
settings["mul3i3"] = ss

ss = table.shallowcopy(ss)
ss.iterationsBetweenRestarts = 80000000
ss.maxInternalNodes = 60
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

local sbox = {
  --0     1    2      3     4    5     6     7      8    9     A      B    C     D     E     F
  0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
  0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
  0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
  0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
  0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
  0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
  0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
  0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
  0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
  0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
  0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
  0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
  0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
  0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
  0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
  0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16 }
local function computeSBox(inp)  
  return sbox[inp+1]
end

local function getFullTest(name, doSynth)
    local loadedCircuit = coreir.load("circuits/"..name..".json")
    local testSettings = {
        inputMin = 0,
        inputMax = math.pow(2,#loadedCircuit.inputs-2)-1,
        testCount = 16,
        validationCount = -1 -- If negative, use full range of inputs to generate validation
    }
    print("Circuit has "..#loadedCircuit.inputs.." inputs, "..#loadedCircuit.outputs.." outputs, "..#loadedCircuit.internalNodes.." internalNodes")
    if name == "SBOX" then
        local sbox2 = stoil.wrapCircuit(loadedCircuit)
        for i=0,255 do
            print(computeSBox(i).." vs "..sbox2(i))
        end
    end
    print("inputMax:"..testSettings.inputMax)
    local tests, validation = stoil.testAndValidationSet(stoil.wrapCircuit(loadedCircuit), testSettings)
    print("testAndValidationSet Generated")
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

local function mul3i(bitCount)
    local maxVal = math.pow(2,bitCount)
    local function mult(input)
        local a = input % maxVal
        local r = (input - a) / maxVal
        local b = r % maxVal
        local c = (r-b) / maxVal
        return a*b*c
    end
    return mult
end

local theName = "SBOX"
local loadedCircuit, tests, validation, searchSettings = getFullTest(theName, false)

local hlsTestParams = {}
local pop10Tests = { {1023,10}, {1022,9}, {1021,9}, {511,9}, {510,8} } 
hlsTestParams["pop10"] = {func = populationCount, inbits = 10, outbits = 4, testCount = 16, extraTests = pop10Tests}
hlsTestParams["pop7"] = {func = populationCount, inbits = 7, outbits = 3, testCount = 16}
local mul4Tests = { {221,169}, {255,225}, {159,135} }
hlsTestParams["mul4"] = {func = mul(4), inbits = 8, outbits = 8, testCount = 16, extraTests = mul4Tests}
hlsTestParams["mul3"] = {func = mul(3), inbits = 6, outbits = 6, testCount = 16}
hlsTestParams["mul2"] = {func = mul(2), inbits = 4, outbits = 4, testCount = 16}
hlsTestParams["mul3i3"] = {func = mul3i(3), inbits = 9, outbits = 9, testCount = 16}
hlsTestParams["mul3i2"] = {func = mul3i(2), inbits = 6, outbits = 6, testCount = 16}
hlsTestParams["SBOX"] = {func = computeSBox, inbits = 8, outbits = 8, testCount = 32}

--print(computeSBox(255))
local hlsName = "SBOX"
local hlsP = hlsTestParams[hlsName]
--theName = hlsName
--local loadedCircuit, tests, validation, searchSettings = getHLSTest(hlsName,hlsP.func,hlsP.inbits,hlsP.outbits,hlsP.testCount, hlsP.extraTests)
local x = os.clock()
--local bestCircuit, bestCost, improved, correctCircuits = stoil.search(loadedCircuit, tests, validation, searchSettings)
print("Search Beginning")
local bestCircuit = stoil.tsearch(loadedCircuit, tests, validation, searchSettings, "out/best", "out/current")
print(string.format("elapsed time: %.2f\n", os.clock() - x))
--print("Best Cost: "..bestCost)
local cCirc, circType = circuit.createTerraCircuit(bestCircuit, searchSettings.maxInternalNodes)
cCirc():toGraphviz("out/final")
--circuit.createTerraCircuit(bestCircuit):toGraphviz("out/final"..i)

--
