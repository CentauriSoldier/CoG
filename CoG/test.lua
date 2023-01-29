--package.path = package.path..";LuaEx\\?.lua;..\\?.lua;?.lua";
package.path = package.path..";CoG\\?.lua";
require("init");
local function p(item)
	print(tostring(item).." ("..type(item)..")")
end

--local r = rectangle(point(0, 0), 25, 20);
--local t = rectangle(point(0, 0), 25, 20);
--local g = polygon({point(0,0), point(-5,5), point(10,10)});

--enum("LETTER", {"A","B","C","D"})

--local l = line(point(0, 40), point(0, 200));
--p(l:getTheta());
--p(g:getInteriorAngle(3))

--wolfram alpha code = polygon (0,0) (10,10) (-5,5)
local tBullet = {

};


local bullet = struct("bullet", {
	id 			= 34,
	velocity 	= 0,
	hasImpacted = false,
	block 		= {code = 45},
});
i = set();
--local k = bullet();
local k = bullet({id = "34sdf"});
--local t = bullet();
--p(s == null)
--k.id = NULL
--k.id =
--k.id = 44
--k.id = null
--k.id = "asd3234asd"
--k.id = 4567
--p(type(k))
--p(struct.struct.bullet)
--p(type(bullet))
--p(type(struct))
--constant("ZERO", 0)
--local sub = enum("SUB", {"ONE", "TWO"}, true);
--[[enum("TEST", {"SUB1", "SUB2"}, {enum("SUB1", {"ONE", "TWO", "THREE", "FOUR", "FIVE"}, nil, true),
								enum("SUB2", {"SIX", "SEVEN", "EIGHT", "NINE", "TEN"}, nil, true)
							});

t = {
	k = TEST.SUB1.TWO,
	r = TEST.SUB2.SEVEN,
}

enum("COLOR", {"RED", "GREEN", "BLUE"})
--st = serialize.table(t)
--print(12)
--print(type(TEST.SUB1.ONE.FIV));
local tSub1Meta = getmetatable(TEST.SUB1.TWO.parent);
local nMetaCount = 0;

for sIndex, vValue in TEST() do
	print(vValue)
end

--print(nMetaCount, serialize.table(tSub1Meta));
--print(type(TEST.SUB1()))
--print(TEST.SUB.valueType)
--print(st)
--print(type(TEST))
--print(COLOR.RED.enum.__name)

--check if item is of type enum.
]]

enum("NUMBER", {"ODD", "EVEN"}, {
				enum("ODD", 	{"ONE", "THREE", "FIVE", "SEVEN", "sd"},		nil, true),
				enum("EVEN", 	{"TWO", "FOUR", "SIX", "EIGHT", "TEN"}, nil, true),
				})
--COLOR.RED.OR = 0
local k = NUMBER.EVEN.TWO
print(NUMBER[1].next())
























--sd
