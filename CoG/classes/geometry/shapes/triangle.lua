--[[*
@authors Centauri Soldier
@copyright Public Domain
@description
	<h2>triangle</h2>
	<p></p>
@license <p>The Unlicense<br>
<br>
@moduleid triangle
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
local serialize		= serialize;
local deserialize	= deserialize;
local type 			= type;

local triangleUpdate;

local triangle = class "triangle" : extends(polygon) {

	--[[
	@desc The constructor for the triangle class.
	@func triangle
	@mod triangle
	@ret oTriangle triangle A triangle object. Public properties are vertices (a table containing points for each corner [topLeft, topRight, bottomRight, bottomLeft, center]), width and height.
	]]
	__construct = function(this, oPoint1, oPoint2, oPoint3)
		this.vertices 	= {
			[1]	= type(oPoint1) == "point" and point(oPoint1.x, oPoint1.y) or point(),
			[2]	= type(oPoint2) == "point" and point(oPoint2.x, oPoint2.y) or point(),
			[3] = type(oPoint3) == "point" and point(oPoint3.x, oPoint3.y) or point(),
		};

		--don't pass the vertices table or have the polygon do an update
		this:super(nil, true);

		this:update();
	end,

	deserialize = function(this, sData)
		local tData = deserialize.table(sData);

		this.vertices.top	 		= this.vertices.top:deserialize(tData.vertices.top);
		this.vertices.bottomLeft 	= this.vertices.bottomLeft:deserialize(tData.vertices.bottomLeft);
		this.vertices.bottomRight 	= this.vertices.bottomRight:deserialize(tData.vertices.bottomRight);
		this.vertices.center		= this.vertices.center:deserialize(tData.vertices.center);

		this.width 		= tData.width;
		this.height 	= tData.height;
	end,

	isAcute = function(this)
		return false;
	end,

	isEquilateral = function(this)
		return false;
	end,

	isIsosceles = function(this)
		return false;
	end,

	isObtuse = function(this)
		return false;
	end,

	isRight = function(this)
	   return false;
   	end,

	isScalene = function(this)
		return false;
	end,

	perimeter = function(this)
		return nil;
	end,

--[[
	pointIsOnPerimeter = function(this, vPoint, vY)

	end
]]
	recalculateVertices = function(this)
		this.vertices.top.x	 		= this.vertices.topLeft.x + this.width;
		this.vertices.top.y	 		= this.vertices.topLeft.y;
		this.vertices.bottomLeft.x 	= this.vertices.topLeft.x
		this.vertices.bottomLeft.y 	= this.vertices.topLeft.y + this.height;
		this.vertices.bottomRight.x	= this.vertices.topRight.x;
		this.vertices.bottomRight.y	= this.vertices.bottomLeft.y;
		this.vertices.center.x		= this.vertices.topLeft.x + this.width / 2;
		this.vertices.center.y		= this.vertices.topLeft.y + this.height / 2;
	end,


	--[[!
		@desc Serializes the object's data.
		@func triangle.serialize
		@module triangle
		@param bDefer boolean Whether or not to return a table of data to be serialized instead of a serialize string (if deferring serializtion to another object).
		@ret sData StringOrTable The data, returned as a serialized table (string) or a table is the defer option is set to true.
	!]]
	serialize = function(this, bDefer)
		local tData = {
			vertices 	= {
				top	 		= this.vertices.top:seralize(),
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

	updateArea = function()
		return (this.width * this.height) / 2;
	end,

};

return triangle;
