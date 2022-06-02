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

enum("TARGET", {"ORC", "ELF", "GNOME", "HUMAN", "DRAGON", "FLYING", "GROUND", "GROUND"});

--tTargetors, tTargets, tImmunities, tRequirements, tProrities, tThreats

orc 	= targetor({TARGET.ORC, TARGET.GROUND},		{TARGET.GROUND, TARGET.FLYING, TARGET.HUMAN}, 	nil, 			nil, 				{TARGET.ELF}, 	nil);
orc = orc * TARGET.DRAGON
orc = orc / TARGET.DRAGON
dragon	= targetor({TARGET.DRAGON}, 				{TARGET.GROUND, TARGET.FLYING}, 				nil, 			{TARGET.FLYING}, 	{TARGET.ORC}, 	{TARGET.ORC});
--elf 	= targetor({ELF, GROUND}, 		{GROUND}, 			{DRAGON}, 	nil, 		nil, 	{ORC});
p(orc > dragon);
