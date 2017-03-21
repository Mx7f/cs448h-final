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

C = terralib.includecstring [[
    #include <stdio.h>
    #include <stdlib.h>
    #include <math.h>
    #include <time.h>

// *Really* minimal PCG32 code / (c) 2014 M.E. O'Neill / pcg-random.org
// Licensed under Apache License 2.0 (NO WARRANTY, etc. see website)

typedef struct { uint64_t state;  uint64_t inc; } pcg32_random_t;

uint32_t pcg32_random_r(pcg32_random_t* rng)
{
    uint64_t oldstate = rng->state;
    // Advance internal state
    rng->state = oldstate * 6364136223846793005ULL + (rng->inc|1);
    // Calculate output function (XSH RR), uses old state for max ILP
    uint32_t xorshifted = ((oldstate >> 18u) ^ oldstate) >> 27u;
    uint32_t rot = oldstate >> 59u;
    return (xorshifted >> rot) | (xorshifted << ((-rot) & 31));
}

]]

terra random01(rng : &C.pcg32_random_t) : double
    var randu32 = C.pcg32_random_r(rng)
    -- Divide by range
    return [double](randu32) / [double](4294967295.0)
end

terra randomu32(rng : &C.pcg32_random_t) : uint32
    return C.pcg32_random_r(rng)
end

local arraytypes = {}
BoundedArray = terralib.memoize(function(typ,maxSize)
    maxSize = assert(tonumber(maxSize),"expected a number")
    local struct ArrayImpl {
        data : typ[maxSize];
        N : int;
    }
    ArrayImpl.metamethods.type, ArrayImpl.metamethods.maxSize = typ,maxSize
    ArrayImpl.metamethods.__typename = function(self) return ("BoundedArray(%s,%d)"):format(tostring(self.metamethods.type),self.metamethods.maxSize) end
    terra ArrayImpl:init()
        self.N = 0
    end
    terra ArrayImpl:resize(size : int)
        self.N = size
    end
    terra ArrayImpl:append(element : typ)
        self.data[self.N] = element
        self.N = self.N+1
    end
    terra ArrayImpl:delete(idx : int)
        for i = idx,self.N-1 do
            self.data[i] = self.data[i+1]
        end
        self.N = self.N-1
    end
    ArrayImpl.metamethods.__apply = macro(function(self,idx)
        return `self.data[idx]
    end)
    ArrayImpl.metamethods.__methodmissing = macro(function(methodname,selfexp,...)
        local args = terralib.newlist {...}
        local params = args:map(function(a) return symbol(a:gettype()) end)
        local terra elemfn(a : &typ, [params])
            return a:[methodname](params)
        end
        local RT = elemfn:gettype().returntype
        return quote
            var self = selfexp
            var r : Array(RT)
            r:init(self.N)
            for i = 0,r.N do
                r.data[i] = elemfn(&self.data[i],args)
            end
        in
            r
        end
    end)
    return ArrayImpl
end)


log.level = "error"
