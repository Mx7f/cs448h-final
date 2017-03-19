package.path = package.path .. ';../luaunit/?.lua;../?.t' .. ';../log/?.lua' .. ';../lua-graphviz/?.lua' .. ';../json/?.lua'
EXPORT_ASSERT_TO_GLOBALS = nil
lu = require('luaunit')


require("bithelpers")

TestBits = {}
    function TestBits:testHamming()
        lu.assertEquals(hammingDistance(3,4), 3)
        lu.assertEquals(hammingDistance(16,8),2)
        lu.assertEquals(hammingDistance(127,9),5)
        lu.assertEquals(hammingDistance(4294967295,3),30)
    end

    function TestBits:testHasBit()
        local v = 0
        for i=1,32 do
            lu.assertEquals(hasbit(v, bit(i)), false)
        end 
        v = 4294967295
        for i=1,32 do
            lu.assertEquals(hasbit(v, bit(i)), true)
        end
        lu.assertEquals(hasbit(1, bit(1)), true)
        lu.assertEquals(hasbit(1, bit(2)), false)
        lu.assertEquals(hasbit(2, bit(1)), false)
        lu.assertEquals(hasbit(2, bit(2)), true)
        lu.assertEquals(hasbit(4, bit(3)), true)
    end
-- End TestBits

local stoil = require("stoil")
local coreir = require("coreir")
local circuits = stoil.circuit
local decoders = require("jcounter_decoder")

TestJDecoders = {}
    function TestJDecoders:testFourBit()
        local fourBitDecoder,testInputs = decoders.fourBit()
        for i,v in ipairs(testInputs) do
            local output = stoil.runCircuit(fourBitDecoder,v)
            lu.assertEquals(output, i-1)
        end
    end

TestAdders = {}
    function TestAdders:testAdd4()
        local loadedCircuit = coreir.load("../circuits/Add4.json")
        for i=1,20 do
            local a = math.random(16)-1
            local b = math.random(16)-1
            local input = (a*16)+b
            local output = stoil.runCircuit(loadedCircuit,input)
            lu.assertEquals(output, a+b)
        end
    end
    function TestAdders:testAdd8()
        local loadedCircuit = coreir.load("../circuits/Add8.json")
        for i=1,20 do
            local a = math.random(math.pow(2,8))-1
            local b = math.random(math.pow(2,8))-1
            local input = (a*math.pow(2,8))+b
            local output = stoil.runCircuit(loadedCircuit,input)
            lu.assertEquals(output, a+b)
        end
    end
    --[[
    function TestAdders:testAdd16()
        local loadedCircuit = coreir.load("../circuits/Add16.json")
        for i=1,20 do
            local a = math.random(math.pow(2,16))-1
            local b = math.random(math.pow(2,16))-1
            local input = (a*math.pow(2,16))+b
            local output = stoil.runCircuit(loadedCircuit,input)
            lu.assertEquals(output, a+b)
        end
    end
    --]]
--[[
TestAddersTerra = {}
    function TestAddersTerra:testAdd8Terra()
        local loadedCircuit = coreir.load("../circuits/Add8.json")
        for i=1,20 do
            local a = math.random(math.pow(2,8))-1
            local b = math.random(math.pow(2,8))-1
            local input = (a*math.pow(2,8))+b
            local output = circuit.runCircuitInTerra(loadedCircuit,input)
            lu.assertEquals(output, a+b)
        end
    end
--]]
os.exit( lu.LuaUnit.run() )