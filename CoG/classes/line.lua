--[[







--TODO this does not works correctly...fix it
theta = function(this, oOther)
	local nRet = 0;

	if (type(this) == "point" and type(oOther) == "point") then
		nXDelta = this.x - oOther.x;
		nYDelta = this.y - oOther.y;

		if (nYDelta == 0) then
			nRet = MATH.UNDEF;
		else
			nRet = math.atan(nYDelta / nXDelta);
		end

	end

	return nRet;
end,
]]

assert(type(point) == "class", "Error loading the line class. It depends on the point class.");

class "line" {

	__construct = function(this, oStartPoint, oEndPoint)

		if (type(oStartPoint) == "point") then
			this.startPoint = oStartPoint;
		else
			this.startPoint = point(0, 0);
		end

		if (type(oEndPoint) == "point") then
			this.endPoint = oEndPoint;
		else
			this.endPoint = point(1, 1);
		end

	end,

	__len = function(this)
		return math.math.sqrt( (this.startPoint.x - this.endPoint.x) ^ 2 + (this.startPoint.y - this.endPoint.y) ^ 2);
	end,

	length = function(this)
		return math.math.sqrt( (this.startPoint.x - this.endPoint.x) ^ 2 + (this.startPoint.y - this.endPoint.y) ^ 2);
	end,


	intersects = function(this, oOther)

	end,


	intersectsAt = function(this, oOther)

	end,


	isParrallel = function(this, oOther)
		local bRet = false;

		if (type(this) == "line" and type(oOther) == "line") then
			local nMySlope 			= this:slope();
			local nOtherSlope 		= oOther:slope();
			local sMySlopeType		= type(nMySlope);
			local sOtherSlopeType	= type(nOtherSlope);


			if (sMySlopeType == "number" and sOtherSlopeType == "number") then
				bRet = nMySlope == nOtherSlope;

			elseif (sOtherSlopeType == "string" and sOtherSlopeType == "string") then
				bRet = true;

			end

		end
		

		return bRet;
	end,

	slope = function(this)
		local nRet = 0;
		local nYDelta = this.endPoint.y - this.startPoint.y;

		if (nYDelta == 0) then
			nRet = MATH.UNDEF;
		else
			nRet = nYDelta / (this.endPoint.x - this.startPoint.x);
		end

		return nRet;
	end,

}
