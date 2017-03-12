require("bithelpers")
require("circuit")
function setInputVal(circuit, input)
    for i=1,#circuit.inputs-2 do
        circuit.inputs[i].val = hasbit(input, bit(i))
    end
end

function evalLUT(node)
    local index = 0
    for i, input in ipairs(node.inputs) do
        if input.val then
            index = setbit(index, bit(i))
        end
    end
    return hasbit(node.lutValue, bit(index))
end

function runCircuit(circuit, input)
    setInputVal(circuit, input)
    for i,node in ipairs(circuit.internalNodes) do
        node.val = evalLUT(node)
    end
    local output = 0
    for i,node in ipairs(circuit.outputs) do
        if #node.inputs < 1 then
            printNode(node)
            toGraphviz(circuit, "out/error")
            assert(false)
        end
        if node.inputs[1].val then
            output = setbit(output, bit(i))
        end
    end
    return output
end

function createTestSuite(circuit, inputs)
    local tests = {}
    for i=1,#inputs do
        local test = {}
        test.input = inputs[i]
        test.output = runCircuit(circuit,test.input)
        tests[i] = test
    end
    return tests
end