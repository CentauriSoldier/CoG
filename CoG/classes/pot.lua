--[[*
@authors Centauri Soldier
@copyright Public Domain
@description
	<h2>pot</h2>
	<p>A logical potentiometer object. The client can set minimum and maximum values for the object, as well as rate of increase/decrease.
	By default, values are clamped at min and max; however, if the object is set to be revolving, any values which exceed the minimum or maximum
	boundaries, are carried over. For eaxmple, imagine a pot is set to have a min value of 0 and a max of 100. Then, imagine its position is set to 120.
	If revolving, it would have a final positional value of 20 and if not revolving its final positional value would be be 100.</p>
@license <p>The Unlicense<br>
<br>
@moduleid pot
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
		<p>Added the option for the potentiometer to be revolving.</p>
	</li>
</ul>
@website https://github.com/CentauriSoldier
*]]
local tPots = {};

local function setError()
	error("Error attemting to set '"..vKey.."'. While getting private values by using their respective keys is allowed, setting them in this manner is not. Please use the provided mutator methods to set values for this object.");
end

--todo remove or fix this. Currently, interfers with the class module's metatables
local tMeta = {

	--returns private values when requested by key
	__index = function(tTable, vKey)

		if (type(vKey) == "string") then

			if (vKey == "min" or vKey == "max" or vKey == "pos" or vKey == "rate") then
				return tPots[tTable][vKey];
			else
				return nil;
			end

		end

	end,

	--prevent the "getter" keys from being changed
	__newindex = function(tTable, vKey, vValue)
		--by default, set the value
		tTable[vKey] = vValue;

		--check for restricted values and block them from being chanegd if needed
		if (type(vKey) == "string") then

			if vKey == "min" then
				tTable[vKey] = nil;
				return nil;

			elseif vKey == "max" then
				tTable[vKey] = nil;
				return nil;

			elseif vKey == "pos" then
				tTable[vKey] = nil;
				return nil;

			elseif vKey == "rate" then
				tTable[vKey] = nil;
				return nil;
			end

		end

	end,

};


local function clampMin(oPot)

	if (oPot.min >= oPot.max) then
		oPot.min = oPot.max - 1;
	end

end

local function clampMax(oPot)

	if (oPot.max <= oPot.min) then
		oPot.max = oPot.min + 1;
	end

end

local function clampPosMin(oPot)

	if (oPot.pos < oPot.min) then

		if (oPot.isRevolving) then
			oPot.pos = oPot.max + oPot.pos;
			clampPosMin(oPot);
		else
			oPot.pos = oPot.min;
		end

	end

end

local function clampPosMax(oPot)

	if (oPot.pos > oPot.max) then

		if (oPot.isRevolving) then
			oPot.pos = oPot.pos - oPot.max;
			clampPosMax(oPot);
		else
			oPot.pos = oPot.max;
		end

	end

end

local function clampRate(oPot)
	local nVariance = oPot.max - oPot.min;

	if (oPot.rate > math.abs(nVariance)) then
		oPot = nVariance;
	end

end



class "pot" {

	__construct = function(this, nMin, nMax, nPos, nRate, bRevolving)
		tPots[this] = {
			min 		= 0,
			max 		= 100,
			pos 		= 0,
			rate 		= 1,
			revolving	= false,
		};

		local oPot = tPots[this];

		--set the min
		if (type(nMin) == "number") then
			oPot.min = nMin;
		end

		--set the max
		if (type(nMax) == "number") then
			oPot.max = nMax;
			clampMax(oPot);
		end

		--set the pos position
		if (type(nPos) == "number") then
			oPot.pos = nPos;
			clampPosMin(oPot);
			clampPosMax(oPot);
		end

		--set the rate
		if (type(nRate) == "number") then
			oPot.rate = nRate;
			clampRate(oPot);
		end

		--set revolution value
		if (type(bRevolving) == "boolean") then
			oPot.revolving = bRevolving;
		end

	end,


	adjust = function(this, nValue)
		local oPot = tPots[this];
		local nAmount = oPot.rate;

		--allow correct input
		if (type(nValue) == "number") then
			nAmount = nValue;
		end

		--set the value
		oPot.pos = oPot.pos + nAmount;

		--clamp it
		clampPosMin(oPot);
		clampPosMax(oPot);

		return tPots[this].pos;
	end,


	decrease = function(this, nTimes)
		local oPot = tPots[this];
		local nCount = 1;

		if (type(nTimes) == "number") then
			nCount = nTimes;
		end

		--set the value
		oPot.pos = oPot.pos - oPot.rate * nCount;
		--clamp it
		clampPosMin(oPot);

		return oPot.pos;
	end,

	destroy = function(this)
		tPots[this] = nil;
		this = nil;
	end,

	getMax = function(this)
		return tPots[this].max;
	end,

	getMin = function(this)
		return tPots[this].min;
	end,

	getPos = function(this)
		return tPots[this].pos;
	end,

	getRate = function(this)
		return tPots[this].rate;
	end,

	increase = function(this, nTimes)
		local oPot = tPots[this];
		local nCount = 1;

		if (type(nTimes) == "number") then
			nCount = nTimes;
		end

		--set the value
		oPot.pos = oPot.pos + oPot.rate * nCount;

		clampPosMax(oPot);

		return oPot.pos;
	end,

	isRevolving = function(this)
		return tPots[this].revolving;
	end,

	setMax = function(this, nValue)
		local oPot = tPots[this];

		if (type(nValue) == "number") then
			oPot.max = nValue;
			clampMax(oPot);
			clampPosMax(oPot)
		end

	end,

	setMin = function(this, nValue)
		local oPot = tPots[this];

		if (type(nValue) == "number") then
			oPot.min = nValue;
			clampMin(oPot);
			clampPosMin(oPot)
		end

	end,

	setPos = function(this, nValue)
		local oPot = tPots[this];

		if (type(nValue) == "number") then
			oPot.pos = nValue;
			clampPosMin(oPot);
			clampPosMax(oPot);
		end

		return oPot.pos;
	end,

	setRate = function(this, nValue)
		local oPot = tPots[this];

		if (type(nValue) == "number") then
			oPot.rate = math.abs(nValue);
			clampRate(oPot);
		end

		return oPot.pos;
	end,

	setRevolving = function(this, bRevolving)
		local oPot = tPots[this];

		if (type(bRevolving) == "boolean") then
			oPot.revolving = bRevolving;
		end

		return oPot.pos;
	end,

};

return pot;
