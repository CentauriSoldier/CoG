local function importVertices(tVertices)

	if (rawtype(tVertices) == "table") then
		this.vertices = {};

		for x = 1, #tVertices do

			if (type(tVertices[x]) == "point")  then
				this.vertices[#this.vertices + 1] = point(tVertices[x].x, tVertices[x].y);
			end

		end

	end

end

local function updateDetector(this)
	this.detector = {};

	--calculate the poly
	local oLastPoint = this.vertices[#this.vertices];
	local nLastX = oLastPoint.x;
	local nLastY = oLastPoint.y;

	for x = 1, #this.vertices do
		local oPoint = this.vertices[x]
		local nX = oPoint.x;
		local nY = oPoint.y;
		-- Only store non-horizontal edges.
		if nY ~= nLastY then
			local index = #this.detector;
			this.detector[index+1] = nX;
			this.detector[index+2] = nY;
			this.detector[index+3] = (nLastX - nX) / (nLastY - nY);
		end
		nLastX = nX;
		nLastY = nY;
	end

end

local function updateCentroid(this)
	this.centroid 	= point();
	local nSumX 	= 0;
	local nSumY		= 0;
	local nVertices = #this.vertices;

	for x = 1, nVertices do
		local oPoint = this.vertices[x];
		nSumX = nSumX + oPoint.x;
		nSumY = nSumY + oPoint.y;
	end

	this.centroid.x = nSumX / nVertices;
	this.centroid.y = nSumY / nVertices;
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
]]
local polygon = class "polygon" : extends(shape) {

	--__construct = function(this)
	--end,

	__tostring = function(this)
		local sRet = "";

		for k, v in pairs(this) do
			local sVType = type(v);

			if sVType == "number" 		or sVType == "point" 	or
			   sVType == "line"			or sVType == "shape" 	or
			   sVType == "polygon"		or sVType == "circle" 	or
			   sVType == "hexagon"		or sVType == "triangle" or
			   sVType == "rectangle"	or sVType == "triangle" then
				sRet = sRet..tostring(k)..": "..tostring(v).."\r\n";
			end

		end

		return sRet;
	end,

	containsPoint 	= function(this, oPoint)
		local tDetector = this.detector;
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

	recalculateVertices = function()
		error("The recalculateVertices function has not been implemeneted in the child class.");
	end,

	update = function(this)
		this:recalculateVertices(this);
		updateDetector(this);
		updateCentroid(this);
	end,
};

return polygon;
