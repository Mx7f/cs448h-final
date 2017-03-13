require("bithelpers")
require("util")
local cc = require("circuit")
local sim = require("simulation")

local ss = {}
local function evaluate(circuit, test)
    local out = sim.runCircuit(circuit, test.input)
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
    log.trace(#testCases, " testCases")
    for _,test in ipairs(testCases) do
        testResult = testResult + evaluate(proposal,test)
    end
    log.info("Raw test case score ", testResult)
    -- Adjustment to make sure failing N tests is worse than failing N+1 validation cases
    -- after passing all test cases
    testResult = testResult * (#validationCases + 1)
    log.info("Adjusted test case score ", testResult)
    if testResult == 0 then
        log.info("Proposal passed all tests, running validation")
        for _,test in ipairs(validationCases) do
            testResult = testResult + evaluate(proposal,test)
        end
        log.info("Final test case score ", testResult)
        if testResult == 0 then
            log.info("validation cases failed: ", testResult)
        end
    end
    return testResult
end

local function cost(proposal, testCases, validationCases, settings)
    local errCost = errorCost(proposal, testCases, validationCases)
    log.info("error cost: "..errCost)
    local totalCost = errCost*settings.weightCorrect + criticalCost(proposal)*settings.weightCritical + sizeCost(proposal)*settings.weightSize
    log.info("total cost "..totalCost)
    return totalCost, errCost 
end

local function totalProposalMass(settings)
    return settings.addMass + settings.deleteMass + settings.inputSwapMass + settings.lutChangeMass
end

--
local function addRewrite(original, rnd) 
    local newCircuit = cc.deepCopy(original)
    log.trace("About to select wire")
    local wire = cc.selectWire(newCircuit, math.ceil(rnd*cc.wireCount(newCircuit)))
    -- TODO: should we select inputs at random upstream from parent node?
    local inputs = {wire.input, cc.getGround(newCircuit), cc.getGround(newCircuit), cc.getGround(newCircuit)}
    -- TODO: should this not be random?
    local lutValue = math.random(math.pow(2,16))-1
    log.trace("About to add LUT")
    cc.addLUTNode(newCircuit, inputs, wire, lutValue)
    return newCircuit
end

local function deleteRewrite(original, rnd)
    local newCircuit = cc.deepCopy(original)
    local nodeIndex = math.ceil(rnd*cc.internalNodeCount(newCircuit))
    local node = cc.selectInternalNode(newCircuit, nodeIndex)
    cc.deleteNode(newCircuit, node)
    return newCircuit
end

local function inputSwapRewrite(original, rnd)
    local newCircuit = cc.deepCopy(original)
    local node,isOutput = cc.selectNonInputNode(newCircuit, math.ceil(rnd*cc.nonInputNodeCount(original)))
    log.trace("Getting potential inputs")
    local potentialInputs = cc.upstreamNodes(newCircuit,node)
    log.info(#potentialInputs, " potential inputs")
    log.trace("Selecting input")
    local newInputIndex = math.random(#potentialInputs)
    local chosenInput = potentialInputs[newInputIndex]
    log.trace("Setting Input")
    if isOutput then
        cc.setInputOfNode(newCircuit, node, 1, chosenInput)
    else
        local i = math.random(4)
        cc.setInputOfNode(newCircuit, node, i, chosenInput)
    end
    log.trace("Set")
    return newCircuit
end

local function lutChangeRewrite(original, rnd)
    log.trace("in lutChangeRewrite")
    local newCircuit = cc.deepCopy(original)
    log.trace("making index")
    local index = math.ceil(rnd*cc.internalNodeCount(newCircuit))
    log.trace("about to select")
    local node = cc.selectInternalNode(newCircuit, index)
    log.trace("selectInternalNode")
    -- TODO: should this not be random?
    local lutValue = math.random(math.pow(2,16))-1
    cc.setLUTValue(node, lutValue)
    log.trace("lutValue")
    return newCircuit
end

local function createRewrite(currentCircuit, settings)
    local massSum = totalProposalMass(settings)
    local N = #currentCircuit.internalNodes
    if N <= settings.minInternalNodes then
        massSum = massSum - settings.deleteMass
    end
    if N >= settings.maxInternalNodes then
        massSum = massSum - settings.addMass
    end
    if N == 0 then
        massSum = massSum - settings.lutChangeMass
    end
    log.debug("massSum: "..massSum)
    local r = math.random()*massSum

    if N < settings.maxInternalNodes then
        if r < settings.addMass then
            log.info("addRewrite")
            return addRewrite(currentCircuit, r/settings.addMass)
        end
        r = r - settings.addMass
    end

    if N > settings.minInternalNodes then
        if r < settings.deleteMass then
            log.info("deleteMass")
            return deleteRewrite(currentCircuit, r/settings.deleteMass)
        end
        r = r - settings.deleteMass
    end

    if r < settings.inputSwapMass then
        log.info("inputSwapRewrite")
        return inputSwapRewrite(currentCircuit, r/settings.inputSwapMass)
    end
    r = r - settings.inputSwapMass

    if N > 0 and r < settings.lutChangeMass then
        log.info("lutChangeRewrite")
        return lutChangeRewrite(currentCircuit, r/settings.lutChangeMass)
    end

    assert(false,"Reached what should be probability 0 case in createRewrite() with r = "..r)
end

local function acceptRewrite(rewriteCost, previousCost, settings)
    log.trace("acceptRewrite")
-- Equation 5: https://raw.githubusercontent.com/StanfordPL/stoke/develop/docs/papers/cacm16.pdf
    local acceptProbability = math.min(1.0, math.exp(-settings.beta*(rewriteCost-previousCost)))
    log.info("acceptProbability="..acceptProbability)
    return acceptProbability >= math.random()
end

function ss.stochasticSearch(initialCircuit, testSet, validationSet, settings)
    log.trace("Stochastic Search")
    local currentCircuit = initialCircuit
    local currentCost,currentCorrectCost = cost(initialCircuit, testSet, validationSet, settings)
    print("Initial correctness cost: "..currentCorrectCost)
    local bestCost = currentCost
    local bestIncorrectCost = currentCost
    local initialCost = currentCost
    local bestCircuit = currentCircuit
    local correctCircuits = {}
    local endCircuits = {}
    for i=1,settings.totalIterations do
        if ((i-1) % settings.iterationsBetweenRestarts) == 0 then
            currentCircuit = initialCircuit
            currentCost = cost(initialCircuit, testSet, validationSet, settings)
            bestIncorrectCost = currentCost
            local independentSearchCount = (i-1) / settings.iterationsBetweenRestarts
            print("------------------------------")
            print("    Independent Search "..independentSearchCount)
            print("------------------------------")
            print("Cost of initial circuit: "..currentCost)
        end
        local rewriteCircuit = createRewrite(currentCircuit,settings)
        log.trace("Rewritten")
        local rewriteCost,rewriteCorrectnessCost = cost(rewriteCircuit, testSet, validationSet, settings)
        if log.level == "debug" or log.level == "trace" then 
            cc.nodeSanityCheck(currentCircuit)
            print("========")
            cc.nodeSanityCheck(rewriteCircuit)
        end
        if acceptRewrite(rewriteCost, currentCost, settings) then
            log.info("Iteration "..i.." Rewrite accepted with cost: "..rewriteCost..", correctness cost: "..rewriteCorrectnessCost)
            currentCost = rewriteCost
            currentCorrectCost = rewriteCorrectnessCost
            currentCircuit = rewriteCircuit
            if currentCorrectCost == 0 and currentCost < bestCost then
                print("======================= NEW BEST CIRCUIT "..i.." =========================")
                print("Cost: "..currentCost)
                if log.level == "debug" or log.level == "trace" then
                    cc.toGraphviz(currentCircuit, "out/correct"..(#correctCircuits + 1))
                end
                correctCircuits[#correctCircuits + 1] = currentCircuit
                bestCost = currentCost
                bestCircuit = currentCircuit
            elseif currentCorrectCost == 0 and currentCost == bestCost then
                log.info("----- Equivalent best circuit: "..i)
            elseif currentCost < bestCost then
                log.info("----- Incorrect lower cost circuit: "..i)
                if currentCost < bestIncorrectCost then
                    bestIncorrectCost = currentCost
                    if log.level == "debug" or log.level == "trace" then
                        cc.toGraphviz(currentCircuit, "out/incorrect_cost"..bestIncorrectCost)
                    end
                end
            end
        else
            log.info("Rewrite rejected")
        end
        if i % 100000 == 0 then
            print("Iteration: "..i)
        end
        if ((i % settings.iterationsBetweenRestarts) == 0) or i == settings.totalIterations then
            if log.level == "debug" or log.level == "trace" then
                cc.toGraphviz(currentCircuit, "out/lastCircuit"..(i / settings.iterationsBetweenRestarts))
            end
            endCircuits[#endCircuits+1] = currentCircuit
        end
    end
    return bestCircuit, bestCost, bestCost < initialCost, correctCircuits
end
return ss
