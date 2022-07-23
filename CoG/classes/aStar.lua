--[[
Alter these to fit your game.
]]
--[[enum("ASTAR", 			{"MAP", "NODE", "PATH", "ROVER"});
enum("ASTAR_LAYER", 	{"SUBTERRAIN", "SUBMARINE", "MARINE", "TERRAIN", "AIR", "SPACE"}, {
	enum("ASTAR_LAYER_SUBTERRAIN", 	{"sd", "sd", "sd", "sd", "sd"}),
	enum("ASTAR_LAYER_SUBMARINE", 	{"PRESSURE", "SALINITY", "sd", "sd", "sd"}),
	enum("ASTAR_LAYER_MARINE", 		{"sd", "sd", "sd", "sd", "sd"}),
	enum("ASTAR_LAYER_TERRAIN", 	{"AQUIFER", "COMPACTION", "DETRITUS", "FORAGEABILITY", "FORESTATION",
							 		 "GRADE", "ICINESS", "PALUDALISM", "ROCKINESS", "ROAD", "SNOWINESS",
							 		 "TEMPERATURE", "TOXICITY", "VERDURE"}),
	enum("ASTAR_LAYER_AIR", 		{"sd", "sd", "sd", "sd", "sd"}),
	enum("ASTAR_LAYER_SPACE", 		{"sd", "sd", "sd", "sd", "sd"}),
});
]]
--map types
constant("ASTAR_MAP_TYPE_HEX_FLAT", 		0);
constant("ASTAR_MAP_TYPE_HEX_POINTED", 	1);
constant("ASTAR_MAP_TYPE_HEX_SQUARE", 		2);
constant("ASTAR_MAP_TYPE_HEX_TRIANGLE", 	3);

--localization
local ASTAR_MAP_TYPE_HEX_FLAT 		= ASTAR_MAP_TYPE_HEX_FLAT;
local ASTAR_MAP_TYPE_HEX_POINTED 	= ASTAR_MAP_TYPE_HEX_POINTED;
local ASTAR_MAP_TYPE_HEX_SQUARE 	= ASTAR_MAP_TYPE_HEX_SQUARE;
local ASTAR_MAP_TYPE_HEX_TRIANGLE 	= ASTAR_MAP_TYPE_HEX_TRIANGLE;
local class = class;
local math 	= math;
local rawtype = rawtype;
local type 	= type;

--declarations
local aStarMap;
local aStarLayer;
local aStarNode;
local aStarAspect;
local aStarPath;
local aStarRover;

--where all class fields are stored
local tRepo = {
	aspects	= {},
	aStars 	= {},
	maps	= {},
	layers 	= {},
	nodes	= {},
	paths 	= {},
	rovers	= {},
	configs = {},
};

--[[
██╗░░██╗███████╗██╗░░░░░██████╗░███████╗██████╗░
██║░░██║██╔════╝██║░░░░░██╔══██╗██╔════╝██╔══██╗
███████║█████╗░░██║░░░░░██████╔╝█████╗░░██████╔╝
██╔══██║██╔══╝░░██║░░░░░██╔═══╝░██╔══╝░░██╔══██╗
██║░░██║███████╗███████╗██║░░░░░███████╗██║░░██║
╚═╝░░╚═╝╚══════╝╚══════╝╚═╝░░░░░╚══════╝╚═╝░░╚═╝

███████╗██╗░░░██╗███╗░░██╗░█████╗░████████╗██╗░█████╗░███╗░░██╗░██████╗
██╔════╝██║░░░██║████╗░██║██╔══██╗╚══██╔══╝██║██╔══██╗████╗░██║██╔════╝
█████╗░░██║░░░██║██╔██╗██║██║░░╚═╝░░░██║░░░██║██║░░██║██╔██╗██║╚█████╗░
██╔══╝░░██║░░░██║██║╚████║██║░░██╗░░░██║░░░██║██║░░██║██║╚████║░╚═══██╗
██║░░░░░╚██████╔╝██║░╚███║╚█████╔╝░░░██║░░░██║╚█████╔╝██║░╚███║██████╔╝
╚═╝░░░░░░╚═════╝░╚═╝░░╚══╝░╚════╝░░░░╚═╝░░░╚═╝░╚════╝░╚═╝░░╚══╝╚═════╝░
]]


local function mapDimmIsValid(nValue)
	return rawtype(nValue) 	== "number" and nValue	> 0 and nValue == math.floor(nValue);
end


local function mapTypeIsValid(nType)
	return 	rawtype(nType) == "number" and
			(	nType == ASTAR_MAP_TYPE_HEX_FLAT 		or
				nType == ASTAR_MAP_TYPE_HEX_POINTED 	or
				nType == ASTAR_MAP_TYPE_HEX_SQUARE		or
				nType == ASTAR_MAP_TYPE_HEX_TRIANGLE
			);
end


local function isNonBlankString(vVal)
	return rawtype(vVal) == "string" and vVal:gsub("%s", "") ~= "";
end


local function layersAreValid(tLayers)
	local bRet = false;

	if (rawtype(tLayers) == "table" and #tLayers > 0) then
		bRet = true;

		for k, v in pairs(tLayers) do

			if ( rawtype(k) ~= "number" or not (rawtype(v) == "string" and v:gsub("5s", "") ~= "") ) then
				bRet = false;
				break;
			end

		end

	end

	return bRet;
end


--[[
███╗░░░███╗░█████╗░██████╗░
████╗░████║██╔══██╗██╔══██╗
██╔████╔██║███████║██████╔╝
██║╚██╔╝██║██╔══██║██╔═══╝░
██║░╚═╝░██║██║░░██║██║░░░░░
╚═╝░░░░░╚═╝╚═╝░░╚═╝╚═╝░░░░░
]]
aStarMap = class "aStarMap" {

	__construct = function(this, prot, sName, nType, tLayerConfigs, nWidth, nHeight, ...)
		local tLayerConfigs = arg or {...}; --TODO check the keywords

		--check the input
		assert(isNonBlankString(sName), 					"Argument 1: aStar map name must be a non-blank string.");
		assert(mapTypeIsValid(nType), 						"Argument 2: map type is invalid.");
		assert(mapDimmIsValid(nWidth),						"Argument 4: map width must be positive integer.");
		assert(mapDimmIsValid(nHeight),						"Argument 5: map height must be positive integer.");
		--TODO assert(#tLayerConfigs > 0)
		--TODO assert(type(oLayerConfigs) == "aStarLayerConfig", 	"Argument 3: must be an aStarLayerConfig object.\nGot type, '"..type(type(tLayerConfig)).."'");

		--create the map table
		tRepo.maps[this] = {
			layers 			= {},--(ORDERED BY ID) this table is managed mostly by the aStarLayer local class
			layersRet		= {},--a decoy table for returning layers to the client
			layersByName	= {},
			name 			= sName,
			type			= nType,
			width 			= nWidth,
			height			= nHeight,
		};

		local tFields 	= tRepo.maps[this];

		-- set metatables for the layers table so
		-- it can be returned quickly and still be secure
		setmetatable(tFields.layersRet, {
			__index = function(t, k)
				return tFields.layers[k] or nil;
			end,
			__newindex = function(t, k, v)
				error("Attempting to modifer read-only layers table for map, '"..tFields.name.."'.");
			end,
			__len = function()
				return #tFields.layers;
			end,
			__pairs = function(t)
				return next, tFields.layers, nil;
			end
		});

		--create the layers and their nodes
		for nLayerID, oConfig in pairs(tLayerConfigs) do
			error(type(oConfig))
			--create the actual layer elements
			tFields.layers[nLayerID] = aStarLayer(nLayerID, oConfig, nWidth, nHeight);

			--reference the layer by name for quick access
			tFields.layersByName[oConfig:getName()] = tFields.layers[nLayerID];
		end

	end,
	getHeight = function(this)
		return tRepo.maps[this].height;
	end,
	getLayers = function(this)
		return tRepo.maps[this].layersRet;
	end,
	getName = function(this)
		return tRepo.maps[this].name;
	end,
	getNode = function(this, sLayer, nX, nY)
		local oLayer = tRepo.maps[this].layersByName[sLayer] or nil;

		if (oLayer) then
			return tRepo.maps[this].layersByName[sLayer]:getNode(nX, nY);
		end

	end,
	getSize = function(this)
		local tFields = tRepo.maps[this];
		return {width = tFields.width, height = tFields.height};
	end,
	getType = function(this)
		return tRepo.maps[this].type;
	end,
	getWidth = function(this)
		return tRepo.maps[this].width;
	end,
};


--[[
██╗░░░░░░█████╗░██╗░░░██╗███████╗██████╗░
██║░░░░░██╔══██╗╚██╗░██╔╝██╔════╝██╔══██╗
██║░░░░░███████║░╚████╔╝░█████╗░░██████╔╝
██║░░░░░██╔══██║░░╚██╔╝░░██╔══╝░░██╔══██╗
███████╗██║░░██║░░░██║░░░███████╗██║░░██║
╚══════╝╚═╝░░╚═╝░░░╚═╝░░░╚══════╝╚═╝░░╚═╝
]]
aStarLayer = class "aStarLayer" {
	__construct = function(this, prot, nLayerID, oConfig, nWidth, nHeight)
		tRepo.layers[this] = {
			id 			= nLayerID,
			config 		= oConfig,
			--ownerMap 	= tMap,
			name		= oConfig:getName(),
			nodes 		= {}, --this table is managed mostly by the aStarNode local class
			nodesRet	= {}, --a decoy table for returning to the client
		};

		local tFields = tRepo.layers[this];
		local tNodes = tFields.nodes;

		-- set metatables for the nodes table so
		-- it can be returned quickly and still be secure
		setmetatable(tFields.nodesRet, {
			__index = function(t, k)
				return tFields.nodes[k] or nil;
			end,
			__newindex = function(t, k, v)
				error("Attempting to modifer read-only nodes table for layer, '"..tFields.name.."'.");
			end,
			__len = function()
				return #tFields.nodes;
			end,
			__pairs = function(t)
				return next, tFields.nodes, nil;
			end
		});

		--create the nodes
		for x = 1, nWidth do
			tNodes[x] = {};

			for y = 1, nHeight do
				tNodes[x][y] = aStarNode(x, y);
			end

		end

	end,
	getNode = function(this, nX, nY)
		local tNodes = tRepo.layers[this].nodesRet[nX];

		if (tNodes) then
			return tNodes[nY] or nil;
		end

	end,
	getNodes = function(this)
		return tRepo.layers[this].nodesRet;
	end,
};


--[[
███╗░░██╗░█████╗░██████╗░███████╗
████╗░██║██╔══██╗██╔══██╗██╔════╝
██╔██╗██║██║░░██║██║░░██║█████╗░░
██║╚████║██║░░██║██║░░██║██╔══╝░░
██║░╚███║╚█████╔╝██████╔╝███████╗
╚═╝░░╚══╝░╚════╝░╚═════╝░╚══════╝
]]
aStarNode = class "aStarNode" {
	__construct = function(this, prot, nX, nY)
		tRepo.nodes[this] = {
			aspects 	= {},
			isPassable	= true,
			rovers		= {},
			roversRet 	= {}, --decoy table to return to the client
			x 			= nX,
			y 			= nY,
		};

		local tFields = tRepo.nodes[this];

		-- set metatables for the nodes table so
		-- it can be returned quickly and still be secure
		setmetatable(tFields.roversRet, {
			__index = function(t, k)
				return tFields.rovers[k] or nil;
			end,
			__newindex = function(t, k, v)
				error("Attempting to modifer read-only occupants table for node at x: "..tFields.x..", y: "..tFields.y..".");
			end,
			__len = function()
				return #tFields.rovers;
			end,
			__pairs = function(t)
				return next, tFields.rovers, nil;
			end
		});
	end,

	addRover = function(this, oRover)

		if (type(oRover) == "aStarRover") then
			local tFields = tRepo.nodes[this];
			tFields.rovers[#tFields.rovers + 1] = oRover;
		end

	end,

	containsRover = function(this, oRover)
		local bRet = false;

		for _, oRoverInNode in pairs(tRepo.nodes[this].rovers) do

			if (oRover == oRoverInNode) then
				bRet = true;
			end

		end

		return bRet;
	end,

	getEntryCost = function(this, oRover)

	end,

	getPassable = function(this)
		return tRepo.nodes[this].isPassable;
	end,

	getPos = function(this)
		local tFields = tRepo.nodes[this];
		return {x = tFields.x, y = tFields.y};
	end,

	getRovers = function(this)
		return tRepo.nodes[this].roversRet;
	end,

	getX = function(this)
		return tRepo.nodes[this].x;
	end,

	getY = function(this)
		return tRepo.nodes[this].y;
	end,

	isPassable = function(this, oRover)
		local tFields 	= tRepo.nodes[this];
		local bRet 		= tRepo.nodes[this].isPassable;

		if (bRet) then

		end

		return bRet;
	end,

	setPassable = function(this, bPassable)

		if (rawtype(bPassable) == "boolean") then
			tRepo.nodes[this].isPassable = bPassable;
		end

	end,

	togglePassable = function(this)
		tRepo.nodes[this].isPassable = not tRepo.nodes[this].isPassable;
	end,
};


--[[
░█████╗░░██████╗██████╗░███████╗░█████╗░████████╗
██╔══██╗██╔════╝██╔══██╗██╔════╝██╔══██╗╚══██╔══╝
███████║╚█████╗░██████╔╝█████╗░░██║░░╚═╝░░░██║░░░
██╔══██║░╚═══██╗██╔═══╝░██╔══╝░░██║░░██╗░░░██║░░░
██║░░██║██████╔╝██║░░░░░███████╗╚█████╔╝░░░██║░░░
╚═╝░░╚═╝╚═════╝░╚═╝░░░░░╚══════╝░╚════╝░░░░╚═╝░░░
]]
aStarAspect = class "aStarAspect" {
	__construct = function(this, prot)

	end,
};

--[[
██████╗░░█████╗░████████╗██╗░░██╗
██╔══██╗██╔══██╗╚══██╔══╝██║░░██║
██████╔╝███████║░░░██║░░░███████║
██╔═══╝░██╔══██║░░░██║░░░██╔══██║
██║░░░░░██║░░██║░░░██║░░░██║░░██║
╚═╝░░░░░╚═╝░░╚═╝░░░╚═╝░░░╚═╝░░╚═╝
]]
aStarPath = class "aStarPath" {
	__construct = function(this, oStartNode, oEndNode, oRover)
		tPaths[this] = {};
	end,

	getSteps = function(this)

	end,

	getStepCount = function(this)

	end,

};


--[[
██████╗░░█████╗░██╗░░░██╗███████╗██████╗░
██╔══██╗██╔══██╗██║░░░██║██╔════╝██╔══██╗
██████╔╝██║░░██║╚██╗░██╔╝█████╗░░██████╔╝
██╔══██╗██║░░██║░╚████╔╝░██╔══╝░░██╔══██╗
██║░░██║╚█████╔╝░░╚██╔╝░░███████╗██║░░██║
╚═╝░░╚═╝░╚════╝░░░░╚═╝░░░╚══════╝╚═╝░░╚═╝
]]
aStarRover = class "aStarRover" {
	__construct = function(this)
		tRovers[this] = {
			affinities 	= {},
			aversions 	= {},

		};

	end,

	getAffinites = function(this)

	end,

	getAversions = function(this)

	end,

};

local aStar = class "aStar" {
	__construct = function(this, prot)
		tRepo.aStars[this] = {
			maps 	= {}, --this table is managed mostly by the aStarMap local class
		};
	end,
	getMap = function(this, sName)
		return tRepo.aStars[this].maps[sName] or nil;
	end,
	getNode = function(this, sMap, sLayer, nX, nY)
		local oMap = tRepo.aStars[this].maps[sMap] or nil;

		if (oMap) then
			return oMap:getNode(sLayer, nX, nY);
		end

	end,
	newMap = function(this, sName, nType, tLayers, nWidth, nHeight)
		local tFields = tRepo.aStars[this];

		--create the map (only if doesn't already exist)
		if (rawtype(tFields.maps[sName]) == "nil") then
			tFields.maps[sName] = aStarMap(sName, nType, tLayers, nWidth, nHeight);
			return tFields.maps[sName];
		end

	end,
};

local aStarLayerConfig = class "aStarLayerConfig" {

	__construct = function (this, prot, sName, ...)
		local tInputAspects = arg or {...};
		--TODO assertions

		tRepo.configs[this] = {
			aspects = {}, --TODO make decoy table for this
			name 	= sName,
		};

		--add all user aspect
		local tAspects = tRepo.configs[this].aspects;
		for _, sAspect in pairs(tInputAspects) do
			tAspects[#tAspects + 1] = sAspect;
		end

	end,
	getName = function(this)
		return tRepo.configs[this].name;
	end,
	getAspects = function(this)
		return tRepo.configs[this].aspects; --TODO decoy this
	end,
};

aStar.newLayerConfig = aStarLayerConfig;

return aStar;
