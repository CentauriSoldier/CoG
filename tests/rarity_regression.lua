--[[!
@fqxn CoG.Tests.Rarity
@desc Verifies discovery, configuration validation, every rarity row, seeded random
    selection and enum persistence. Run in a fresh Lua 5.4 process:
    lua tests/rarity_regression.lua
    Optional modes: overlay, equal-chances, invalid-color, invalid-chance,
    invalid-duplicate, invalid-hole, invalid-tier, invalid-count.
!]]
local _sMode = ... or "defaults";
local _pTests = assert(debug.getinfo(1, "S").source:match("^@(.+)[/\\][^/\\]+$"));
local _pCoG = _pTests.."/..";
local _nChecks = 0;
local _loadfile = loadfile;

--[[!
@fqxn CoG.Tests.Rarity.check
@desc Counts a successful assertion or raises its failure description.
!]]
local function check(bCondition, sMessage)
    assert(bCondition, sMessage);
    _nChecks = _nChecks + 1;
end

package.path = _pCoG.."/?.lua;".._pCoG.."/../LuaEx/?.lua;"..package.path;
require("LuaEx.load")(3);
local _cRarity = class.getbyname("CoG.Rarity");
check(class.is(_cRarity) and Rarity == nil, "LuaEx must discover Rarity before its alias is published.");
check(lxe.isEnum(_cRarity.LEVEL), "Rarity enum must exist before CoG configuration.");

local _tOverlays = {
    overlay = [[return {Rarity = {
        COLOR = {[1] = "#123456"},
        CHANCE = CoGBase.purge({100, 30, 20, 10, 5, 2}),
    }};]],
    ["equal-chances"] = [[return {Rarity = {CHANCE = CoGBase.purge({100, 100, 0, 0, 0, 0})}};]],
    ["invalid-color"] = [[return {Rarity = {COLOR = {[1] = "red"}}};]],
    ["invalid-chance"] = [[return {Rarity = {CHANCE = {[1] = 99}}};]],
    ["invalid-duplicate"] = [[return {Rarity = {NAME = {[1] = "UNCOMMON"}}};]],
    ["invalid-hole"] = [[return {Rarity = {NAME = CoGBase.purge({[1] = "COMMON", [3] = "RARE"})}};]],
    ["invalid-tier"] = [[local eTier = require("cog.config.TIER");
        return {Rarity = {MAX_AFFIX_TIER = {[2] = eTier.VII}}};]],
    ["invalid-count"] = [[return {Rarity = {MIN_PREFIXES = {[1] = 9}}};]],
};
local _sOverlay = _tOverlays[_sMode];

if (_sOverlay) then
    -- Exercise the real assembler and overlay environment without writing a config.
    loadfile = function(pFile, sMode, tEnvironment)
        if (pFile:match("[/\\]RarityReviewConfig%.lua$")) then
            return load(_sOverlay, "@"..pFile, sMode, tEnvironment);
        end

        if (tEnvironment ~= nil) then
            return _loadfile(pFile, sMode, tEnvironment);
        end

        return _loadfile(pFile, sMode);
    end
end

local _bInitialized, _vResult = pcall(require("cog.load"), _sOverlay and 1 or 0, "RarityReviewConfig");
loadfile = _loadfile;

if (_sMode:match("^invalid")) then
    check(not _bInitialized, "Malformed rarity settings must fail during cog.load.");
    check(tostring(_vResult):find("Rarity config", 1, true) ~= nil,
        "Failure must identify the malformed rarity settings.");
    print("PASS Rarity (".._sMode.."): ".._nChecks.." checks.");
    return;
end

assert(_bInitialized, _vResult);
check(rawequal(Rarity, _cRarity), "The alias must be the discovered class.");
check(rawequal(require("cog.Rarity"), Rarity), "The require alias must retain identity.");
check(not pcall(function() return Rarity(); end), "The constructor must remain private.");
check(not pcall(function() return Rarity._tData; end), "Captured data must remain private.");
check(not pcall(function() Rarity.LEVEL = {}; end), "The level collection binding must be read-only.");
check(not pcall(function() Rarity.LEVEL.I = {}; end), "Enum members must be immutable.");
check(not pcall(function()
    lxc.loadSources({["ForbiddenRarityChild.lxc"] =
        "namespace RarityTests { class Child : CoG.Rarity {} }"}, _G);
end), "Rarity must remain final.");

local _tGetters = {
    getColor = "COLOR", getChance = "CHANCE",
    getMinAffixTier = "MIN_AFFIX_TIER", getMaxAffixTier = "MAX_AFFIX_TIER",
    getMinPrefixCount = "MIN_PREFIXES", getMaxPrefixCount = "MAX_PREFIXES",
    getMinSuffixCount = "MIN_SUFFIXES", getMaxSuffixCount = "MAX_SUFFIXES",
};

for nIndex, sName in ipairs(CoGBase.config.Rarity.NAME) do
    local eLevel = Rarity.LEVEL[nIndex];
    check(Rarity.getName(eLevel) == sName and eLevel.Ordinal == nIndex, "Level names and ordinals must match configuration.");

    for sMethod, sField in pairs(_tGetters) do
        check(Rarity[sMethod](eLevel) == CoGBase.config.Rarity[sField][nIndex],
            sMethod.." must return the selected configuration row.");
    end

    check(rawequal(deserialize(serialize(eLevel)), eLevel), "Enum save/load must retain the owned member identity.");
end

for sMethod in pairs(_tGetters) do
    check(not pcall(Rarity[sMethod], {}), sMethod.." must reject invalid levels.");
end

-- Compare both the chosen level and the next draw against the archived behavior.
for nSeed = 1, 40 do
    for _, nAdjustment in ipairs({-100, -7.5, 0, 3.5, 100}) do
        math.randomseed(nSeed, 19);
        local nExpectedRoll = RNG.percent() + nAdjustment;
        local nExpected = 1;
        for nLevel = #Rarity.LEVEL, 1, -1 do
            if (nExpectedRoll <= CoGBase.config.Rarity.CHANCE[nLevel]) then
                nExpected = nLevel;
                break;
            end
        end
        local nExpectedNext = math.random();
        math.randomseed(nSeed, 19);
        local eActual = Rarity.getRandom(nAdjustment);
        local nActualNext = math.random();
        check(eActual.Ordinal == nExpected, "Seeded rarity selection must retain its behavior.");
        check(nActualNext == nExpectedNext, "Rarity selection must retain random-stream consumption.");
    end
end

-- Cover every integer percentage boundary using the actual RNG, without a stub.
for nTarget = 0, 101 do
    math.randomseed(27, 4);
    local nRoll = RNG.percent();
    local nExpected = 1;

    for nIndex = #CoGBase.config.Rarity.NAME, 1, -1 do
        if (nTarget <= CoGBase.config.Rarity.CHANCE[nIndex]) then
            nExpected = nIndex;
            break;
        end
    end

    math.randomseed(27, 4);
    check(Rarity.getRandom(nTarget - nRoll).Ordinal == nExpected, "Threshold boundary selection must match.");
end

for _, vInvalid in ipairs({false, "0", math.huge, -math.huge, 0/0}) do
    check(not pcall(Rarity.getRandom, vInvalid), "Invalid adjustments must fail.");
end

if (_sMode == "overlay") then
    check(Rarity.getColor(Rarity.LEVEL.I) == "#123456", "The configured color must apply.");
elseif (_sMode == "equal-chances") then
    check(Rarity.getRandom() == Rarity.LEVEL.II, "Equal thresholds must allow zero-probability levels.");
end

check(rawequal(deserialize(serialize(Rarity)), Rarity), "Class references must retain save/load identity.");
print("PASS Rarity (".._sMode.."): ".._nChecks.." checks.");

