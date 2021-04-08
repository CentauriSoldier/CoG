local tStacks = {};

class "stack" {

	 __construct = function(this)
		tStacks[this] = {};
	end,

	__len = function(this)--doesn't work in < Lua v5.2
		return table.maxn(tStacks[this]);
	end,

	pop = function(this)
		local vRet = nil;

		if (tStacks[this][1]) then
			vRet = table.remove(tStacks[this], 1);
		end

		return vRet;
	end,

	push = function(this, vValue)
		assert(type(vValue) ~= "nil", "Error pushing item.\r\nValue cannot be nil.");
		table.insert(tStacks[this], 1, vValue);
		return this;
	end,

	values = function(this)
		local tRet = {};

		for nIndex, vValue in pairs(tStacks[this]) do
			tRet[nIndex] = vValue;
		end

		return tRet;
	end,
}

return stack;
