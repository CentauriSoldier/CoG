--[[*
@authors Centauri Soldier
@copyright Public Domain
@description
	<h2>protean</h2>
	<p>An object designed to hold a base value (or use an external one) as well
	as adjuster values which operate on the base value to produce a final result.
	Designed to be a simple-to-use modifier system.</p>
	<br>
	<p>
	<b>Note:</b> <em>"bonus"</em> and <em>"penalty"</em> are logical concepts.
	How they are calculated is up to the client. They should be set, applied
	and processed as if they infer their respective, purported affects. That is,
	a <em>"bonus"</em> could be a positve value in one case or a negative value
	in another, so long as the target is gaining some net benefit. The sign of
	the value should not be assumed but, rather, tailored to apply a beneficial
	affect (for bonus) or detramental affect (for penalty).
	<br>
	<br>
	Also, any multiplicative value is treated as a percetage and should be a float value.
	<br>
	E.g.,
	<br>
	<ul>
		<li>1 	 = 100%</li>
		<li>0.2  = 20%</li>
		<li>1.65 = 165%</li>
	</ul>
	<br>
	In order of altering affect intensity (descending):
	Base, Multiplicative, Addative
	<br>
	<br>
	How the final value is calcualted:
	<br>
	Let V be some value, B be the base adjustment,
	M be the multiplicative adjustment, A be the
	addative adjustment and sub-b be the bonus and sub-p be the penalty.
	<br>
	<br>
	V = [(V + Bb - Bp) * (1 + Mb - Mp)] + Ab - Ap
	<br>
	<br>
	There may be some instances where a client may use several protean objects but wants the
	same base value for all of them. In this case, it would be cumbersome to have to set the
	base value for each protean object. So, a protean object may be told to use an external
	reference for the base value. In this case, a table is provided to the protean object with a key
	of PROTEAN.EXTERNAL_INDEX and a number value. This allows for multiple protean objects to reference
	the same base value without the need for resetting the base value of each object. Note: the table
	input will have a metamethod (__index) added to it which will update the final value of the Protean objects
	whenever the value is changed. If the table input already has a metamethod of __index, the Protean's __index
	metamethod will overwrite it.
	</p>
@license <p>The Unlicense<br>
<br>
@moduleid protean
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
		<p>Added the ability to set a callback function on value change.</p>
		<p>Added the ability to enable or disable the callback function.</p>
		<p>Added the ability to disable auto-calculation of the final value.</p>
		<p>Added the ability to manually call for calculation of the final value.</p>
	</li>
</ul>
@website https://github.com/CentauriSoldier
*]]
assert(type(const) == "function", "const has not been loaded.");
PROTEAN							= const("PROTEAN");
PROTEAN.BASE					= const("PROTEAN.BASE", "", true);
PROTEAN.BASE.BONUS				= "Base Bonus";
PROTEAN.BASE.PENALTY 			= "Base Penalty";
PROTEAN.MULTIPLICATIVE			= const("PROTEAN.MULTIPLICATIVE", "", true);
PROTEAN.MULTIPLICATIVE.BONUS	= "Multiplicative Bonus";
PROTEAN.MULTIPLICATIVE.PENALTY	= "Multiplicative Penalty";
PROTEAN.ADDATIVE				= const("PROTEAN.ADDATIVE", "", true);
PROTEAN.ADDATIVE.BONUS			= "Addative Bonus";
PROTEAN.ADDATIVE.PENALTY 		= "Addative Penalty";
PROTEAN.VALUE					= const("PROTEAN.VALUE");
PROTEAN.VALUE.BASE				= "Base Value";
PROTEAN.VALUE.FINAL				= "Final Value";
PROTEAN.LIMIT					= const("PROTEAN.LIMIT");
PROTEAN.LIMIT.MIN				= "Minimum Limit";
PROTEAN.LIMIT.MAX				= "Maximum Limit";
--PROTEAN.EXTERNAL_INDEX			= "Protean External Index";

local tProteans = {};

--local function ExternalTableIsValid(tTable)
--	return type(tTable) == "table" and type(tTable[PROTEAN.EXTERNAL_INDEX]) == "number";
--end

local function calculateFinalValue(oProtean)
	local nBase = oProtean[PROTEAN.VALUE.BASE];

	--check for an external reference to the base value
	--if (oProtean.UseExternalValue and ExternalTableIsValid(nBase)) then
--		nBase = oProtean[PROTEAN.VALUE.BASE][PROTEAN.EXTERNAL_INDEX];
--	end

	local nBaseBonus	= oProtean[PROTEAN.BASE.BONUS];
	local nBasePenalty	= oProtean[PROTEAN.BASE.PENALTY];
	local nMultBonus	= oProtean[PROTEAN.MULTIPLICATIVE.BONUS];
	local nMultPenalty	= oProtean[PROTEAN.MULTIPLICATIVE.PENALTY];
	local nAddBonus		= oProtean[PROTEAN.ADDATIVE.BONUS];
	local nAddPenalty	= oProtean[PROTEAN.ADDATIVE.PENALTY];

	oProtean[PROTEAN.VALUE.FINAL] = ((nBase + nBaseBonus - nBasePenalty) * (1 + nMultBonus - nMultPenalty)) + nAddBonus - nAddPenalty;
end

local function setValue(oProtean, sType, vValue)

	if (sType ~= PROTEAN.VALUE.FINAL) then

		--if a number was passed
		if (type(vValue) == "number") then
			oProtean[sType] = vValue;

			if (sType == PROTEAN.VALUE.BASE and oProtean.UseExternalValue) then
				oProtean.UseExternalValue	= false;
			end

		--if a proper, external table was passed (and the value being set is PROTEAN.VALUE.BASE)
		--elseif (ExternalTableIsValid(vValue) and sType == PROTEAN.VALUE.BASE) then
		--	oProtean.UseExternalValue = true;
		end

		if (oProtean.autoCalculate) then
			--(re)calculate the final value
			calculateFinalValue(oProtean);
		end

	end

	if (oProtean.isCallbackActive and type(oProtean.onChange) == "function") then
		oProtean.onChange(oProtean);
	end

	return oProtean[sType];
end


class "protean" {
	--[[!
		@desc The constructor for the protean class.
		@func protean
		@module protean
		@param nBaseValue number This value is Vb where Vf = [(Vb + Bb - Bp) * (1 + Mb - Mp)] + Ab - Ap and where Vf is the calculated, final value. If set to nil, it will default to 0.
		@param nBaseBonus number/nil This value is Bb where Vf = [(Vb + Bb - Bp) * (1 + Mb - Mp)] + Ab - Ap and where Vf is the calculated, final value. If set to nil, it will default to 0.
		@param nBasePenalty number/nil This value is Bp where Vf = [(Vb + Bb - Bp) * (1 + Mb - Mp)] + Ab - Ap and where Vf is the calculated, final value. If set to nil, it will default to 0.
		@param nMultiplicativeBonus number/nil This value is Mb where Vf = [(Vb + Bb - Bp) * (1 + Mb - Mp)] + Ab - Ap and where Vf is the calculated, final value. If set to nil, it will default to 0.
		@param nMultiplicativePenalty number/nil This value is Mp where Vf = [(Vb + Bb - Bp) * (1 + Mb - Mp)] + Ab - Ap and where Vf is the calculated, final value. If set to nil, it will default to 0.
		@param nAddativeBonus number/nil This value is Ab where Vf = [(Vb + Bb - Bp) * (1 + Mb - Mp)] + Ab - Ap and where Vf is the calculated, final value. If set to nil, it will default to 0.
		@param nAddativePenalty number/nil This value is Ap where Vf = [(Vb + Bb - Bp) * (1 + Mb - Mp)] + Ab - Ap and where Vf is the calculated, final value. If set to nil, it will default to 0.
		@param nMinLimit number/nil This is the minimum value that the calculated, final value will return. If set to nil, it will be ignored and there will be no minimum value.
		@param nMaxLimit number/nil This is the maximum value that the calculated, final value will return. If set to nil, it will be ignored and there will be no maximum value.
		@param fonChange function/nil If the (optional) input is a function, this will be called whenever a change is made to this object (unless callback is inactive).
		@param bAutoCalculate Whether or not this object should auto-calculate the final value whenever a change is made. This is true by default. If set to nil, it will default to true.
		@return oProtean protean A protean object.
	!]]
	__construct = function(this, nBaseValue, nBaseBonus, nBasePenalty, nMultiplicativeBonus, nMultiplicativePenalty, nAddativeBonus, nAddativePenalty, nMinLimit, nMaxLimit, fonChange, bAutoCalculate)
		--TODO assertions for input values

		tProteans[this] = {
			[PROTEAN.VALUE.BASE]				= nBaseValue or 0,
			[PROTEAN.BASE.BONUS] 				= nBaseBonus 				or 0,
			[PROTEAN.BASE.PENALTY] 				= nBasePenalty 				or 0,
			[PROTEAN.MULTIPLICATIVE.BONUS] 		= nMultiplicativeBonus 		or 0,
			[PROTEAN.MULTIPLICATIVE.PENALTY] 	= nMultiplicativePenalty 	or 0,
			[PROTEAN.ADDATIVE.BONUS] 			= nAddativeBonus 			or 0,
			[PROTEAN.ADDATIVE.PENALTY] 			= nAddativePenalty 			or 0,
			[PROTEAN.VALUE.FINAL]				= 0, --this is (re)calcualted whenever another item is changed
			[PROTEAN.LIMIT.MIN] 				= nMinLimit,
			[PROTEAN.LIMIT.MAX] 				= nMaxLimit,
			--UseExternalValue					= ExternalTableIsValid(vBaseValue),
			autoCalculate						= true,--bAutoCalculate
			onChange 							= fonChange,
			isCallbackActive					= false,
		};

		--calculate the final value for the first time
		calculateFinalValue(tProteans[this]);
	end,

	--[[!
	@desc Adjusts the given value by the amount input. Note: if using an external table which contains the base value, and the type provided is PROTEAN.VALUE.BASE, nil will be returned. An external base value cannot be adjusted from inside the Protean	object (although the base bonus and base penalty may be).
	@func protean.adjust
	@module protean
	@param sType PROTEAN The type of value to adjust.
	@param nValue number The value by which to adjust the given value.
	@return nValue number The adjusted value (or nil is PROTEAN.VALUE.BASE was input as the type).
	!]]
	adjust = function(this, sType, nValue)

		if (tProteans[this][sType]) then

			if (type(vValue) == "number") then
				return setValue(tProteans[this], sType, tProteans[this][sType] + vValue);
			end

		end

	end,

	--[[!
		@desc Calculates the final value of the protean. This is done on-change by default so that the final value (when requested) is always up-to-date and accurate. There is no need to call this unless auto-calculate has been disabled. In that case, this serves an external utility function to perform the normally-internal operation of calculating and updating the final value.
		@func protean.calulateFinalValue
		@module protean
		@return nValue number The calculated final value.
	!]]
	calulateFinalValue = function(this)
		calculateFinalValue(oProtean);
		return tProteans[this][PROTEAN.VALUE.FINAL];
	end,

	--[[!
	@desc Set this object to be deleted by the garbage collector.
	@func protean.destroy
	@module protean
	!]]
	destroy = function(this)
		tProteans[this] = nil;
		this = nil;
	end,

	--[[!
		@desc Gets the value of the given value type. Note: if the type provided is PROTEAN.VALUE.FINAL and MIN or MAX limits have been set, the returned value will fall within the confines of those paramter(s).
		@func protean.get
		@module protean
		@param sType PROTEAN The type of value to get.
		@return nValue number The value of the given type.
	!]]
	get = function(this, sType)
		local nRet = 0;

		if (tProteans[this][sType]) then
			nRet = tProteans[this][sType];

			if (sType == PROTEAN.VALUE.FINAL) then

				--clamp the value if it has been limited
				if (tProteans[this][PROTEAN.LIMIT.MIN]) then

					if (nRet < tProteans[this][PROTEAN.LIMIT.MIN]) then
						nRet = tProteans[this][PROTEAN.LIMIT.MIN];
					end

				end

				if (tProteans[this][PROTEAN.LIMIT.MAX]) then

					if (nRet > tProteans[this][PROTEAN.LIMIT.MAX]) then
						nRet = tProteans[this][PROTEAN.LIMIT.MAX];
					end

				end

			elseif (sType == PROTEAN.VALUE.BASE) then

				if (tProteans[this].UseExternalValue and ExternalTableIsValid(tProteans[this][PROTEAN.VALUE.BASE])) then
					nRet = tProteans[this][PROTEAN.VALUE.BASE][PROTEAN.EXTERNAL_INDEX];
				end

			end

		end

		return nRet;
	end,

	--[[!
		@desc Determines whether or not auto-calculate is active.
		@func protean.isAutoCalculated
		@module protean
		@return bActive boolean Whether or not auto-calculate occurs on value change.
	!]]
	isAutoCalculated = function(this)
		return tProteans[this].autoCalculate;
	end,

	--[[!
		@desc Determines whether or not the callback is called on change.
		@func protean.isCallbackActive
		@module protean
		@return bActive boolean Whether or not the callback is called on value change.
	!]]
	isCallbackActive = function(this)
		return tProteans[this].isCallbackActive;
	end,

	--[[!
		@desc Set the given value type to the value input. Note: if using an external table which contains the base value, and the type provided is PROTEAN.VALUE.BASE, this object will stop using the external value and will use the value input.
		@func protean.set
		@module protean
		@param sType PROTEAN The type of value to adjust.
		@param nValue number The value which to set given value type.
		@return nValue number The new value.
	!]]
	set = function(this, sType, vValue)

		if (tProteans[this][sType]) then
			return setValue(tProteans[this], sType, vValue);
		end

	end,

	--[[!
		@desc By default, the final value is calculated whenever a change is made to a value; however, this method gives the power of that choice to the client. If disabled, the client will need to call calculateFinalValue to update the final value.
		@func protean.setAutoCalculate
		@module protean
		@param bAutoCalculate boolean Whether or not the objects should auto-calculate the final value.
	!]]
	setAutoCalculate = function(this, bFlag)

		if (type(bFlag) == "boolean") then
			tProteans[this].autoCalculate		 = bFlag;
		else
			tProteans[this].autoCalculate		 = false;
		end

	end,

	--[[!
		@desc Set the given function as this objects's onChange callback which is called whenever a change occurs (if active).
		@func protean.setCallback
		@module protean
		@param fCallback function The callback function (which must accept the protean object as its first parameter)
	!]]
	setCallback = function(this, fCallback)

		if (type(fCallback) == "function") then
			tProteans[this].onChange = fCallback;
			isCallbackActive		 = true;
		else
			tProteans[this].onChange = nil;
			isCallbackActive		 = false;
		end

	end,

	--[[!
		@desc Set the object's callback function (if any) to active/inactive. If active, it will fire whenever a change is made while nothing will occur if it is inactive.
		@func protean.setCallbackActive
		@module protean
		@param bActive boolean A boolean value indicating whether or no the callback function should be called.
	!]]
	setCallbackActive = function(this, bFlag)

		if (type(bFlag) == "boolean") then
			tProteans[this].isCallbackActive		 = bFlag;
		else
			tProteans[this].isCallbackActive		 = false;
		end

	end,
}

return protean;
