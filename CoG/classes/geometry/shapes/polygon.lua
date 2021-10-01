local tProtectedRepo = {};

local function importVertices(tProt, tVertices)
	local nVerticesCount = #tVertices;

		if (nVerticesCount > 0) then
		tProt.vertices = {};

		for x = 1, nVerticesCount do

			if (type(tVertices[x]) == "point")  then
				tProt.vertices[#tProt.vertices + 1] = point(tVertices[x].x, tVertices[x].y);
			end

		end

	end

end

local function updateDetector(tProt)
	tProt.detector = {};

	--calculate the poly
	local oLastPoint = tProt.vertices[#tProt.vertices];
	local nLastX = oLastPoint.x;
	local nLastY = oLastPoint.y;

	for x = 1, #tProt.vertices do
		local oPoint = tProt.vertices[x];
		local nX = oPoint.x;
		local nY = oPoint.y;
		-- Only store non-horizontal edges.
		if nY ~= nLastY then
			local index = #tProt.detector;
			tProt.detector[index+1] = nX;
			tProt.detector[index+2] = nY;
			tProt.detector[index+3] = (nLastX - nX) / (nLastY - nY);
		end
		nLastX = nX;
		nLastY = nY;
	end

end

local function updateCentroid(tProt)
	tProt.centroid 	= point();
	local nSumX 	= 0;
	local nSumY		= 0;
	local nVertices = #tProt.vertices;

	for x = 1, nVertices do
		local oPoint = tProt.vertices[x];
		nSumX = nSumX + oPoint.x;
		nSumY = nSumY + oPoint.y;
	end

	tProt.centroid.x = nSumX / nVertices;
	tProt.centroid.y = nSumY / nVertices;
end


local function updateArea(tProt)--this algorithm doesn't work on complex polygons, find one which does and check before returning the area
	local nSum = 0;
	local tVertices = tProt.vertices;
	local nVerticesCount = #tVertices;

	for i = 1, nVerticesCount do
		local oPoint1 = tVertices[i];
		local oPoint2 = i < nVerticesCount and tVertices[i + 1] or tVertices[1];

		nSum = nSum + (oPoint1.x * oPoint2.y - oPoint1.y * oPoint2.x)
	end

	tProt.area = math.abs(nSum / 2);
end

local function updatePerimeterAndEdges(tProt)
	local nSum 				= 0;
	local tVertices 		= tProt.vertices;
	local nVerticesCount 	= #tVertices;
	tProt.edges 				= {};

	for i = 1, nVerticesCount do
		local oPoint1 = tVertices[i];
		local oPoint2 = i < nVerticesCount and tVertices[i + 1] or tVertices[1];
		tProt.edges[i] = math.sqrt( (oPoint1.x - oPoint2.x)^2 + (oPoint1.y - oPoint2.y)^2 );
		nSum = nSum + tProt.edges[i];
	end

	tProt.perimeter = nSum;
end

local function placeHolder() end

--[[!
	@mod polygon
	@func polygon
	@desc Used for creating various polygons and handling point
	detection and detector properties. The child class is responsible
	for creating vertices (upon construction) and storing them
	in the public property of 'vertices' (a numerically-indexed
	table whose values are points). The child class is also
	responsible for updating the polygon whenever changes are
	made to size or position. This is done by calling super:update().
	It is expected, when creating the vertices, that a child class will
	insert them into the table starting with the first vertex and continuing
	around the polygon clockwise.
]]
local polygon = class "polygon" : extends(shape) {

	__construct = function(this, tProtected, tVertices, bSkipUpdate)
		tProtectedRepo[this] = rawtype(tProtected) 	== "table" and tProtected or {};
		local tProt = tProtectedRepo[this];

		--setup the protected fields
		tProt.perimeter	= rawtype(tProt.perimeter) 	== "number" and tProt.perimeter 	or 0;
		tProt.vertices	= rawtype(tProt.vertices)	== "table" 	and tProt.vertices 		or {};
		tProt.edges		= rawtype(tProt.edges)		== "table" 	and tProt.edges 		or {};
		tProt.area 		= rawtype(tProt.area) 		== "number" and tProt.area 			or 0;

		--setup the protected methods
		tProt.updateArea				= updateArea;
		tProt.updateCentroid 			= updateCentroid;
		tProt.updateDetector 			= updateDetector;
		tProt.updatePerimeterAndEdges 	= updatePerimeterAndEdges;

		--print("a:s "..tostring(rawtype(this.updateVertices)))
		--indicate whether or not this polygon should recalculate its vertices during update
		--this.doUpdateVertices = rawtype(this.updateVertices) == "function";

		--import the vertices (if present)
		if (rawtype(tVertices) == "table") then
			importVertices(tProt, tVertices);
		end

		--creates mock edge lengths until the next update
		for x = 1, #tProt.vertices do
			tProt.edges[x] = 0;
		end

		--update the polygon (if not skipped)
		if (not bSkipUpdate) then
		--	this:update();
		end

	end,

	__tostring = function(this)
		local sRet = "";

		for k, v in pairs(tProtectedRepo[this]) do
			local sVType = type(v);

			if sVType == "number" 		or sVType == "point" 	or
			   sVType == "line"			or sVType == "shape" 	or
			   sVType == "polygon"		or sVType == "circle" 	or
			   sVType == "hexagon"		or sVType == "triangle" or
			   sVType == "rectangle"	then
				sRet = sRet..tostring(k)..": "..tostring(v).."\r\n";
			end

		end

		return sRet;
	end,

	containsPoint 	= function(this, oPoint)
		local tProt 	= tProtectedRepo[this];
		local tDetector = tProt.detector;
		local nDetector = #tDetector;
		local nLastPX 	= tDetector[nDetector-2]
		local nLastPY 	= tDetector[nDetector-1]
		local bInside 	= false;

		for index = 1, #tDetector, 3 do
			local nPX = tDetector[index];
			local nPY = tDetector[index+1];
			local nDeltaX_Div_DeltaY = tDetector[index+2];

			if ((nPY > oPoint.y) ~= (nLastPY > oPoint.y)) and (oPoint.x < (oPoint.y - nPY) * nDeltaX_Div_DeltaY + nPX) then
				bInside = not bInside;
			end

			nLastPX = nPX;
			nLastPY = nPY;
		end

		return bInside;
	end,

	intersects = function(this, oOther)

	end,

	isConcave = function(this)
		return false;
	end,

	isConvex = function(this)
		return not this:isConcave();
	end,

	isComplex = function(this)--when crossing over itself
		return false;
	end,

	isRegular = function(this)--when all sides are equal and all angles are equal
		return false;
	end,

	--[[update = function(this)
		this:updateVertices();
		this:updatePerimeterAndEdges();
		this:updateDetector();
		this:updateCentroid();
		this:updateArea();
	end,]]

	setVertex = function(this, nIndex, oPoint)
		local tProt = tProtectedRepo[this];

		if (tProt.vertices[nIndex] ~= nil) then
			tProt.vertices[nIndex].x = oPoint.x;
			tProt.vertices[nIndex].y = oPoint.y;
		end

	end,

	setVertices = function(this, nIndex, tPoints)
		local tProt = tProtectedRepo[this];

		if (tProt.vertices[nIndex] ~= nil) then
			tProt.vertices[nIndex].x = oPoint.x;
			tProt.vertices[nIndex].y = oPoint.y;
		end

	end,
};

return polygon;
