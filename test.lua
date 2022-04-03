--package.path = package.path..";LuaEx\\?.lua;..\\?.lua;?.lua";
package.path = package.path..";CoG\\?.lua";
require("init");
local function p(item)
	print(tostring(item).." ("..type(item)..")")
end

local r = rectangle(point(7, 3), 25, 25);
--local p = line(point(0, -20), point(0, 30));
--p(r:serialize());
p(r:getInteriorAngle(1))
