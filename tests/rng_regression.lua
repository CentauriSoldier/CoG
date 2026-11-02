--[[!
@fqxn CoG.Tests.RNG
@desc Verifies real LuaEx discovery and compares seeded results and random-stream
    consumption with the archived implementation. The old class factory is never
    loaded: a test-only collector reads its static function declarations.
    Run in a fresh Lua 5.4 process: lua tests/rng_regression.lua
!]]
local _pTests = assert(debug.getinfo(1, "S").source:match("^@(.+)[/\\][^/\\]+$"));
local _pCoG = _pTests.."/..";
local _nChecks = 0;

--[[!
@fqxn CoG.Tests.RNG.check
@desc Counts a successful assertion or raises the given failure description.
!]]
local function check(bCondition, sMessage)
    assert(bCondition, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn CoG.Tests.RNG.same
@desc Compares scalar values and nested result arrays, including packed nil slots.
!]]
local function same(vLeft, vRight)
    if (type(vLeft) ~= type(vRight)) then return false; end
    if (type(vLeft) ~= "table") then return vLeft == vRight; end

    for k, v in pairs(vLeft) do
        if (not same(v, vRight[k])) then return false; end
    end
    for k in pairs(vRight) do
        if (vLeft[k] == nil) then return false; end
    end

    return true;
end

package.path = _pCoG.."/?.lua;".._pCoG.."/../LuaEx/?.lua;"..package.path;
require("LuaEx.load")(3);
local _cRNG = class.getbyname("CoG.RNG");
check(class.is(_cRNG) and RNG == nil, "LuaEx must discover RNG before its alias is published.");
require("cog.load")();
check(rawequal(RNG, _cRNG), "The RNG alias must be the discovered class.");
check(rawequal(require("cog.RNG"), RNG), "The require alias must retain identity.");
check(not pcall(function() return RNG(); end), "RNG must retain its private constructor.");
check(not pcall(function() return RNG.validateFinite(1, "value"); end), "Helpers must be private.");

local _wBaseline = setmetatable({
    class = function(...) return table.pack(...); end,
}, {__index = _G});
local _loadBaseline = loadfile(_pCoG.."/legacy/cog/RNG.lua", "t", _wBaseline) or
    assert(loadfile(_pCoG.."/cog/RNG.lua", "t", _wBaseline));
local _tBaseline = _loadBaseline()[3];

local _tCases = { {"binary", table.pack()}, {"binary", table.pack(0)}, {"binary", table.pack(1)}, {"bipolar", table.pack()}, {"bipolar", table.pack(0.25)}, {"boolean", table.pack(0)}, {"boolean", table.pack(1)}, {"boolean", table.pack(0.75)}, {"choice", table.pack("A", "B")}, {"choice", table.pack(false, true, 1)}, {"multiChoice", table.pack("A", "B", "C")}, {"multiChoice", table.pack(false, true)}, {"percent", table.pack()}, {"percent", table.pack(true)}, {"pick", table.pack({[0] = "A", [8] = "B", ignored = "C"})}, {"pick", table.pack({"A", "B", "C"}, 3, false)}, {"pick", table.pack({"A", "B"}, 5, true)}, {"pick", table.pack({}, 0)}, {"randomx", table.pack()}, {"randomx", table.pack(10, 0.01)}, {"randomx", table.pack(10, 1)}, {"randomx", table.pack(5, 0.8)}, {"rollCheck", table.pack()}, {"rollCheck", table.pack(6, 0)}, {"rollCheck", table.pack(6, 7)}, {"rollDice", table.pack()}, {"rollDice", table.pack(12, 3, 4)}, {"rollPercentage", table.pack()}, {"rollPercentage", table.pack(0, 3)}, {"rollPercentage", table.pack(100, 3)}, {"rollPercentage", table.pack(12.5, 5)},
};

for _, tCase in ipairs(_tCases) do
    local sMethod, tArguments = tCase[1], tCase[2];

    for nSeed = 1, 8 do
        math.randomseed(nSeed, 31);
        local tExpected = table.pack(_tBaseline[sMethod](table.unpack(tArguments, 1, tArguments.n)));
        local nExpectedNext = math.random();
        math.randomseed(nSeed, 31);
        local tActual = table.pack(RNG[sMethod](table.unpack(tArguments, 1, tArguments.n)));
        local nActualNext = math.random();
        check(same(tActual, tExpected), sMethod.." changed its seeded result.");
        check(nActualNext == nExpectedNext, sMethod.." changed random-stream consumption.");
    end
end

local _tInvalid = { {"multiChoice", table.pack()}, {"multiChoice", table.pack("A", nil, "C")}, {"binary", table.pack(-0.1)}, {"bipolar", table.pack(1.1)}, {"boolean", table.pack(false)}, {"choice", table.pack("A", "B", math.huge)}, {"percent", table.pack(1)}, {"pick", table.pack({1}, 2, false)}, {"pick", table.pack({1}, -1)}, {"randomx", table.pack(11)}, {"randomx", table.pack(5, 0)}, {"rollCheck", table.pack(0)}, {"rollCheck", table.pack(6, 0/0)}, {"rollDice", table.pack(6, 1.5)}, {"rollDice", table.pack(6, 1, 0)}, {"rollPercentage", table.pack(-1)}, {"rollPercentage", table.pack(101)}, {"rollPercentage", table.pack(50, math.huge)},
};

for _, tCase in ipairs(_tInvalid) do
    local sMethod, tArguments = tCase[1], tCase[2];
    check(not pcall(RNG[sMethod], table.unpack(tArguments, 1, tArguments.n)),
        sMethod.." must retain invalid-input rejection.");
end

check(rawequal(deserialize(serialize(RNG)), RNG), "Class references must retain save/load identity.");
print("PASS RNG: ".._nChecks.." checks.");
