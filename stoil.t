require("util")
require("tablehelpers")
require("bithelpers")
local sim = require("simulation")
local cc = require("circuit")
local ss = require("stochasticsearch")
stoil = {}
stoil.search = ss.stochasticSearch
stoil.circuit = cc
stoil.createTestSuite = sim.createTestSuite
stoil.runCircuit = sim.runCircuit
return stoil
