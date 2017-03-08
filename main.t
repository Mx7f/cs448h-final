--[[

Prototype implementation of STOIL, STOKE for icestick LUTs

Author: Michael Mara, mmara@cs.stanford.edu

--]]

local function topologicalSort()
    assert(false,"TODO: implement topologicalSort()")
end
local function InputNode()
    assert(false,"TODO: implement InputNode()")
end
local function ConstNode()
    assert(false,"TODO: implement ConstNode()")
end
local function OutputNode()
    assert(false,"TODO: implement OutputNode()")
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
    graph.internalNodeCount = 0
end

local function sizeCost(circuit)
    return circuit.internalNodeCount
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

local function deepCopy(circuit)
    local newCircuit = {}
    assert(false,"TODO: implement deepCopy(circuit)")
    return newCircuit
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
    r = r - settings.lutChangeMass

    else
        assert(false,"Reached what should be probability 0 case in createRewrite() with r = "..r)
    end
end



--instruction_mass 1 # Proposal mass
--local_swap_mass 1 # Proposal mass
--opcode_mass 1 # Proposal mass
--operand_mass 1 # Proposal mass

local testCases
local validationCases
