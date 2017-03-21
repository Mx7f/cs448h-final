from mantle import *
from magma import coreir_json

for b in [4,5,6,7,8]:
	name = "Add" + str(b)
	defn = define_circuit_from_generator(lambda: Add(b), "_" + name)
	coreir_json.compile(defn, "../circuits/" + name + ".json")

for b in [4,5,6,7,8]:
	name = "Sub" + str(b)
	defn = define_circuit_from_generator(lambda: Sub(b), "_" + name)
	coreir_json.compile(defn, "../circuits/" + name + ".json")