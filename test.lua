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
--local s = rectangle(point(), 40, 20)
--p(s)

local tProtectedRepo = {};

local animal = class "animal" {

	__construct = function(this, protected, sName, bIsBiped)
		--setup the protected table for this instance (or import the given one if it's not nil)
		tProtectedRepo[this] = rawtype(protected) == "table" and protected or {};

		--for readability
		local tProt = tProtectedRepo[this];

		--create the protected properties
		tProt.name 		= type(sName) 		== "string" and sName 		or "";
		tProt.isBiped 	= type(bIsBiped)	== "string" and bIsBiped 	or false;

	end,


};

local dog = class "dog" : extends(animal) {

	__construct = function(this, protected, sName)
		--setup the protected table for this instance (or import the given one if it's not nil)
		tProtectedRepo[this] = rawtype(protected) == "table" and protected or {};

		--for readability
		local tProt = tProtectedRepo[this];

		--call the parent constructor
		this:super(tProt, sName, false);
	end,

	bark = function(this)
		print(tProtectedRepo[this].name.." says, \"Woof!\".");
	end,
};

local spot = dog("Spot");
spot:bark();
