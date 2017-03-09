--[[ Adapted from http://ricilake.blogspot.com/2007/10/iterating-bits-in-lua.html 
	These are highly inefficient and should only be used for prototyping

--]]

function bit(p)
  return 2 ^ (p - 1)  -- 1-based indexing
end

-- Typical call:  if hasbit(x, bit(3)) then ...
function hasbit(x, p)
  return x % (p + p) >= p       
end

function setbit(x, p)
  return hasbit(x, p) and x or x + p
end

function clearbit(x, p)
  return hasbit(x, p) and x - p or x
end

function hammingDistance(x,y)
  local p = 1
  while p < x do p = p + p end
  while p < y do p = p + p end
  local dist = 0
  repeat
    if (p <= x) ~= (p <= y) then
        dist = dist + 1
    end
    if p <= x then x = x - p end
    if p <= y then y = y - p end
    p = p * 0.5
  until p < 1
  return dist
end



function setBits(bits)
    local result = 0
    for i,b in ipairs(bits) do
        result = setbit(result, bit(b))
    end
    return result
end