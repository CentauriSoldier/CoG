-- Checks native SlotPattern against the archived geometry algorithms.
local pTests = assert(debug.getinfo(1, "S").source:match("^@(.+)[/\\][^/\\]+$"));
local pCoG = pTests.."/..";
package.path = pCoG.."/?.lua;"..pCoG.."/../LuaEx/?.lua;"..package.path;
require("LuaEx.load")(3);
local Pattern = CoG.SlotPattern;
local nChecks = 0;
local function check(bCondition, sMessage)
    assert(bCondition, sMessage);
    nChecks = nChecks + 1;
end
local function equal(a, b)
    if (rawequal(a, b)) then return true; end
    if (rawtype(a) ~= "table" or rawtype(b) ~= "table") then return false; end
    for k, v in pairs(a) do if (not equal(v, b[k])) then return false; end end
    for k in pairs(b) do if (a[k] == nil) then return false; end end
    return true;
end
local function reject(fAction, sFragment)
    local bOK, vError = pcall(fAction);
    check(not bOK and (not sFragment or tostring(vError):find(sFragment, 1, true)),
        "Expected rejection "..tostring(sFragment)..", got "..tostring(vError));
end

-- Supply only the old class factory's method binding. Geometry and validation
-- bodies execute unchanged, without loading the retired class implementation.
local tEnvironment = setmetatable({}, {__index = _G});
tEnvironment.class = function(sName, tMeta, tStatic, tPrivate, tProtected, tPublic)
    return function(tSlots)
        local tData = {pri = {slots = {}}};
        local oPattern = {};
        for sMethod, fMethod in pairs(tPublic) do
            if (sMethod ~= sName) then
                oPattern[sMethod] = function(...) return fMethod(oPattern, tData, ...); end;
            end
        end
        setmetatable(oPattern, {__len = function() return tMeta.__len(oPattern, tData); end});
        tPublic[sName](oPattern, tData, tSlots);
        return oPattern;
    end;
end
local Reference = assert(loadfile(pCoG.."/legacy/cog/Objects/ItemSystem/SlotPattern.lua", "t", tEnvironment))();
check(class.is(Pattern) and class.getname(Pattern) == "CoG.SlotPattern", "native discovery");
require("cog.load")();
check(rawget(_G, "SlotPattern") == nil, "no loader alias");
local oEmpty = Pattern();
check(#oEmpty == 0 and oEmpty.getSlotCount() == 0 and oEmpty.getBounds() == nil, "empty layout");
check(next(oEmpty.getSlots()) == nil and oEmpty.eachSlot()() == nil, "empty copies and iterator");
check(not oEmpty.contains(0, 0), "empty membership");
reject(function() return oEmpty.slots; end, "private");
reject(function() return Pattern.copySlots; end, "private");

local function compare(tSlots)
    local oNative, oOld = Pattern(tSlots), Reference(tSlots);
    check(equal(oNative.getSlots(), oOld.getSlots()), "copied geometry matches archive");
    check(#oNative == #oOld and oNative.getSlotCount() == oOld.getSlotCount(), "occupied count matches archive");
    check(equal(oNative.getBounds(), oOld.getBounds()), "bounds match archive");
    local fNative, fOld = oNative.eachSlot(), oOld.eachSlot();
    for nIndex = 1, #tSlots + 2 do
        local i, x, y = fNative(); local j, a, b = fOld();
        check(i == j and x == a and y == b, "iteration order and exhaustion match archive");
    end
    for nX = -3, 3 do
        for nY = -3, 3 do
            check(oNative.contains(nX, nY) == oOld.contains(nX, nY), "membership matches archive");
        end
    end
    return oNative;
end
compare({});
compare({{x = 0, y = 0}, {x = 0, y = 1}, {x = 1, y = 1}});
compare({{x = -8, y = -9}, {x = -6, y = -4}});
compare({{x = 10, y = 20}, {x = 11, y = 22}});
for nCase = 1, 120 do
    local tSlots = {};
    for nIndex = 1, nCase % 13 do
        tSlots[nIndex] = {x = nIndex - nCase % 8, y = (nIndex * nCase) % 19 - 9};
    end
    compare(tSlots);
end

local tSource = {{x = 1, y = 2}, {x = -3, y = 4}};
local oPattern = Pattern(tSource);
tSource[1].x = 99;
check(oPattern.contains(1, 2) and not oPattern.contains(99, 2), "constructor copies input");
local tOutput = oPattern.getSlots(); tOutput[1].x = 55; tOutput[2] = nil;
check(oPattern.contains(1, 2) and #oPattern == 2, "getter copies records and list");
local fSnapshot = oPattern.eachSlot();
local tReplacement = {{x = -10, y = 20}};
check(rawequal(oPattern.setSlots(tReplacement), oPattern), "setter remains chainable");
tReplacement[1].x = 100;
check(oPattern.contains(-10, 20), "setter copies input");
local i, x, y = fSnapshot();
check(i == 1 and x == 1 and y == 2, "iterator snapshots survive replacement");
i, x, y = fSnapshot();
check(i == 2 and x == -3 and y == 4 and fSnapshot() == nil, "snapshot retains original order");
local tBounds = oPattern.getBounds(); tBounds.width = 99;
check(oPattern.getBounds().width == 1, "bounds are independent");

local tInvalid = {
    false, 4, "bad", {{x = 0}}, {{y = 0}}, {{x = 0, y = 0, z = 0}},
    {{x = 0.5, y = 0}}, {{x = 0, y = math.huge}}, {{x = 0/0, y = 0}},
    {{x = -math.huge, y = 0}}, {{x = "1", y = 0}}, {false},
    {[0] = {x = 0, y = 0}}, {[1.5] = {x = 0, y = 0}},
    {[2] = {x = 0, y = 0}}, {bad = {x = 0, y = 0}},
    {{x = 0, y = 0}, {x = 0, y = 0}},
    {[1] = {x = 0, y = 0}, [3] = {x = 1, y = 1}},
};
for _, vInput in ipairs(tInvalid) do
    local bNative = pcall(Pattern, vInput);
    local bOld = pcall(Reference, vInput);
    check(not bNative and bNative == bOld, "constructor rejection matches archive");
    local tBefore = oPattern.getSlots();
    reject(function() oPattern.setSlots(vInput); end);
    check(equal(oPattern.getSlots(), tBefore), "invalid setter is atomic");
end
reject(function() oPattern.setSlots(nil); end, "requires a table");
for _, nInvalid in ipairs({false, "0", 0.5, math.huge, -math.huge, 0/0}) do
    reject(function() oPattern.contains(nInvalid, 0); end, "finite integers");
    reject(function() oPattern.contains(0, nInvalid); end, "finite integers");
end
reject(function() oPattern.contains(nil, 0); end, "finite integers");
check(oPattern.setSlots({}).getBounds() == nil and #oPattern == 0, "clear with empty layout");
oPattern.setSlots({{x = -2, y = 3}, {x = 4, y = 5}});
local oCopy = clone(oPattern);
check(not rawequal(oCopy, oPattern) and class.isa(oCopy, Pattern), "native clone identity and class");
check(equal(oCopy.getSlots(), oPattern.getSlots()), "native clone geometry");
oCopy.setSlots({{x = 99, y = 88}});
check(oPattern.contains(-2, 3) and not oPattern.contains(99, 88), "clone storage is independent");
local tGraph = {first = oPattern, alias = oPattern}; tGraph.self = tGraph;
local tLoaded = deserialize(serialize(tGraph));
check(rawequal(tLoaded.first, tLoaded.alias) and rawequal(tLoaded.self, tLoaded), "graph aliases and cycles");
check(equal(tLoaded.first.getSlots(), oPattern.getSlots()), "restored geometry");
tLoaded.first.setSlots({});
check(#oPattern == 2, "restored storage is independent");
check(#deserialize(serialize(Pattern())) == 0, "empty persistence");
check(rawequal(clone(Pattern), Pattern) and rawequal(deserialize(serialize(Pattern)), Pattern), "class references stay canonical");

local Serializer = require("LuaEx.lib.serializer");
local function forgedSnapshot(vSlots)
    local oMarker = {};
    local tAdapter = {
        project = function(vValue)
            if (rawequal(vValue, oMarker)) then
                return {Kind = "instance", Class = "CoG.SlotPattern", Fields = {
                    ["CoG.SlotPattern:slots"] = {Index = 1, Type = "table", ClassType = false, Locked = false},
                }}, {vSlots};
            end
        end,
        checkFunction = function() end, checkGraph = function() end,
        allocate = function() error("Encoding cannot allocate instances."); end,
        finish = function() error("Encoding cannot restore instances."); end,
    };
    return "--LXC:3\n"..Serializer.serializeStaged(oMarker, tAdapter);
end
for _, tSlots in ipairs({
    {{x = 0.5, y = 0}}, {{x = 0}}, {{x = 0, y = 0, extra = 1}},
    {{x = 1, y = 1}, {x = 1, y = 1}}, {[2] = {x = 0, y = 0}},
}) do
    reject(function() deserialize(forgedSnapshot(tSlots)); end);
end
check(deserialize(forgedSnapshot({{x = -5, y = 8}})).contains(-5, 8), "valid native field projection");
check(#deserialize(serialize(oPattern)) == 2, "valid restores still work after failures");
local LXC = require("LuaEx.lib.lxc");
LXC.loadSources({["SlotPatternTest.lxc"] = [=[namespace SlotPatternTest {
    class Derived : CoG.SlotPattern {
        private label = "derived";
        public Derived(slots) { base(slots); }
        public getLabel() { return this.label; }
    }
}]=]}, _G);
local oDerived = SlotPatternTest.Derived({{x = 2, y = 3}});
local oDerivedCopy = clone(oDerived);
check(class.isinstanceof(oDerivedCopy, SlotPatternTest.Derived) and oDerivedCopy.getLabel() == "derived", "native clone preserves concrete subclass fields");
check(oDerivedCopy.contains(2, 3) and #oDerivedCopy == 1, "inherited geometry and length survive cloning");
local oDerivedLoaded = deserialize(serialize(oDerived));
check(class.isinstanceof(oDerivedLoaded, SlotPatternTest.Derived) and oDerivedLoaded.contains(2, 3), "derived persistence");
print("PASS SlotPattern: "..nChecks.." checks.");
