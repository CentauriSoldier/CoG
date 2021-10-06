--package.path = package.path..";LuaEx\\?.lua;..\\?.lua;?.lua";
package.path = package.path..";CoG\\?.lua";
require("init");
local function p(item)
	print(tostring(item).." ("..type(item)..")")
end

--local g = aStar.Grid(100, 60);

--local h = hexagon(point, 2, false);
--local r = rectangle(point(33, 66), 40, 20);

--h.width = 33;
--r:update();

--local po = polygon({point(1, 3), point(7, 3), point(7, 7), point(4, 7)});

--p(po.area)
--local poi = point(5, 5);
--print("poi:"..tostring(poi));
--local s = rectangle(point(), 40, 20)
--p(s);

--p(s:getVertex(2));

--local l = line(point(-25, -53), point(200, 68))
--l:setStart(point(0, 0))
--print(l:getDistance())

local l1 = line(point(45, 67), point(412, 234))
local l3 = line(point(45, 67), point(412, 234))
local l2 = line(point(145, -600), point(3, 3))

print(l1 == l3);
--print(l2)
