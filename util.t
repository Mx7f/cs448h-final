package.path = package.path .. ';log/?.lua'
log = require("log")
log.level = "error"