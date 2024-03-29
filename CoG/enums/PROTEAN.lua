--legacy
--[[
local PROTEAN 					= enum.prep("PROTEAN");
PROTEAN.BASE 					= enum.prep("BASE", true);
PROTEAN.BASE.BONUS				= 0;
PROTEAN.BASE.PENALTY			= 1;
PROTEAN.MULTIPLICATIVE 			= enum.prep("MULTIPLICATIVE", true);
PROTEAN.MULTIPLICATIVE.BONUS	= 2;
PROTEAN.MULTIPLICATIVE.PENALTY	= 3;
PROTEAN.ADDATIVE 				= enum.prep("ADDATIVE", true);
PROTEAN.ADDATIVE.BONUS			= 4;
PROTEAN.ADDATIVE.PENALTY		= 5;
PROTEAN.VALUE 					= enum.prep("VALUE", true);
PROTEAN.VALUE.BASE 				= 6;
PROTEAN.VALUE.FINAL				= 7;
PROTEAN.LIMIT 					= enum.prep("LIMIT", true);
PROTEAN.LIMIT.MIN				= 8;
PROTEAN.LIMIT.MAX				= 9;

--finalize the enum
PROTEAN();
]]
