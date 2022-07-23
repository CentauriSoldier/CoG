function getsourcepath()
	--determine the call location
	local sPath = debug.getinfo(1, "S").source;
	--remove the calling filename
	local sFilenameRAW = sPath:match("^.+"..package.config:sub(1,1).."(.+)$");
	--make a pattern to account for case
	local sFilename = "";
	for x = 1, #sFilenameRAW do
		local sChar = sFilenameRAW:sub(x, x);

		if (sChar:find("[%a]")) then
			sFilename = sFilename.."["..sChar:upper()..sChar:lower().."]";
		else
			sFilename = sFilename..sChar;
		end

	end
	sPath = sPath:gsub("@", ""):gsub(sFilename, "");
	--remove the "/" at the end
	sPath = sPath:sub(1, sPath:len() - 1);

	return sPath;
end

--determine the call location
local sPath = getsourcepath();

--update the package.path (use the main directory to prevent namespace issues)
package.path = package.path..";"..sPath.."\\..\\?.lua;";

--load LuaEx
require("init");
--============= TEST CODE BELOW =============
local as = aStar();
local groundConfig = aStar.newLayerConfig("Ground", "AQUIFER", "COMPACTION", "DETRITUS", "FORAGEABILITY", "FORESTATION",
												"GRADE", "ICINESS", "PALUDALISM", "ROCKINESS", "ROAD", "SNOWINESS",
												"TEMPERATURE", "TOXICITY", "VERDURE");
--print(type(groundConfig))
local oWorldMap = as:newMap("World Map", ASTAR_MAP_TYPE_HEX_POINTED, {groundConfig}, 50, 28);
--local tWorldMapLayers = oWorldMap:getLayers();

--print(as:getNode("World Map", "Ground", 10, 24):getPassable());

--for nID, oLayer in pairs(tWorldMapLayers) do

	--local tNodes = oLayer:getNodes();

	--for x, tXNodes in pairs(tNodes) do

		--for y, oNode in pairs(tXNodes) do
			--local tPos = oNode:getPos();
			--print(tPos.x, tPos.y)
		--end

	--end

--end
