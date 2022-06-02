--[[*
@moduleid targetor
@authors Centauri Soldier
@copyright Copyright © 2020 Centauri Soldier
@description <h2>Targetor</h2><h3>Targetor objects for target matching and determination.</p>
<h3>Implentation must create the following enums:</h3>
<ul>
	<li>TARGET <em>(enum type)</em></li>
</ul>
<p>Any number of target types may be created for this constant type. The types may then be assigned to targetor objects and be used to check targetability</p>
<p>IMMUNITY and PREREQ are similar but differ in that ANY immunity makes this object untargetable by an object of the noted target type. Regarding PREREQs,
a potential targetor of this object must have this target's type as a TARGET and must also have all PREREQs as targets in order to target this object.</p>
@features
@usage <p>Once a <strong>Targetor</strong> object has been created, it can be operated upon using TARGET types
<em>(or numerically indexed tables containing multiple TARGET types)</em> or other <strong>Targetor</strong> objects.</p>
@todo <p>create <strong>__tostring</strong> metamethod.
@version 0.1
*]]
local tTargetors = {};

constant("TARGETABLE",	0); --things I can target
constant("TARGETOR", 	1);	--things i can be targeted by
constant("IMMUNITY", 	2);	--things that cannot target me even if they claim to be able to
constant("PREREQ",		3); --something every targetor must have in order to target me (e.g., RANGED requirement for FLYING targets)
constant("PRIORITY", 	4); --this is the base prority sorting system; that is, objects will recognize types with lower indices as higher value targets
constant("THREAT", 		5); --this is the base threat sorting system; that is, objects will recognize types with lower indices as higher threats

local TARGETABLE	= TARGETABLE;
local TARGETOR 		= TARGETOR;
local IMMUNITY 		= IMMUNITY;
local PREREQ		= PREREQ;
local PRIORITY		= PRIORITY;
local THREAT 		= THREAT;

local rawtype			= rawtype;
local leftOnlyObject 	= leftOnlyObject;
local rightOnlyObject	= rightOnlyObject;
local bothObjects		= bothObjects;

--[[
local function targetIsValid(...)
	local sTargetType = select(1, ...);
	local bRet = false;

	if (type(sTargetType) == "string") then

		for _, sValue in pairs(TARGET()) do

			if (sTargetType == sValue) then
				bRet = true;
				break;
			end

		end

	end

	return bRet;
end]]

local function typeTableIsValid(tInput)
	local bRet = false;

	if (rawtype(tInput) == "table") then
		local bError = false;

		for _, sInputType in pairs(tInput) do

			if (type(sInputType) ~= "TARGET") then
				bError = true;
				break;
			end

		end

		bRet = not bError;
	end

	return bRet;
end


local function importTypes(tTypes)
	local tRet = {};

	for _, eType in pairs(tTypes) do
		tRet[eType] = true;
	end

	return tRet;
end

local function meetsRequirements(oThis, oOther)
	local bRet = true;

	for eRequirement, _ in pairs(oOther.requirements) do

		if not (oThis.targetables[eRequirement]) then
			bRet = false;
			break;
		end

	end

	return bRet;
end

local function hasTargetable(oThis, oOther)
	local bRet = false;

	for eType, _ in pairs(oThis.targetables) do

		if (oOther.targetors[eType]) then
			bRet = true;
			break;
		end

	end

	return bRet;
end


local function isImmune(oThis, oOther)
	local bRet = false;

	for eImmunity, _ in pairs(oThis.immunities) do

		if (oOther.targetors[eImmunity]) then
			bRet = true;
			break;
		end

	end

	return bRet;
end




--TODO change the word IMMUNE to UNTARGETABLE for clarity









local function setType(tTable, sType, vValue)

	if (targetIsValid(sType)) then
		tTable[sType] = vValue;
	end

end

local function clearType(tTable, sType)

	if (targetIsValid(sType)) then

		if (tTable[sType]) then
			tTable[sType] = nil;
		end

	end

end

local function setTypes(tTable, vTypes, vValue)
	local sType = type(vTypes);

	if (sType == "string") then
		setType(tTable, vTypes, vValue);

	elseif (sType == "table") then

		for _, sTargetType in pairs(vTypes) do
			setType(tTable, sTargetType, vValue);
		end

	end

end

local bTargetEnumExists = false;

local targetor = class "targetor" {

	__construct = function(this, tProt, tTheTargetors, tTargetables, tImmunities, tRequirements, tProrities, tThreats)

		--make sure the enum is setup
		if not (bTargetEnumExists) then
			assert(type(TARGET) == "enum", "Error creator targetor. 'TARGET' enum has not been created.")
			bTargetEnumExists = true;
		end

		tTargetors[this] = {
			targetors 		= typeTableIsValid(tTheTargetors)  	and importTypes(tTheTargetors)	or {}, --what kind of targetor types I am
			targetables		= typeTableIsValid(tTargetables) 	and importTypes(tTargetables) 	or {}, --types I can target (if the target is not immune) (inclusive list)
			immunities 		= typeTableIsValid(tImmunities)  	and importTypes(tImmunities) 	or {}, --targetor types that cannot target me (takes precedence over another's 'targets' table)
			requirements	= typeTableIsValid(tRequirements)  	and importTypes(tRequirements) 	or {}, --the must-have type(s) required in order to target me (exclusive list)
			priorities	 	= typeTableIsValid(tProrities)  	and importTypes(tProrities)		or {}, --what I try to target first
			threats			= typeTableIsValid(tThreats)  		and importTypes(tThreats) 		or {}, --what I avoid being targeted by first
		};

	end,

	destroy = function(this)
		tTargetors[this] = nil;
	end,

	addTargetor = function(this, oTargtor)

	end,

	addTargetable = function(this, oTargtor)

	end,

	addImmunity = function(this, oTargtor)

	end,

	--[[!
	@module Targetor
	@func __add
	@scope local
	@desc <p>Adds the given TARGET type to the object's 'targetors' table.</p>
	@ret targetor oTargetor Returns the targetor object.
	!]]
	__add = function(vLeft, vRight)
		local oRet = 0;
		local sLeftType = type(vLeft);
		local sRightType = type(vRight);

		if (sLeftType == "targetor" and sRightType == "TARGET") then
			tTargetors[vLeft].targetors[vRight] = true;
			oRet = vLeft;
		elseif (sLeftType == "TARGET" and sRightType == "targetor") then
			tTargetors[vRight].targetors[vLeft] = true;
			oRet = vRight;
		else
			error("Error adding targetor with TARGET. One side must be of type 'targetor' and the other side of type 'TARGET';");
		end

		return oRet;
	end,

	--[[!
	@module Targetor
	@func __div
	@scope local
	@desc <p>Removes the given TARGET type from the object's 'targetables' table.</p>
	@ret targetor oTargetor Returns the targetor object.
	!]]
	__div = function(vLeft, vRight)
		local oRet = 0;
		local sLeftType = type(vLeft);
		local sRightType = type(vRight);

		if (sLeftType == "targetor" and sRightType == "TARGET") then
			tTargetors[vLeft].targetables[vRight] = nil;
			oRet = vLeft;
		elseif (sLeftType == "TARGET" and sRightType == "targetor") then
			tTargetors[vRight].targetables[vLeft] = nil;
			oRet = vRight;
		else
			error("Error multiplying targetor with TARGET. One side must be of type 'targetor' and the other side of type 'TARGET';");
		end
	--TODO Correct error text for each of these!!!!!!!!!!!!!!!
		return oRet;
	end,

	--[[!
	@module targetor
	@func __lt
	@desc <p>Determines whether the right object can target the left (or, if using the greater-than symbol, whether the left can target the right).
			This function accounts for targetable types, requirements and immunitites.</p>
	@ret boolean bCanTarget Returns true if it can target and false otherwise.
	!]]
	__lt = function(this, other)
		local sThisType 	= type(other);
		local sOtherType 	= type(other);
		assert(sThisType 	== "targetor", "Left side of operator is of type "..sThisType..". Expected type targetor.");
		assert(sOtherType 	== "targetor", "Right side of operator is of type "..sOtherType..". Expected type targetor.");
		local oThis 		= tTargetors[this];
		local oOther 		= tTargetors[other];

		return meetsRequirements(oOther, oThis) and (not isImmune(oThis, oOther)) and hasTargetable(oOther, oThis);
	end,


	--[[!
	@module Targetor
	@func __mul
	@scope local
	@desc <p>Adds the given TARGET type to the object's 'targetables' table.</p>
	@ret targetor oTargetor Returns the targetor object.
	!]]
	__mul = function(vLeft, vRight)
		local oRet = 0;
		local sLeftType = type(vLeft);
		local sRightType = type(vRight);

		if (sLeftType == "targetor" and sRightType == "TARGET") then
			tTargetors[vLeft].targetables[vRight] = true;
			oRet = vLeft;
		elseif (sLeftType == "TARGET" and sRightType == "targetor") then
			tTargetors[vRight].targetables[vLeft] = true;
			oRet = vRight;
		else
			error("Error multiplying targetor with TARGET. One side must be of type 'targetor' and the other side of type 'TARGET';");
		end
--TODO Correct error text for each of these!!!!!!!!!!!!!!!
		return oRet;
	end,


	--[[!
	@module Targetor
	@func __sub
	@scope local
	@desc <p>Removes the given TARGET type from the object's 'targetors' table.</p>
	@ret targetor oTargetor Returns the targetor object.
	!]]
	__sub = function(vLeft, vRight)
		local oRet = 0;
		local sLeftType = type(vLeft);
		local sRightType = type(vRight);

		if (sLeftType == "targetor" and sRightType == "TARGET") then
			tTargetors[vLeft].targetors[vRight] = nil;
			oRet = vLeft;
		elseif (sLeftType == "TARGET" and sRightType == "targetor") then
			tTargetors[vRight].targetors[vLeft] = nil;
			oRet = vRight;
		else
			error("Error removing TARGET from targetor. One side must be of type 'targetor' and the other side of type 'TARGET';");
		end

		return oRet;
	end,

};

return targetor;
