--[[*
@authors Centauri Soldier
@copyright Public Domain
@description
	<h2>triangle</h2>
	<p></p>
@license <p>The Unlicense<br>
<br>
@moduleid line
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

--localization
local class 		= class;
local deserialize	= deserialize;
local math			= math;
local point 		= point;
local serialize		= serialize;
local type 			= type;
local MATH_UNDEF	= MATH_UNDEF;

local tProtectedRepo = {};

local function update(this)
	local tProt = tProtectedRepo[this];

	--update the line's center
	tProt.center.x = (tProt.start.x + tProt.stop.x) / 2;
	tProt.center.y = (tProt.start.y + tProt.stop.y) / 2;

	--update the line's slope, theta and y intercept
	local nYDelta = tProt.stop.y - tProt.start.y;
	local nXDelta = tProt.stop.x - tProt.start.x;
	tProt.slopeIsUndefined = nYDelta == 0;

	if (tProt.slopeIsUndefined) then
		tProt.slope 		= MATH.UNDEF;
		tProt.theta 		= MATH.UNDEF;
		tProt.yIntercept 	= 0;
	else
		tProt.slope 		= nYDelta / nXDelta;
		tProt.theta 		= math.atan(tProt.slope);
		tProt.yIntercept 	= tProt.start.y - tProt.slope * tProt.start.x;
	end

	--update the deltas
	tProt.deltaX = nXDelta;
	tProt.deltaY = nYDelta;

	--update the line's length
	tProt.length = math.sqrt( (tProt.start.x - tProt.stop.x) ^ 2 + (tProt.start.y - tProt.stop.y) ^ 2);
end

return class "line" {

	__construct = function(this, tProtected, oStartPoint, oEndPoint)
		tProtectedRepo[this] = rawtype(tProtected) == "table" and tProtected or {};
		local tProt = tProtectedRepo[this];

		tProt.start 	= point(0, 0);
		tProt.stop 		= point(0, 0);
		tProt.center 	= point(0, 0);

		--if (type(oStartPoint) == "point") then
			tProt.start.x = oStartPoint.x;
			tProt.start.y = oStartPoint.y;
		--end

		--if (type(oEndPoint) == "point") then
			tProt.stop.x = oEndPoint.x;
			tProt.stop.y = oEndPoint.y;
		--end

		update(this);
	end,

	__tostring = function(this)
		local tProt = tProtectedRepo[this];
		local sRet 	= "";

		sRet = sRet.."start: "..tostring(tProt.start).."\r\n";
		sRet = sRet.."end: "..tostring(tProt.stop).."\r\n";
		sRet = sRet.."center: "..tostring(tProt.center).."\r\n";
		sRet = sRet.."slope: "..tProt.slope.."\r\n";
		sRet = sRet.."theta: "..tProt.theta.."\r\n";
		sRet = sRet.."delta x: "..tProt.deltaX.."\r\n";
		sRet = sRet.."delta y: "..tProt.deltaY.."\r\n";
		sRet = sRet.."length: "..tProt.length.."\r\n";
		sRet = sRet.."y intercept: "..tProt.yIntercept.."\r\n";

		return sRet;
	end,

	__len = function(this)
		return tProtectedRepo[this].length;
	end,


	__eq = function(this, oOther)
		local tMe 		= tProtectedRepo[this];
		local tOther 	= tProtectedRepo[oOther];
		return tMe.start.x 	== tOther.start.x 	and tMe.start.y == tOther.start.y and
			   tMe.stop.x 	== tOther.stop.x 	and tMe.stop.y 	== tOther.stop.y;
	end,

	deserialize = function(this, sData)
		local tData = deserialize.table(sData);

		this.start 	= this.start:deserialize(tData.start);
		this.stop	= this.stop:deserialize(tData.stop);
		error("UDPATE THIS FUNCTION")
		return this;
	end,


	drawASCII = function()



	end,

--TODO finish this!
	getAngleTo = function(this, oOther)
		local tProt = tProtectedRepo[this];
		local nRet = nil;

		if (type(oOther) == "line") then
			local oMyPoint 	= tProt.start;
			local oHisPoint	= oOther.start;

			--TODO this is the case where neither slope is undefined...include cases of undefined slopes
			--y = mx + b
			local nMyB = oMyPoint.y - oMyPoint.slope * oMyPoint.x;
			print(nMyB)

		end

		return nRet;
	end,


	getDeltaX = function(this)
		return tProtectedRepo[this].deltaX;
	end,


	getDeltaY = function(this)
		return tProtectedRepo[this].deltaY;
	end,


	getDistance = function(this)
		return tProtectedRepo[this].length;
	end,


	getEnd = function(this)
		return tProtectedRepo[this].stop;
	end,


	getLength = function(this)
		return tProtectedRepo[this].length;
	end,


	getSlope = function(this)
		return tProtectedRepo[this].slope;
	end,


	getStart = function(this)
		return tProtectedRepo[this].start;
	end,


	getTheta = function(this)
		return tProtectedRepo[this].theta;
	end,


	getYIntercept = function(this)
		return tProtectedRepo[this].yIntercept;
	end,


	intersects = function(this, oOther)
		local tMe 		= tProtectedRepo[this];
		local tOther 	= tProtectedRepo[oOther];

		local A1 = tMe.stop.y - tMe.start.y;
		local B1 = tMe.start.x - tMe.stop.x;

		local A2 = tOther.stop.y - tOther.start.y;
		local B2 = tOther.start.x - tOther.stop.x;

		return (A1 * B2 - A2 * B1) ~= 0;
	end,


	intersectsAt = function(this, oOther)
		local tMe 		= tProtectedRepo[this];
		local tOther 	= tProtectedRepo[oOther];
		local oRet		= MATH_UNDEF;

		local A1 = tMe.stop.y - tMe.start.y;
		local B1 = tMe.start.x - tMe.stop.x;
		local C1 = A1 * tMe.start.x + B1 * tMe.start.y;

		local A2 = tOther.stop.y - tOther.start.y;
		local B2 = tOther.start.x - tOther.stop.x;
		local C2 = A2 * tOther.start.x + B2 * tOther.start.y;

		local nDeterminate = (A1 * B2 - A2 * B1);

		if (nDeterminate ~= 0) then
			local x = (B2 * C1 - B1 * C2) / nDeterminate;
			local y = (A1 * C2 - A2 * C1) / nDeterminate;

			oRet = point(x, y);
		end

		return oRet;
	end,


	isParrallel = function(this, oOther)
		local tMe 		= tProtectedRepo[this];
		local tOther 	= tProtectedRepo[oOther];

		return (tMe.slopeIsUndefined and tOther.slopeIsUndefined) or
			   (	(not tMe.slopeIsUndefined and not tOther.slopeIsUndefined)
			   		 and (tMe.slope == tOther.slope)
			   );
	end,

	--[[!
		@desc Serializes the object's data.
		@func line.serialize
		@module line
		@param bDefer boolean Whether or not to return a table of data to be serialized instead of a serialize string (if deferring serializtion to another object).
		@ret sData StringOrTable The data, returned as a serialized table (string) or a table is the defer option is set to true.
	!]]
	serialize = function(this, bDefer)
		local tData = {
			start 	= this.start:seralize(),
			stop 	= this.stop:serialize(),
		};

		if (not bDefer) then
			tData = serialize.table(tData);
		end
		error("UPDATE THIS FUNCTION")--TODO UPDATE THIS
		return tData;
	end,


	setEnd = function(this, oPoint)
		tProtectedRepo[this].stop.x = oPoint.x;
		tProtectedRepo[this].stop.y = oPoint.y;
		update(this);
	end,


	setStart = function(this, oPoint)
		tProtectedRepo[this].start.x = oPoint.x;
		tProtectedRepo[this].start.y = oPoint.y;
		update(this);
	end,
};
