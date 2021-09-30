--package.path = package.path..";LuaEx\\?.lua;..\\?.lua;?.lua";
package.path = package.path..";CoG\\?.lua";
require("init");
local function p(item)
	print(tostring(item).." ("..type(item)..")")
end

--local g = aStar.Grid(100, 60);

local h = hexagon(point, 2, false);
--local r = rectangle(point(33, 66), 40, 20);

--h.width = 33;
--r:update();

p(h)
