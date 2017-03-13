package.path = package.path .. ';../luaunit/?.lua;../?.t'
EXPORT_ASSERT_TO_GLOBALS = nil
lu = require('luaunit')


require("bithelpers")


TestBits = {}
function TestBits:testHamming()
    lu.assertEquals(hammingDistance(3,4), 3)
    lu.assertEquals(hammingDistance(16,8),2)
    lu.assertEquals(hammingDistance(127,9),5)
    lu.assertEquals(hammingDistance(4294967295,3),30)
end

function TestBits:testHasBit()
    local v = 0
    for i=1,32 do
        lu.assertEquals(hasbit(v, bit(i)), false)
    end 
    v = 4294967295
    for i=1,32 do
        lu.assertEquals(hasbit(v, bit(i)), true)
    end
end

os.exit( lu.LuaUnit.run() )