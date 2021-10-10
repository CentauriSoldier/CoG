local tProtectedRepo = {};

local SHAPE_ANCHOR_COUNT		= SHAPE_ANCHOR_COUNT;
local SHAPE_ANCHOR_TOP_LEFT 	= SHAPE_ANCHOR_TOP_LEFT;
local SHAPE_ANCHOR_TOP_RIGHT 	= SHAPE_ANCHOR_TOP_RIGHT;
local SHAPE_ANCHOR_BOTTOM_RIGHT = SHAPE_ANCHOR_BOTTOM_RIGHT;
local SHAPE_ANCHOR_BOTTOM_LEFT 	= SHAPE_ANCHOR_BOTTOM_LEFT;
local SHAPE_ANCHOR_CENTROID		= SHAPE_ANCHOR_CENTROID;
local SHAPE_ANCHOR_DEFAULT		= SHAPE_ANCHOR_DEFAULT;
local class 					= class;
local deserialize				= deserialize;
local line 						= line;
local math 						= math;
local pairs 					= pairs;
local point 					= point;
local rawtype 					= rawtype;
local serialize					= serialize;
local table 					= table;
local tostring 					= tostring;
local type 						= type;


local function importVertices(tProt, tVertices, nMax)
	nMax = rawtype(nMax) == "number" and nMax or #tVertices;

		if (nMax > 0) then
		tProt.vertices 		= {};
		tProt.verticesCount = 0;

		for x = 1, nMax do

			if (type(tVertices[x]) == "point") then
				tProt.verticesCount	= tProt.verticesCount + 1;
				tProt.vertices[tProt.verticesCount + 1] = point(tVertices[x].x, tVertices[x].y);

			end

		end

	end

end

local function updateDetector(tProt)
	tProt.detector = {};

	--calculate the poly
	local oLastPoint = tProt.vertices[tProt.verticesCount];
	local nLastX = oLastPoint.x;
	local nLastY = oLastPoint.y;

	for x = 1, tProt.verticesCount do
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

local function updateAnchors(tProt)
	local nSumX 				= 0;
	local nSumY					= 0;
	local tVertices 			= tProt.vertices;
	local nVertices 			= tProt.verticesCount;
	local oAnchorTopLeft 		= tProt.anchors[SHAPE_ANCHOR_TOP_LEFT];
	local oAnchorTopRight		= tProt.anchors[SHAPE_ANCHOR_TOP_RIGHT];
	local oAnchorBottomRight 	= tProt.anchors[SHAPE_ANCHOR_BOTTOM_RIGHT];
	local oAnchorBottomLeft 	= tProt.anchors[SHAPE_ANCHOR_BOTTOM_LEFT];

	--prep the 'corner' anchor points
	local oPoint1 = tVertices[1];

	--top left
	oAnchorTopLeft.x = oPoint1.x;
	oAnchorTopLeft.y = oPoint1.y;
	--top right
	oAnchorTopRight.x = oPoint1.x;
	oAnchorTopRight.y = oPoint1.y;
	--bottom right
	oAnchorBottomRight.x = oPoint1.x;
	oAnchorBottomRight.y = oPoint1.y;
	--bottom left
	oAnchorBottomLeft.x = oPoint1.x;
	oAnchorBottomLeft.y = oPoint1.y;

	for x = 1, nVertices do
		--process data for the centroid
		local oPoint = tVertices[x];
		nSumX = nSumX + oPoint.x;
		nSumY = nSumY + oPoint.y;

		--update the 'corner' anchor points

		--top left
		oAnchorTopLeft.x = oPoint.x < oAnchorTopLeft.x and oPoint.x or oAnchorTopLeft.x;
		oAnchorTopLeft.y = oPoint.y < oAnchorTopLeft.y and oPoint.y or oAnchorTopLeft.y;
		--top right
		oAnchorTopRight.x = oPoint.x > oAnchorTopRight.x and oPoint.x or oAnchorTopRight.x;
		oAnchorTopRight.y = oPoint.y < oAnchorTopRight.y and oPoint.y or oAnchorTopRight.y;
		--bottom right
		oAnchorBottomRight.x = oPoint.x > oAnchorBottomRight.x and oPoint.x or oAnchorBottomRight.x;
		oAnchorBottomRight.y = oPoint.y > oAnchorBottomRight.y and oPoint.y or oAnchorBottomRight.y;
		--bottom left
		oAnchorBottomLeft.x = oPoint.x < oAnchorBottomLeft.x and oPoint.x or oAnchorBottomLeft.x;
		oAnchorBottomLeft.y = oPoint.y > oAnchorBottomLeft.y and oPoint.y or oAnchorBottomLeft.y;
	end

	--update the centroid anchor
	tProt.anchors[SHAPE_ANCHOR_CENTROID].x = nSumX / nVertices;--tProt.centroid.x;
	tProt.anchors[SHAPE_ANCHOR_CENTROID].y = nSumY / nVertices;--tProt.centroid.y;
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
	local nVerticesCount 	= tProt.verticesCount;

	if (tProt.edges[nVerticesCount] == nil) then
		tProt.edges	= {};

		for x = 1, nVerticesCount do
			tProt.edges[x] = line(nil, nil, true);
		end

	end

	for i = 1, nVerticesCount do
		local oPoint1 = tVertices[i];
		local oPoint2 = i < nVerticesCount and tVertices[i + 1] or tVertices[1];
		tProt.edges[i]:setStart(oPoint1, true);
		tProt.edges[i]:setEnd(oPoint2);
		-- = 0;--math.sqrt( (oPoint1.x - oPoint2.x)^2 + (oPoint1.y - oPoint2.y)^2 );
		nSum = nSum + tProt.edges[i]:getLength();
	end

	tProt.perimeter = nSum;
end

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

	Protected fields:
	anchorIndex
	area 					(number)
	edges					(numerically-indexed table of lines)
	perimeter				(number)
	vertices 				(numerically-indexed table of points)
	verticesCount			(number) NO CHILD CLASS SHOULD MODIFY THIS VALUE
	importVertices 			(function)
	updateArea				(function)
	updateAnchors 			(function)
	updateDetector 			(function)
	updatePerimeterAndEdges (function)


]]
local polygon = class "polygon" : extends(shape) {

	__construct = function(this, tProtected, tVertices, bSkipUpdate)
		tProtectedRepo[this] = rawtype(tProtected) 	== "table" and tProtected or {};
		--super(tProtectedRepo[this], true);
		local tProt = tProtectedRepo[this];

		--import (or setup) the protected fields
		tProt.perimeter				= rawtype(tProt.perimeter) 		== "number" and tProt.perimeter 		or 0;
		tProt.vertices				= rawtype(tProt.vertices)		== "table" 	and tProt.vertices 			or {};
		tProt.edges					= rawtype(tProt.edges)			== "table" 	and tProt.edges 			or {};
		tProt.area 					= rawtype(tProt.area) 			== "number" and tProt.area 				or 0;
		--this can be be set to a vertex ID or one of the shape anchor constants
		tProt.anchorIndex 			= rawtype(tProt.anchorIndex) 	== "number" and tProt.anchorIndex		or SHAPE_ANCHOR_DEFAULT;

		--setup the anchor points
		tProt.anchors	=  {
			[SHAPE_ANCHOR_TOP_LEFT] 	= point(),
			[SHAPE_ANCHOR_TOP_RIGHT]	= point(),
			[SHAPE_ANCHOR_BOTTOM_RIGHT]	= point(),
			[SHAPE_ANCHOR_BOTTOM_LEFT]	= point(),
			[SHAPE_ANCHOR_CENTROID]		= point(),
		}

		--setup the protected methods
		tProt.importVertices			= importVertices;
		tProt.updateArea				= updateArea;
		tProt.updateAnchors 			= updateAnchors;
		tProt.updateDetector 			= updateDetector;
		tProt.updatePerimeterAndEdges 	= updatePerimeterAndEdges;

		--import the vertices (if present)
		if (rawtype(tVertices) == "table") then
			tProt:importVertices(tVertices);
		end

		--update the polygon (if not skipped)
		if (not bSkipUpdate) then
			tProt:updatePerimeterAndEdges();
			tProt:updateDetector();
			tProt:updateAnchors();
			tProt:updateArea();
		end

		tProt.verticesCount = #tProt.vertices;
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


	containsCoord 	= function(this, nX, nY)
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

			if ((nPY > nY) ~= (nLastPY > nY)) and (nX < (nY - nPY) * nDeltaX_Div_DeltaY + nPX) then
				bInside = not bInside;
			end

			nLastPX = nPX;
			nLastPY = nPY;
		end

		return bInside;
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

	deserialize = function(this)
		error("COMPLETE THIS")
	end,

--TODO should these return a copy of the point?
	getPos = function(this)
		local tProt	= tProtectedRepo[this];
		local oRet;

		if (tProt.vertices[tProt.anchorIndex] ~= nil) then
			oRet = tProt.vertices[tProt.anchorIndex];
		elseif (tProt.anchors[tProt.anchorIndex] ~= nil) then
			oRet = tProt.anchors[tProt.anchorIndex];
		end

		return oRet;
	end,

	intersects = function(this, oOther)
		return false;
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

	getAnchorIndex = function(this)
		return tProtectedRepo[this].anchorIndex;
	end,

	getArea = function(this)
		return tProtectedRepo[this].area;
	end,
	--TODO should these return a copy of the point?
	getCentroid = function(this)
		return tProtectedRepo[this].anchors[SHAPE_ANCHOR_CENTROID];
	end,
--TODO should these return a copy
	getEdge = function(this, nIndex)
		return tProtectedRepo[this].edges[nIndex] or nil;
	end,
	--TODO return a copy
	getEdges = function(this)
		return tProtectedRepo[this].edges or nil;
	end,

--TODO should these return a copy of the point?
	getVertex = function(this, nIndex)
		return tProtectedRepo[this].vertices[nIndex];
	end,

	serialize = function(this)
		return serialize.table(tProtectedRepo[this]);
	end,

	setAnchorIndex = function(this, nIndex)
		local tProt	= tProtectedRepo[this];

		if (tProt.vertices[nIndex] ~= nil or tProt.anchors[nIndex] ~= nil) then
			tProt.anchorIndex = nIndex;
		end

		return this;
	end,


	setPos = function(this, nX, nY)
		local tProt	= tProtectedRepo[this];
		local oPivot;
		local nXDelta;
		local nYDelta;

		if (tProt.vertices[tProt.anchorIndex] ~= nil) then
			oPivot = tProt.vertices[tProt.anchorIndex];
		elseif (tProt.anchors[tProt.anchorIndex] ~= nil) then
			oPivot = tProt.anchors[tProt.anchorIndex];
		end

		--get the delta values
		nXDelta = nX - oPivot.x;
		nYDelta = nY - oPivot.y;

		--shift the vertices by the delta values
		for x = 1, tProt.verticesCount do
			local oPoint = tProt.vertices[x];
			oPoint.x = oPoint.x + nXDelta;
			oPoint.y = oPoint.y + nYDelta;
		end

		--update the centroid and anchors
		updateAnchors(tProt);

		return this;
	end,

	setVertex = function(this, nIndex, oPoint)
		local tProt = tProtectedRepo[this];

		if (tProt.vertices[nIndex] ~= nil) then
			tProt.vertices[nIndex].x = oPoint.x;
			tProt.vertices[nIndex].y = oPoint.y;
			tProt:updatePerimeterAndEdges();
			tProt:updateDetector();
			tProt:updateAnchors();
			tProt:updateArea();
		end

	end,

	setVertices = function(this, tPoints)
		local tProt = tProtectedRepo[this];
		tProt:importVertices(tPoints, tProt.verticesCount);
	end,
};

return polygon;
