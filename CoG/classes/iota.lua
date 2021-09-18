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
	<li>
		<b>1.2</b>
		<br>
		<p>Removed dependence on AAA.</p>
	</li>
</ul>
@website https://github.com/CentauriSoldier
*]]
local iota;
local sIota = 'iota';

local tIota = {};
local tIotas = {};

--localization
--local IOTA 		= IOTA;
local math 		= math;
local unpack 	= unpack;
local type 		= type;
local class 	= class;
local pairs 	= pairs;
local string 	= string;

--=====================================================>
-- 					String Precache
--=====================================================>
--this is the place that strings are stored for use by the __tostring method

--used by the __tostring method
local sBlank 	= "";
local sYears 	= "";
local sDays 	= "";
local sHours 	= "";
local sMinutes 	= "";
local sSeconds 	= "";

--CHANGE THESE TO YOUR LIKING
local sYearPrefix 	= "Year: ";
local sDayPrefix 	= " Day: ";
local sHourPrefix 	= " Hour: ";
local sMinutePrefix = " Minute: ";
local sSecondPrefix = " Second: ";

--=====================================================<
--DO NOT CHANGE THESE VALUES
local tStringPreCache = {};
local PRECACHE_YEARS 	= 1;
local PRECACHE_DAYS 	= 2;
local PRECACHE_HOURS 	= 3;
local PRECACHE_MINUTES 	= 4;
local PRECACHE_SECONDS 	= 5;




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
	local oIota			= tIotas[this];
	local nMax 			= iota.MAX.SECONDS;
	local nPreValue 	= 0;
	local nPostValue	= 0;

	if (oIota[iota.INTERVAL.SECONDS] >= nMax) then
		nPreValue = oIota[iota.INTERVAL.MINUTES];
		oIota[iota.INTERVAL.MINUTES]  = oIota[iota.INTERVAL.MINUTES] + math.floor(oIota[iota.INTERVAL.SECONDS] / nMax);
		oIota[iota.INTERVAL.SECONDS]  = oIota[iota.INTERVAL.SECONDS] % nMax;
		nPostValue = oIota[iota.INTERVAL.MINUTES] - nPreValue;

		if (type(oIota.callbacks[iota.CALLBACK.ON_MINUTE]) == 'function') then
			oIota.callbacks[iota.CALLBACK.ON_MINUTE](this, nPostValue, unpack(oIota.callbackArgs[iota.CALLBACK.ON_MINUTE]));
		end

	end

	nMax = iota.MAX.MINUTES;
	if (oIota[iota.INTERVAL.MINUTES] >= nMax) then
		nPreValue = oIota[iota.INTERVAL.HOURS];
		oIota[iota.INTERVAL.HOURS] 	 = oIota[iota.INTERVAL.HOURS] + math.floor(oIota[iota.INTERVAL.MINUTES] / nMax);
		oIota[iota.INTERVAL.MINUTES]  = oIota[iota.INTERVAL.MINUTES] % nMax;
		nPostValue = oIota[iota.INTERVAL.HOURS] - nPreValue;

		if (type(oIota.callbacks[iota.CALLBACK.ON_HOUR]) == 'function') then
			oIota.callbacks[iota.CALLBACK.ON_HOUR](this, nPostValue, unpack(oIota.callbackArgs[iota.CALLBACK.ON_HOUR]));
		end

	end

	nMax = iota.MAX.HOURS;
	if (oIota[iota.INTERVAL.HOURS] >= nMax) then
		nPreValue = oIota[iota.INTERVAL.DAYS];
		oIota[iota.INTERVAL.DAYS]   = oIota[iota.INTERVAL.DAYS] + math.floor(oIota[iota.INTERVAL.HOURS] / nMax);
		oIota[iota.INTERVAL.HOURS]  = oIota[iota.INTERVAL.HOURS] % nMax;
		nPostValue = oIota[iota.INTERVAL.DAYS] - nPreValue;

		if (type(oIota.callbacks[iota.CALLBACK.ON_DAY]) == 'function') then
			oIota.callbacks[iota.CALLBACK.ON_DAY](this, nPostValue, unpack(oIota.callbackArgs[iota.CALLBACK.ON_DAY]));
		end

	end

	nMax = iota.MAX.DAYS;
	if (oIota[iota.INTERVAL.DAYS] >= nMax) then
		nPreValue = oIota[iota.INTERVAL.YEARS];
		oIota[iota.INTERVAL.YEARS] = oIota[iota.INTERVAL.YEARS] + math.floor(oIota[iota.INTERVAL.DAYS] / nMax);
		oIota[iota.INTERVAL.DAYS]  = oIota[iota.INTERVAL.DAYS] % nMax
		nPostValue = oIota[iota.INTERVAL.YEARS] - nPreValue;

		if (type(oIota.callbacks[iota.CALLBACK.ON_YEAR]) == 'function') then
			oIota.callbacks[iota.CALLBACK.ON_YEAR](this, nPostValue, unpack(oIota.callbackArgs[iota.CALLBACK.ON_YEAR]));
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

iota = class "iota" {

	__construct = function(this)
		tIotas[this] = {
			callbacks 	 	= {},
			callbackArgs 	= {},
			ShowYears 		= true,
			ShowDays		= true,
			ShowHours 		= true,
			ShowMinutes		= true,
			ShowSeconds 	= true,

			--marker = {}, --used for tracking how much time has passed from one point to the next
		};
		local oIota = tIotas[this];

		--setup values
		for _, eItem in iota.INTERVAL() do
			oIota[tostring(eItem)] 		= 0;
			--oIota.marker[sName] 	= 0;
		end

		--setup callbacks
		for _, eItem in iota.CALLBACK() do
			oIota.callbacks[eItem.value] 		= 0;
			oIota.callbackArgs[eItem.value]		= {};
		end

	end,

	--todo left/right checks
	__add = function(this, oIota)
		local oMe			= tIotas[this];
		local oRet 			= iota();
		local nAddMinutes 	= 0;
		local nAddHours 	= 0;
		local nAddDays 		= 0;
		local nAddYears 	= 0;

		oRet[iota.INTERVAL.SECONDS] 	= oMe[iota.INTERVAL.SECONDS] 	+ oIota[iota.INTERVAL.SECONDS];
		oRet[iota.INTERVAL.MINUTES] 	= oMe[iota.INTERVAL.MINUTES] 	+ oIota[iota.INTERVAL.MINUTES];
		oRet[iota.INTERVAL.HOURS] 		= oMe[iota.INTERVAL.HOURS] 		+ oIota[iota.INTERVAL.HOURS];
		oRet[iota.INTERVAL.DAYS] 		= oMe[iota.INTERVAL.DAYS] 		+ oIota[iota.INTERVAL.DAYS];
		oRet[iota.INTERVAL.YEARS] 		= oMe[iota.INTERVAL.YEARS] 		+ oIota[iota.INTERVAL.YEARS];

		return levelValues(this);

	end,

	__tostring = function(this)
		local oIota	= tIotas[this];
		local tCache = tStringPreCache;

		--TODO for some reason, hours and minutes are missing a space...find out why
		--TODO create contingent for non-existent year strings
		sYears 		= oIota.ShowYears 	and tCache[PRECACHE_YEARS][oIota[iota.INTERVAL.YEARS]] 			or sBlank;
		sDays 		= oIota.ShowDays 	and tCache[PRECACHE_DAYS][oIota[iota.INTERVAL.DAYS]] 			or sBlank;
		sHours 		= oIota.ShowHours 	and tCache[PRECACHE_HOURS][oIota[iota.INTERVAL.HOURS]] 			or sBlank;
		sMinutes 	= oIota.ShowMinutes and tCache[PRECACHE_MINUTES][oIota[iota.INTERVAL.MINUTES]] 		or sBlank;
		sSeconds 	= oIota.ShowSeconds and tCache[PRECACHE_SECONDS][oIota[iota.INTERVAL.SECONDS]] 		or sBlank;

		return sYears..sDays..sHours..sMinutes..sSeconds;
		--return "Year: "..oIota[IOTA.YEARS]..' '..
		--	   string.format(" Day: %03d Hour: %02d", oIota[IOTA.DAYS], oIota[IOTA.HOURS]);
	end,


	--__tostring = function(...)
		--local oIota	= tIotas[arg[1]];

		--return oIota[IOTA.YEARS]..':'..
			--   string.format("%03d:%02d:%02d:%02d",
			  -- oIota[IOTA.DAYS], 		oIota[IOTA.HOURS],
			  -- oIota[IOTA.MINUTES], 	oIota[IOTA.SECONDS]);
	--end,]]

	--todo break this out into more functions
	addValue = function(this, sValueItem, nValue)
		local oIota 		= tIotas[this];

		if oIota[sValueItem] then
			--setMarker(oIota);
			oIota[sValueItem] = oIota[sValueItem] + nValue;
			levelValues(this);
		end

		return this;
	end,

	--[[addSeconds = function(...)
		local oIota 		= tIotas[];
		local sValueItem 	= arg[2];
		local nValue 		= arg[3];


	end,finish this!]]

	deserialize = function(this, sData)
		local oIota = tIotas[this];
		local tData = deserialize(sData);

			oIota[iota.INTERVAL.SECONDS]	= tData[iota.INTERVAL.SECONDS];
			oIota[iota.INTERVAL.MINUTES]	= tData[iota.INTERVAL.MINUTES];
			oIota[iota.INTERVAL.HOURS]		= tData[iota.INTERVAL.HOURS];
			oIota[iota.INTERVAL.DAYS]		= tData[iota.INTERVAL.DAYS];
			oIota[iota.INTERVAL.YEARS]		= tData[iota.INTERVAL.YEARS];

		return this;
	end,

	destroy = function(this)
		tIotas[this] = nil;
		this = nil;
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


	getSeconds = function(this)
		return tIotas[this][iota.INTERVAL.SECONDS];
	end,

	getMinutes = function(this)
		return tIotas[this][iota.INTERVAL.MINUTES];
	end,

	getHours = function(this)
		return tIotas[this][iota.INTERVAL.HOURS];
	end,

	getDays = function(this)
		return tIotas[this][iota.INTERVAL.DAYS];
	end,

	getYears = function(this)
		return tIotas[this][iota.INTERVAL.YEARS];
	end,

	getValue = function(this, sValueItem)
		local oIota 		= tIotas[this];
		local nRet 			= 0;

		if oIota[sValueItem] then
			nRet = oIota[sValueItem];
		end

		return nRet;
	end,

	--TODO convert this function to work with the new aaa
	multValue = function(this, sValueItem, nValue)
		local oIota 		= tIotas[this];

		if (oIota[sValueItem]) then
			oIota[sValueItem] = oIota[sValueItem] * nValue;
			levelValues(this);
		end

		return this;
	end,

	--[[!
		@desc Serializes the object's data.
		@func iota.serialize
		@module iota
		@param bDefer boolean Whether or not to return a table of data to be serialized instead of a serialize string (if deferring serializtion to another object).
		@ret sData StringOrTable The data, returned as a serialized table (string) or a table is the defer option is set to true.
	!]]
	serialize = function(this)
		local oIota = tIotas[this];

		local tData = {
			[iota.INTERVAL.SECONDS]	= oIota[iota.INTERVAL.SECONDS],
			[iota.INTERVAL.MINUTES]	= oIota[iota.INTERVAL.MINUTES],
			[iota.INTERVAL.HOURS]	= oIota[iota.INTERVAL.HOURS],
			[iota.INTERVAL.DAYS]	= oIota[iota.INTERVAL.DAYS],
			[iota.INTERVAL.YEARS]	= oIota[iota.INTERVAL.YEARS],
		};

		return serialize.table(tData);
	end,

	--todo fix this, it should use levelValues
	set = function(this, nYears, nDays, nHours, nMinutes, nSeconds)
		local oIota 	= tIotas[this];

		oIota[iota.INTERVAL.YEARS] 		= T((nYears 	>= 0), 	nYears, 																							0);
		oIota[iota.INTERVAL.DAYS] 		= T((nDays 		>= 0), 	T((nDays 	< oIota.Max[iota.INTERVAL.DAYS]), 		nDays, 		oIota.Max[iota.INTERVAL.DAYS]), 	0);
		oIota[iota.INTERVAL.HOURS] 		= T((nHours 	>= 0), 	T((nHours 	< oIota.Max[iota.INTERVAL.HOURS]), 		nHours, 	oIota.Max[iota.INTERVAL.HOURS]), 	0);
		oIota[iota.INTERVAL.MINUTES]	= T((nMinutes	>= 0), 	T((nMinutes < oIota.Max[iota.INTERVAL.MINUTES]), 	nMinutes, 	oIota.Max[iota.INTERVAL.MINUTES]), 	0);
		oIota[iota.INTERVAL.SECONDS] 	= T((nSeconds 	>= 0), 	T((nSeconds < oIota[iota.INTERVAL.SECONDS]), 		nSeconds, 	oIota[iota.INTERVAL.SECONDS]), 		0);

		return this;
	end,

	setCallback = function(this, sFunction, fCallback, tArgs)
		local oIota 	= tIotas[this];

		--error(type(tIotas[arg[1]]), 4)
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


	setDays = function(this, nDays)
		local oIota 	= tIotas[this];
		local nMax 		= oIota.Max[iota.INTERVAL.DAYS];

		oIota[iota.INTERVAL.DAYS] = T((nDays >= 0), T((nDays < nMax), nDays, nMax), 0);
		return this;
	end,


	setHours = function(this, nHours)
		local oIota 	= tIotas[this];
		local nMax = oIota.Max[iota.INTERVAL.HOURS];

		oIota[iota.INTERVAL.HOURS] = T((nHours >= 0), T((nHours < nMax), nHours, nMax), 0);
		return this;
	end,


	setMinutes = function(this, nMinutes)
		local oIota 	= tIotas[this];
		local nMax = oIota.Max[iota.INTERVAL.MINUTES];

		oIota[iota.INTERVAL.MINUTES] = T((nMinutes >= 0), T((nMinutes < nMax), nMinutes, nMax), 0);
		return this;
	end,


	setSeconds = function(this, nSeconds)
		local oIota 	= tIotas[this];
		local nMax = oIota.Max[iota.INTERVAL.SECONDS];

		oIota[iota.INTERVAL.SECONDS] = T((nSeconds >= 0), T((nSeconds < nMax), nSeconds, nMax), 0);
		return this;
	end,

	setYears = function(this, nYears)
		local oIota 	= tIotas[this];

		oIota[iota.INTERVAL.YEARS] = T((nYears >= 0), nYears, 0);
		return this;
	end,

	setValue = function(this, sValueItem, nValue)
		local oIota 		= tIotas[this];

		if (oIota[sValueItem]) then

			if (sValueItem == iota.INTERVAL.SECONDS) then
				oIota:setSeconds(nValue);

			elseif (sValueItem == iota.INTERVAL.MINUTES) then
				oIota:setMinutes(nValue);

			elseif (sValueItem == iota.INTERVAL.HOURS) then
				oIota:setHours(nValue);

			elseif (sValueItem == iota.INTERVAL.DAYS) then
				oIota:setDays(nValue);

			elseif (sValueItem == iota.INTERVAL.YEARS) then
				oIota:setYears(nValue);
			end

		end

		return this;
	end,

	showYears = function(this, bFlag)
		tIotas[this].ShowYears = type(bFlag) == "boolean" and bFlag or false;
		return this;
	end,

	showDays = function(this, bFlag)
		tIotas[this].ShowDays = type(bFlag) == "boolean" and bFlag or false;
		return this;
	end,

	showHours = function(this, bFlag)
		tIotas[this].ShowHours = type(bFlag) == "boolean" and bFlag or false;
		return this;
	end,

	showMinutes = function(this, bFlag)
		tIotas[this].ShowMinutes = type(bFlag) == "boolean" and bFlag or false;
		return this;
	end,

	showSeconds = function(this, bFlag)
		tIotas[this].ShowSeconds = type(bFlag) == "boolean" and bFlag or false;
		return this;
	end,

};

iota.INTERVAL 	= enum("iota.INTERVAL", {"YEARS", "DAYS", "HOURS", "MINUTES", "SECONDS"}, nil, true);
iota.MAX 		= enum("iota.MAX", {"YEARS", "DAYS", "HOURS", "MINUTES", "SECONDS"}, {999999, 365, 24, 60, 60}, true);
iota.CALLBACK	= enum("iota.CALLBACK", {"ON_SECOND", "ON_MINUTE", "ON_HOUR", "ON_DAY", "ON_YEAR"}, {"onSecond", "onMinute", "onHour", "onDay", "onYear"}, true);

tStringPreCache = {
	[PRECACHE_YEARS] 	= {max = iota.MAX.YEARS.value, 		func = function(nValue) return sYearPrefix	..tostring(nValue); 				end},
	[PRECACHE_DAYS] 	= {max = iota.MAX.DAYS.value, 		func = function(nValue) return sDayPrefix	..string.format("%03d", nValue); 	end},
	[PRECACHE_HOURS] 	= {max = iota.MAX.HOURS.value, 		func = function(nValue) return sHourPrefix	..string.format("%02d", nValue); 	end},
	[PRECACHE_MINUTES] 	= {max = iota.MAX.MINUTES.value, 	func = function(nValue) return sMinutePrefix..string.format("%02d", nValue); 	end},
	[PRECACHE_SECONDS] 	= {max = iota.MAX.SECONDS.value, 	func = function(nValue) return sSecondPrefix..string.format("%02d", nValue); 	end},
};


for nType = 1, #tStringPreCache do
	--store the max value and function
	local nMax = tStringPreCache[nType].max;
	local func = tStringPreCache[nType].func;

	--now, set the value to be a table
	tStringPreCache[nType] = {};

	--store the strings in the table
	for x = 0, nMax do
		tStringPreCache[nType][x] = func(x);
	end

end

--[[
"Year: "..oIota[IOTA.YEARS]..' '..
	  string.format(" Day: %03d Hour: %02d", oIota[IOTA.DAYS], oIota[IOTA.HOURS]);
]]

return iota;
