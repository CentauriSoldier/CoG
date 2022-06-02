--package.path = package.path..";LuaEx\\?.lua;..\\?.lua;?.lua";
package.path = package.path..";CoG\\?.lua";
require("init");
local function p(item)
	print(tostring(item).." ("..type(item)..")")
end

local r = rectangle(point(0, 0), 25, 20);

--local l = line(point(0, 40), point(0, 200));
--p(l:getTheta());
--p(r:getInteriorAngle(4))
local po = pot(1, 100, 1, 1, POT_CONTINUITY_ALT);

for x = 1, 100 do
	--p(po:getPos())
	po:decrease();
	p(po:getPos())
end
