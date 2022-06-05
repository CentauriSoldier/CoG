--package.path = package.path..";LuaEx\\?.lua;..\\?.lua;?.lua";
package.path = package.path..";CoG\\?.lua";
require("init");
local function p(item)
	print(tostring(item).." ("..type(item)..")")
end

local r = rectangle(point(0, 0), 25, 20);

enum("LETTER", {"A","B","C","D"})

--local l = line(point(0, 40), point(0, 200));
--p(l:getTheta());
--p(r:getInteriorAngle(4))
targetor.init({"ORC", "ELF", "GNOME", "HUMAN", "DRAGON", "FLYING", "GROUND"});

--tTheTargetors, tTargetables, tImmunities, tInterdictors, tPrereqs, tProrities, tThreats
local t = targetor.TARGET;
--p(t.ORC)
--orc = targetor();
orc 	= targetor({t.ORC, t.GROUND},		{t.GROUND, t.HUMAN, t.DRAGON}, 	nil, 		nil, nil, 			{t.ELF}, 	nil);
--elf 	= targetor({ELF, GROUND}, 		{GROUND}, 			{DRAGON}, 	nil, 		nil, 	{ORC});
--orc = orc - targetor.TARGETABLE.DRAGON
dragon	= targetor({t.DRAGON}, 				{t.GROUND, t.FLYING}, 			{t.HUMAN}, 	nil, {t.FLYING}, 	{t.ORC}, 	{t.ORC});

--dragon = targetor.PREREQ.FLYING - dragon;
orc = targetor.TARGETABLE.FLYING + orc
--orc = targetor.PRIORITY.ELF + orc
--orc = targetor.PRIORITY.ELF - orc
for k, v in pairs(orc:get(targetor.TARGETABLE)) do
	--p("Orc targetables: "..tostring(k).." | "..tostring(v))
end
--dragon = dragon - targetor.IMMUNITY.ORC;
--orc = orc - targetor.INTERDICTOR.DRAGON
--p(orc > dragon);
p(orc:has(targetor.TARGETABLE.FLYING))
--p("Orc has preques for Dragon: "..tostring(orc:hasPrereqsFor(dragon)))

for k, v in pairs(dragon:get(targetor.PREREQ)) do
	--p(tostring(k).." | "..tostring(v))
end
--a = 1;
--b = 2;
--c = 3;

--e = true;
--f = false;
--p(a & b)
