local tQueues = {};

class "queue" {

	 __construct = function(this)
		tQueues[this] = {};
	end,


	__len = function(this)--doesn't work in < Lua v5.2
		return table.maxn(tQueues[this]);
	end,


	enqueue = function(this, vValue)
		assert(type(vValue) ~= "nil", "Error enqueueing item.\r\nValue cannot be nil.");
		table.insert(tQueues[this], 1, vValue);
		return vValue;
	end,


	dequeue = function(this)
		local vRet = nil;
		local nIndex = table.maxn(tQueues[this]);

		if (nIndex > 0) then
			vRet = table.remove(tQueues[this], nIndex);
		end

		return vRet;
	end,


	size = function(this)
		return table.maxn(tQueues[this]);
	end,


	values = function(this)
		local tRet = {};

		for nIndex, vValue in pairs(tQueues[this]) do
			tRet[nIndex] = vValue;
		end

		return tRet;
	end,
}
