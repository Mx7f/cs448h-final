--[[

Prototype implementation of STOIL, STOKE for icestick LUTs

Author: Michael Mara, mmara@cs.stanford.edu

TODO: integrate https://github.com/silentbicycle/lunatest

TODO: Add graphviz support

TODO: JIT compile simulator

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
printGraph(fourBitDecoder)

print(runCircuit(fourBitDecoder,12))
