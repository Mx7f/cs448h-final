require("simulation")
require("tablehelpers")

NodeType = {INTERNAL={},INPUT={},OUTPUT={}}

function nodeTypeString(typ)
    if typ == NodeType.INTERNAL then
        return "INTERNAL"
    end
    if typ == NodeType.INPUT then
        return "INPUT"
    end
    if typ == NodeType.OUTPUT then
        return "OUTPUT"
    end
end

function printNode(node)
    print("BEGIN_NODE")
    print("  type = "..nodeTypeString(node.type))
    if node.inputs and #node.inputs > 0 then
        io.write("  inputs[", tostring(#node.inputs), "] = {")
        for i,input in ipairs(node.inputs) do
            io.write(nodeTypeString(input.type), ", ")
        end
        io.write("}\n")
    end
    if node.outputs and #node.outputs > 0 then
        io.write("  outputs[", tostring(#node.outputs), "] = {")
        for i,output in ipairs(node.outputs) do
            io.write(nodeTypeString(output.type), ", ")
        end
        io.write("}\n")
    end
    if node.lutValue then
        print("  lutValue = "..string.format("%x", node.lutValue))
    end
    print("END_NODE")
end

function printGraph(graph)
    print("inputs")
    for i,input in ipairs(graph.inputs) do
        printNode(input)
    end
    print("internal")
    for i,node in ipairs(graph.internalNodes) do
        printNode(node)
    end
    print("outputs")
    for i,output in ipairs(graph.outputs) do
        printNode(output)
    end
end

local function Wire(input, output)
    local wire = {}
    wire.input = input
    wire.output = output
    wire.indexInOut = table.invert(output.inputs)[input]
    wire.indexInIn = table.invert(input.outputs)[output]
    if not wire.indexInIn then
        print("No indexInIn")
        print("input: "..tostring(input))
        print("output: "..tostring(output))
        print(nodeTypeString(wire.input.type))
        print(nodeTypeString(wire.output.type))
        print("#input.outputs = "..#input.outputs)
        for i,v in ipairs(input.outputs) do
            print("input.outputs[i] = "..nodeTypeString(v.type))
        end
    end
    if not wire.indexInOut then
        print("No indexInOut")
        print(nodeTypeString(wire.input.type))
        print(nodeTypeString(wire.output.type))
        print("#output.inputs = "..#output.inputs)
        for i,v in ipairs(output.inputs) do
            print("output.inputs[i] = "..nodeTypeString(v.type))
        end

    end
    --assert(wire.indexInOut, "No indexInOut")
    --assert(wire.indexInIn, "No indexInIn")
    return wire
end

function getInputWires(node)
    local result = {}
    for i,input in ipairs(node.inputs) do
        print(tostring(node.inputs[i]).." -> "..tostring(node))
        result[i] = Wire(node.inputs[i],node)
    end
    return result
end

function getOutputWires(node)
    local result = {}
    for i,input in ipairs(node.outputs) do
        result[i] = Wire(node, node.outputs[i])
    end
    return result
end

function visit(node, newNodes)
    node.marked = true
    for i,m in ipairs(node.outputs) do
        if m.type == NodeType.INTERNAL then
            visit(m, newNodes)
        end
    end
    newNodes[#newNodes+1] = node
end

function topologicalSort(nodes)
    
    for i,v in ipairs(nodes) do
        v.marked = false
    end

    local newNodes = {}
    for i,v in ipairs(nodes) do
        if not v.marked then
            visit(v, newNodes)
        end
    end

    for i,v in ipairs(newNodes) do
        -- inline reverse
        nodes[i] = newNodes[#newNodes-i+1]
    end
end

function getWireArray(circuit)
    local wires = {}
    for i,output in ipairs(circuit.outputs) do
        wires = table.concat(wires, getInputWires(output))
    end
    for i,node in ipairs(circuit.internalNodes) do
        wires = table.concat(wires, getInputWires(node))
    end
    print("wireArray size: "..#wires)
    return wires
end

function makeConsistent(circuit)
    circuit.wires = getWireArray(circuit)
    topologicalSort(circuit.internalNodes)
end

function deleteNode(circuit, node)
    print("deleteNode")
    local oldIndex = table.invert(circuit.internalNodes)[node]
    table.remove(circuit.internalNodes, oldIndex)
    local outWires = getOutputWires(node)
    local inWires = getInputWires(node)
    local passThrough = {}
     print("patching outputs "..#inWires)
    for i,wire in ipairs(inWires) do
        if wire.indexInOut == 1 then
            -- TODO: randomize?
            print("First index")
            print(nodeTypeString(wire.input.type))
            print(nodeTypeString(wire.output.type))
            if not wire.indexInIn then
                print("No indexInIn in deleteNode")
            end
            print("wire.indexInIn: "..(wire.indexInIn))
            print("Changing wire.indexInIn/#wire.input.outputs "..wire.indexInIn.."/"..#wire.input.outputs)
            passThrough = wire.input

            wire.input.outputs[wire.indexInIn] = node.outputs[1]
        else 
            print("Removing")
            table.remove(wire.input.outputs, wire.indexInIn)
        end
    end
    print("patching inputs "..#outWires)
    for i,wire in ipairs(outWires) do
        if wire.indexInIn == 1 then
            -- TODO: randomize?
            wire.output.inputs[wire.indexInOut] = passThrough
        else 
            -- TODO: randomize?
            wire.output.inputs[wire.indexInOut] = circuit.groundNode
        end
    end
    makeConsistent(circuit)
end

function selectInternalNode(circuit, internalNodeIndex)
    print("selectInternalNode("..internalNodeIndex..")")
    return circuit.internalNodes[internalNodeIndex]
end

function nonInputNodeCount(circuit)
    return #circuit.internalNodes + #circuit.outputs
end

function addDownstreamNodes(node, downstreamNodeSet)
    for i,v in ipairs(node.outputs) do
        if v.type ~= NodeType.OUTPUT then
            downstreamNodeSet[v] = true
            addDownstreamNodes(v)
        end
    end
end

function upstreamNodes(circuit, node)
    local downstreamNodesSansOutputs = {}
    downstreamNodesSansOutputs[node] = true
    --print("upstreamNodes")
    if node.type ~= NodeType.OUTPUT then
        addDownstreamNodes(node, downstreamNodesSansOutputs)
    end
    local upNodes = {}
    for i,v in ipairs(circuit.internalNodes) do
        if not downstreamNodesSansOutputs[v] then
            upNodes[#upNodes+1] = v
        end
    end
    for i,v in ipairs(circuit.inputs) do
        upNodes[#upNodes+1] = v
    end
    return upNodes
end

function setInput(circuit,node,index,inputNode)
    local wire = getInputWires(node)[index]
    table.remove(wire.input.outputs[wire.indexInIn])
    node.inputs[index] = inputNode
    inputNode.outputs[#inputNode.outputs+1] = node
    makeConsistent(circuit.internalNodes)
end

function selectNonInputNode(circuit, nonInputNodeIndex)
    print("selectNonInputNode")
    if nonInputNodeIndex > #circuit.internalNodes[internalNodeIndex] then
        local i = nonInputNodeIndex - #circuit.internalNodes
        return circuit.outputs[i], true
    else
        return circuit.internalNodes[internalNodeIndex], false
    end
    assert(false,"selectNonInputNode index too large")
end

function wireCount(circuit)
    return #circuit.wires
end

function selectWire(circuit, wireIndex)
    return circuit.wires[wireIndex]
end

function twoLevelCopyNode(node)
    local copiedNode = table.shallowcopy(node)
    if copiedNode.inputs then
        copiedNode.inputs = table.shallowcopy(node.inputs)
    end
    if copiedNode.outputs then
        copiedNode.outputs = table.shallowcopy(node.outputs)
    end
    return copiedNode
end

function deepCopy(circuit)
    print("Before Deep Copy")
    getWireArray(circuit)
    print("Deep copy")
    local newCircuit = {}
    newCircuit.inputs = {}
    newCircuit.internalNodes = {}
    newCircuit.outputs = {}
    local oldToNew = {}
    for i=1,#circuit.inputs do 
        newCircuit.inputs[i] = twoLevelCopyNode(circuit.inputs[i])
        if oldToNew[circuit.inputs[i]] then
            print("==== DUPLICATE CIRCUIT IN DEEP COPY (INPUTS): "..tostring(oldToNew[circuit.inputs[i]]))
        end
        oldToNew[circuit.inputs[i]] = newCircuit.inputs[i]
    end
    for i=1,#circuit.outputs do 
        newCircuit.outputs[i] = twoLevelCopyNode(circuit.outputs[i])
        if oldToNew[circuit.outputs[i]] then
            print("==== DUPLICATE CIRCUIT IN DEEP COPY (OUTPUTS): "..tostring(oldToNew[circuit.outputs[i]]))
        end
        oldToNew[circuit.outputs[i]] = newCircuit.outputs[i]
    end
    for i=1,#circuit.internalNodes do 
        newCircuit.internalNodes[i] = twoLevelCopyNode(circuit.internalNodes[i])
        if oldToNew[circuit.internalNodes[i]] then
            print("==== DUPLICATE CIRCUIT IN DEEP COPY (INTERNAL): "..tostring(oldToNew[circuit.internalNodes[i]]))
        end
        oldToNew[circuit.internalNodes[i]] = newCircuit.internalNodes[i]
    end
    -- Now node references at top level are fixed, need to fix all internal references

    for oldN,newN in pairs(oldToNew) do
        print("old: "..tostring(oldN))
        print("new: "..tostring(newN))
        if newN.inputs and #newN.inputs > 0 then
            for i,v in ipairs(newN.inputs) do
                newN.inputs[i] = oldToNew[v]
            end
        end
        if newN.outputs and #newN.outputs > 0 then
            for i,v in ipairs(newN.outputs) do
                newN.outputs[i] = oldToNew[v]
            end
        end
    end
    newCircuit.wires = getWireArray(newCircuit)
    -- Topo sorting is maintained during deep copy
    print("Deep copy done")
    return newCircuit
end

function internalNodeCount(circuit)
    return #circuit.internalNodes
end

local function InputNode()
    local node = {}
    node.type = NodeType.INPUT
    node.outputs = {}
    return node
end

local function ConstNode(val)
    local node = InputNode()
    node.val = val
    return node
end

local function OutputNode(inputNode)
    local node = {}
    node.type = NodeType.OUTPUT
    node.inputs = {inputNode}
    return node
end

local function LUTNode(inputs,output,lutValue)
    local node      = {}
    node.inputs     = table.shallowcopy(inputs)
    node.outputs    = {output}
    node.lutValue   = lutValue
    node.type       = NodeType.INTERNAL
    return node
end

function setLUTValue(node, lutValue)
    assert(node.lutValue, "Tried to assign lut value to non-lut node")
    node.lutValue = lutValue
end

function nodeSanityCheck(circuit)
    print("NODE SANITY CHECK")
    local validNodes = {}
    for i,v in ipairs(circuit.inputs) do validNodes[v] = true end
    for i,v in ipairs(circuit.outputs) do validNodes[v] = true end
    for i,v in ipairs(circuit.internalNodes) do validNodes[v] = true end
    print("SETUP DONE")
    for k,v in pairs(validNodes) do
        if (k.outputs) and #k.outputs > 0 then
            for i,node in ipairs(k.outputs) do
                if not validNodes[node] then
                    print("INVALID NODE FOUND IN OUTPUT "..i.." OF "..nodeTypeString(k.type))
                    print("Claims to be "..nodeTypeString(node.type))
                else
                    if not table.invert(node.inputs)[k] then
                        print("FOUND MISMATCHING WIRE IN OUTPUT "..i.." OF "..nodeTypeString(k.type))
                    end
                end
            end
        end
        if (k.inputs) and #k.inputs > 0 then
            for i,node in ipairs(k.inputs) do
                if not validNodes[node] then
                    print("INVALID NODE FOUND IN INPUT "..i.." OF "..nodeTypeString(k.type))
                    print("Claims to be "..nodeTypeString(node.type))
                else
                    if not table.invert(node.outputs)[k] then
                        print("FOUND MISMATCHING WIRE IN INPUT "..i.." OF "..nodeTypeString(k.type))
                    end
                end
            end
        end
    end
    print("NODE SANITY CHECK DONE")
end

function isNode(circuit, node)
    local validNodes = {}
    for i,v in ipairs(circuit.inputs) do validNodes[v] = true end
    for i,v in ipairs(circuit.outputs) do validNodes[v] = true end
    for i,v in ipairs(circuit.internalNodes) do validNodes[v] = true end
    return validNodes[node] ~= nil
end

function addLUTNode(graph, inputs, wire, lutValue)
    for i,v in ipairs(inputs) do
        print(isNode(graph,v))
    end
    print(isNode(graph,wire.input))
    print(isNode(graph,wire.output))

    local node = LUTNode(inputs,wire.output,lutValue)
    print("Adding lut node, wire.indexInIn "..wire.indexInIn)
    print(wire.input.outputs[wire.indexInIn])
    print(wire.output)
    wire.output.inputs[wire.indexInOut] = node

    table.remove(wire.input.outputs,wire.indexInIn)
    for i,v in ipairs(inputs) do
        v.outputs[#v.outputs + 1]  = node
    end
    
    graph.internalNodes[#graph.internalNodes+1] = node

    topologicalSort(graph.internalNodes)
    graph.wires = getWireArray(graph)
    print("LUTNODE added")
end

function emptyGraph(inputsCount, outputCount)
    local graph = {}
    graph.inputs = {}
    for i=1,inputsCount do 
        graph.inputs[i] = InputNode() 
    end
    local groundNode = ConstNode(false)
    local powerNode  = ConstNode(true)
    graph.inputs[inputsCount+1] = groundNode
    graph.inputs[inputsCount+2] = powerNode
    graph.outputs = {}
    for i=1,outputCount do 
        graph.outputs[i] = OutputNode(groundNode) 
        groundNode.outputs[#groundNode.outputs + 1] = graph.outputs[i]
    end
    graph.internalNodes = {}
    graph.wires = getWireArray(graph)
    return graph
end

function createTestSuite(circuit, inputs)
    local tests = {}
    tests.input = inputs
    tests.output = {}
    for i=1,#inputs do
        tests.output[i] = runCircuit(circuit,tests.input[i])
    end
    return tests
end
