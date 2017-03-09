--[[

Prototype implementation of STOIL, STOKE for icestick LUTs

Author: Michael Mara, mmara@cs.stanford.edu

--]]

local NodeType = {INTERNAL = {}, INPUT = {}, OUTPUT = {}}

local function topologicalSort()
    assert(false,"TODO: implement topologicalSort()")
end

local function deleteNode(circuit, node)
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

local function setInput(node,index,inputNode)
    assert(false,"TODO: implement setInput(node,index,inputNode)")
end

local function selectNonInputNode(circuit, internalNodeIndex)
    assert(false,"TODO: implement selectInternalNode(circuit, index)")
end

local function selectWire(graph, wireIndex)
    assert(false, "implement selectWire")
end

local function getWireArray(graph)
    assert(false, "implement getWireArray")
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
    -- TODO: something with val?
    return InputNode()
end

local function OutputNode(inputNode)
    local node = {}
    node.type = NodeType.OUTPUT
    node.inputs = {inputNode}
    return node
end

local function LutNode(inputs,output,lutValue)
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
    node = LUTNode(inputs,output,lutValue)
    wire.output[wire.indexInOut] = node
    wire.input[wire.indexInIn]   = node
    graph.internalNodes[#graph.internalNodes+1] = node
    graph.wires = getWireArray()
end



local function emptyGraph(inputsCount, outputCount)
    local graph = {}
    graph.inputs = {}
    for i=1,inputsCount do 
        graph.inputs = InputNode() 
    end
    groundNode = ConstNode(0)
    powerNode  = ConstNode(1)
    graph.inputs[inputsCount+1] = groundNode
    graph.inputs[inputsCount+2] = powerNode
    for i=1,outputCount do 
        graph.outputs = OutputNode(groundNode) 
    end
    graph.wires = getWireArray(graph)
    graph.internalNodes = {}
    graph.topoSortedNodes = {}
    graph.topoSorted = false
end

local function sizeCost(circuit)
    return #circuit.internalNodes
end

local function criticalPathLength(circuit)
    assert(false,"TODO: implement criticalPathLength()")
end

local function criticalCost(circuit)
    critPathLength = 0
    for _,node in circuit.outputs
        critPathLength = max(critPathLength,criticalPathLength(node))
    end
    return critPathLength
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
local addRewrite(original, rnd) do
    newCircuit = deepCopy(original)
    wire = selectWire(newCircuit, math.ceil(rnd*wireCount(original))
    -- TODO: should we select inputs at random upstream from parent node?
    inputs = {wire.input, newCircuit.ground, newCircuit.ground, newCircuit.ground}
    -- TODO: should this not be random?
    lutValue = math.random(math.pow(2,16))-1
    node = addLUTNode(newCircuit, inputs, wire.output, lutValue)
    return newCircuit
end

local deleteRewrite(original, rnd) do
    newCircuit = deepCopy(original)
    node = selectInternalNode(newCircuit, math.ceil(rnd*internalNodeCount(original)))
    deleteNode(newCircuit, node)
    return newCircuit
end

local inputSwapRewrite(original, rnd) do
    newCircuit = deepCopy(original)
    node,isOutput = selectNonInputNode(newCircuit, math.ceil(rnd*nonInputNodeCount(original)))
    potentialInputs = upstreamNodes(newCircuit,node)
    chosenInput = potentialInputs[math.ceil(rnd*(#potentialInputs)]
    if isOutput then
        setInput(node, 1, chosenInput)
    else
        i = math.random(4)
        setInput(node, i, chosenInput)
    end
    return newCircuit
end

local lutChangeRewrite(original, rnd) do
    newCircuit = deepCopy(original)
    node = selectInternalNode(newCircuit, math.ceil(rnd*internalNodeCount(original)))
    -- TODO: should this not be random?
    lutValue = math.random(math.pow(2,16))-1
    setLUTValue(node, lutValue)
    return newCircuit
end

local createRewrite(currentCircuit, settings)
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



local testCases
local validationCases
