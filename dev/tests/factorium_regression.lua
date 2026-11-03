-- Native Factorium and archived-algorithm parity checks. Run defaults, logging or archive.
local sMode = ... or "defaults";
assert(sMode == "defaults" or sMode == "logging" or sMode == "archive", "Unknown Factorium test mode.");
local pTests = assert(debug.getinfo(1, "S").source:match("^@(.+)[/\\][^/\\]+$"));
local pCoG = pTests.."/..";
package.path = pCoG.."/?.lua;"..pCoG.."/../LuaEx/?.lua;"..package.path;
require("LuaEx.load")(sMode == "logging" and 4 or 3);
local nChecks = 0;
local function check(bCondition, sMessage)
    assert(bCondition, sMessage);
    nChecks = nChecks + 1;
    return bCondition;
end
local LXC = require("LuaEx.lib.lxc");
LXC.loadSources({["FactoriumTest.lxc"] = [=[
namespace FactoriumTest {
    class Creature : CoG.CoGBase { public Creature() {} }
    class Dragon : Creature { public Dragon() {} }
    class Mod : CoG.BaseMod { public Mod(info) { base(info); } }
}
]=]}, _G);
local Factorium = CoG.Factorium;
local function fixture(sName, cParent, tContract)
    local cClass = class.getbyname(sName);
    return cClass;
end
local register = Factorium.registerClass;
if (sMode == "archive") then
    -- Adapt only legacy class reflection to native fixture identities. The
    -- archived repository algorithms and their public methods remain unchanged.
    local tProxies, tOriginals = {}, {};
    local Root = setmetatable({}, {});
    tProxies[CoG.CoGBase], tOriginals[Root] = Root, CoG.CoGBase;
    local function original(v) return tOriginals[v] or v; end
    local function proxy(c) return tProxies[c] or c; end
    fixture = function(sName, cParent, tContract)
        local cClass = class.getbyname(sName);
        local cProxy = setmetatable(tContract, {});
        tProxies[cClass], tOriginals[cProxy] = cProxy, cClass;
        return cProxy;
    end
    local tClass = setmetatable({
        is = function(v) return class.is(original(v)); end,
        isinstance = class.isinstance,
        ischildorself = function(v, p)
            v, p = original(v), original(p);
            return v == p or class.ischild(v, p);
        end,
        getname = function(v) return class.getname(original(v)); end,
        getparentname = function(v) return class.getparentname(original(v)); end,
        getbyname = function(sName) return proxy(class.getbyname(sName)); end,
        haspublicmember = function(v, sName)
            local t = tOriginals[v] and v;
            local member = t and rawget(t, sName);
            return member ~= nil, true, rawtype(member);
        end,
    }, {__call = function(_, sName, _, tPublic) return tPublic; end});
    local tEnvironment = setmetatable({class = tClass, CoG = Root, BaseMod = CoG.BaseMod}, {__index = _G});
    Factorium = assert(loadfile(pCoG.."/legacy/cog/ModSystem/Factorium.lua", "t", tEnvironment))();
    register = function(cClass) return Factorium.registerClass(cClass); end;
end
local fOpen, tLogWrites = io.open, {};
if (sMode == "logging") then
    io.open = function(pFile, sAccess, ...)
        if (pFile == "Factorium.log") then
            check(sAccess == "a", "default logger appends");
            return {close = function() end, write = function(_, sText)
                tLogWrites[#tLogWrites + 1] = sText;
            end};
        end
        return fOpen(pFile, sAccess, ...);
    end;
end
local function temporaryPath()
    local pFile = os.tmpname();
    if (pFile:sub(1, 1) == "\\" and os.getenv("TEMP")) then
        return os.getenv("TEMP")..pFile;
    end
    return pFile;
end
local pMod = temporaryPath();
local pFailure = temporaryPath();
local pMissing = pMod..".missing";
local tMessages = {};
Factorium.setLog(function(sMessage)
    tMessages[#tMessages + 1] = sMessage;
end);

local nFactories = 0;
local nParentChecks = 0;
local nChildChecks = 0;

local CreatureContract = {
    Blueprint = {
        health = 100,
        stats = { armor = 0, speed = 10 },
        slots = { "first", "second" },
    },
    validateBlueprint = function(bp)
        nParentChecks = nParentChecks + 1;

        if (rawtype(bp.health) ~= "number" or bp.health <= 0) then
            return false, "health must be positive";
        end

        return true;
    end,
    fromBlueprint = function(bp)
        nFactories = nFactories + 1;
        return bp;
    end,
};
local Creature = fixture("FactoriumTest.Creature", CoG.CoGBase, CreatureContract);

local DragonContract = {
    Blueprint = { health = 500, stats = { armor = 20 }, element = "fire" },
    validateBlueprint = function(bp)
        nChildChecks = nChildChecks + 1;

        if (bp.explode) then
            error("deliberate validator failure");
        end

        return bp.element == "fire" or bp.element == "ice", "invalid element";
    end,
    fromBlueprint = function(bp)
        nFactories = nFactories + 1;
        return bp;
    end,
};
local Dragon = fixture("FactoriumTest.Dragon", Creature, DragonContract);

check(register(Creature, CreatureContract));
check(register(Dragon, DragonContract));
check(register(Dragon, DragonContract));
check(not register(CoG.BaseMod, {}));
check(not register(nil, {}));

local function mod(nID, tBlueprints, tRequired, tConflicts)
    return {
        id = string.format("10000000-0000-4000-8000-%012d", nID),
        name = "Test mod "..nID,
        authors = { "Tester" },
        description = "Factorium regression fixture",
        released = "2026-10-13",
        updated = "2026-10-13",
        version = 1,
        required = tRequired or {},
        conflicts = tConflicts or {},
        blueprints = tBlueprints or {},
    };
end

local function bp(sID, nHealth)
    return { id = sID, class = "FactoriumTest.Dragon", health = nHealth };
end

local tCycle = bp("cycle", 10);
tCycle.loop = tCycle;
local tKeyCycle = bp("key-cycle", 10);
local tBadKey = {};
tBadKey[tBadKey] = "loop";
tKeyCycle[tBadKey] = true;
local tInvalidKey = bp("invalid-key", 10);
tInvalidKey[true] = "bad";
local tClassLeak = bp("class-leak", 10);
tClassLeak.hidden = Dragon;
local fRoll = function() return 7; end;
local tSource = bp("dragon", nil);
tSource.stats = { speed = 15 };
tSource.slots = { "override" };
tSource.enabled = false;
tSource.weight = 0;
tSource.extra = "retained";
tSource.roll = fRoll;
local tShared = { value = 8 };
tSource.left = tShared;
tSource.right = tShared;
tSource[{ tag = "table-key" }] = { value = 9 };

local tBob = mod(1, {
    tSource,
    { id = "creature", class = "FactoriumTest.Creature" },
    bp("bad-health", -1),
    { id = "bad-element", class = "FactoriumTest.Dragon", element = "water" },
    { id = "explode", class = "FactoriumTest.Dragon", explode = true },
    { id = "unknown", class = "UnknownClass" },
    tCycle, tKeyCycle, tInvalidKey, tClassLeak,
    bp("last-good", 50),
});

local bImported, tCounts = Factorium.importMod(tBob);
check(bImported and tCounts.loaded == 3 and tCounts.skipped == 8);
check(Factorium.getBlueprint(Dragon, "dragon") == nil);
Factorium.finalizeImports();
local tCompiled, sModID = Factorium.getBlueprint(Dragon, "dragon");
check(tCompiled.health == 500 and tCompiled.stats.armor == 20 and tCompiled.stats.speed == 15);
check(tCompiled.slots[1] == "override" and tCompiled.slots[2] == "second");
check(tCompiled.enabled == false and tCompiled.weight == 0 and tCompiled.extra == "retained");
check(tCompiled.roll == fRoll and tCompiled.roll() == 7);
check(sModID == tBob.id and nFactories == 0);
check(nParentChecks > 0 and nChildChecks > 0);
check(Factorium.getBlueprint(Creature, "dragon") == nil);
check(Factorium.getBlueprints(Creature).dragon == nil);
check(Factorium.getBlueprints(Dragon).dragon.class == nil);
tCompiled.stats.armor = 999;
tSource.stats.speed = 999;
check(Factorium.getBlueprint(Dragon, "dragon").stats.armor == 20);
check(Factorium.getBlueprint(Dragon, "dragon").stats.speed == 15);
check(CreatureContract.Blueprint.stats.armor == 0 and DragonContract.Blueprint.stats.armor == 20);

-- Ed's valid override wins. Bad replacements do not erase the old winner.
local tEd = mod(2, { bp("dragon", 900), bp("new-dragon", 400) }, { tBob.id });
check(Factorium.importMod(tEd));
Factorium.finalizeImports();
check(Factorium.getBlueprint(Dragon, "dragon").health == 900);
check(Factorium.setModActive(tEd.id, false));
Factorium.finalizeImports();
check(Factorium.getBlueprint(Dragon, "dragon").health == 500);
check(Factorium.setModActive(tEd.id, true));
Factorium.finalizeImports();
check(Factorium.getBlueprint(Dragon, "dragon").health == 900);
check(Factorium.replaceMod(mod(2, { bp("dragon", -2) }, { tBob.id })));
Factorium.finalizeImports();
check(Factorium.getBlueprint(Dragon, "dragon").health == 900);
check(Factorium.getBlueprint(Dragon, "new-dragon") == nil);

-- A globally duplicated ID may move to a different class, with no stale index.
check(Factorium.importMod(mod(3, { { id = "dragon", class = "FactoriumTest.Creature" } })));
Factorium.finalizeImports();
check(Factorium.getBlueprint(Dragon, "dragon") == nil);
check(Factorium.getBlueprint(Creature, "dragon").health == 100);
check(Factorium.removeMod(mod(3).id));
Factorium.finalizeImports();
check(Factorium.getBlueprint(Dragon, "dragon").health == 900);
check(Factorium.removeMod(tBob.id));
Factorium.finalizeImports();
check(not Factorium.getModStatus(tEd.id).accepted);
check(Factorium.getBlueprint(Dragon, "dragon") == nil);

-- Rejected early mods do not reserve conflicts. One-sided declarations count.
local tMissing = mod(90).id;
local tEarly = mod(10, { bp("conflict", 10) }, { tMissing }, { mod(11).id });
local tLater = mod(11, { bp("conflict", 11) });
check(Factorium.importMod(tEarly));
check(Factorium.importMod(tLater));
Factorium.finalizeImports();
check(Factorium.getModStatus(tLater.id).accepted);
check(Factorium.getBlueprint(Dragon, "conflict").health == 11);
check(Factorium.replaceMod(mod(10, { bp("conflict", 10) }, {}, { tLater.id })));
Factorium.finalizeImports();
check(Factorium.getModStatus(tEarly.id).accepted);
check(not Factorium.getModStatus(tLater.id).accepted);
check(Factorium.getBlueprint(Dragon, "conflict").health == 10);
check(Factorium.removeMod(tEarly.id));
Factorium.finalizeImports();
check(Factorium.getModStatus(tLater.id).accepted);

-- An accepted early mod losing a dependency releases its conflict claim.
local tA = mod(20, {}, { mod(22).id }, { mod(23).id });
local tB = mod(21, {}, {}, { mod(22).id });
local tC = mod(22);
local tD = mod(23);
for _, tMod in ipairs({ tA, tB, tC, tD }) do
    check(Factorium.importMod(tMod));
end
Factorium.finalizeImports();
check(not Factorium.getModStatus(tA.id).accepted);
check(Factorium.getModStatus(tB.id).accepted);
check(not Factorium.getModStatus(tC.id).accepted);
check(Factorium.getModStatus(tD.id).accepted);

-- Loading uses the configured environment and does not execute until runMods.
local tEnv = { marker = 321 };
check(Factorium.setEnvironment(tEnv));
local hFile = check(io.open(pMod, "w"));
hFile:write([[return {
    id = "10000000-0000-4000-8000-000000000030",
    name = "Environment test", authors = { "Tester" }, description = "Test",
    released = "2026-10-13", updated = "2026-10-13", version = 1,
    blueprints = { { id = "environment", class = "FactoriumTest.Dragon",
                    health = marker, callback = function() return marker end } }
}]]);
hFile:close();
check(Factorium.loadMod(pMod));
check(Factorium.getModStatus(mod(30).id) == nil);
check(Factorium.setEnvironment({ marker = 999 }));
local tRun = Factorium.runMods();
check(tRun.loaded == 1 and tRun.skipped == 0);
Factorium.finalizeImports();
local tEnvironmentBP = Factorium.getBlueprint(Dragon, "environment");
check(tEnvironmentBP.health == 321 and tEnvironmentBP.callback() == 321);
check(#tMessages > 0 and #Factorium.getWarnings() == #tMessages);

-- The default logger uses BaseLog; a bad logger cannot stop later imports.
check(Factorium.setLog(nil));
check(not Factorium.importMod({ name = "invalid metadata" }));
check(#Factorium.getWarnings() > 0);
check(Factorium.setLog(function() error("logger failed") end));
check(not Factorium.importMod({}));
check(Factorium.importMod(mod(31, { bp("after-logger-failure", 31) })));
Factorium.finalizeImports();
check(Factorium.getBlueprint(Dragon, "after-logger-failure").health == 31);

-- The fallback environment is valid. Runtime failures skip only that file.
check(Factorium.setEnvironment({}));
local hFailure = check(io.open(pFailure, "w"));
hFailure:write("return unavailable_global()");
hFailure:close();
check(Factorium.loadMod(pFailure));
check(Factorium.runMods().skipped == 1);
check(not Factorium.loadMod(pMissing));

-- BaseMod subclasses carry conflicts, dependencies and raw definitions.
local ModClass = FactoriumTest.Mod;
local tModInfo = mod(32, { bp("mod-object", 32) }, { mod(31).id });
tModInfo.conflicts = { mod(90).id };
local oMod = ModClass(tModInfo);
check(oMod.getInfo().conflicts[1] == mod(90).id);
check(Factorium.importMod(oMod));
Factorium.finalizeImports();
check(Factorium.getBlueprint(Dragon, "mod-object").health == 32);

-- Table keys use identity while being copied out of the private repository.
local tIdentityKey = { tag = "identity" };
DragonContract.Blueprint[tIdentityKey] = { first = 1, second = 2 };
local tKeyedBP = bp("keyed", 40);
tKeyedBP[tIdentityKey] = { first = 9 };
check(Factorium.importMod(mod(40, { tKeyedBP })));
Factorium.finalizeImports();
local tKeyedResult = Factorium.getBlueprint(Dragon, "keyed");
local bFound = false;

for vKey, vValue in pairs(tKeyedResult) do
    if (rawtype(vKey) == "table" and vKey.tag == "identity") then
        check(vKey ~= tIdentityKey);
        check(vValue.first == 9 and vValue.second == 2);
        bFound = true;
    end
end

check(bFound);


-- Replay the same catalog changes against native and archived algorithms.
-- The runner compares this fingerprint across both modes.
local nDigest = 0;
local function digest(sValue)
    for nIndex = 1, #sValue do
        nDigest = (nDigest * 33 + sValue:byte(nIndex)) % 2147483647;
    end
end
for nStep = 1, 240 do
    local nID = 100 + (nStep * 7) % 19;
    local nAction = nStep % 6;
    if (nAction < 3) then
        local tRequired = nStep % 4 == 0 and {mod(100 + (nID + 3) % 19).id} or {};
        local tConflicts = nStep % 5 == 0 and {mod(100 + (nID + 9) % 19).id} or {};
        check(Factorium.importMod(mod(nID, {bp("replay-"..nID % 5,
            nStep % 11 == 0 and -1 or nStep)}, tRequired, tConflicts)));
    elseif (nAction == 3) then
        Factorium.setModActive(mod(nID).id, nStep % 2 == 0);
    elseif (nAction == 4) then
        Factorium.removeMod(mod(nID).id);
    else
        check(not Factorium.replaceMod({id = mod(nID).id, name = "invalid"}));
    end
    local tReport = Factorium.finalizeImports();
    digest(tReport.accepted..":"..tReport.rejected..";");
    for nMod = 100, 118 do
        local tStatus = Factorium.getModStatus(mod(nMod).id);
        digest(tStatus and (tostring(tStatus.active)..tostring(tStatus.accepted)
            ..tostring(tStatus.pending)..tostring(tStatus.reason)) or "missing");
    end
    for nBP = 0, 4 do
        local tBP, sID = Factorium.getBlueprint(Dragon, "replay-"..nBP);
        digest(tBP and (tBP.id..":"..tBP.health..":"..sID) or "missing");
    end
end
print("PARITY Factorium: "..nDigest);

if (sMode ~= "archive") then
    require("cog.load")();
    check(rawget(_G, "Factorium") == nil, "CoG startup adds no short alias");
    check(class.is(Factorium) and class.getname(Factorium) == "CoG.Factorium", "native discovery");
    check(not pcall(Factorium), "constructor remains private");
    check(not pcall(function() return Factorium._tRepository; end), "repository remains private");
    local tWarn = Factorium.getWarnings();
    local nWarnings = #tWarn;
    tWarn[1] = "changed";
    check(Factorium.getWarnings()[1] ~= "changed", "warning snapshots are independent");
    local nLogged = 0;
    check(Factorium.setLog(function()
        nLogged = nLogged + 1;
        check(not pcall(function() return Factorium._tRepository; end), "callback cannot borrow private access");
    end));
    check(not Factorium.setLog({}));
    check(not Factorium.importMod({}));
    check(nLogged == 2, "invalid logger preserves the previous callback");
    check(#Factorium.getWarnings() == nWarnings + 2);

    LXC.loadSources({["FactoriumLayers.lxc"] = [=[namespace FactoriumLayers {
        class Parent : CoG.CoGBase { public Parent() {} }
        class Middle : Parent { public Middle() {} }
        class Child : Middle { public Child() {} }
        class Invalid : CoG.CoGBase { public Invalid() {} }
        class Corrupt : CoG.CoGBase { public Corrupt() {} }
    }]=]}, _G);
    local tOrder = {};
    local nCalled = 0;
    local fFactory = function() nCalled = nCalled + 1; end;
    local tParent = {Blueprint = {nested = {parent = 1}, health = 100},
        validateBlueprint = function(bp)
            tOrder[#tOrder + 1] = "parent";
            bp.nested.parent = 999;
            return bp.health > 0, "parent constraint";
        end, fromBlueprint = fFactory};
    local tChild = {Blueprint = {nested = {child = 2}, health = 200},
        validateBlueprint = function(bp)
            tOrder[#tOrder + 1] = "child";
            return bp.nested.parent == 1, "parent mutation leaked";
        end, fromBlueprint = fFactory};
    check(Factorium.registerClass(FactoriumLayers.Child, tChild));
    check(Factorium.registerClass(FactoriumLayers.Parent, tParent));
    check(Factorium.registerClass(FactoriumLayers.Child), "successful registration is cached");
    check(nCalled == 0 and #tOrder == 0, "registration invokes neither validators nor factories");
    check(not Factorium.registerClass(FactoriumLayers.Invalid, {}));
    check(not Factorium.registerClass(FactoriumLayers.Invalid, tChild), "failed registration is cached");
    local tCycle = {}; tCycle.loop = tCycle;
    check(not Factorium.registerClass(FactoriumLayers.Corrupt,
        {Blueprint = tCycle, validateBlueprint = function() return true; end, fromBlueprint = fFactory}));
    check(not Factorium.isClassRegistered(FactoriumLayers.Invalid));
    check(not Factorium.isClassRegistered(FactoriumLayers.Middle));
    local tLayerMod = mod(500, {{id = "layered", class = "FactoriumLayers.Child"}});
    local bImported, tReport = Factorium.importMod(tLayerMod);
    check(bImported and tReport.loaded == 1 and tReport.skipped == 0);
    check(Factorium.getBlueprints(FactoriumLayers.Child) == nil, "pending queries are blocked");
    Factorium.finalizeImports();
    local tResult = Factorium.getBlueprint(FactoriumLayers.Child, "layered");
    check(tResult.health == 200 and tResult.nested.parent == 1 and tResult.nested.child == 2);
    check(table.concat(tOrder, ",") == "parent,child", "ancestry order survives late parent registration and empty intermediate class");
    check(nCalled == 0, "import never constructs objects");
    tParent.Blueprint.nested.added = 4;
    tChild.validateBlueprint = function() error("replacement should not be discovered"); end;
    -- Cached validator identity is retained, while mutable default contents are reread.
    tChild.Blueprint.health = 350;
    check(Factorium.replaceMod(tLayerMod));
    Factorium.finalizeImports();
    check(Factorium.getBlueprint(FactoriumLayers.Child, "layered").health == 350
        and Factorium.getBlueprint(FactoriumLayers.Child, "layered").nested.added == 4);
    tChild.Blueprint.loop = tChild.Blueprint;
    bImported, tReport = Factorium.replaceMod(tLayerMod);
    check(bImported and tReport.skipped == 1 and tReport.loaded == 1);
    Factorium.finalizeImports();
    check(Factorium.getBlueprint(FactoriumLayers.Child, "layered").health == 350,
        "corrupted defaults reject replacements without erasing history");
    tChild.Blueprint.loop = nil;

    tOrder = {};
    check(Factorium.registerClass(CoG.CoGBase, {
        Blueprint = {root = true},
        validateBlueprint = function(bp)
            tOrder[#tOrder + 1] = "root";
            return bp.root == true;
        end,
        fromBlueprint = fFactory,
    }));
    tOrder = {};
    check(Factorium.importMod(mod(501, {{id = "rooted", class = "FactoriumLayers.Child"}})));
    Factorium.finalizeImports();
    check(Factorium.getBlueprint(FactoriumLayers.Child, "rooted").root == true);
    check(table.concat(tOrder, ",") == "root,parent,child", "root contributes first even when registered last");

    if (sMode == "logging") then
        check(#tLogWrites > 0 and tLogWrites[1]:find("WARNING", 1, true), "actual native default logger writes a warning");
        local BaseLogClass = class.getbyname("LuaEx.Classes.BaseLog");
        local tObjectLog = {};
        check(Factorium.setLog({log = function(sMessage, eLevel)
            tObjectLog[#tObjectLog + 1] = {sMessage, eLevel};
        end}));
        check(not Factorium.importMod({}));
        check(#tObjectLog == 1 and rawequal(tObjectLog[1][2], BaseLogClass.LEVEL.WARNING), "object logger receives native warning level");
        FactoriumTest.Mod({});
        check(#tObjectLog == 2, "BaseMod shares the selected logging destination");
    end
end

io.open = fOpen;
os.remove(pMod);
os.remove(pFailure);
print("PASS Factorium "..sMode..": "..nChecks.." checks");
