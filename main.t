--[[

Prototype implementation of STOIL, STOKE for icestick LUTs

Author: Michael Mara, mmara@cs.stanford.edu

TODO: integrate https://github.com/silentbicycle/lunatest

TODO: Add graphviz support

TODO: JIT compile simulator

--]]


function bit(p)
  return 2 ^ (p - 1)  -- 1-based indexing
end

-- Typical call:  if hasbit(x, bit(3)) then ...
function hasbit(x, p)
  return x % (p + p) >= p       
end

function setbit(x, p)
  return hasbit(x, p) and x or x + p
end

function clearbit(x, p)
  return hasbit(x, p) and x - p or x
end

function table.invert(t)
  local u = { }
  for k, v in pairs(t) do u[v] = k end
  return u
end

function table.slice(tbl, first, last, step)
  local sliced = {}

  for i = first or 1, last or #tbl, step or 1 do
    sliced[#sliced+1] = tbl[i]
  end

  return sliced
end

function table.concat(t1,t2)
    for i=1,#t2 do
        t1[#t1+1] = t2[i]
    end
    return t1
end

local NodeType = {INTERNAL={},INPUT={},OUTPUT={}}

local function nodeTypeString(typ)
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

local function printNode(node)
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

local function printGraph(graph)
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

local function getInputWires(node)
    local result = {}
    for i,input in ipairs(node.inputs) do
        result[i] = Wire(node.inputs[i],node)
    end
    return result
end

local function visit(node, newNodes)
    node.marked = true
    for i,m in ipairs(node.outputs) do
        if m.type == NodeType.INTERNAL then
            visit(m, newNodes)
        end
    end
    newNodes[#newNodes+1] = node
end

local function topologicalSort(nodes)
    
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


local function deleteNode(circuit, node)
    topologicalSort(circuit.internalNodes)
    assert(false,"TODO: implement deleteNode(circuit, node)")
end

local function selectInternalNode(circuit, internalNodeIndex)
    assert(false,"TODO: implement selectInternalNode(circuit, index)")
end

local function nonInputNodeCount(circuit)
    assert(false,"TODO: nonInputNodeCount(circuit)")
end

local function upstreamNodes(circuit)
    assert(false,"TODO: implement upstreamNodes(circuit, index)")
end

local function setInput(circuit,node,index,inputNode)
    topologicalSort(circuit.internalNodes)
    assert(false,"TODO: implement setInput(node,index,inputNode)")
end

local function selectNonInputNode(circuit, internalNodeIndex)
    assert(false,"TODO: implement selectInternalNode(circuit, index)")
end

local function selectWire(graph, wireIndex)
    assert(false, "implement selectWire")
end

local function getWireArray(graph)
    local wires = {}
    for i,output in ipairs(graph.outputs) do
        wires = table.concat(wires, getInputWires(output))
    end
    for i,node in ipairs(graph.internalNodes) do
        wires = table.concat(wires, getInputWires(node))
    end
    return wires
end

local function deepCopy(circuit)
    local newCircuit = {}
    assert(false,"TODO: implement deepCopy(circuit)")
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

local function setLUTValue(node, lutValue)
    assert(node.lutValue, "Tried to assign lut value to non-lut node")
    node.lutValue = lutValue
end

local function addLUTNode(graph, inputs, wire, lutValue)
    local node = LUTNode(inputs,wire.output,lutValue)
    wire.output.inputs[wire.indexInOut] = node
    wire.input.outputs[wire.indexInIn]  = node
    graph.internalNodes[#graph.internalNodes+1] = node
    graph.wires = getWireArray(graph)
    topologicalSort(graph.internalNodes)
end

local function emptyGraph(inputsCount, outputCount)
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

local function sizeCost(circuit)
    return #circuit.internalNodes
end

local function criticalPathLength(circuit)
    assert(false,"TODO: implement criticalPathLength()")
end

local function criticalCost(circuit)
    critPathLength = 0
    for _,node in circuit.outputs do
        critPathLength = max(critPathLength,criticalPathLength(node))
    end
    return critPathLength
end

local function hammingDistance(x,y)
  local p = 1
  while p < x do p = p + p end
  while p < y do p = p + p end
  local dist = 0
  repeat
    if (p <= x) ~= (p <= y) then
        dist = dist + 1
    end
    if p <= x then x = x - p end
    if p <= y then y = y - p end
    p = p * 0.5
  until p < 1
  return dist
end

local function setInputVal(circuit, input)
    print("Setting input vals")
    for i=1,#circuit.inputs-2 do
        circuit.inputs[i].val = hasbit(input, bit(i))
    end
    print("input vals set")
end

local function evalLUT(node)
    print("evalLUT "..#node.inputs)
    local index = 0
    for i, input in ipairs(node.inputs) do
        if input.val then
            index = setbit(index, bit(i))
        end
    end
    print("index is "..index)
    return hasbit(node.lutValue, bit(index))
end

local function runCircuit(circuit, input)
    setInputVal(circuit, input)
    for i,node in ipairs(circuit.internalNodes) do
        node.val = evalLUT(node)
    end
    local output = 0
    for i,node in ipairs(circuit.outputs) do
        if node.inputs[1].val then
            output = setbit(output, bit(i))
        end
    end
    return output
end

local function evaluate(circuit, test)
    out = runCircuit(circuit, test.input)
    return hammingDistance(test.output, out)
end

local function errorCost(proposal, testCases, validationCases)
    local testResult = 0
    for _,test in ipairs(testCases) do
        testResult = testResult + evaluate(proposal,test)
    end
    -- Adjustment to make sure failing N tests is worse than failing N+1 validation cases
    -- after passing all test cases
    testResult = testResult * (#validationCases)

    if testResult == 0 then
        print("Proposal passed all tests, running validation")
        for _,test in ipairs(validationCases) do
            testResult = testResult + evaluate(proposal,test)
        end
        if testResult == 0 then
            print("validation cases failed: "..testResult)
        end
    end
    return testResult
end

local function cost(proposal, testCases, validationCases, weightCorrect, weightCritical, weightSize)
    local errCost = errorCost(proposal, testCases, validationCases)
    local totalCost = errCost*weightCorrect + criticalCost(proposal)*weightCritical + sizeCost(proposal)*weightSize
    return errCost, totalCost
end

local function totalProposalMass(settings)
    return settings.addMass + settings.deleteMass + settings.inputSwapMass + settings.lutChangeMass
end

--
local function addRewrite(original, rnd) 
    newCircuit = deepCopy(original)
    wire = selectWire(newCircuit, math.ceil(rnd*wireCount(original)))
    -- TODO: should we select inputs at random upstream from parent node?
    inputs = {wire.input, newCircuit.ground, newCircuit.ground, newCircuit.ground}
    -- TODO: should this not be random?
    lutValue = math.random(math.pow(2,16))-1
    node = addLUTNode(newCircuit, inputs, wire, lutValue)
    return newCircuit
end

local function deleteRewrite(original, rnd)
    newCircuit = deepCopy(original)
    node = selectInternalNode(newCircuit, math.ceil(rnd*internalNodeCount(original)))
    deleteNode(newCircuit, node)
    return newCircuit
end

local function inputSwapRewrite(original, rnd)
    newCircuit = deepCopy(original)
    node,isOutput = selectNonInputNode(newCircuit, math.ceil(rnd*nonInputNodeCount(original)))
    potentialInputs = upstreamNodes(newCircuit,node)
    chosenInput = potentialInputs[math.ceil(rnd*(#potentialInputs))]
    if isOutput then
        setInput(newCircuit, node, 1, chosenInput)
    else
        i = math.random(4)
        setInput(newCircuit, node, i, chosenInput)
    end
    return newCircuit
end

local function lutChangeRewrite(original, rnd)
    newCircuit = deepCopy(original)
    node = selectInternalNode(newCircuit, math.ceil(rnd*internalNodeCount(original)))
    -- TODO: should this not be random?
    lutValue = math.random(math.pow(2,16))-1
    setLUTValue(node, lutValue)
    return newCircuit
end

local function createRewrite(currentCircuit, settings)
    massSum = totalProposalMass(settings)
    local r = math.random()*massSum

    if r < settings.addMass then
        return addRewrite(currentCircuit, r/settings.addMass)
    end
    r = r - settings.addMass

    if r < settings.deleteMass then
        return deleteRewrite(currentCircuit, r/settings.deleteMass)
    end
    r = r - settings.deleteMass

    if r < settings.inputSwapMass then
        return inputSwapRewrite(currentCircuit, r/settings.inputSwapMass)
    end
    r = r - settings.inputSwapMass

    if r < settings.lutChangeMass then
        return lutChangeRewrite(currentCircuit, r/settings.lutChangeMass)
    end

    assert(false,"Reached what should be probability 0 case in createRewrite() with r = "..r)
end

local fourBitDecoder = emptyGraph(4,3)
local regularInputs = table.slice(fourBitDecoder.inputs, 1, 4)


local function setBits(bits)
    local result = 0
    for i,b in ipairs(bits) do
        result = setbit(result, bit(b))
    end
    return result
end


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
