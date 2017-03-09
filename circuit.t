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


function deleteNode(circuit, node)
    topologicalSort(circuit.internalNodes)
    assert(false,"TODO: implement deleteNode(circuit, node)")
end

function selectInternalNode(circuit, internalNodeIndex)
    assert(false,"TODO: implement selectInternalNode(circuit, index)")
end

function nonInputNodeCount(circuit)
    assert(false,"TODO: nonInputNodeCount(circuit)")
end

function upstreamNodes(circuit)
    assert(false,"TODO: implement upstreamNodes(circuit, index)")
end

function setInput(circuit,node,index,inputNode)
    topologicalSort(circuit.internalNodes)
    assert(false,"TODO: implement setInput(node,index,inputNode)")
end

function selectNonInputNode(circuit, internalNodeIndex)
    assert(false,"TODO: implement selectInternalNode(circuit, index)")
end

function selectWire(graph, wireIndex)
    assert(false, "implement selectWire")
end

function deepCopy(circuit)
    local newCircuit = {}
    assert(false,"TODO: implement deepCopy(circuit)")
    return newCircuit
end

function getWireArray(graph)
    local wires = {}
    for i,output in ipairs(graph.outputs) do
        wires = table.concat(wires, getInputWires(output))
    end
    for i,node in ipairs(graph.internalNodes) do
        wires = table.concat(wires, getInputWires(node))
    end
    return wires
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