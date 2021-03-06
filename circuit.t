require("tablehelpers")
require("util")
NodeType = {INTERNAL={},INPUT={},OUTPUT={}}

local terra max(a : int32, b : int32)
    return terralib.select( a > b, a, b)
end

local Cir = {}
function Cir.nodeTypeString(typ)
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

function Cir.printNode(node)
    print("BEGIN_NODE")
    print("  type = "..Cir.nodeTypeString(node.type))
    if node.inputs and #node.inputs > 0 then
        io.write("  inputs[", tostring(#node.inputs), "] = {")
        for i,input in ipairs(node.inputs) do
            io.write(Cir.nodeTypeString(input.type), ", ")
        end
        io.write("}\n")
    end
    if node.lutValue then
        print("  lutValue = "..string.format("%x", node.lutValue))
    end
    print("END_NODE")
end

function Cir.print(circuit)
    print("inputs")
    for i,input in ipairs(circuit.inputs) do
        printNode(input)
    end
    print("internal")
    for i,node in ipairs(circuit.internalNodes) do
        printNode(node)
    end
    print("outputs")
    for i,output in ipairs(circuit.outputs) do
        printNode(output)
    end
end

local function Wire(input, output, indexInOut)
    local wire = {}
    wire.input = input
    wire.output = output
    wire.indexInOut = indexInOut
    return wire
end

function Cir.getInputWires(node)
    local result = {}
    for i,input in ipairs(node.inputs) do
        log.trace(tostring(node.inputs[i])," -> ",tostring(node))
        result[i] = Wire(node.inputs[i],node, i)
    end
    return result
end

local function visit(node, newNodes)
    node.marked = true
    for i,m in ipairs(node.inputs) do
        if m.type == NodeType.INTERNAL and (not m.marked) then
            visit(m, newNodes)
        end
    end
    newNodes[#newNodes+1] = node
end

local function topologicalSort(nodes)
    
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

function Cir.getWireArray(circuit)
    local wires = {}
    for i,output in ipairs(circuit.outputs) do
        wires = table.concattables(wires, Cir.getInputWires(output))
    end
    for i,node in ipairs(circuit.internalNodes) do
        wires = table.concattables(wires, Cir.getInputWires(node))
    end
    log.debug("wireArray size: "..#wires)
    return wires
end

function Cir.makeConsistent(circuit)
    circuit.wires = Cir.getWireArray(circuit)
    topologicalSort(circuit.internalNodes)
end

function Cir.deleteNode(circuit, node)
    log.trace("deleteNode")
    log.trace("patching inputs")
    for i,wire in ipairs(circuit.wires) do
        if wire.input == node then
            --TODO: randomize?
            log.debug("Patching wire at index "..wire.indexInOut)
            wire.output.inputs[wire.indexInOut] = node.inputs[1]
        end
    end
    log.trace("Actual removal")
    local oldIndex = table.invert(circuit.internalNodes)[node]
    table.remove(circuit.internalNodes, oldIndex)
    Cir.makeConsistent(circuit)
end

function Cir.selectInternalNode(circuit, internalNodeIndex)
    log.trace("selectInternalNode("..internalNodeIndex..")")
    return circuit.internalNodes[internalNodeIndex]
end

function Cir.nonInputNodeCount(circuit)
    return #circuit.internalNodes + #circuit.outputs
end


--TODO: check if downstream nodes are really downstream?
function Cir.upstreamNodes(circuit, node)
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

function Cir.setInputOfNode(circuit,node,index,inputNode)
    node.inputs[index] = inputNode
    log.trace("Setting index "..index.." to node type "..Cir.nodeTypeString(inputNode.type))
    log.trace("Input set. Making consistent")
    Cir.makeConsistent(circuit)
end

function Cir.selectNonInputNode(circuit, nonInputNodeIndex)
    log.trace("selectNonInputNode")
    if nonInputNodeIndex > #circuit.internalNodes then
        local i = nonInputNodeIndex - #circuit.internalNodes
        return circuit.outputs[i], true
    else
        return circuit.internalNodes[nonInputNodeIndex], false
    end
    assert(false,"selectNonInputNode index too large")
end

function Cir.wireCount(circuit)
    return #circuit.wires
end

function Cir.selectWire(circuit, wireIndex)
    return circuit.wires[wireIndex]
end

local function twoLevelCopyNode(node)
    local copiedNode = table.shallowcopy(node)
    if copiedNode.inputs then
        copiedNode.inputs = table.shallowcopy(node.inputs)
    end
    return copiedNode
end

function Cir.deepCopy(circuit)
    log.trace("Deep copy")
    local newCircuit = {}
    newCircuit.inputs = {}
    newCircuit.internalNodes = {}
    newCircuit.outputs = {}
    local oldToNew = {}
    log.info("deepCopy of circuit with Inp/Int/Out: "..#circuit.inputs.."/"..#circuit.internalNodes.."/"..#circuit.outputs)
    for i=1,#circuit.inputs do 
        newCircuit.inputs[i] = twoLevelCopyNode(circuit.inputs[i])
        if oldToNew[circuit.inputs[i]] then
            log.error("==== DUPLICATE CIRCUIT IN DEEP COPY (INPUTS): "..tostring(oldToNew[circuit.inputs[i]]))
            Cir.toGraphviz(circuit, "out/error")
            assert(false)
        end
        oldToNew[circuit.inputs[i]] = newCircuit.inputs[i]
    end
    for i=1,#circuit.outputs do 
        newCircuit.outputs[i] = twoLevelCopyNode(circuit.outputs[i])
        if oldToNew[circuit.outputs[i]] then
            log.error("==== DUPLICATE CIRCUIT IN DEEP COPY (OUTPUTS): "..tostring(oldToNew[circuit.outputs[i]]))
            Cir.toGraphviz(circuit, "out/error")
            assert(false)
        end
        oldToNew[circuit.outputs[i]] = newCircuit.outputs[i]
    end
    for i=1,#circuit.internalNodes do 
        newCircuit.internalNodes[i] = twoLevelCopyNode(circuit.internalNodes[i])
        if oldToNew[circuit.internalNodes[i]] then
            log.error("==== DUPLICATE CIRCUIT IN DEEP COPY (INTERNAL): "..tostring(oldToNew[circuit.internalNodes[i]]))
            Cir.toGraphviz(circuit, "out/error")
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
    newCircuit.wires = Cir.getWireArray(newCircuit)
    -- Topo sorting is maintained during deep copy
    log.trace("Deep copy done")
    return newCircuit
end

function Cir.internalNodeCount(circuit)
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

function Cir.setLUTValue(node, lutValue)
    assert(node.lutValue, "Tried to assign lut value to non-lut node")
    node.lutValue = lutValue
end

function Cir.nodeSanityCheck(circuit)
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
                    log.error("INVALID NODE FOUND IN INPUT ", i, " OF ", Cir.nodeTypeString(k.type))
                    log.error("Claims to be ", Cir.nodeTypeString(node.type))
                end
            end
        elseif k.type ~= NodeType.INPUT then
            log.error("NON-INPUT NODE WITHOUT INPUTS: ", Cir.nodeTypeString(k.type))
        end
    end
    log.debug("NODE SANITY CHECK DONE")
end

local function isNode(circuit, node)
    local validNodes = {}
    for i,v in ipairs(circuit.inputs) do validNodes[v] = true end
    for i,v in ipairs(circuit.outputs) do validNodes[v] = true end
    for i,v in ipairs(circuit.internalNodes) do validNodes[v] = true end
    return validNodes[node] ~= nil
end

function Cir.addLUTNode(circuit, inputs, wire, lutValue)
    for i,v in ipairs(inputs) do
        log.trace(isNode(circuit,v))
    end
    log.trace(isNode(circuit,wire.input))
    log.trace(isNode(circuit,wire.output))

    local node = LUTNode(inputs,lutValue)
    wire.output.inputs[wire.indexInOut] = node
    
    circuit.internalNodes[#circuit.internalNodes+1] = node

    Cir.makeConsistent(circuit)
    log.debug("LUTNODE added")
    return node
end

function Cir.getGround(circuit)
    return circuit.inputs[#circuit.inputs-1]
end

function Cir.getPower(circuit)
    return circuit.inputs[#circuit.inputs]
end

function Cir.emptyCircuit(inputsCount, outputCount)
    local circuit = {}
    circuit.inputs = {}
    for i=1,inputsCount do 
        circuit.inputs[i] = InputNode() 
    end
    local groundNode = ConstNode(false)
    local powerNode  = ConstNode(true)
    circuit.inputs[inputsCount+1] = groundNode
    circuit.inputs[inputsCount+2] = powerNode
    circuit.outputs = {}
    for i=1,outputCount do 
        circuit.outputs[i] = OutputNode(groundNode)
    end
    circuit.internalNodes = {}
    circuit.wires = Cir.getWireArray(circuit)
    return circuit
end


local function uniqueNodeName(node)
    return "node"..string.sub(tostring(node), 10)
end

local struct TestSet {
    inputs : &uint64
    outputs : &uint64
    N : uint64
}
terra TestSet:set(idx : uint64, inp : uint64, out : uint64)
    self.inputs[idx]    = inp
    self.outputs[idx]   = out
end
terra TestSet:init(size : uint64)
    self.N = size
    self.inputs = [&uint64](C.malloc(sizeof(uint64) * size))
    self.outputs = [&uint64](C.malloc(sizeof(uint64) * size))
end
terra TestSet:free()
    C.free(self.inputs)
    C.free(self.outputs)
end

Cir.TestSet = TestSet

local struct TerraInputNode {
    val : uint32
}

local struct TerraOutputNode {
    inputIndex : int32
}

local struct TerraLUTNode {
    inputs      : int32[4]
    lutValue    : uint32
    val         : uint32
}

local makeTerraCircuit = terralib.memoize(function(numInputs, numOutputs, maxInternalNodes)
    local struct TerraCircuit {
        inputs  : TerraInputNode[numInputs]
        luts : BoundedArray(TerraLUTNode, maxInternalNodes) -- TODO:Abstract
        outputs : TerraOutputNode[numOutputs]
    }

    terra TerraCircuit:deleteLUT(nodeIndex : int32)
        self.luts:delete(nodeIndex)
        for i=nodeIndex,self.luts.N do
            for j=0,4 do
                var currIndex = self.luts.data[i].inputs[j]
                if currIndex > nodeIndex + numInputs then
                    self.luts.data[i].inputs[j] = currIndex-1
                end
            end
        end
        for i=0,numOutputs do
            var currIndex = self.outputs[i].inputIndex
            if currIndex > nodeIndex + numInputs then
                self.outputs[i].inputIndex = currIndex-1
            end
        end
    end

    terra TerraCircuit:isInputIndex( index : int32)
        return index < numInputs
    end

    terra TerraCircuit:packLUTs()
        C.printf("For now TerraCircuit:packLUTs assumes all gates start as 2 input, I0 I1")
        var maxInd = self.luts.N
        for k=0,maxInd do
            var i = maxInd - k - 1
            var lut = self.luts.data[i]
            var inputs : int32[2] = array(lut.inputs[0], lut.inputs[1])
            if (not self:isInputIndex(inputs[0])) and (not self:isInputIndex(inputs[1])) then
                -- Trivial rewiring
                var lut0 = self.luts.data[inputs[0]-numInputs]
                var lut1 = self.luts.data[inputs[1]-numInputs]
                self.luts.data[i].inputs[0] = lut0.inputs[0]
                self.luts.data[i].inputs[1] = lut0.inputs[1]
                self.luts.data[i].inputs[2] = lut1.inputs[0]
                self.luts.data[i].inputs[3] = lut1.inputs[1]

                var oldLutVal = self.luts.data[i].lutValue
                self.luts.data[i].lutValue = 0
                --[[for j=0,16 do
                    lut0.lutValue[]
                end--]]
            end 
        end
    end


    terra TerraCircuit:pruneUnusedLUTs()
        var used : BoundedArray(bool, maxInternalNodes)
        used.N = self.luts.N
        for i=0,used.N do
            used.data[i] = false 
        end
        for i=0,numOutputs do
            var index = self.outputs[i].inputIndex
            if index >= numInputs then
                used.data[index-numInputs] = true 
            end
        end
        var maxInd = self.luts.N
        for k=0,maxInd do
            var i = maxInd - k - 1
            if used.data[i] then
                for j=0,4 do
                    var index = self.luts.data[i].inputs[j]
                    if index >= numInputs then
                        used.data[index-numInputs] = true 
                    end
                end
            else
                self:deleteLUT(i)
            end
        end
    end

    terra TerraCircuit:simulate()
        --C.printf("self.luts.N, %u\n", self.luts.N)
        for i=0,self.luts.N do
            var bitindex = 0
            for j=0,4 do
                var nodeindex = self.luts.data[i].inputs[j]
                if nodeindex < [numInputs] then
                    bitindex = bitindex or (self.inputs[nodeindex].val << j)
                else
                    nodeindex = nodeindex - [numInputs]
                    bitindex = bitindex or (self.luts.data[nodeindex].val << j)
                end
            end
            self.luts.data[i].val = 1 and (self.luts.data[i].lutValue >> bitindex)
        end
        --C.printf("numOutputs, %u\n", numOutputs)
        var result : uint32 = 0 --TODO: get rid of 32-bit limitation
        for i=0,numOutputs do
            var nodeindex = self.outputs[i].inputIndex
            if nodeindex < [uint32]([numInputs]) then
                result = result or (self.inputs[nodeindex].val << i)
            else
                nodeindex = nodeindex - [int32]([numInputs])
                result = result or (self.luts.data[nodeindex].val << i)
            end
        end
        return result
    end
    terra TerraCircuit:setInputs(inp : uint64)
        for i=0,numInputs do
            self.inputs[i].val = [uint32]((inp >> i) and 1)
        end
    end

    local showConstantInputs = false
    terra TerraCircuit:toGraphviz(filename : rawstring)
        var inputCount : uint32 = [numInputs]
        if not [showConstantInputs] then
            inputCount = inputCount - 2
        end

        var fp = C.fopen(filename, "w")
        --Header
        C.fprintf(fp, "digraph {\nrankdir = TB;\nsubgraph {\n")

        --Input Nodes
        for i=0,inputCount do
            C.fprintf(fp, "    node%d [label=\"input%d\"]\n", i, i)
        end

        --Internal Nodes
        C.fprintf(fp, "node[shape=box]\n")
        for i=0,self.luts.N do
            C.fprintf(fp, "    node%d [label=\"%04x\"]\n", [numInputs] + i, self.luts.data[i].lutValue)
        end

        --Output Nodes
        C.fprintf(fp, "node[shape=oval]\n")
        for i=0,[numOutputs] do
            C.fprintf(fp, "    output%d [label=\"output%d\"]\n", i, i)
        end

        -- Edges
        for i=0,self.luts.N do
            for j=0,4 do
                var inp = self.luts.data[i].inputs[j]
                if [showConstantInputs] or (inp >= [numInputs]) or (inp < inputCount) then
                    C.fprintf(fp, "        node%d -> node%d\n", inp, [numInputs] + i)
                end
            end
        end
        for i=0,[numOutputs] do
            var inp = self.outputs[i].inputIndex
            if [showConstantInputs] or (inp >= [numInputs]) or (inp < inputCount) then
                C.fprintf(fp, "        node%d -> output%d\n", inp, i)
            end
        end

        -- Fake edges to sort inputs
        for i=0,inputCount-1 do
            C.fprintf(fp, "        node%d -> node%d [style=invis]\n", i, i+1)
        end
        -- Fake edges to sort outputs
        for i=0,[numOutputs]-1 do
            C.fprintf(fp, "        output%d -> output%d [style=invis]\n", i, i+1)
        end

        -- Put inputs at the top
        C.fprintf(fp, "    {rank = same; ")
        for i=0,inputCount do
            C.fprintf(fp, "node%d;", i)
        end
        C.fprintf(fp, "}\n")

        -- Put outputs at the bottom
        C.fprintf(fp, "    {rank = same; ")
        for i=0,[numOutputs] do
            C.fprintf(fp, "output%d;", i)
        end
        C.fprintf(fp, "}\n")
        --Footer
        C.fprintf(fp, "} /* closing subgraph */\n")
        --if useCostLabel then
        --    C.fprintf(fp, "label=\"Cost %f; Error Cost %f\"\nlabelloc=top;\nlabeljust=left;\n", cost, errorCost)
        --end
        C.fprintf(fp, "}\n")
        C.fclose(fp)
    end

    terra TerraCircuit:addLUTPreservingTopology(newLUTIndex : int32, lutValue : int32, inputs : int32[4])
        var newLUTIndex = newLUTIndex
        --C.printf("newLUTIndex: %d\n", newLUTIndex)
        --C.printf("self.luts.N: %d\n", self.luts.N)
        for i=0,self.luts.N-newLUTIndex do
            var idx = self.luts.N-i
            --C.printf("moving : %d to %d\n", idx-1, idx)
            self.luts.data[idx] = self.luts.data[idx-1]
        end
        self.luts.N = self.luts.N+1
        self.luts.data[newLUTIndex].inputs = inputs
        self.luts.data[newLUTIndex].lutValue = lutValue
        for i=newLUTIndex+1,self.luts.N do
            --C.printf("Rewriting inputs of : %d\n", i)
            for j=0,4 do
                var idx = self.luts.data[i].inputs[j]
                if idx >= (newLUTIndex + numInputs) then
                    idx = idx + 1
                end
                --C.printf("%d -> %d\n", self.luts.data[i].inputs[j], idx)
                self.luts.data[i].inputs[j] = idx
            end
        end
        for i=0,numOutputs do
            --C.printf("Rewriting input of output %d\n", i)
            var idx = self.outputs[i].inputIndex
            if idx >= (newLUTIndex + numInputs) then
                idx = idx + 1
            end
            --C.printf("%d -> %d\n", self.outputs[i].inputIndex, idx)
            self.outputs[i].inputIndex = idx
        end
    end
    terra TerraCircuit:setLUTInputs(lutIndex : int32, inputs : int32[4])
        self.luts.data[lutIndex].inputs = inputs
    end
    terra TerraCircuit:setOutInput(outIndex : int32, inIndex : int32)
        self.outputs[outIndex].inputIndex = inIndex
    end
    terra TerraCircuit:hammingDist(inp : uint64, out : uint64)
        --C.printf("About to set Inputs\n")
        self:setInputs(inp)
        --C.printf("About to simulate\n")
        var result = self:simulate()
        --C.printf("About to popcount\n")
        return popcount(result ^ out)
    end
    terra TerraCircuit:hammingErrorOnTestSet(testSet : TestSet)
        var dist : int32 = 0
        --C.printf("hammingErrorOnTestSet: size(%d)\n",testSet.N)
        for i=0,testSet.N do
            dist = dist + self:hammingDist(testSet.inputs[i], testSet.outputs[i])
        end
        --C.printf("error %d\n",dist)
        return dist
    end

    return TerraCircuit
end)

function Cir.terraCircuitToLuaCircuit(terraCircuit)
    local inputCount = terralib.typeof(terraCircuit.inputs).N-2
    local outputCount = terralib.typeof(terraCircuit.outputs).N
    local luaCircuit = Cir.emptyCircuit(inputCount, outputCount)
    local internalNodeCount = terraCircuit.luts.N
    for i=1,internalNodeCount do
        local lutValue = terraCircuit.luts.data[i-1].lutValue
        local inputs = {}
        for j=0,3 do
            local index = terraCircuit.luts.data[i-1].inputs[j]
            index = index + 1
            if index <= #luaCircuit.inputs then
                inputs[#inputs+1] = luaCircuit.inputs[index]
            else
                index = index - #luaCircuit.inputs
                inputs[#inputs+1] = luaCircuit.internalNodes[index]
            end
        end
        local newNode = LUTNode(inputs,lutValue)
        luaCircuit.internalNodes[#luaCircuit.internalNodes+1] = newNode
    end
    for i=1,outputCount do
        local index = terraCircuit.outputs[i-1].inputIndex
        index = index + 1
        if index <= #luaCircuit.inputs then
            luaCircuit.outputs[i].inputs[1] = luaCircuit.inputs[index]
        else
            index = index - #luaCircuit.inputs
            luaCircuit.outputs[i].inputs[1] = luaCircuit.internalNodes[index]
        end
    end
    Cir.makeConsistent(luaCircuit)
    return luaCircuit
end

function Cir.createTerraCircuit(circuit, maxInternalNodes)
    local nodesToIndices = {}
    for i,v in ipairs(circuit.inputs) do
        nodesToIndices[v] = i-1
    end
    for i,v in ipairs(circuit.internalNodes) do
        nodesToIndices[v] = i-1+(#circuit.inputs)
    end
    local tCircType = makeTerraCircuit(#circuit.inputs, #circuit.outputs, maxInternalNodes)
    print("Creating Terra Circuit")
    local terra createCircuit()

        var circ : tCircType
        circ.luts:resize([#circuit.internalNodes])
        escape 
            for i,v in ipairs(circuit.internalNodes) do
                for j=0,3 do
                    local nodeIndex = nodesToIndices[v.inputs[j+1]]
                    emit quote 
                        circ.luts([i-1]).inputs[j] = [int32](nodeIndex)
                    end
                end
                emit quote
                    circ.luts([i-1]).lutValue = uint32(v.lutValue)
                end
            end
            for i,v in ipairs(circuit.outputs) do
                local nodeIndex = nodesToIndices[v.inputs[1]]
                emit quote
                    circ.outputs[i-1].inputIndex = [int32](nodeIndex)
                end
            end
        end
        return circ
    end
    return createCircuit, tCircType
end
--[[
function Cir.runCircuitInTerra(circuit, input)
    local terra runCircuit()
        var circ = [createTerraCircuit(circuit)()]
        circ:setInputs([input])
        return circ:simulate()
    end
    return runCircuit()
end
--]]


local function runCreatedCircuitInTerra(terraCircuit, input)
    local terra runCircuit()
        var circ = [terraCircuit]
        var inp : uint64 = [input]
        circ:setInputs([input])
        return circ:simulate()
    end
    return runCircuit()
end

function Cir.createTerraTestSet(testSet)
    local terra createTestSet()
        var tSet : TestSet
        tSet:init([#testSet])
        return tSet
    end
    local tSet = createTestSet()
    for i,v in ipairs(testSet) do
        tSet:set(i-1, v.input, v.output)
    end
    return tSet
end

function Cir.hammingDistanceOnTestSetTerra(circuit, testSet)
    local hammingDist = 0
    local tCirc,TerraCircuitType  = Cir.createTerraCircuit(circuit)
    local terraTestSet = Cir.createTerraTestSet(testSet)
    local terra hammingDistOnTest()
        var terraCircuit = tCirc()
        var tSet : TestSet = terraTestSet
        var result = terraCircuit:hammingErrorOnTestSet(tSet)
        tSet:free()
        return result
    end
    print("Before terra compilation")
    local hammingDist = hammingDistOnTest()
    print("Hamming dist "..hammingDist)
    return hammingDist
end

function Cir.toGraphviz(circuit, filename)
    local graph = graphviz()
    for i=1,#circuit.inputs-2 do
        graph:node(uniqueNodeName(circuit.inputs[i]), "input"..i-1)
    end
    graph:node(uniqueNodeName(circuit.inputs[#circuit.inputs-1]), "0")
    graph:node(uniqueNodeName(circuit.inputs[#circuit.inputs]), "1")

    for i,v in ipairs(circuit.internalNodes) do
        graph:node(uniqueNodeName(v), string.format("%x", v.lutValue))
        for j,input in ipairs(v.inputs) do
            graph:edge(uniqueNodeName(input), uniqueNodeName(v))
        end
    end

    for i=1,#circuit.outputs do
        local v = circuit.outputs[i]
        graph:node(uniqueNodeName(v), "output"..i-1)
        for j,input in ipairs(v.inputs) do
            graph:edge(uniqueNodeName(input), uniqueNodeName(v))
        end
    end
    graph:compile(filename)
end

return Cir