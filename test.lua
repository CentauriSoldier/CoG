--package.path = package.path..";LuaEx\\?.lua;..\\?.lua;?.lua";
package.path = package.path..";CoG\\?.lua";
require("init");

local t = iota();


print(type(IOTA.MAX))
print(subtype(IOTA.MAX))

t:setHours(13)
print(t:getHours());
print(tostring(t))
