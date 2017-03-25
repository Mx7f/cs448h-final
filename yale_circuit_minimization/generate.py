from mantle import *
from magma import coreir_json,fork,col,wire,AnonymousCircuit,In,Bit

filename = "AESReverseDepth.txt"

def generate_aes():
  with open(filename) as f:
    content = f.readlines()
  content = [x.strip() for x in content]
  inputs  = dict([("U"+str(i), In(Bit)()) for i in range(8)])
  outputs = {}
  gates = {}

  for i in range(6,len(content)):
    tokens = content[i].split()
    assert(tokens[1] == "=")
    operator = tokens[3]
    gate = []
    if operator == "x":
      gate = And2()
    elif operator == "+":
      gate = Xor2()
    elif operator == "#":
      gate = NXor2()

    #wire inputs
    I0 = tokens[2]
    I1 = tokens[4]
    if I0[0] == "U":
      wire(inputs[I0],gate.I0)
    else:
      wire(gates[I0],gate.I0)
    if I1[0] == "U":
      wire(inputs[I1],gate.I1)
    else:
      wire(gates[I1],gate.I1)

    name = tokens[0]
    if name[0] == "S" or name[0] == "W":
      outputs[name] = gate.O
    else:
      gates[name] = gate.O

  args = []
  for k, v in inputs.items():
    args.append(k)
    args.append(v)
  for k, v in outputs.items():
    args.append(k)
    args.append(v)
  print(args)
  return AnonymousCircuit(*args)

name = "SBOX_yale_i"
defn = define_circuit_from_generator(generate_aes, "_" + name)
coreir_json.compile(defn, "../circuits/" + name + ".json")



