require("util")
local circuit = require("circuit")

local coreir = {}
local function getPort(name)
    return name:match("[^.]+$")
end
local function getPath(connectEnd)
    return {loc=connectEnd.path[1], port=connectEnd.path[2][1], index=connectEnd.path[2][2]}
end
local function getDirectionFromPortType(portType)
    if portType[1] == "Array" then
        return getDirectionFromPortType(portType[3])
    end
    if portType[1] == "BitIn" then
        return "In"
    elseif  portType[1] == "BitOut" then
        return "Out"
    end
    assert(false, "Unabled to get direction From Port type")
end

local function getIsInputFromType(typ, port)
    for i,v in ipairs(typ[2]) do
        if v[1] == port then
            return getDirectionFromPortType(v[2])=="In"
        end
    end
    assert(false, "Failed to getIsInputFromType on "..port)
end
local function getIsInputFromConnectEnd(connectEnd, modules, currModule)
    if connectEnd.loc == "self" then
        local isInput = getIsInputFromType(currModule.type, connectEnd.port)
        return isInput
    else
        local instance = currModule.def.instances[connectEnd.loc]
        local primitiveName = instance.instref[2]
        local primitiveType = modules[primitiveName].type
        return getIsInputFromType(primitiveType, connectEnd.port)
    end
end


local function alphabetic_order_carry_last(name1, name2)
    local n1 = name1
    local n2 = name2
    for i=1,string.len(name1) do
        if name1:sub(i,i) == "C" then
            n1 = "__"..n1
        end
    end
    for i=1,string.len(name2) do
        if name2:sub(i,i) == "C" then
            n2 = "__"..n2
        end
    end
    return n1<n2
end

function coreir.load(filename)
    local jsonCircuit = json.decode(readAll(filename))
    local loadedCircuit = {}
    local modules = jsonCircuit.namespaces._G.modules
    for k,v in pairs(modules) do
        if k ~= "SB_LUT4" and k ~= "SB_CARRY" then
            local inputs = {}
            local outputs = {}
            local interface = v.type[2]
            for i,port in ipairs(interface) do
                local name  = port[1]
                local typ   = port[2]
                if name ~= "POWER" and name ~= "GROUND" then
                    -- Reverse direction
                    if typ[1] == "BitIn" then
                        outputs[#outputs + 1] = name
                    elseif typ[1] == "BitOut" then
                        inputs[#inputs + 1] = name
                    else
                        assert(typ[1] == "Array")
                        if typ[3][1] == "BitIn" then
                            for j=1,typ[2] do
                                outputs[#outputs + 1] = name.."["..tostring(j-1).."]"
                            end
                        elseif typ[3][1] == "BitOut" then
                            for j=1,typ[2] do
                                inputs[#inputs + 1] = name.."["..tostring(j-1).."]"
                            end
                        else
                            assert(false)
                        end
                    end
                end
            end
            table.sort(outputs, alphabetic_order_carry_last)
            table.sort(inputs, alphabetic_order_carry_last)
            inputs[#inputs + 1] = "GROUND"
            inputs[#inputs + 1] = "POWER"
            for i=1,#inputs do
                print("input: "..inputs[i])
            end
            for i=1,#outputs do
                print("output: "..outputs[i])
            end
            loadedCircuit = circuit.emptyCircuit(#inputs - 2,#outputs)
            local gates = {}
            local ground = loadedCircuit.inputs[#inputs-1]
            local default_inputs = {ground, ground, ground, ground}
            for name,gate in pairs(v.def.instances) do
                local lut_value = 0xe8e8
                if gate.instref[#gate.instref] == "SB_LUT4" then
                    lut_value = gate.config.LUT_INIT
                else
                    assert(gate.instref[#gate.instref] == "SB_CARRY")
                end
                local createdGate = circuit.addLUTNode(loadedCircuit, default_inputs, loadedCircuit.wires[1], lut_value)
                gates[name] = createdGate
            end
            local nameToIndex = { I0=1, I1=2, I2=3, I3=4, CI=3 }
            for i,connection in ipairs(v.def.connections) do
                local conn = {getPath(connection[1]), getPath(connection[2])}
                -- {loc, port, index}
                local isInput1 = getIsInputFromConnectEnd(conn[1],modules,v)
                local isInput2 = getIsInputFromConnectEnd(conn[2],modules,v)
                assert(isInput1~=isInput2, "Erroneous connection from input "..conn[1].loc.." "..conn[1].port.."to input "..conn[2].loc.." "..conn[2].port)
                local fromEnd = conn[1]
                local toEnd = conn[2]
                if isInput1 then
                    toEnd = conn[1]
                    fromEnd = conn[2]
                end

                local toNode = {}
                local fromNode = {}
                local toPortName = toEnd.port
                if toEnd.index then
                    toPortName = toEnd.port.."["..toEnd.index.."]"
                end
                local fromPortName = fromEnd.port
                if fromEnd.index then
                    fromPortName = fromEnd.port.."["..fromEnd.index.."]"
                end

                local indexInToNode = 1
                if toEnd.loc == "self" then
                    local toIndex = table.indexOf(outputs, toPortName)
                    assert(toIndex > 0, "Invalid input "..toEnd.port)
                    toNode = loadedCircuit.outputs[toIndex]
                else
                    toNode = gates[toEnd.loc]
                    indexInToNode = nameToIndex[toEnd.port]
                end
                if fromEnd.loc == "self" then
                    if fromEnd.port == "GROUND" then
                        fromNode = loadedCircuit.inputs[#loadedCircuit.inputs-1]
                    elseif fromEnd.port == "POWER" then
                        fromNode = loadedCircuit.inputs[#loadedCircuit.inputs]
                    else
                        local fromIndex = table.indexOf(inputs, fromPortName)
                        fromNode = loadedCircuit.inputs[fromIndex]
                    end
                else
                    fromNode = gates[fromEnd.loc]
                end
                print("wire("..fromEnd.loc.."."..fromPortName..", "..toEnd.loc.."."..toPortName..")")
                print(toNode)
                print(indexInToNode)
                print(fromNode)
                circuit.setInputOfNode(loadedCircuit,toNode,indexInToNode,fromNode)
            end
        end
    end
    circuit.toGraphviz(loadedCircuit, "testLoad")
    return loadedCircuit
end
return coreir