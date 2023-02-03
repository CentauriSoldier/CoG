local tProtectedRepo = {};

local QUADRANT_I 		= QUADRANT_I;
local QUADRANT_II 		= QUADRANT_II
local QUADRANT_III		= QUADRANT_III;
local QUADRANT_IV 		= QUADRANT_IV;
local QUADRANT_O		= QUADRANT_O;
local QUADRANT_X		= QUADRANT_X;
local QUADRANT_X_NEG 	= QUADRANT_X_NEG;
local QUADRANT_Y		= QUADRANT_Y;
local QUADRANT_Y_NEG	= QUADRANT_Y_NEG;
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


local SIDE_TRIANGLE_DIFFERENTIAL 		= 3;
local SIDE_ANGLE_FACTOR_DIFFERENTIAL	= 2;
local SUM_OF_EXTERIOR_ANGLES			= 360;
--[[
list of protected properties
area
anchorPoint
anchors
detector
edges 		-
edgesCount
exteriorAngles
interiorAngles
perimeter
sumOfInteriorAngles
vertices 	-
verticesCount
x
y

list of protected methods
updatePerimeterAndEdges
updateDetector
updateAnchors
updateArea
updateAngles

]]
local function importVertices(tProt, tVertices, nMax)
	nMax = rawtype(nMax) == "number" and nMax or #tVertices;

	tProt.vertices 		= {};
	tProt.verticesCount = 0;

	for nVertex, oPoint in ipairs(tVertices) do
		tProt.verticesCount	= tProt.verticesCount + 1;

		--make sure the input indices are sequential integers
		if (nVertex ~= tProt.verticesCount) then
			error("Cannot create polygon; vertices must be of type point; vertex ${vertexID} is out of bounds. It should be ${vertexCount}" % {vertexID = nVertex, vertexCount = tProt.verticesCount});
		end

		--make sure each vertex is a point
		if (type(oPoint) ~= "point") then
			error("Cannot create polygon; vertices must be of type point; vertex ${vertexID} is of type ${vertexType}" % {vertexID = nVertex, vertexType = type(oPoint)});
		end

		tProt.vertices[tProt.verticesCount] = point(oPoint.x, oPoint.y);
	end

	if (tProt.verticesCount < 3) then
		error("Cannot create polygon; must have 3 or more sides; given only "..tProt.verticesCount.." vertices.");
	end

	tProt.sumOfInteriorAngles = (tProt.verticesCount - 2) * 180;
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

	tProt.area = nSum / 2;
	--make sure it's a positive number (since the loop goes clockwise instead of CCW)
	tProt.area = tProt.area >= 0 and tProt.area or -tProt.area;
end

local function updatePerimeterAndEdges(tProt)
	tProt.perimeter			= 0;
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

		tProt.perimeter = tProt.perimeter + tProt.edges[i]:getLength();
	end

	tProt.edgesCount = #tProt.edges;
end

local function updateAngles(tProt)
	tProt.interiorAngles 		= {};
	tProt.exteriorAngles 		= {};
	tProt.isConcave 			= false;
	tProt.isRegular				= false;
	local nRegularityAngleMark	= 0;
	local nRegularityEdgeMark	= 0;
	local bRegularityFailed		= false;
	local tEdges 				= tProt.edges;
	local nEdges				= #tProt.edges;


	for nLine = 1, tProt.edgesCount do --use the number of vertices since it's the same as the number of edges
		local bIsFirstLine 	= nLine == 1;

		--determine the lines between which the angle will be
		local oLine1 = tEdges[nLine];
		local oLine2 = bIsFirstLine and tEdges[nEdges] or tEdges[nLine - 1];
		--[[create a ghost triangle by creating a third, ghost line between
			the start of the first line and the end of the second line]]
		local oLine3 = line(oLine1:getEnd(), oLine2:getStart()); --ghost line

		--get the length of each line
		local nLength1 = oLine1:getLength();
		local nLength2 = oLine2:getLength();
		local nLength3 = oLine3:getLength();

		--get the angle opposite the ghost side using law of cosines (c^2 = a^2 + b^2 - 2ab*cos(C))
		local nTheta = math.deg(math.acos((nLength1 ^ 2 + nLength2 ^ 2 - nLength3 ^ 2) / (2 * nLength1 * nLength2)));

		--save the angle
		tProt.interiorAngles[nLine] = nTheta;

		--check for concavity
		if (nTheta > 180) then
			tProt.isConcave = true;
		end

		--regularity check init
		if (bIsFirstLine) then
			nRegularityAngleMark 	= nTheta;
			nRegularityEdgeMark 	= nLength1;
		end

		--regularity check
		if not (bRegularityFailed) then
			--[[check that this angle is the same as
				the last and the side, the same as the last]]
			bRegularityFailed = not (nRegularityAngleMark == nTheta and nRegularityEdgeMark == nLength1);
		end

		--if this is the last line and all angles/edges are repectively equal
		if (not bRegularityFailed and nLine == nEdges) then
			tProt.isRegular = true;
		end

		--get the exterior angle: this allows for negative interior angles so all ext angles == 360 even on concave polygons
		tProt.exteriorAngles[nLine] = 180 - tProt.interiorAngles[nLine];
	end

end

--[[!
	@mod polygon
	@func polygon
	@desc Used for creating various polygons and handling point
	detection and detector properties. The child class is responsible
	for creating vertices (upon construction) and storing them
	in the protected property of 'vertices' (a numerically-indexed
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
		tProt.isConcave				= false;
		tProt.isRegular				= false;
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
		tProt.updateAngles 				= updateAngles;

		--import the vertices (if present)
		if (rawtype(tVertices) == "table") then
			importVertices(tProt, tVertices);
		end

		--update the polygon (if not skipped)
		if (not bSkipUpdate) then
			tProt:updatePerimeterAndEdges();
			tProt:updateDetector();
			tProt:updateAnchors();
			tProt:updateArea();
			tProt:updateAngles();
		end

		if not (tProt.verticesCount) then
			tProt.verticesCount = #tProt.vertices;
		end

		if not (tProt.edgesCount) then
			tProt.edgesCount	= #tProt.edges;
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

	getSumofExteriorAngles = function()
		return SUM_OF_EXTERIOR_ANGLES;
	end,

	--gets the sum of all interior angles
	getSumofInteriorAngles = function(this)
		return tProtectedRepo[this].sumOfInteriorAngles;
	end,

--TODO should these return a copy of the point?
	getPos = function(this)
		local tProt	= tProtectedRepo[this];
		local oRet;

		if (tProt.vertices[tProt.anchorIndex] ~= nil) then--TODO is this right?
			oRet = tProt.vertices[tProt.anchorIndex];
		elseif (tProt.anchors[tProt.anchorIndex] ~= nil) then
			oRet = tProt.anchors[tProt.anchorIndex];
		end

		return oRet;
	end,

	getInteriorAngle = function(this, nVertex)
		return tProtectedRepo[this].interiorAngles[nVertex] or nil;
	end,

	getExteriorAngle = function(this, nVertex)
		return tProtectedRepo[this].exteriorAngles[nVertex] or nil;
	end,

	intersects = function(this, oOther)
		error("This function has not yet been written. Please refrain from using this function for the time being.");
	end,

	isConcave = function(this)--at least one angle that is greater than 180 degrees
		return tProtectedRepo[this].isConcave;
	end,

	isConvex = function(this)--no angle greater than 180 degrees
		return not tProtectedRepo[this].isConcave;
	end,

	isComplex = function(this)--when crossing over itself
		return false;
	end,

	isIrregular = function(this, oOther)
		return not tProtectedRepo[this].isRegular;
	end,

	isRegular = function(this)--when all sides are equal and all angles are equal
		return tProtectedRepo[this].isRegular;
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
	--TODO return a copy (yes, because edges cannot be properly modified by the client; they must use the vertices)
	getEdges = function(this)
		return tProtectedRepo[this].edges or nil;
	end,

	getVertex = function(this, nIndex)--TODO check input value
		local oVertex = tProtectedRepo[this].vertices[nIndex];
		return point(oVertex.x, oVertex.y);
	end,

	serialize = function(this)
		return serialize.table(tProtectedRepo[this]);
	end,
	--TODO should this auto-update position or at least have an optional arg for that?
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
			tProt:updateAngles();
		end

		return this;
	end,

	--TODO should each subclass be forced to set a minimum limit for the vertices so that a fewer-than-expected-input will throw an error.
	setVertices = function(this, tPoints)
		local tProt = tProtectedRepo[this];
		--TODO this function has been updated and, as such, these input arguments are wrong
		tProt:importVertices(tPoints, tProt.verticesCount);
		--TODO doesn't this need updated here?
		return this;
	end,

	translate = function(this, nX, nY)
		local tProt = tProtectedRepo[this];

		--update all vertices
		for nVertex, oVertex in ipairs(tProt.vertices) do
			oVertex.x = oVertex.x + nX;
			oVertex.y = oVertex.y + nY;
		end

		--update all anchors
		for nVertex, oVertex in ipairs(tProt.anchors) do
			oVertex.x = oVertex.x + nX;
			oVertex.y = oVertex.y + nY;
		end

		return this;
	end,

	translateTo = function(this, oPoint)
		local tProt = tProtectedRepo[this];

		--get the anchor point and find the change in x and y
		local oAnchor = tProt.anchors[tProt.anchorIndex];
		local nDeltaX = oPoint.x - oAnchor.x;
		local nDeltaY = oPoint.y - oAnchor.y;

		--adjust all vertices to reflect that change
		for nVertex, oVertex in ipairs(tProt.vertices) do
			oVertex.x = oVertex.x + nDeltaX;
			oVertex.y = oVertex.y + nDeltaY;
		end

		--update all anchors
		for nVertex, oVertex in ipairs(tProt.anchors) do
			oVertex.x = oVertex.x + nDeltaX;
			oVertex.y = oVertex.y + nDeltaY;
		end

		return this;
	end,

	tween = function(this, oPoint, nStepX, nStepY)
		local tProt = tProtectedRepo[this];
		local oAnchor = tProt.anchors[tProt.anchorIndex];

		if (oAnchor.x ~= oPoint.x or oAnchor.y ~= oPoint.y) then
			local nTotalXToGo = math.abs(math.abs(oAnchor.x) - math.abs(oPoint.x));
			local nTotalYToGo = math.abs(math.abs(oAnchor.y) - math.abs(oPoint.y));

			--make sure we don't over step
			if (nXStep > nTotalXToGo or nYStep > nTotalYToGo) then
				--LEFT OFF HERE!!!!
			else

				--update all vertices
				for nVertex, oVertex in ipairs(tProt.vertices) do
					oVertex.x = oVertex.x + nX;
					oVertex.y = oVertex.y + nY;
				end

				--update all anchors
				for nVertex, oVertex in ipairs(tProt.anchors) do
					oVertex.x = oVertex.x + nX;
					oVertex.y = oVertex.y + nY;
				end

			end

		end

	end
};

return polygon;
