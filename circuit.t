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
    return wire
end

function getInputWires(node)
    local result = {}
    for i,input in ipairs(node.inputs) do
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
        print("Clearing")
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
    return wires
end

function makeConsistent(circuit)
    circuit.wires = getWireArray(circuit)
    topologicalSort(circuit.internalNodes)
end

function deleteNode(circuit, node)
    local oldIndex = table.invert(circuit.internalNodes)[node]
    table.remove(circuit.internalNodes, oldIndex)
    local outWires = getOutputWires(node)
    local inWires = getInputWires(node)
    local passThrough = {}
    for i,wire in ipairs(inWires) do
        if wire.indexInOut == 1 then
            -- TODO: randomize?
            passThrough = wire.input
            wire.input.outputs[wire.indexInIn] = node.outputs[1]
        else 
            table.remove(wire.input.outputs, wire.indexInIn)
        end
    end
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
    return circuit.internalNodes[internalNodeIndex]
end

function nonInputNodeCount(circuit)
    return #circuit.internalNodes + #circuit.outputs
end

local function addDownstreamNodes(node, downstreamNodeSet)
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
    if node.type ~= NodeType.OUTPUT then
        addDownstreamNodes(node, downstreamNodesSansOutputs)
    end
    local upNodes = {}
    for i,v in ipairs(circuit.internalNodes) do
        if not downstreamNodesSansOutputs[v] do
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
    if nonInputNodeIndex > #circuit.internalNodes[internalNodeIndex] then
        local i = nonInputNodeIndex - #circuit.internalNodes
        return circuit.outputs[i]
    else
        return circuit.internalNodes[internalNodeIndex]
    end
    assert(false,"selectInternalNode index too large")
end

function selectWire(circuit, wireIndex)
    return circuit.wires[wireIndex]
end



function deepCopy(circuit)
    local newCircuit = {}
    newCircuit.inputs = {}
    newCircuit.internalNodes = {}
    newCircuit.outputs = {}
    local oldToNew = {}
    for i=1,#circuit.inputs do 
        newCircuit.inputs[i] = table.shallowcopy(circuit.inputs[i])
        oldToNew[circuit.inputs[i]] = newCircuit.inputs[i]
    end
    for i=1,#circuit.outputs do 
        newCircuit.outputs[i] = table.shallowcopy(circuit.outputs[i])
        oldToNew[circuit.outputs[i]] = newCircuit.outputs[i]
    end
    for i=1,#circuit.internalNodes do 
        newCircuit.internalNodes[i] = table.shallowcopy(circuit.internalNodes[i])
        oldToNew[circuit.internalNodes[i]] = newCircuit.internalNodes[i]
    end
    -- Now node references at top level are fixed, need to fix all internal references
    for oldN,newN in pairs(oldToNew) do
        for i,v in ipairs(newN.inputs) do
            newN.inputs[i] = oldToNew[v]
        end
        for i,v in ipairs(newN.outputs) do
            newN.outputs[i] = oldToNew[v]
        end
        for i,v in ipairs(newN.internalNodes) do
            newN.internalNodes[i] = oldToNew[v]
        end
    end
    newCircuit.wires = getWireArray(newCircuit)
    -- Topo sorting is maintained during deep copy
    return newCircuit
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
    node.inputs     = inputs
    node.outputs    = {output}
    node.lutValue   = lutValue
    node.type       = NodeType.INTERNAL
    return node
end

function setLUTValue(node, lutValue)
    assert(node.lutValue, "Tried to assign lut value to non-lut node")
    node.lutValue = lutValue
end

function addLUTNode(graph, inputs, wire, lutValue)
    local node = LUTNode(inputs,wire.output,lutValue)
    wire.output.inputs[wire.indexInOut] = node
    wire.input.outputs[wire.indexInIn]  = node
    graph.internalNodes[#graph.internalNodes+1] = node
    graph.wires = getWireArray(graph)
    topologicalSort(graph.internalNodes)
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