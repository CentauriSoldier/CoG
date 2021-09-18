--package.path = package.path..";LuaEx\\?.lua;..\\?.lua;?.lua";
package.path = package.path..";CoG\\?.lua";
require("init");

local t = iota();

print(tostring(t))
t:setHours(344)

print(t:getHours());
