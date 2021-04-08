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
</ul>
@website https://github.com/CentauriSoldier
*]]
assert(type(shape) == "class", "Error loading the rectangle class. It depends on the shape class.");
assert(type(point) == "class", "Error loading the rectangle class. It depends on the point class.");

--VERTEX_TOP_LEFT 	= "topLeft";
--VERTEX_TOP_RIGHT 	= "topRight";
--VERTEX_BOTOM_RIGHT 	= "bottomRight";
--VERTEX_BOTOM_LEFT 	= "bottomLeft";
--VERTEX_CENTER	 	= "center";

local function recalculateVertices(this)
	this.vertices.topRight 		= point(this.vertices.topLeft.x + this.width, this.vertices.topLeft.y);
	this.vertices.bottomLeft 	= point(this.vertices.topLeft.x, this.vertices.topLeft.y + this.height);
	this.vertices.bottomRight 	= point(this.vertices.topRight.x, this.vertices.bottomLeft.y);
	this.vertices.center		= point(this.vertices.topLeft.x + this.width / 2, this.vertices.topLeft.y + this.height / 2);
end


class "rectangle" : extends(shape) {

	--[[
	@desc The constructor for the rectangle class.
	@func rectangle
	@mod rectangle
	@ret oRectangle rectangle A rectangle object. Public properties are vertices (a table containing points for each corner [topLeft, topRight, bottomRight, bottomLeft, center]), width and height.
	]]
	__construct = function(this, pTopLeft, nWidth, nHeight)
		this.vertices 	= {
			topLeft = nil,
		};
		this.width 		= 0;
		this.height 	= 0;

		--check the point input
		if (type(pTopLeft) == "point") then
			this.vertices.topLeft = point(pTopLeft.x, pTopLeft.y);
		else
			this.vertices.topLeft = point();
		end

		--check the width and height input
		if (type(nWidth) == "number") then
			this.width = nWidth;
		end

		if (type(nHeight) == "number") then
			this.height = nHeight;
		end

		recalculateVertices(this);
	end,


	area = function()
		return this.width * this.height;
	end,


	containsPoint = function(this, vPoint, vY)
		local sPointType 	= type(vPoint);
		local x 			= 0;
		local y 			= 0;

		if (sPointType == "point") then
			x = vPoint.x;
			y = vPoint.y;

		elseif (sPointType == "number" and type(vY) == "number") then
			x = vPoint;
			y = vY;
		end

		return x >= this.vertices.topLeft.x and x <= this.vertices.topRight.x and
			   y >= this.vertices.topLeft.y and y <= this.vertices.bottomRight.y;
	end,


	perimeter = function(this)
		return 2 * this.width + 2 * this.height;
	end,

--[[
	pointIsOnPerimeter = function(this, vPoint, vY)

	end
]]
	recalculateVertices = function(this)
		recalculateVertices(this);
	end,

};

return rectangle;
