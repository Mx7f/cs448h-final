require("simulation")
require("tablehelpers")
require("util")
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
    if not wire.indexInOut then
        log.trace("No indexInOut")
        log.trace(nodeTypeString(wire.input.type))
        log.trace(nodeTypeString(wire.output.type))
        log.trace("#output.inputs = ", #output.inputs)
        for i,v in ipairs(output.inputs) do
            log.trace("output.inputs[i] = ", nodeTypeString(v.type))
        end

    end
    --assert(wire.indexInOut, "No indexInOut")
    --assert(wire.indexInIn, "No indexInIn")
    return wire
end

function getInputWires(node)
    local result = {}
    for i,input in ipairs(node.inputs) do
        log.trace(tostring(node.inputs[i])," -> ",tostring(node))
        result[i] = Wire(node.inputs[i],node)
    end
    return result
end

function visit(node, newNodes)
    node.marked = true
    for i,m in ipairs(node.inputs) do
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
        --nodes[i] = newNodes[#newNodes-i+1]
        nodes[i] = v
    end
end

function getWireArray(circuit)
    local wires = {}
    for i,output in ipairs(circuit.outputs) do
        wires = table.concattables(wires, getInputWires(output))
    end
    for i,node in ipairs(circuit.internalNodes) do
        wires = table.concattables(wires, getInputWires(node))
    end
    log.debug("wireArray size: "..#wires)
    return wires
end

function makeConsistent(circuit)
    circuit.wires = getWireArray(circuit)
    topologicalSort(circuit.internalNodes)
end

function deleteNode(circuit, node)
    log.trace("deleteNode")
    log.trace("patching inputs")
    for i,wire in ipairs(circuit.wires) do
        if wire.input == node then
            --TODO: randomize?
            wire.output.inputs[wire.indexInOut] = node.inputs[1]
        end
    end
    log.trace("Actual removal")
    local oldIndex = table.invert(circuit.internalNodes)[node]
    table.remove(circuit.internalNodes, oldIndex)
    makeConsistent(circuit)
end

function selectInternalNode(circuit, internalNodeIndex)
    log.trace("selectInternalNode("..internalNodeIndex..")")
    return circuit.internalNodes[internalNodeIndex]
end

function nonInputNodeCount(circuit)
    return #circuit.internalNodes + #circuit.outputs
end


--TODO: check if downstream nodes are really downstream?
function upstreamNodes(circuit, node)
    local upNodes = {}
    for i,v in ipairs(circuit.internalNodes) do
        if node == v then
            break
        end
        upNodes[#upNodes+1] = v
    end
    for i,v in ipairs(circuit.inputs) do
        upNodes[#upNodes+1] = v
    end
    return upNodes
end

function setInput(circuit,node,index,inputNode)
    node.inputs[index] = inputNode
    log.trace("Input set. Making consistent")
    makeConsistent(circuit)
end

function selectNonInputNode(circuit, nonInputNodeIndex)
    log.trace("selectNonInputNode")
    if nonInputNodeIndex > #circuit.internalNodes then
        local i = nonInputNodeIndex - #circuit.internalNodes
        return circuit.outputs[i], true
    else
        return circuit.internalNodes[nonInputNodeIndex], false
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
    return copiedNode
end

function deepCopy(circuit)
    log.trace("Deep copy")
    local newCircuit = {}
    newCircuit.inputs = {}
    newCircuit.internalNodes = {}
    newCircuit.outputs = {}
    local oldToNew = {}
    for i=1,#circuit.inputs do 
        newCircuit.inputs[i] = twoLevelCopyNode(circuit.inputs[i])
        if oldToNew[circuit.inputs[i]] then
            log.error("==== DUPLICATE CIRCUIT IN DEEP COPY (INPUTS): "..tostring(oldToNew[circuit.inputs[i]]))
            assert(false)
        end
        oldToNew[circuit.inputs[i]] = newCircuit.inputs[i]
    end
    for i=1,#circuit.outputs do 
        newCircuit.outputs[i] = twoLevelCopyNode(circuit.outputs[i])
        if oldToNew[circuit.outputs[i]] then
            log.error("==== DUPLICATE CIRCUIT IN DEEP COPY (OUTPUTS): "..tostring(oldToNew[circuit.outputs[i]]))
            assert(false)
        end
        oldToNew[circuit.outputs[i]] = newCircuit.outputs[i]
    end
    for i=1,#circuit.internalNodes do 
        newCircuit.internalNodes[i] = twoLevelCopyNode(circuit.internalNodes[i])
        if oldToNew[circuit.internalNodes[i]] then
            log.error("==== DUPLICATE CIRCUIT IN DEEP COPY (INTERNAL): "..tostring(oldToNew[circuit.internalNodes[i]]))
            assert(false)
        end
        oldToNew[circuit.internalNodes[i]] = newCircuit.internalNodes[i]
    end
    -- Now node references at top level are fixed, need to fix all internal references

    for oldN,newN in pairs(oldToNew) do
        log.trace("old: "..tostring(oldN))
        log.trace("new: "..tostring(newN))
        if newN.inputs and #newN.inputs > 0 then
            for i,v in ipairs(newN.inputs) do
                newN.inputs[i] = oldToNew[v]
            end
        end
    end
    newCircuit.wires = getWireArray(newCircuit)
    -- Topo sorting is maintained during deep copy
    log.trace("Deep copy done")
    return newCircuit
end

function internalNodeCount(circuit)
    return #circuit.internalNodes
end

local function InputNode()
    local node = {}
    node.type = NodeType.INPUT
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

local function LUTNode(inputs,lutValue)
    local node      = {}
    node.inputs     = table.shallowcopy(inputs)
    node.lutValue   = lutValue
    node.type       = NodeType.INTERNAL
    return node
end

function setLUTValue(node, lutValue)
    assert(node.lutValue, "Tried to assign lut value to non-lut node")
    node.lutValue = lutValue
end

function nodeSanityCheck(circuit)
    log.debug("NODE SANITY CHECK")
    local validNodes = {}
    for i,v in ipairs(circuit.inputs) do validNodes[v] = true end
    for i,v in ipairs(circuit.outputs) do validNodes[v] = true end
    for i,v in ipairs(circuit.internalNodes) do validNodes[v] = true end
    log.debug("SETUP DONE")
    for k,v in pairs(validNodes) do
        if (k.inputs) and #k.inputs > 0 then
            for i,node in ipairs(k.inputs) do
                if not validNodes[node] then
                    log.error("INVALID NODE FOUND IN INPUT ", i, " OF ", nodeTypeString(k.type))
                    log.error("Claims to be ", nodeTypeString(node.type))
                end
            end
        end
    end
    log.debug("NODE SANITY CHECK DONE")
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
        log.trace(isNode(graph,v))
    end
    log.trace(isNode(graph,wire.input))
    log.trace(isNode(graph,wire.output))

    local node = LUTNode(inputs,lutValue)
    wire.output.inputs[wire.indexInOut] = node
    
    graph.internalNodes[#graph.internalNodes+1] = node

    topologicalSort(graph.internalNodes)
    graph.wires = getWireArray(graph)
    log.debug("LUTNODE added")
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
    end
    graph.internalNodes = {}
    graph.wires = getWireArray(graph)
    return graph
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
