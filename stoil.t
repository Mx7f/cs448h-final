require("util")
require("tablehelpers")
require("bithelpers")
local sim = require("simulation")
local cc = require("circuit")
local ss = require("stochasticsearch")
local tss = require("terraStochasticSearch")
stoil = {}
stoil.search = ss.stochasticSearch
stoil.tsearch = tss.terraBasedStochasticSearch
stoil.defaultSearchSettings = ss.defaultSearchSettings
stoil.circuit = cc
stoil.createTestSuite = sim.createTestSuite
stoil.testAndValidationSet = sim.testAndValidationSet
stoil.wrapCircuit = sim.wrapCircuit
stoil.runCircuit = sim.runCircuit

return stoil
