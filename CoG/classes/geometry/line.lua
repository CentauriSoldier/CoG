--[[*
@authors Centauri Soldier
@copyright Public Domain
@description
	<h2>line</h2>
	<p></p>
@license <p>The Unlicense<br>
<br>
@moduleid line
@version 1.2
@versionhistory
<ul>
	<li>
		<b>1.2</b>
		<br>
		<p>Updated to work with new LuaEx class system.</p>
	</li>
	<li>
		<b>1.1</b>
		<br>
		<p>Add serialize and deserialize methods.</p>
	</li>
	<li>
		<b>1.0</b>
		<br>
		<p>Created the module.</p>
	</li>
</ul>
@website https://github.com/CentauriSoldier
*]]

--localization
local class 		= class;
local deserialize	= deserialize;
local math			= math;
local point 		= point;
local rawtype		= rawtype;
local serialize		= serialize;
local type 			= type;
local MATH_ARL		= MATH_ARL;
local MATH_UNDEF	= MATH_UNDEF;
local nSpro			= class.args.staticprotected;
local nPri 			= class.args.private;
local nPro 			= class.args.protected;
local nPub 			= class.args.public;
local nIns			= class.args.instances;

--a location for storing temporary points so they don't need to be created every calcualtion
local tTempPoints = {};

local function update(this)
	local pri = tProtectedRepo[this];
	--update the line's midpoint
	pri.midpoint.x = (pri.start.x + pri.stop.x) / 2;
	pri.midpoint.y = (pri.start.y + pri.stop.y) / 2;

	--update the line's slope, theta and y intercept
	local nYDelta = pri.stop.y - pri.start.y;
	local nXDelta = pri.stop.x - pri.start.x;
	pri.slopeIsUndefined = nXDelta == 0;

	--get the quadrant addative for theta
	local nXIsPos	= nXDelta > 0;
	local nYIsPos	= nYDelta > 0;

	--determine slope and y-intercept
	if (pri.slopeIsUndefined) then
		pri.slope 		= MATH_UNDEF;
		pri.yIntercept 	= pri.start.x == 0 and MATH_ARL or MATH_UNDEF;
	else
		pri.slope 		= nYDelta / nXDelta;
		pri.yIntercept 	= pri.start.y - pri.slope * pri.start.x;
	end

	--translate end point to the origin (using the object's temp point) in order to find theta
	local oEnd = tTempPoints[this];

	oEnd.x = pri.stop.x - pri.start.x;
	oEnd.y = pri.stop.y - pri.start.y;

	pri.theta = math.deg(math.atan2(oEnd.y, oEnd.x));
	--make sure the value is positive
	pri.theta = pri.theta >= 0 and pri.theta or 360 + pri.theta;

	--get the standard-form components and set the x intercept
	pri.a = nYDelta;--pri.stop.y - pri.start.y;
	pri.b = pri.start.x - pri.stop.x;
	pri.c = pri.a * pri.start.x + pri.b * pri.start.y;

	--y = mx + b => 0 = mx + b => -b = mx => x = -b/m
	pri.xIntercept = pri.slopeIsUndefined and pri.start.x or (pri.slope == 0 and MATH_UNDEF or -pri.yIntercept / pri.slope);


	--update whether or not the intercepts are defined
	pri.xInterceptIsUndefined = rawtype(pri.xIntercept) == "string";
	pri.yInterceptIsUndefined = rawtype(pri.yIntercept) == "string";

	--update the deltas
	pri.deltaX = nXDelta;
	pri.deltaY = nYDelta;

	--update the line's length
	pri.length = math.sqrt( (pri.start.x - pri.stop.x) ^ 2 + (pri.start.y - pri.stop.y) ^ 2);
end

--local spro = args[nSpro];
--local pri = args[nPri];
--local pro = args[nPro];
--local pub = args[nPub];
--local ins = args[nIns];

return class(
"line",
{--metamethods
	__tostring = function(this)
		local pri = tProtectedRepo[this];
		local sRet 	= "";

		sRet = sRet.."start: "..tostring(pri.start).."\r\n";
		sRet = sRet.."end: "..tostring(pri.stop).."\r\n";
		sRet = sRet.."midpoint: "..tostring(pri.midpoint).."\r\n";
		sRet = sRet.."slope: "..pri.slope.."\r\n";
		sRet = sRet.."theta: "..pri.theta.."\r\n";
		sRet = sRet.."delta x: "..pri.deltaX.."\r\n";
		sRet = sRet.."delta y: "..pri.deltaY.."\r\n";
		sRet = sRet.."length: "..pri.length.."\r\n";
		sRet = sRet.."x intercept: "..pri.xIntercept.."\r\n";
		sRet = sRet.."y intercept: "..pri.yIntercept.."\r\n";
		sRet = sRet.."A: "..pri.a.."\r\n";
		sRet = sRet.."B: "..pri.b.."\r\n";
		sRet = sRet.."C: "..pri.c.."\r\n";
		sRet = sRet.."Vector: <"..pri.a..", "..pri.b..">";

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
},
{--static protected

},
{--static public

},
{--private
	pri.midpoint,
	pri.start,
	pri.stop,
	pri.a,
	pri.b,
	pri.c,
	pri.deltaX,
	pri.deltaY,
	pri.length,
	pri.slope,
	pri.slopeIsUndefined,
	pri.theta,
	pri.yIntercept,
	pri.yInterceptIsUndefined,
	pri.xIntercept,
	pri.xInterceptIsUndefined,
},
{--protected

},
{--public

	line = function(this, tProtected, oStartPoint, oEndPoint, bSkipUpdate)
		tProtectedRepo[this] = tProtected;
		local pri = tProtectedRepo[this];

		pri.midpoint  	= point();
		pri.start 		= type(oStartPoint) == "point" 	and point(oStartPoint.x, 	oStartPoint.y) 	or point();
		pri.stop 		= type(oEndPoint)	== "point" 	and point(oEndPoint.x, 		oEndPoint.y) 	or point();

		--default the fields (in case no update is performed)
		pri.a 						= 0;
		pri.b 						= 0;
		pri.c 						= 0;
		pri.deltaX 					= 0;
		pri.deltaY 					= 0;
		pri.length 					= 0;
		pri.slope 					= 0;
		pri.slopeIsUndefined 		= true;
		pri.theta 					= 0;
		pri.yIntercept 				= 0;
		pri.yInterceptIsUndefined 	= true;
		pri.xIntercept 				= 0;
		pri.xInterceptIsUndefined 	= true;
		--pri. = 0;

		--create this line's temp point (used during updates)
		tTempPoints[this] = point(0, 0);

		if (not bSkipUpdate) then
			update(this);
		end

	end,

	deserialize = function(this, sData)
		local tData = deserialize.table(sData);

		this.start 	= this.start:deserialize(tData.start);
		this.stop	= this.stop:deserialize(tData.stop);
		error("UDPATE THIS FUNCTION")
		return this;
	end,


	getASCII = function(this)
		--TODO shrink the line to proportions of 10s
		local sRet = "";


		return sRet;
	end,

	--TODO finish this! Check if it's accurate
	--[[getObtuseAngleTo = function(this, oOther)
		local tMe 		= tProtectedRepo[this];
		local tOther 	= tProtectedRepo[oOther];

		local nAngle = math.abs(tMe.theta - tOther.theta);
		return nAngle <= 90 and nAngle or 90 + nAngle;
	end,


	getAcuteAngleTo = function(this, oOther)
		local tMe 		= tProtectedRepo[this];
		local tOther 	= tProtectedRepo[oOther];

		local nAngle = math.abs(tMe.theta - tOther.theta);
		return nAngle < 90 and nAngle or 180 - nAngle;
	end,]]

	getDeltaX = function(this)
		return tProtectedRepo[this].deltaX;
	end,

	getDeltaY = function(this)
		return tProtectedRepo[this].deltaY;
	end,

	getEnd = function(this)
		return tProtectedRepo[this].stop;
	end,

	getLength = function(this)
		return tProtectedRepo[this].length;
	end,

	getMidPoint = function(this)
		return tProtectedRepo[this].midpoint;
	end,

	getPointAtDistance = function(this, nDistance)
		--https://stackoverflow.com/questions/1250419/finding-points-on-a-line-with-a-given-distance
	end,

	getPointOfIntersection = function(this, oOther)
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

	--get the polar radius
	getR = function(this)
		return tProtectedRepo[this].length;
	end,

	getSlope = function(this)
		return tProtectedRepo[this].slope;
	end,


	getStart = function(this)
		return tProtectedRepo[this].start;
	end,

	--get the polar angles from the x-axis
	getTheta = function(this)
		return tProtectedRepo[this].theta;
	end,


	getXIntercept = function(this)
		return tProtectedRepo[this].xIntercept;
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

	isDistinctFrom = function(this, oOther)

	end,

	isParrallelTo = function(this, oOther)
		local tMe 		= tProtectedRepo[this];
		local tOther 	= tProtectedRepo[oOther];
		local bBothSlopesAreDefined 	= (not tMe.slopeIsUndefined) and (not tOther.slopeIsUndefined);
		local bBothSlopesAreUndefined 	= tMe.slopeIsUndefined and tOther.slopeIsUndefined;

		return bBothSlopesAreUndefined or (bBothSlopesAreDefined and (tMe.slope == tOther.slope));
	end,

	coincidesWith = function(this, oOther)
		local tMe 							= tProtectedRepo[this];
		local tOther 						= tProtectedRepo[oOther];
		local bBothSlopesAreDefined 		= (not tMe.slopeIsUndefined) and (not tOther.slopeIsUndefined);
		local bBothSlopesAreUndefined 		= tMe.slopeIsUndefined and tOther.slopeIsUndefined;
		local bBothXInterceptsAreDefined 	= (not tMe.xInterceptIsUndefined) and (not tOther.xInterceptIsUndefined);
		local bBothXInterceptsAreUndefined 	= tMe.xInterceptIsUndefined and tOther.xInterceptIsUndefined;
		local bBothYInterceptsAreDefined 	= (not tMe.yInterceptIsUndefined) and (not tOther.yInterceptIsUndefined);
		local bBothYInterceptsAreUndefined 	= tMe.yInterceptIsUndefined and tOther.yInterceptIsUndefined;
		local bAreParrallel					= (bBothSlopesAreUndefined or (bBothSlopesAreDefined and (tMe.slope == tOther.slope)));

		return bAreParrallel and
			   (
			   (bBothXInterceptsAreUndefined	or (bBothXInterceptsAreDefined and (tMe.xIntercept == tOther.xIntercept))) and
			   (bBothYInterceptsAreUndefined	or (bBothYInterceptsAreDefined and (tMe.yIntercept == tOther.yIntercept)))
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
		local pri = tProtectedRepo[this];
		--[[local tData = {
			start 	= pri.start:seralize(),
			stop 	= pri.stop:serialize(),
		};

		if (not bDefer) then
			tData = serialize.table(tData);
		end

		return tData;]]
		return serialize.table(pri);
	end,

	setEnd = function(this, oPoint, bSkipUpdate)
		local pri = tProtectedRepo[this];
		pri.stop.x = oPoint.x;
		pri.stop.y = oPoint.y;

		if (not bSkipUpdate) then
			update(this);
		end

	end,

	setStart = function(this, oPoint, bSkipUpdate)
		local pri = tProtectedRepo[this];
		pri.start.x = oPoint.x;
		pri.start.y = oPoint.y;

		if (not bSkipUpdate) then
			update(this);
		end

	end,

	slopeIsDefined = function(this)
		return not tProtectedRepo[this].slopeIsUndefined;
	end,

	xInterceptIsDefined = function(this)
		return not tProtectedRepo[this].xInterceptIsUndefined;
	end,

	yInterceptIsDefined = function(this)
		return not tProtectedRepo[this].yInterceptIsUndefined;
	end,
},
nil,    --extending class
nil,    --interface(s) (either nil, an interface or a table of interfaces)
false  --if the class is final
);
