--TODO finish this. It needs to use a protean and be integer values only Zero or less  means it's empty

--[[*
	@moduleid pool
	@authors Centauri Soldier
	@copyright Copyright © 2020 Centauri Soldier
	@description <h2>pool</h2><h3>Utility class used to keep track of things like Health, Magic, etc.</h3><p>You can operate on <strong>pool</strong> objects using some math operators.</p>
	<ul>
		<li><p><b>+</b>: adds a number to the pool's CURRENT value or, if adding another pool object instead of a number, it will add the other pool's CURRENT value to it's own <em>(up to it's MAX)</em> value.</p></li>
		<li><p><b>-</b>: does the same as addition but for subtraction. Will not go below the pool's MIN value.</p></li>
		<li><p><b>%</b>: will modify a pool's MAX value using a number value or another pool object <em>(uses it's MAX value)</em>. Will not allow itself to be set at or below the MIN value.</p></li>
		<li><p><b>*</b>: operates as expected on the object's CURRENT value.</p></li>
		<li><p><b>/</b>: operates as expected on the object's CURRENT value. All div is floored.</p></li>
		<li><p><b>-</b><em>(unary minus)</em>: will set the object's CURRENT value to the value of MIN.</p></li>
		<li><p><b>#</b>: will set the object's CURRENT value to the value of MAX.</p></li>
		<li><p><b></b></p></li>
		<li><p><b></b></p></li>
	</ul>
	@version 0.2
	@todo Complete the binary operator metamethods.
	*]]

	--[[!
	@module pool
	@func __construct
	@scope local
	@desc The constructor for the pool class.
!]]
enum("PoolValue", 		{"Max", "Current", "Regen"});
enum("PoolCallback", 	{"OnAdjust", "OnIncrease", "OnDecrease", "OnEmpty", "OnMin", "OnMax", "OnRegen"});

local tPools = {};

local PoolValue 		= PoolValue;
local PoolCallback 		= PoolCallback;
local leftOnlyObject 	= leftOnlyObject;
local rightOnlyObject	= rightOnlyObject;
local bothObjects		= bothObjects;
local type				= type;
local math				= math;
local counting 			= math.counting;
local whole 			= math.whole;
local floor 			= math.floor;
local ProteanLimit	 	= ProteanLimit;
local ProteanMod		= ProteanMod;
local ProteanValue		= ProteanValue;



local function clampMax(this)
	local tFields 		= tPools[this];
	local tValues 		= tFields.values;
	local eMax			= PoolValue.Max;
	local oMax 			= tValues[eMax];
	local nMax 			= counting(oMax:get(ProteanValue.Final));

	local nBaseAddative = 0;

	while (nMax <= tValues.Min) do
		--increase the addative
		nBaseAddative = nBaseAddative + 1;
		--set the new value
		oMax:set(ProteanValue.Base, nMax + nBaseAddative);
		--reget the final value (clamped to be a counting number)
		nMax = counting(oMax:get(ProteanValue.Final));
	end

end


local function clampCurrent(this)
	local tFields 		= tPools[this];
	local tValues 		= tFields.values;
	local eMax			= PoolValue.Max;
	local eCurrent  	= PoolValue.Current;
	local nMax 			= counting(tValues[eMax]:get(ProteanValue.Final));

	tValues[eCurrent] = tValues[eCurrent];

	if (tValues[eCurrent] > nMax) then
		tValues[eCurrent] = nMax;
	end

end

--[[
local function clampRegen(this)
	local tFields 		= tPools[this];
	local tValues 		= tFields.values;
	local eRegen 	 	= PoolValue.Regen;

	tValues[eRegen] = math.floor(tValues[eRegen]);
end
]]


local pool = class "pool" {

	__construct = function(this, shared, nMax, nCurrent, nRegen)
		tPools[this] 	= shared;
		local tFields 	= shared;

		tFields.callbacks 	= {};
		tFields.values 		= {};

		--setup the callbacks
		for _, eEvent in PoolCallback() do
			tPools[this].callbacks[eEvent] = null;
		end

		--initialize the values
		local tValues = tFields.values;
		local eMax			= PoolValue.Max;
		local eCurrent  	= PoolValue.Current;
		local eRegen  		= PoolValue.Regen;

		tValues.Min			= 1;
		tValues[eMax] 		= type(nMax) 		== "number"	and counting(nMax)		or 2;
		tValues[eCurrent] 	= type(nCurrent) 	== "number" and whole(nCurrent) 	or 1;
		tValues[eRegen] 	= type(nRegen) 		== "number" and floor(nRegen) 		or 0;

		--create the proteans
		tValues[eMax] 		= protean(tValues[eMax]);
		tValues[eRegen] 	= protean(tValues[eRegen]);

		--clamp the values
		clampMax(this);
		clampCurrent(this);
	end,

	get = function(this, eValue)
		local nRet 		= nil;
		local tFields 	= tPools[this];
		local tValues 	= tFields.values;

		if (type(eValue) == "PoolValue") then

			if (eValue == PoolValue.Max) then
				nRet = counting(tValues[eValue]:get(ProteanValue.Final));

			elseif (eValue == PoolValue.Current) then
				nRet = tValues[eValue];

			elseif (eValue == PoolValue.Regen) then
				nRet = math.floor(tValues[eValue]:get(ProteanValue.Final));
			end

		end

		return nRet;
	end,

	getModifier = function(this, ePoolValue, eProteanMod)
		local nRet = nil;

		if (type(ePoolValue) == "PoolValue" and type(eProteanMod) == "ProteanMod") then
			return tPools[this].values[ePoolValue]:get(eProteanMod);
		end

		return nRet;
	end,

	isEmpty = function(this)
		local tFields = tPools[this];
		local tValues = tFields.values;

		return tValues[PoolValue.Current] < tValues.Min;
	end,

	isFull = function(this)
		local tFields = tPools[this];
		local tValues = tFields.values;

		return tValues[PoolValue.Current] == tValues[PoolValue.Max]:get(ProteanValue.Final);
	end,

	regen = function(this)
		local tFields 	= tPools[this];
		local tValues 	= tFields.values;
		local eCurrent	= PoolValue.Current;
		local eRegen 	= PoolValue.Regen;
		local eFinal 	= ProteanValue.Final;

		tValues[eCurrent] = tValues[eCurrent] + math.floor(tValues[eRegen]:get(eFinal));
		clampCurrent(this);
--TODO check values and onEvents
		return this;
	end,

	set = function(this, eValue, nValue)
		local tFields 	= tPools[this];
		local tValues 	= tFields.values;
		local eBase		= ProteanValue.Base;

		if (type(eValue) == "PoolValue" and type(nValue) == "number") then
			local oProtean = tValues[eValue];

			if (eValue == PoolValue.Max) then
				oProtean:set(eBase, counting(nValue));
				clampMax(this);
				clampCurrent(this);

			elseif (eValue == PoolValue.Current) then
				oProtean:set(eBase, whole(nValue));
				clampCurrent(this);

			elseif (eValue == PoolValue.Regen) then
				oProtean:set(eBase, math.floor(nValue));
			end

		end

		return this;
	end,

	setCallback = function(this, eEvent, fCallback)

		if (eEvent and fCallback and type(eEvent) == 'PoolCallback' and type(fCallback) == 'function') then
			tPools[this].callbacks[eEvent] = fCallback;
		end

		return this;
	end,

	setModifier = function(this, ePoolValue, eProteanMod, nValue)

		if (type(ePoolValue) == "PoolValue" and type(eProteanMod) == "ProteanMod" and type(nValue) == "number") then
			local tValues 	= tPools[this].values;
			local eMax 		= PoolValue.Max;
			local eRegen 	= PoolValue.Regen;

			if (ePoolValue == eMax) then
				tValues[ePoolValue]:set(eProteanMod, math.abs(nValue));
				clampMax(this);
				clampCurrent(this);
			elseif (ePoolValue == eRegen) then
				tValues[ePoolValue]:set(eProteanMod, math.abs(nValue));
			end
		end

		return this;
	end,

	__tostring = function(this)
		local tFields 	= tPools[this];
		local tValues 	= tFields.values;
		local eMax		= PoolValue.Max;
		local eCurrent	= PoolValue.Current;
		local eRegen	= PoolValue.Regen;

		return 	"Min = ${min}\r\nMax = ${max}\r\nCurrent = ${current}\r\nRegen = ${regen}" %
				{min = tValues.Min, max = this:get(eMax), current = this:get(eCurrent), regen = this:get(eRegen)};
	end,


	--[[!
	@module pool
	@func __add
	@scope local
	@desc NOT DONE YET!
	!]]
	--[[__add = function(vLeft, vRight)
		local sLeftType 	= type(vLeft);
		local sRightType 	= type(vRight);
		local sPool 		= "pool";
		local eCurrent  	= PoolValue.Current;
		local eOnAdd		= PoolCallback.OnAdd;
		local oRet 			= nil;

		if (leftOnlyObject(sLeftType, sRightType, sPool)) then
			oRet = vLeft;
			setValue(vLeft, eCurrent, tPools[vLeft].values[eCurrent] + vRight, eOnAdd);

		elseif (rightOnlyObject(sLeftType, sRightType, sPool)) then
			oRet = vRight;
			setValue(vRight, eCurrent, tPools[vRight].values[eCurrent] + vLeft, PeOnAdd);

		elseif (bothObjects(sLeftType, sRightType, sPool)) then
			oRet = vLeft;
			setValue(vLeft, eCurrent, tPools[vLeft].values[eCurrent] + tPools[vRight].values[eCurrent], eOnAdd);

		end

		return oRet;
	end,]]

	--[[!
	@module pool
	@func __mod
	@scope local
	@desc <p>Sets the pool object's MIN or MAX value depending on order.</p>
	<ul>
		<li><p>If the pool object is on the left and a number on the right, sets the object's MAX value to the indicated value.</p></li>
		<li><p>If the object is on the right and a number on the left, sets the MIN value to indicated number.</p></li>
		<li><p>If both sides are pool objects, it sets the MIN and MAX values of the left side object to the MIN and MAX values of that of the right object.</p></li>
	</ul>
	<p>Note: if the M
	AX is ever set below or equal to the MIN value, it will be automatically altered to be one higher than the MIN value.</p>
	!]]
	--[[__mod = function(vLeft, vRight)
		local sLeftType 	= type(vLeft);
		local sRightType 	= type(vRight);
		local sPool 		= "pool";
		local eMin 			= PoolValue.Min;
		local eMax 			= PoolValue.Max;
		local eOnMod		= PoolCallback.OnMod;
		local oRet 			= nil;

		if (leftOnlyObject(sLeftType, sRightType, sPool)) then
			oRet = vLeft;
			setValue(vLeft, eMax, vRight, eOnMod);

		elseif (rightOnlyObject(sLeftType, sRightType, sPool)) then
			oRet = vRight;
			setValue(vRight, eMin, vLeft, eOnMod);

		elseif (bothObjects(sLeftType, sRightType, sPool)) then
			setValue(vLeft, eMin, tPools[vRight].values[eMin], eOnMod);
			setValue(vLeft, eMax, tPools[vRight].values[eMax], eOnMod);

		end

		return oRet;
	end,
	__sub = function(vLeft, vRight)
		local sLeftType 	= type(vLeft);
		local sRightType	= type(vRight);
		local sPool 		= "pool";
		local eCurrent 		= PoolValue.Current;
		local eOnSub 		= PoolCallback.OnSub;
		local oRet 			= nil;

		if (leftOnlyObject(sLeftType, sRightType, sPool)) then
			oRet = vLeft;
			setValue(vLeft, eCurrent, tPools[vLeft].values[eCurrent] - vRight, eOnSub);

		elseif (rightOnlyObject(sLeftType, sRightType, sPool)) then
			oRet = vRight;
			setValue(vRight, eCurrent, tPools[vRight].values[eCurrent] - vLeft, eOnSub);

		elseif (bothObjects(sLeftType, sRightType, sPool)) then
			oRet = vLeft;
			setValue(vLeft, eCurrent, tPools[vLeft].values[eCurrent] - tPools[vRight].values[eCurrent], eOnSub);

		end

		return oRet;
	end,





	__unm = function(this)
		local tFields 	= tPools[this];
		setValue(this, PoolValue.Current, tFields.values[PoolValue.Min], PoolCallback.OnMin);
		return this;
	end,

]]











	--DO I NEED THESE ONE BELOW? They may overcomplicate the class


















--[[
	__div = function(vLeft, vRight)
		local sLeftType 	= type(vLeft);
		local sRightType 	= type(vRight);
		local sPool 		= "pool";
		local eCurrent		= PoolValue.Current;
		local eOnDiv		= PoolCallback.OnDiv;
		local oRet 			= nil;

		if (leftOnlyObject(sLeftType, sRightType, sPool)) then
			oRet = vLeft;
			setValue(vLeft, eCurrent, math.floor(tPools[vLeft].values[eCurrent] / vRight), eOnDiv);

		elseif (rightOnlyObject(sLeftType, sRightType, sPool)) then
			oRet = vRight;
			setValue(vRight, eCurrent, math.floor(tPools[vRight].values[eCurrent] / vLeft), eOnDiv);

		elseif (bothObjects(sLeftType, sRightType, sPool)) then
			oRet = vLeft;
			setValue(vLeft, eCurrent, math.floor(tPools[vLeft].values[eCurrent] / tPools[vRight].values[eCurrent]), eOnDiv);

		end

		return oRet;
	end,
]]
--[[	__len = function(this)
		setValue(this, PoolValue.Current, tPools[this].values[PoolValue.Max], PoolCallback.OnMax);
		return this;
	end,
]]


--[[
	__mul = function(vLeft, vRight)
		local sLeftType 	= type(vLeft);
		local sRightType 	= type(vRight);
		local sPool 		= "pool";
		local eCurrent		= PoolValue.Current;
		local eOnMul 		= PoolCallback.OnMul;
		local oRet 			= nil;

		if (leftOnlyObject(sLeftType, sRightType, sPool)) then
			oRet = vLeft;
			setValue(vLeft, eCurrent, tPools[vLeft].values[eCurrent] * vRight, eOnMul);

		elseif (rightOnlyObject(sLeftType, sRightType, sPool)) then
			oRet = vRight;
			setValue(vRight, eCurrent, tPools[vRight].values[eCurrent] * vLeft, eOnMul);

		elseif (bothObjects(sLeftType, sRightType, sPool)) then
			oRet = vLeft;
			setValue(vLeft, eCurrent, tPools[vLeft].values[eCurrent] * tPools[vRight].values[eCurrent], eOnMul);

		end

		return oRet;
	end,

]]


--[[
	get = function(this, eValue)
		local nRet 		= nil;
		local tFields 	= tPools[this];
		local tValues 	= tFields.values;

		if (type(tValues[eValue]) ~= "nil") then
			nRet = math.floor(tValues[eValue]);--always returns an integer value
		end

		--return nRet or math.huge;
		return nRet;
	end,
]]
--TODO finish this
	copy = function(this)
		local tFields 	= tPools[this];
		local tValues 	= tFields.values
		local oRet 		= pool(tValues.Min, tValues.Max, tValues.Current, tValues.Regen);

		for nID, eValue in PoolValue() do
			setValue(oRet, eValue, tValues[eValue]);
		end

		return oRet;
	end,
--[[
	set = function(this, eValue, nValue)
		local tFields = tPools[this];

		if ((type(nValue) == "number") and type(tFields.values[eValue]) ~= "nil") then
			setValue(this, eValue, nValue, PoolCallback.OnSet);
		end

		return this;
	end,
]]

};

return pool;
