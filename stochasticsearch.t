require("circuit")
require("bithelpers")
require("simulation")

function evaluate(circuit, test)
    out = runCircuit(circuit, test.input)
    return hammingDistance(test.output, out)
end

local function sizeCost(circuit)
    return #circuit.internalNodes
end

local function furthestDistanceToInput(node)
    local distance = 0
    if node.inputs then
        for i,v in ipairs(node.inputs) do
            local dist = furthestDistanceToInput(v)+1
            distance = math.max(distance, dist)
        end
    end
    return distance
end

local function criticalPathLength(circuit)
    local maxPathLength = 0
    for i,v in ipairs(circuit.outputs) do
        local dist = furthestDistanceToInput(v)
        maxPathLength = math.max(maxPathLength, dist)
    end
    return maxPathLength
end

local function criticalCost(circuit)
    local critPathLength = criticalPathLength(circuit)
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

local function cost(proposal, testCases, validationCases, settings)
    local errCost = errorCost(proposal, testCases, validationCases)
    print("error cost: "..errCost)
    local totalCost = errCost*settings.weightCorrect + criticalCost(proposal)*settings.weightCritical + sizeCost(proposal)*settings.weightSize
    print("total cost "..totalCost)
    return totalCost, errCost 
end

local function totalProposalMass(settings)
    return settings.addMass + settings.deleteMass + settings.inputSwapMass + settings.lutChangeMass
end

--
local function addRewrite(original, rnd) 
    local newCircuit = deepCopy(original)
    print("About to select wire")
    local wire = selectWire(newCircuit, math.ceil(rnd*wireCount(original)))
    -- TODO: should we select inputs at random upstream from parent node?
    local inputs = {wire.input, newCircuit.ground, newCircuit.ground, newCircuit.ground}
    -- TODO: should this not be random?
    local lutValue = math.random(math.pow(2,16))-1
    print("About to add LUT")
    addLUTNode(newCircuit, inputs, wire, lutValue)
    return newCircuit
end

local function deleteRewrite(original, rnd)
    local newCircuit = deepCopy(original)
    local node = selectInternalNode(newCircuit, math.ceil(rnd*internalNodeCount(original)))
    deleteNode(newCircuit, node)
    return newCircuit
end

local function inputSwapRewrite(original, rnd)
    local newCircuit = deepCopy(original)
    local node,isOutput = selectNonInputNode(newCircuit, math.ceil(rnd*nonInputNodeCount(original)))
    print("Getting potential inputs")
    local potentialInputs = upstreamNodes(newCircuit,node)
    print("Selecting input")
    local chosenInput = potentialInputs[math.ceil(rnd*(#potentialInputs))]
    print("Setting Input")
    if isOutput then
        setInput(newCircuit, node, 1, chosenInput)
    else
        local i = math.random(4)
        setInput(newCircuit, node, i, chosenInput)
    end
    print("Set")
    return newCircuit
end

local function lutChangeRewrite(original, rnd)
    print("in lutChangeRewrite")
    local newCircuit = deepCopy(original)
    print("making index")
    local index = math.ceil(rnd*internalNodeCount(original))
    print("about to select")
    local node = selectInternalNode(newCircuit, index)
    print("selectInternalNode")
    -- TODO: should this not be random?
    local lutValue = math.random(math.pow(2,16))-1
    setLUTValue(node, lutValue)
    print("lutValue")
    return newCircuit
end

local function createRewrite(currentCircuit, settings)
    local massSum = totalProposalMass(settings)
    print("massSum: "..massSum)
    local r = math.random()*massSum

    if r < settings.addMass then
        print("addRewrite")
        return addRewrite(currentCircuit, r/settings.addMass)
    end
    r = r - settings.addMass

    if r < settings.deleteMass then
        print("deleteMass")
        return deleteRewrite(currentCircuit, r/settings.deleteMass)
    end
    r = r - settings.deleteMass

    if r < settings.inputSwapMass then
        print("inputSwapRewrite")
        return inputSwapRewrite(currentCircuit, r/settings.inputSwapMass)
    end
    r = r - settings.inputSwapMass

    if r < settings.lutChangeMass then
        print("lutChangeRewrite")
        return lutChangeRewrite(currentCircuit, r/settings.lutChangeMass)
    end

    assert(false,"Reached what should be probability 0 case in createRewrite() with r = "..r)
end

function acceptRewrite(rewriteCost, previousCost, settings)
    print("acceptRewrite")
-- Equation 5: https://raw.githubusercontent.com/StanfordPL/stoke/develop/docs/papers/cacm16.pdf
    local acceptProbability = math.min(1.0, math.exp(-settings.beta*(rewriteCost-previousCost)))
    print("acceptProbability="..acceptProbability)
    return acceptProbability >= math.random()
end

function stochasticSearch(initialCircuit, testSet, validationSet, settings)
    print("Stochastic Search")
    local currentCircuit = initialCircuit
    local currentCost,currentCorrectCost = cost(initialCircuit, testSet, validationSet, settings)
    print("Initial correctness cost: "..currentCorrectCost)
    local bestCost = currentCost
    local initialCost = currentCost
    local bestCircuit = currentCircuit
    local correctCircuits = {}
    for i=1,settings.totalIterations do
        if ((i-1) % settings.iterationsBetweenRestarts) == 0 then
            currentCircuit = initialCircuit
            currentCost = cost(initialCircuit, testSet, validationSet, settings)
            local independentSearchCount = (i-1) / settings.iterationsBetweenRestarts
            print("------------------------------")
            print("    Independent Search "..independentSearchCount)
            print("------------------------------")
            print("Cost of initial circuit: "..currentCost)
        end
        local rewriteCircuit = createRewrite(currentCircuit,settings)
        print("Rewritten")
        local rewriteCost,rewriteCorrectnessCost = cost(rewriteCircuit, testSet, validationSet, settings)
        nodeSanityCheck(rewriteCircuit)
        print("========")
        nodeSanityCheck(currentCircuit)
        if acceptRewrite(currentCost, rewriteCost, settings) then
            print("Iteration "..i.." Rewrite accepted with cost: "..rewriteCost..", correctness cost: "..rewriteCorrectnessCost)
            currentCost = rewriteCost
            currentCorrectCost = rewriteCorrectnessCost
            currentCircuit = rewriteCircuit
            if currentCorrectCost == 0 and currentCost < bestCost then
                print("======= NEW BEST CIRCUIT ======")
                correctCircuits[#correctCircuits + 1] = currentCircuit
                bestCost = currentCost
                bestCircuit = currentCircuit
            end
        else
            print("Rewrite rejected")
        end
    end
    return bestCircuit, bestCost, bestCost < initalCost, correctCircuits
end
