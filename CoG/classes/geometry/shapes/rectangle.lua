--[[*
@authors Centauri Soldier
@copyright Public Domain
@description
	<h2>rectangle</h2>
	<p></p>
@license <p>The Unlicense<br>
<br>
@moduleid rectangle
@version 1.1
@versionhistory
<ul>
	<li>
		<b>1.0</b>
		<br>
		<p>Created the module.</p>
	</li>
	<li>
		<b>1.1</b>
		<br>
		<p>Add serialize and deserialize methods.</p>
	</li>
</ul>
@website https://github.com/CentauriSoldier
*]]

--localization
local class 		= class;
local constant		= constant;
local deserialize	= deserialize;
local math			= math;
local point			= point;
local rawtype 		= rawtype;
local serialize		= serialize;
local type 			= type;

constant("RECTANGLE_VERTEX_TOP_LEFT", 		1);
constant("RECTANGLE_VERTEX_TOP_RIGHT", 		2);
constant("RECTANGLE_VERTEX_BOTTOM_RIGHT", 	3);
constant("RECTANGLE_VERTEX_BOTTOM_LEFT", 	4);

local RECTANGLE_VERTEX_TOP_LEFT 	= RECTANGLE_VERTEX_TOP_LEFT;
local RECTANGLE_VERTEX_TOP_RIGHT 	= RECTANGLE_VERTEX_TOP_RIGHT;
local RECTANGLE_VERTEX_BOTTOM_RIGHT = RECTANGLE_VERTEX_BOTTOM_RIGHT;
local RECTANGLE_VERTEX_BOTTOM_LEFT 	= RECTANGLE_VERTEX_BOTTOM_LEFT;

local tProtectedRepo = {};

local function updateVertices(tProt)
	local tVertices 	= tProt.vertices;
	local pMyTopLeft	= tVertices[RECTANGLE_VERTEX_TOP_LEFT];
	local pTopRight 	= tVertices[RECTANGLE_VERTEX_TOP_RIGHT];
	local pBottomRight 	= tVertices[RECTANGLE_VERTEX_BOTTOM_RIGHT];
	local pBottomLeft 	= tVertices[RECTANGLE_VERTEX_BOTTOM_LEFT];

	pTopRight.x 	= pMyTopLeft.x + tProt.width;
	pTopRight.y 	= pMyTopLeft.y;
	pBottomRight.x 	= pTopRight.x;
	pBottomRight.y	= pTopRight.y + tProt.height;
	pBottomLeft.x	= pMyTopLeft.x;
	pBottomLeft.y	= pBottomRight.y;
end

local rectangle = class "rectangle" : extends(polygon) {

	--[[
	@desc The constructor for the rectangle class.
	@func rectangle
	@mod rectangle
	@ret oRectangle rectangle A rectangle object. Public properties are vertices (a numerically-indexed table containing points for each corner), width and height.
	]]
	__construct = function(this, tProtected, pTopLeft, nWidth, nHeight)
		tProtectedRepo[this] = rawtype(tProtected) == "table" and tProtected or {};
		local tProt = tProtectedRepo[this];

		--setup the protected fields
		tProt.vertices = {
			[1] = point(),
			[2]	= point(),
			[3]	= point(),
			[4]	= point(),
		};
		tProt.width 	= rawtype(nWidth) 	== "number" and nWidth 	or 0;
		tProt.height 	= rawtype(nHeight) 	== "number" and nHeight or 0;

		--check the point input
		if (type(pTopLeft) == "point") then
			tProt.vertices[1].x = pTopLeft.x;
			tProt.vertices[1].y = pTopLeft.y;
			tProt.vertices[2].x = pTopLeft.x + nWidth;
			tProt.vertices[2].y = pTopLeft.y;
			tProt.vertices[3].x = pTopLeft.x + nWidth;
			tProt.vertices[3].y = pTopLeft.y + nHeight;
			tProt.vertices[4].x = pTopLeft.x;
			tProt.vertices[4].y = pTopLeft.y + nHeight;
		end

		--override the required protected methods
		tProt.updateArea = function(tProt)
			tProt.area = tProt.width * tProt.height;
		end

		tProt.updatePerimeterAndEdges = function(tProt)
			tProt.perimeter = 2 * tProt.width + 2 * tProt.height;
			local tVertices = tProt.vertices;

			tProt.edges 	= {
				[1] = math.abs(tVertices[1].x + tVertices[2].x),
				[2] = math.abs(tVertices[2].y + tVertices[3].y),
				[3] = math.abs(tVertices[1].x + tVertices[2].x),
				[4] = math.abs(tVertices[2].y + tVertices[3].y),
			};
		end

		--pass this classes fields but don't pass the vertices table or have the polygon do an update
		this:super(tProt, nil, true);

		--update the rectangle
		tProt:updateDetector();
		tProt:updateCentroid();
		tProt:updatePerimeterAndEdges();
		tProt:updateArea();
	end,


	deserialize = function(this, sData)
		local tData = deserialize.table(sData);

		--this.vertices[]	 	= this.vertices.topLeft:deserialize(tData.vertices.topLeft);
		--this.vertices[]		= this.vertices.topRight:deserialize(tData.vertices.topRight);
		--this.vertices[] 	= this.vertices.bottomLeft:deserialize(tData.vertices.bottomLeft);
		--this.vertices[] 	= this.vertices.bottomRight:deserialize(tData.vertices.bottomRight);
		--this.vertices[]		= this.vertices.center:deserialize(tData.vertices.center);

		this.width 		= tData.width;
		this.height 	= tData.height;
	end,

	getHeight = function(this)
		return tProtectedRepo[this].height;
	end,

	getWidth = function(this)
		return tProtectedRepo[this].width;
	end,


--[[
	pointIsOnPerimeter = function(this, vPoint, vY)

	end
]]


	--[[!
		@desc Serializes the object's data.
		@func rectangle.serialize
		@module rectangle
		@param bDefer boolean Whether or not to return a table of data to be serialized instead of a serialize string (if deferring serializtion to another object).
		@ret sData StringOrTable The data, returned as a serialized table (string) or a table is the defer option is set to true.
	!]]
	serialize = function(this, bDefer)
		local tData = {
			vertices 	= {
				topLeft		= this.vertices.topLeft:seralize(),
				topRight	= this.vertices.topRight:seralize(),
				bottomLeft 	= this.vertices.bottomLeft:seralize(),
				bottomRight = this.vertices.bottomRight:seralize(),
				center		= this.vertices.center:seralize(),
			},
			width 		= this.width,
			height 		= this.height,
		};

		if (not bDefer) then
			tData = serialize.table(tData);
		end

		return tData;
	end,

	setHeight = function(this, nHeight)
		local tProt 	= tProtectedRepo[this];
		local tVertices = tProt.vertices;
		local nDelta 	= nHeight - tProt.height;
		tProt.height 	= nHeight;

		tVertices[3].y = tVertices[3].y + nDelta;
		tVertices[4].y = tVertices[4].y + nDelta;

		tProt:updateCentroid();
		tProt:updateDetector();
		tProt:updatePerimeterAndEdges();
		tProt:updateArea();
	end,

	setWidth = function(this, nWidth)
		local tProt 	= tProtectedRepo[this];
		local tVertices = tProt.vertices;
		local nDelta 	= nWidth - tProt.width;
		tProt.height 	= nWidth;

		tVertices[2].x = tVertices[2].x + nDelta;
		tVertices[3].x = tVertices[3].x + nDelta;

		tProt:updateCentroid();
		tProt:updateDetector();
		tProt:updatePerimeterAndEdges();
		tProt:updateArea();
	end,

	setPos = function(this, tPoint)
		local tProt 	= tProtectedRepo[this];
		local tVertices = tProt.vertices;
		local nDeltaX 	= tPoint.x - tVertices[1].x;
		local nDeltaY 	= tPoint.y - tVertices[1].y;

		tVertices[1].x = tPoint.x;
		tVertices[1].y = tPoint.y;
		tVertices[2].x = tVertices[2].x + nDeltaX;
		tVertices[2].y = tVertices[2].y + nDeltaY;
		tVertices[3].x = tVertices[3].x + nDeltaX;
		tVertices[3].y = tVertices[3].y + nDeltaY;
		tVertices[4].x = tVertices[4].x + nDeltaX;
		tVertices[4].y = tVertices[4].y + nDeltaY;

		tProt:updateCentroid();
		tProt:updateDetector();
	end,
};

return rectangle;
