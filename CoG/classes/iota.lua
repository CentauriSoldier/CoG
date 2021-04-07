--[[*
@authors Centauri Soldier
@copyright Public Domain
@description
	<h2>iota</h2>
	<p></p>
@license <p>The Unlicense<br>
<br>
@moduleid shape
@version 1.0
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
		<p>Addded callback functions.</p>
	</li>
</ul>
@website https://github.com/CentauriSoldier
*]]
--TODO remove dependency on AAA
assert(type(const) == "function", "const has not been loaded.");
local sIota = 'iota';

--set the constants for this class
IOTA 						= const("IOTA");
IOTA.YEARS					= "years";
IOTA.DAYS 					= "days";
IOTA.HOURS 					= "hours";
IOTA.MINUTES 				= "minutes";
IOTA.SECONDS 				= "seconds";
IOTA.MAX					= const("IOTA.MAX", 'Max numbers for iota values.', true);
IOTA.MAX.YEARS				= 9999999999;
IOTA.MAX.DAYS 				= 365;
IOTA.MAX.HOURS 				= 24;
IOTA.MAX.MINUTES 			= 60;
IOTA.MAX.SECONDS			= 60;
IOTA.CALLBACK				= const('IOTA.CALLBACK', 'Call back functions for when values change.', true);
IOTA.CALLBACK.ON_SECOND		= 'onSecond';
IOTA.CALLBACK.ON_MINUTE		= 'onMinute';
IOTA.CALLBACK.ON_HOUR		= 'onHour';
IOTA.CALLBACK.ON_DAY		= 'onDay';
IOTA.CALLBACK.ON_YEAR		= 'onYear';

local tIota = {};

--sets the marker before a change is made to the iota
--[[local function setMarker(oIota)

	for _, sName in pairs(IOTA()) do
		oIota.marker[sName] = oIota[sName];
	end

	return oIota;
end
]]


--TODO add onSecond callback method
local function levelValues(this)
	local oIota			= tIota[this];
	local nMax 			= IOTA.MAX.SECONDS;
	local nPreValue 	= 0;
	local nPostValue	= 0;

	if (oIota[IOTA.SECONDS] >= nMax) then
		nPreValue = oIota[IOTA.MINUTES];
		oIota[IOTA.MINUTES]  = oIota[IOTA.MINUTES] + math.floor(oIota[IOTA.SECONDS] / nMax);
		oIota[IOTA.SECONDS]  = oIota[IOTA.SECONDS] % nMax;
		nPostValue = oIota[IOTA.MINUTES] - nPreValue;

		if (type(oIota.callbacks[IOTA.CALLBACK.ON_MINUTE]) == 'function') then
			oIota.callbacks[IOTA.CALLBACK.ON_MINUTE](this, nPostValue, unpack(oIota.callbackArgs[IOTA.CALLBACK.ON_MINUTE]));
		end

	end

	nMax = IOTA.MAX.MINUTES;
	if (oIota[IOTA.MINUTES] >= nMax) then
		nPreValue = oIota[IOTA.HOURS];
		oIota[IOTA.HOURS] 	 = oIota[IOTA.HOURS] + math.floor(oIota[IOTA.MINUTES] / nMax);
		oIota[IOTA.MINUTES]  = oIota[IOTA.MINUTES] % nMax;
		nPostValue = oIota[IOTA.HOURS] - nPreValue;

		if (type(oIota.callbacks[IOTA.CALLBACK.ON_HOUR]) == 'function') then
			oIota.callbacks[IOTA.CALLBACK.ON_HOUR](this, nPostValue, unpack(oIota.callbackArgs[IOTA.CALLBACK.ON_HOUR]));
		end

	end

	nMax = IOTA.MAX.HOURS;
	if (oIota[IOTA.HOURS] >= nMax) then
		nPreValue = oIota[IOTA.DAYS];
		oIota[IOTA.DAYS]   = oIota[IOTA.DAYS] + math.floor(oIota[IOTA.HOURS] / nMax);
		oIota[IOTA.HOURS]  = oIota[IOTA.HOURS] % nMax;
		nPostValue = oIota[IOTA.DAYS] - nPreValue;

		if (type(oIota.callbacks[IOTA.CALLBACK.ON_DAY]) == 'function') then
			oIota.callbacks[IOTA.CALLBACK.ON_DAY](this, nPostValue, unpack(oIota.callbackArgs[IOTA.CALLBACK.ON_DAY]));
		end

	end

	nMax = IOTA.MAX.DAYS;
	if (oIota[IOTA.DAYS] >= nMax) then
		nPreValue = oIota[IOTA.YEARS];
		oIota[IOTA.YEARS] = oIota[IOTA.YEARS] + math.floor(oIota[IOTA.DAYS] / nMax);
		oIota[IOTA.DAYS]  = oIota[IOTA.DAYS] % nMax
		nPostValue = oIota[IOTA.YEARS] - nPreValue;

		if (type(oIota.callbacks[IOTA.CALLBACK.ON_YEAR]) == 'function') then
			oIota.callbacks[IOTA.CALLBACK.ON_YEAR](this, nPostValue, unpack(oIota.callbackArgs[IOTA.CALLBACK.ON_YEAR]));
		end

	end

	--[[adjust the pre-set marker now that the changes are complete
	for _, sName in pairs(IOTA()) do
		oIota.marker[sName]	 = oIota[sName] - oIota.marker[sName];
	end	]]

	return this;
end


--[[local function getValueP(oIota, sName)
	return oIota[sName];
end
]]

class "iota" {

	__construct = function(...)
		local this 		= arg[1];
		tIota[this] = {
			callbacks 	 = {},
			callbackArgs = {},
			--marker = {}, --used for tracking how much time has passed from one point to the next
		};
		local oIota = tIota[this];

		--set up values
		for _, sName in pairs(IOTA()) do
			oIota[sName] 			= 0;
			--oIota.marker[sName] 	= 0;
		end

		--setup callbacks
		for _, sName in pairs(IOTA.CALLBACK()) do
			oIota.callbacks[sName] 		= 0;
			oIota.callbackArgs[sName]	= {};
		end

	end,

	--todo left/right checks
	__add = function(...)
		local this 			= arg[1];
		local oiota 		= AAA.CheckTypes(sIota, "__add", arg, 2, {"iota"});
		local oMe			= tIota[this];
		local oRet 			= iota();
		local nAddMinutes 	= 0;
		local nAddHours 	= 0;
		local nAddDays 		= 0;
		local nAddYears 	= 0;

		oRet[IOTA.SECONDS] 	= oMe[IOTA.SECONDS] 	+ oiota[IOTA.SECONDS];
		oRet[IOTA.MINUTES] 	= oMe[IOTA.MINUTES] 	+ oiota[IOTA.MINUTES];
		oRet[IOTA.HOURS] 	= oMe[IOTA.HOURS] 		+ oiota[IOTA.HOURS];
		oRet[IOTA.DAYS] 	= oMe[IOTA.DAYS] 		+ oiota[IOTA.DAYS];
		oRet[IOTA.YEARS] 	= oMe[IOTA.YEARS] 		+ oiota[IOTA.YEARS];

		return levelValues(this);

	end,

	__tostring = function(...)
		local oIota	= tIota[arg[1]];

		return "Year: "..oIota[IOTA.YEARS]..' '..
			   string.format(" Day: %03d Hour: %02d", oIota[IOTA.DAYS], oIota[IOTA.HOURS]);
	end,


	--__tostring = function(...)
		--local oIota	= tIota[arg[1]];

		--return oIota[IOTA.YEARS]..':'..
			--   string.format("%03d:%02d:%02d:%02d",
			  -- oIota[IOTA.DAYS], 		oIota[IOTA.HOURS],
			  -- oIota[IOTA.MINUTES], 	oIota[IOTA.SECONDS]);
	--end,]]

	--todo break this out into more functions
	addValue = function(...)
		local this			= arg[1];
		local oIota 		= tIota[this];
		local sValueItem 	= arg[2];
		local nValue 		= arg[3];

		if oIota[sValueItem] then
			--setMarker(oIota);
			oIota[sValueItem] = oIota[sValueItem] + nValue;
			levelValues(this);
		end

		return this;
	end,

	--[[addSeconds = function(...)
		local oIota 		= tIota[];
		local sValueItem 	= arg[2];
		local nValue 		= arg[3];


	end,finish this!]]

	destroy = function(...)
		tIota[arg[1]] = nil;
	end,

	--[[
		returns the change since the last adjustment
	]]
	--[[delta = function(...)
		local oIota = tIota[;
		local tRet = {};

		for _, sName in pairs(IOTA()) do
			tRet[sName] = oIota.marker[sName];
		end

		return tRet;
	end,]]


	getSeconds = function(...)
		return tIota[arg[1]][IOTA.SECONDS];
	end,

	getMinutes = function(...)
		return tIota[arg[1]][IOTA.MINUTES];
	end,

	getHours = function(...)
		return tIota[arg[1]][IOTA.HOURS];
	end,

	getDays = function(...)
		return tIota[arg[1]][IOTA.DAYS];
	end,

	getYears = function(...)
		return tIota[arg[1]][IOTA.YEARS];
	end,

	getValue = function(...)
		local oIota 		= tIota[arg[1]];
		local sValueItem 	= AAA.CheckTypes(sIota, 'getValue', arg, 2, {'string'});
		local nRet 			= 0;

		if oIota[sValueItem] then
			nRet = oIota[sValueItem];
		end

		return nRet;
	end,

	--TODO convert this function to work with the new aaa
	multValue = function(...)
		local this			= arg[1];
		local oIota 		= tIota[this];
		local sValueItem 	= AAA.CheckTypes(sIota, 'multValue', arg, 2, {'string'});
		local nValue 		= AAA.CheckTypes(sIota, 'multValue', arg, 3, {'number'});

		if (oIota[sValueItem]) then
			oIota[sValueItem] = oIota[sValueItem] * nValue;
			levelValues(this);
		end

		return this;
	end,

	--todo fix this, it should use levelValues
	set = function(...)
		local sFunction = 'set';
		local this			= arg[1];
		local oIota 	= tIota[this];
		local nYears 	= AAA.CheckTypes(sIota, sFunction, arg, 2, {'number'});
		local nDays 	= AAA.CheckTypes(sIota, sFunction, arg, 3, {'number'});
		local nHours 	= AAA.CheckTypes(sIota, sFunction, arg, 4, {'number'});
		local nMinutes 	= AAA.CheckTypes(sIota, sFunction, arg, 5, {'number'});
		local nSeconds 	= AAA.CheckTypes(sIota, sFunction, arg, 6, {'number'});

		oIota[IOTA.YEARS] 	= T((nYears 	>= 0), 	nYears, 																		0);
		oIota[IOTA.DAYS] 	= T((nDays 		>= 0), 	T((nDays 	< oIota.Max[IOTA.DAYS]), 	nDays, 		oIota.Max[IOTA.DAYS]), 		0);
		oIota[IOTA.HOURS] 	= T((nHours 	>= 0), 	T((nHours 	< oIota.Max[IOTA.HOURS]), 	nHours, 	oIota.Max[IOTA.HOURS]), 	0);
		oIota[IOTA.MINUTES]	= T((nMinutes	>= 0), 	T((nMinutes < oIota.Max[IOTA.MINUTES]), nMinutes, 	oIota.Max[IOTA.MINUTES]), 	0);
		oIota[IOTA.SECONDS] = T((nSeconds 	>= 0), 	T((nSeconds < oIota[IOTA.SECONDS]), 	nSeconds, 	oIota[IOTA.SECONDS]), 		0);

		return this;
	end,

	setCallback = function(...)
		local sFunction = 'setCallback';
		local this		= arg[1];
		local oIota 	= tIota[this];
		local sFunction	= AAA.CheckTypes(sIota, sFunction, arg, 2, {'string'});
		local fCallback	= AAA.CheckTypes(sIota, sFunction, arg, 3, {'function', 'nil'});
		local tArgs		= AAA.CheckTypes(sIota, sFunction, arg, 4, {'table', 'nil'});
		--error(type(tIota[arg[1]]), 4)
		if (oIota.callbacks[sFunction]) then
			--local sType = type(fCallback);

			--if (sType == 'function') then
				oIota.callbacks[sFunction] 		= fCallback or 0;
				oIota.callbackArgs[sFunction]	= tArgs or {};
			--elseif (sType == 'nil') then
				--oIota.callbacks[sFunction] = 0;
			--end

		end

		return this;
	end,

	setDays = function(...)
		local this		= arg[1];
		local oIota 	= tIota[this];
		local nDays 	= AAA.CheckTypes(sIota, 'setDays', arg, 2, {'number'});
		local nMax 		= oIota.Max[IOTA.DAYS];

		oIota[IOTA.DAYS] = T((nDays >= 0), T((nDays < nMax), nDays, nMax), 0);
		return this;
	end,


	setHours = function(...)
		local this		= arg[1];
		local oIota 	= tIota[this];
		local nHours 	= AAA.CheckTypes(sIota, 'setHours', arg, 2, {'number'});
		local nMax = oIota.Max[IOTA.HOURS];

		oIota[IOTA.HOURS] = T((nHours >= 0), T((nHours < nMax), nHours, nMax), 0);
		return this;
	end,


	setMinutes = function(...)
		local this		= arg[1];
		local oIota 	= tIota[this];
		local nMinutes 	= AAA.CheckTypes(sIota, 'setMinutes', arg, 2, {'number'});
		local nMax = oIota.Max[IOTA.MINUTES];

		oIota[IOTA.MINUTES] = T((nMinutes >= 0), T((nMinutes < nMax), nMinutes, nMax), 0);
		return this;
	end,


	setSeconds = function(...)
		local this		= arg[1];
		local oIota 	= tIota[this];
		local nSeconds 	= AAA.CheckTypes(sIota, 'setSeconds', arg, 2, {'number'});
		local nMax = oIota.Max[IOTA.SECONDS];

		oIota[IOTA.SECONDS] = T((nSeconds >= 0), T((nSeconds < nMax), nSeconds, nMax), 0);
		return this;
	end,

	setYears = function(...)
		local this		= arg[1];
		local oIota 	= tIota[this];
		local nYears 	= AAA.CheckTypes(sIota, 'setYears', arg, 2, {'number'});

		oIota[IOTA.YEARS] = T((nYears >= 0), nYears, 0);
		return this;
	end,

	setValue = function(...)
		local this			= arg[1];
		local oIota 		= tIota[this];
		local sValueItem 	= AAA.CheckTypes(sIota, 'setValue', arg, 2, {'string'});
		local nValue 		= AAA.CheckTypes(sIota, 'setValue', arg, 3, {'number'});

		if (oIota[sValueItem]) then

			if (sValueItem == IOTA.SECONDS) then
				oIota:setSeconds(nValue);

			elseif (sValueItem == IOTA.MINUTES) then
				oIota:setMinutes(nValue);

			elseif (sValueItem == IOTA.HOURS) then
				oIota:setHours(nValue);

			elseif (sValueItem == IOTA.DAYS) then
				oIota:setDays(nValue);

			elseif (sValueItem == IOTA.YEARS) then
				oIota:setYears(nValue);
			end

		end

		return this;
	end,

};

return iota;