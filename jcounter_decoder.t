local stoil = require("stoil")
local circuit = stoil.circuit

local decoders = {}
function decoders.fourBit()
    local fourBitDecoder = circuit.emptyCircuit(4,3)

    local regularInputs = table.slice(fourBitDecoder.inputs, 1, 4)

    local jcounterStates = {0, 1, 3, 7, 15, 14, 12, 8}
    local js = jcounterStates
    local onesLUT = setBits({js[2]+1, js[4]+1, js[6]+1, js[8]+1})
    local outputWires1 = circuit.getInputWires(fourBitDecoder.outputs[1])
    circuit.addLUTNode(fourBitDecoder, regularInputs, outputWires1[1], onesLUT)

    local twosLUT = setBits({js[3]+1, js[4]+1, js[7]+1, js[8]+1})
    local outputWires2 = circuit.getInputWires(fourBitDecoder.outputs[2])
    circuit.addLUTNode(fourBitDecoder, regularInputs, outputWires2[1], twosLUT)

    local foursLUT = setBits({js[5]+1, js[6]+1, js[7]+1, js[8]+1})
    local outputWires3 = circuit.getInputWires(fourBitDecoder.outputs[3])
    circuit.addLUTNode(fourBitDecoder, regularInputs, outputWires3[1], foursLUT)

    return fourBitDecoder, jcounterStates
end
return decoders

