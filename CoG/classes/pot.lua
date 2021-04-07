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
		oPot.pos = oPot.min;
	end

end

local function clampPosMax(oPot)

	if (oPot.pos > oPot.max) then
		oPot.pos = oPot.max;
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

		if (type(nTimes) == "nunmber") then
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

		if (type(nTimes) == "nunmber") then
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
