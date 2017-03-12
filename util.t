package.path = package.path .. ';log/?.lua' .. ';lua-graphviz/?.lua'
graphviz = require("graphviz")
log = require("log")
log.level = "error"
