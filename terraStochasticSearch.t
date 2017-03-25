require("bithelpers")
require("util")
local cc = require("circuit")
local sim = require("simulation")

local ss = {}

local partialLUTRewrites = true

ss.defaultSearchSettings = {
    addMass = 1,
    deleteMass = 1,
    inputSwapMass = 1,
    lutChangeMass = 1,
    totalIterations = 10000000,
    iterationsBetweenRestarts = 1000000,
    maxInternalNodes = 100,
    minInternalNodes = 0,
    beta = 1.0,
    weightCorrect = 1.0,
    weightCritical = 1.0,
    weightSize = 1.0
}

local terra max(a : int32, b : int32)
    return terralib.select( a > b, a, b)
end

local terra min(a : double, b : double)
    return terralib.select( a < b, a, b)
end

local terra seedRand()
    C.srand(C.time([&int64](0)))
end
seedRand()


function ss.terraBasedStochasticSearch(initialCircuit, testCases, validationCases, settings, outBestName, outCurrentName)
    log.trace("Stochastic Search")
    local tCircuitGen,TerraCircuitType = cc.createTerraCircuit(initialCircuit, settings.maxInternalNodes)
    local valSet = cc.createTerraTestSet(validationCases)
    local tSet = cc.createTerraTestSet(testCases)
    local totalProposalMass = settings.addMass + settings.deleteMass + settings.inputSwapMass + settings.lutChangeMass
    local GROUND = #initialCircuit.inputs - 2

    print("Initial variables called")

    local terra lutToGlobalIndex(lutIndex : int32)
        return lutIndex + [#initialCircuit.inputs]
    end

    local terra addRewrite(circuit : &TerraCircuitType, r : double, rng : &C.pcg32_random_t)
        --C.printf("addRewrite\n")
        var newCircuit : TerraCircuitType = @circuit

        var wireCount : int32  = newCircuit.luts.N*4 + [#initialCircuit.outputs]
        --C.printf("wireCount = %d\n", wireCount)
        --C.printf("r = %f\n", r)
        var wireIndex : int32  = [int32](r*wireCount)
        var nodeIndex : int32  = newCircuit.luts.N
        var lutValue  : uint32 = randomu32(rng) and [uint32]([math.pow(2,16)-1])
        --C.printf("wireIndex: %d\n", wireIndex)
        --C.printf("lutValue: %d\n", lutValue)
        if wireIndex >= newCircuit.luts.N*4 then
            var outIndex = wireIndex - newCircuit.luts.N*4
            --C.printf("outIndex: %d\n", outIndex)
            var lutInput = newCircuit.outputs[outIndex].inputIndex
            var inp1 = randomu32(rng) % lutToGlobalIndex(nodeIndex)
            var inp2 = randomu32(rng) % lutToGlobalIndex(nodeIndex)
            var inp3 = randomu32(rng) % lutToGlobalIndex(nodeIndex)
            var inputs = arrayof(int32, lutInput, inp1, inp2, inp3)
            newCircuit:setLUTInputs(nodeIndex, inputs)
            newCircuit:setOutInput(outIndex, lutToGlobalIndex(nodeIndex))
            newCircuit.luts.N = newCircuit.luts.N + 1
            newCircuit.luts.data[nodeIndex].lutValue = lutValue
        else
            nodeIndex = wireIndex / 4
            var inputIndex = wireIndex % 4
            --C.printf("nodeIndex: %d\n", nodeIndex)
            --C.printf("inputIndex: %d\n", inputIndex)
            var oldInputIndex = newCircuit.luts.data[nodeIndex].inputs[inputIndex]
            --C.printf("oldInputIndex: %d\n", oldInputIndex)
            var inp1 = randomu32(rng) % lutToGlobalIndex(nodeIndex)
            var inp2 = randomu32(rng) % lutToGlobalIndex(nodeIndex)
            var inp3 = randomu32(rng) % lutToGlobalIndex(nodeIndex)
            var inputs = arrayof(int32, oldInputIndex, inp1, inp2, inp3)
            --C.printf("GROUND: %d\n", inputs[1])
            newCircuit:addLUTPreservingTopology(nodeIndex, lutValue, inputs)
            newCircuit.luts.data[nodeIndex+1].inputs[inputIndex] = lutToGlobalIndex(nodeIndex)
        end
        return newCircuit
    end

    local terra deleteRewrite(circuit : &TerraCircuitType, r : double, rng : &C.pcg32_random_t)
        --C.printf("deleteRewrite\n")
        var newCircuit = @circuit
        var nodeIndex = [int32](r*newCircuit.luts.N)

        var inputIndex = randomu32(rng) and 3
        --C.printf("Input index: %d\n", inputIndex)
        var oldInputIndex = newCircuit.luts.data[nodeIndex].inputs[inputIndex]
        --C.printf("oldInputIndex: %d\n", oldInputIndex)
        newCircuit.luts:delete(nodeIndex)
        for i=nodeIndex,newCircuit.luts.N do
            for j=0,4 do
                var currIndex = newCircuit.luts.data[i].inputs[j]
                if currIndex == lutToGlobalIndex(nodeIndex) then
                    -- TODO: should we randomize this?
                    currIndex = oldInputIndex
                elseif currIndex > lutToGlobalIndex(nodeIndex) then
                    currIndex = currIndex-1
                end
                newCircuit.luts.data[i].inputs[j] = currIndex
            end
        end
        for i=0,[#initialCircuit.outputs] do
            var currIndex = newCircuit.outputs[i].inputIndex
            if currIndex == lutToGlobalIndex(nodeIndex) then
                -- TODO: should we randomize this?
                currIndex = oldInputIndex
            elseif currIndex > lutToGlobalIndex(nodeIndex) then
                currIndex = currIndex-1
            end
            newCircuit.outputs[i].inputIndex = currIndex
        end
        return newCircuit
    end

    local terra inputSwapRewrite(circuit : &TerraCircuitType, r : double, rng : &C.pcg32_random_t)
        --C.printf("inputSwapRewrite\n")
        var newCircuit = @circuit
        var nonInputNodeCount = newCircuit.luts.N + [#initialCircuit.outputs]
        var nodeIndex = [int32](r*nonInputNodeCount)
        var maxNodeIndex = min(nodeIndex,newCircuit.luts.N)+[#initialCircuit.inputs]
        var inputNodeIndex = [int32](random01(rng)*maxNodeIndex)
        -- TODO: Less haphazard handling of upstream nodes
        if nodeIndex < newCircuit.luts.N then
            var i = randomu32(rng) and 3
            --C.printf("Adjusting node %d input %d\n", nodeIndex, i)
            newCircuit.luts.data[nodeIndex].inputs[i] = inputNodeIndex
        else
            newCircuit.outputs[nodeIndex-newCircuit.luts.N].inputIndex = inputNodeIndex
        end
        return newCircuit
    end



    local terra lutChangeRewrite(circuit : &TerraCircuitType, r : double, rng : &C.pcg32_random_t)
        --C.printf("lutChangeRewrite\n")
        var newCircuit = @circuit
        var index = [int32](r*newCircuit.luts.N)
        var lutVal : uint32 

        if [partialLUTRewrites] then
            var temp = randomu32(rng)
            var mask = (temp >> 16) and [uint32]([math.pow(2,16)-1])
            var val = temp and [uint32]([math.pow(2,16)-1])
            var invmask = mask ^ [uint32]([math.pow(2,16)-1])
            lutVal = (mask and val) or (invmask and newCircuit.luts.data[index].lutValue)
        else
            lutVal = randomu32(rng) and [uint32]([math.pow(2,16)-1])
        end

        --C.printf("New lutVal = %d\n", lutVal)
        newCircuit.luts.data[index].lutValue = lutVal
        return newCircuit
    end

    local terra createRewrite(circuit : &TerraCircuitType, rng : &C.pcg32_random_t)
        var massSum : double = totalProposalMass
        var N = circuit.luts.N
        if N <= settings.minInternalNodes then
            massSum = massSum - settings.deleteMass
        end
        if N >= settings.maxInternalNodes then
            massSum = massSum - settings.addMass
        end
        if N == 0 then
            massSum = massSum - settings.lutChangeMass
        end
        var r : double = random01(rng)*massSum

        if N < settings.maxInternalNodes then
            if r < settings.addMass then
                return addRewrite(circuit, r/settings.addMass, rng)
            end
            r = r - settings.addMass
        end

        if N > settings.minInternalNodes then
            if r < settings.deleteMass then
                return deleteRewrite(circuit, r/settings.deleteMass, rng)
            end
            r = r - settings.deleteMass
        end

        if r < settings.inputSwapMass then
            return inputSwapRewrite(circuit, r/settings.inputSwapMass, rng)
        end
        r = r - settings.inputSwapMass

        if N > 0 and r < settings.lutChangeMass then
            return lutChangeRewrite(circuit, r/settings.lutChangeMass, rng)
        end

        C.printf("Reached what should be probability 0 case in createRewrite() with r = %f\n",r)
    end

    local terra acceptRewrite(rewriteCost : double, previousCost : double, rng : &C.pcg32_random_t)
    -- Equation 5: https://raw.githubusercontent.com/StanfordPL/stoke/develop/docs/papers/cacm16.pdf
        var tmp : double = C.exp([double]([-settings.beta])*(rewriteCost-previousCost))
        var acceptProbability : double = min(1.0, tmp)
        --log.info("acceptProbability="..acceptProbability)
        var threshold = random01(rng)
        --C.printf("tmp=C.exp([-settings.beta]*(rewriteCost-previousCost))\n")
        --C.printf("%f=C.exp(%f*(%f-%f))\n", tmp, [double]([-settings.beta]), rewriteCost, previousCost)
        --C.printf("Accept? %f vs %f\n", acceptProbability, threshold)
        return acceptProbability >= threshold
    end

    local terra furthestDistanceToInput(circuit : &TerraCircuitType, nodeIndex : int32) : int32
        if nodeIndex < [#initialCircuit.inputs] then
            return 0
        end
        var node = circuit.luts.data[nodeIndex-[#initialCircuit.inputs] ]
        var distance : int32 = 0
        for i=0,4 do
            var dist = furthestDistanceToInput(circuit, node.inputs[i])+1
            distance = max(distance, dist)
        end
        return distance
    end

    local terra criticalPathLength(circuit : &TerraCircuitType)
        var maxPathLength : int32 = 0
        for i=0,[#initialCircuit.outputs] do
            var dist : int32 = furthestDistanceToInput(circuit, circuit.outputs[i].inputIndex)+1
            maxPathLength = max(maxPathLength, dist)
        end
        return maxPathLength
    end

    local terra errorCost(proposal : &TerraCircuitType, testSet : cc.TestSet, validationSet : cc.TestSet)
        var testResult = [double](proposal:hammingErrorOnTestSet(testSet))
        -- Adjustment to make sure failing N tests is worse than failing N+1 validation cases
        -- after passing all test cases
        testResult = testResult * (validationSet.N + 1)*[#initialCircuit.inputs]
        if testResult == 0 then

            testResult = [double](proposal:hammingErrorOnTestSet(validationSet))
            --C.printf("VALIDATION: %f\n", testResult)
        end
        return testResult
    end

    local terra cost(proposal : &TerraCircuitType, testSet : cc.TestSet, validationSet : cc.TestSet)
        var errCost : double = errorCost(proposal, testSet, validationSet)

        var totalCost : double = errCost*[settings.weightCorrect]
        if [settings.weightCritical] > 0 then
            totalCost = totalCost + criticalPathLength(proposal)*[settings.weightCritical]
        end
        if [settings.weightSize] > 0 then
            totalCost = totalCost + proposal.luts.N * [settings.weightSize]
        end
        return totalCost, errCost
    end

    local terra stochasticSearch()
        C.printf("In compiled Stochastic search\n")
        var rng : C.pcg32_random_t
        var seed : uint64 = C.rand()
        seed = (seed << 32) or C.rand()
        rng.state = seed
        seed = C.rand()
        seed = (seed << 32) or C.rand()
        rng.inc = seed
        --rng.state = 1344398434
        --rng.inc = 423398434
        C.printf("%lu %lu\n", rng.state, rng.inc)

        for i=0,15 do random01(&rng) end

        var initialCircuit : TerraCircuitType = tCircuitGen()
        var validationSet = valSet
        var testSet = tSet

        var prunedCircuit = initialCircuit
        prunedCircuit:packLUTs()
        prunedCircuit:pruneUnusedLUTs()
        initialCircuit:toGraphviz("out/pruned")
        C.printf("Unpacked: %d\nPacked & Pruned: %d\n", initialCircuit.luts.N, prunedCircuit.luts.N)


        initialCircuit:toGraphviz("out/init")
        initialCircuit:toGraphviz(outBestName)
        var currentCircuit = initialCircuit
        var currentCost, currentCorrectCost = cost(&initialCircuit, testSet, validationSet)
        var anyCorrectFound = (currentCorrectCost == 0.0)
        var bestIncorrectCost = currentCost
        var bestCircuit = initialCircuit
        var bestCost = currentCost
        for i=0,[settings.totalIterations] do
            if (i % [settings.iterationsBetweenRestarts]) == 0 then
                currentCircuit = initialCircuit
                currentCost, currentCorrectCost = cost(&initialCircuit, testSet, validationSet)
                bestIncorrectCost = currentCost
                var independentSearchCount : int32 = i / [settings.iterationsBetweenRestarts]
                C.printf("------------------------------\n")
                C.printf("    Independent Search %d \n",independentSearchCount)
                C.printf("------------------------------\n")
                C.printf("Cost of initial circuit: %f\n", currentCost)
            end
            var rewriteCircuit = createRewrite(&currentCircuit, &rng)
            var rewriteCost,rewriteCorrectnessCost = cost(&rewriteCircuit, testSet, validationSet)
            if acceptRewrite(rewriteCost, currentCost, &rng) then
                --log.info("Iteration "..i.." Rewrite accepted with cost: "..rewriteCost..", correctness cost: "..rewriteCorrectnessCost)
                --C.printf("Iteration %d Rewrite accepted with cost: %f, correctness cost: %f\n", i, rewriteCost, rewriteCorrectnessCost)
                currentCost = rewriteCost
                currentCorrectCost = rewriteCorrectnessCost
                currentCircuit = rewriteCircuit
                if (currentCorrectCost == 0 or (not anyCorrectFound)) and currentCost < bestCost then
                    if anyCorrectFound then
                        C.printf("======================= NEW BEST CORRECT CIRCUIT %d =========================\n", i)
                        C.printf("Cost: %f\n", currentCost)
                    else
                        if currentCorrectCost == 0.0 then
                            C.printf("==================================================\n")
                            C.printf(" CORRECT IMPLEMENTATION FOUND!!!! %d, cost: %f\n", i, currentCost)
                            C.printf("==================================================\n")
                            C.printf("Cost: %f\n", currentCost)
                            anyCorrectFound = true 
                        else 
                            C.printf("-------------------- NEW BEST INCORRECT CIRCUIT %d --------------------\n", i)
                            C.printf("Cost: %f, correctnessCost: %f\n", currentCost, currentCorrectCost)
                        end
                    end
                    currentCircuit:toGraphviz(outBestName)
                    --if log.level == "debug" or log.level == "trace" then
                    --    cc.toGraphviz(currentCircuit, "out/correct"..(#correctCircuits + 1))
                    --end
                    --correctCircuits[#correctCircuits + 1] = currentCircuit
                    bestCost = currentCost
                    bestCircuit = currentCircuit
                elseif currentCorrectCost == 0 and currentCost == bestCost then
                    --log.info("----- Equivalent best circuit: "..i)
                elseif currentCost < bestCost then
                    --log.info("----- Incorrect lower cost circuit: "..i)
                    if currentCost < bestIncorrectCost then
                        bestIncorrectCost = currentCost
                        --[[if log.level == "debug" or log.level == "trace" then
                            cc.toGraphviz(currentCircuit, "out/incorrect_cost"..bestIncorrectCost)
                        end--]]
                    end
                end
            else
                --log.info("Rewrite rejected")
            end
            if i % 100000 == 0 then
                C.printf("Iteration: %d\n",i)
                C.printf("Cost: %f, correctnessCost: %f\n", currentCost, currentCorrectCost)
                currentCircuit:toGraphviz(outCurrentName)
            end
            --[[if (((i+1) % settings.iterationsBetweenRestarts) == 0) or (i+1) == settings.totalIterations then
                if log.level == "debug" or log.level == "trace" then
                    cc.toGraphviz(currentCircuit, "out/lastCircuit"..((i+1) / settings.iterationsBetweenRestarts))
                end
                endCircuits[#endCircuits+1] = currentCircuit
            end--]]
        end
        return bestCircuit
    end
--[[
    local terra testRewrite()
        var rng : C.pcg32_random_t
        rng.state = 1344398434
        rng.inc = 423398434
        for i=0,15 do random01(&rng) end
        var initialCircuit : TerraCircuitType = tCircuitGen()
        var tC1 : TerraCircuitType = createRewrite(&initialCircuit, &rng)
        var tC2 : TerraCircuitType = createRewrite(&tC1, &rng)
        var tC3 : TerraCircuitType = createRewrite(&tC2, &rng)
        return tC2
    end
    local tC1 = testRewrite()
    cc.toGraphviz(cc.terraCircuitToLuaCircuit(tC1),"out/test2")
    assert(false)
    --cc.toGraphviz(cc.terraCircuitToLuaCircuit(tC2),"out/test2")
    --cc.toGraphviz(cc.terraCircuitToLuaCircuit(tC3),"out/test3")
--]]
    print("Setup complete, calling terra implementation")
    return cc.terraCircuitToLuaCircuit(stochasticSearch())
end
return ss
