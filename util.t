package.path = package.path .. ';log/?.lua' .. ';lua-graphviz/?.lua' .. ';json/?.lua'
graphviz = require("graphviz")
log = require("log")
json = require("json")

function readAll(file)
    local f = io.open(file, "r")
    local content = f:read("*all")
    f:close()
    return content
end


log.level = "error"
