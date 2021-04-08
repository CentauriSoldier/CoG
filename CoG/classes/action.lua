local tActions = {};

class "action" {

	__construct = function(this, oCost, bRegen, oRegenAmount)
		tActions[this] = {
			cost 		= type(oCost)			== "protean" 	and oCost 			or protean(),
			regens		= type(bRegen) 			== "boolean"	and bRegen 			or false,
			regenAmount = type(oRegenAmount) 	== "protean" 	and oRegenAmount 	or protean(),
		};

	end,

	act = function(this)

	end,

	getCost = function(this)
		return tActions[this].cost;
	end,

	getRegenAmount = function(this)
		return tActions[this].regenAmount;
	end,

	regens = function(this)
		return tActions[this].regens;
	end,

	setRegens = function(this, bFlag)
		tActions[this].regens = type(bFlag) == "boolean" and bFlag or false;
		return this;
	end,
};
