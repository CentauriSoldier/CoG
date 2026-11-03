--[[!
@fqxn CoG.Tests.BaseMod
@desc Checks native discovery, archived metadata validation, protected construction,
    nullable read-only fields, logging and native persistence. Run under Lua 5.4;
    optional argument logging enables the actual utility-class logger in memory.
!]]
local _sMode = ... or "defaults";
local _pTests = assert(debug.getinfo(1, "S").source:match("^@(.+)[/\\][^/\\]+$"));
local _pCoG = _pTests.."/..";
local _nChecks = 0;

--[[!
@fqxn CoG.Tests.BaseMod.check
@desc Counts a successful observable assertion.
!]]
local function check(bCondition, sMessage)
    assert(bCondition, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn CoG.Tests.BaseMod.reject
@desc Requires failure, optionally matching a diagnostic fragment.
!]]
local function reject(fAction, sFragment)
    local bOK, vError = pcall(fAction);
    check(not bOK and (not sFragment or tostring(vError):find(sFragment, 1, true)),
        "Expected rejection "..tostring(sFragment).."; got "..tostring(vError));
end

--[[!
@fqxn CoG.Tests.BaseMod.metadata
@desc Produces independent valid metadata with intentionally mixed-case UUIDs.
!]]
local function metadata()
    return {
        id = "ABCDEF00-1234-4000-8000-000000000001",
        name = "Metadata test",
        authors = {"Bob", "Ed"},
        description = "Tests complete mod metadata initialization.",
        released = "2024-02-29",
        updated = "2026-10-30",
        version = 1.5,
        required = {"ABCDEF00-1234-4000-8000-000000000002"},
        conflicts = {"ABCDEF00-1234-4000-8000-000000000003"},
        blueprints = {sample = {value = 3}},
    };
end

--[[!
@fqxn CoG.Tests.BaseMod.equal
@desc Compares normalized plain metadata without cloning raw blueprint references.
!]]
local function equal(vFirst, vSecond)
    if (rawequal(vFirst, vSecond)) then return true; end
    if (rawtype(vFirst) ~= "table" or rawtype(vSecond) ~= "table") then return false; end
    for k, v in pairs(vFirst) do if (not equal(v, vSecond[k])) then return false; end end
    for k in pairs(vSecond) do if (vFirst[k] == nil) then return false; end end
    return true;
end

assert(_sMode == "defaults" or _sMode == "logging", "Unknown BaseMod test mode.");
package.path = _pCoG.."/?.lua;".._pCoG.."/../LuaEx/?.lua;"..package.path;
require("LuaEx.load")(_sMode == "logging" and 4 or 3);
local BaseModClass = CoG.BaseMod;
check(class.is(BaseModClass) and rawequal(class.getbyname("CoG.BaseMod"), BaseModClass), "LuaEx discovers BaseMod");
check(rawget(_G, "BaseMod") == nil, "discovery publishes no short alias");
require("cog.load")();
check(rawget(_G, "BaseMod") == nil, "CoG loader remains unchanged");
check(BaseModClass.DEFAULT_MOD_ID == "27a27ca4-5f85-48ea-a30d-e6ad95d89d84", "permanent default-content identity is unchanged");
check(BaseModClass.MAX_VERSION == 999, "version ceiling is unchanged");
reject(function() BaseModClass.DEFAULT_MOD_ID = "changed"; end, "const/final");
reject(function() BaseModClass.MAX_VERSION = 1; end, "const/final");
reject(function() BaseModClass(metadata()); end, "constructor");

local tLogged = {};
check(BaseModClass.setLog(function(sMessage)
    tLogged[#tLogged + 1] = sMessage;
end), "host callback is accepted");
lxc.loadSources({["BaseModTest.lxc"] = [=[namespace BaseModTest {
    class Mod : CoG.BaseMod {
        public Mod(info) { base(info); }
        public readProtectedName() { return this.Name; }
        public writeProtectedName(name) { this.Name = name; }
        public writeProtectedID(id) { this.ID = id; }
        public changePath(path) { this.Path = path; }
        public hasRequired(id) { return this.required[id] == true; }
        public hasConflict(id) { return this.conflicts[id] == true; }
    }
}]=]}, _G);
local ModClass = BaseModTest.Mod;
local tSource = metadata();
local oMod = ModClass(tSource);
local tInfo = oMod.getInfo();
check(class.isa(oMod, BaseModClass), "subclass invokes the protected constructor");
check(tInfo.id == tSource.id:lower() and tInfo.version == 1.5, "identity normalization and version");
check(tInfo.contact == "" and tInfo.website == "", "optional strings default to empty");
check(oMod.readProtectedName() == tSource.name and oMod.getName() == tSource.name, "protected reads remain scalar and getters are retained");
check(oMod.getID() == tInfo.id and oMod.getDescription() == tSource.description, "final metadata getters");
check(oMod.getReleased() == tSource.released and oMod.getUpdated() == tSource.updated, "date getters");
check(oMod.getVersion() == 1.5 and oMod.getContact() == "" and oMod.getWebsite() == "", "version and optional getters");
check(oMod.hasRequired(tSource.required[1]:lower()) and oMod.hasConflict(tSource.conflicts[1]:lower()), "protected UUID membership sets are normalized");
check(rawequal(tInfo.blueprints, tSource.blueprints), "raw blueprints retain their original reference");
tSource.authors[1] = "Changed source";
tInfo.authors[2] = "Changed result";
tInfo.required[1] = "Changed result";
check(oMod.getInfo().authors[1] == "Bob" and oMod.getInfo().authors[2] == "Ed", "authors are independently copied in and out");
check(oMod.getInfo().required[1] == "abcdef00-1234-4000-8000-000000000002", "returned relationship lists do not expose sets");
check(oMod.getPath() == "", "path begins empty");
oMod.changePath("mods/example");
check(oMod.getPath() == "mods/example", "path remains mutable through protected subclass access");
reject(function() oMod.writeProtectedName("Changed"); end, "read-only");
reject(function() oMod.writeProtectedID("changed"); end, "read-only");
reject(function() return oMod.Name; end, "protected member");
reject(function() oMod.Name = "Changed"; end, "protected member");
reject(function() return BaseModClass._tWarnings; end, "private member");
reject(function() return BaseModClass._tLog; end, "private member");
reject(function() return oMod.authors; end, "protected member");
reject(function() oMod.getName = function() return "Changed"; end; end, "replace a method");
reject(function() lxc.loadSources({["override.lxc"] = "namespace BaseModTest { class BadGetter : CoG.BaseMod { public override getName() { return 'changed'; } } }"}, _G); end, "final member");
reject(function() lxc.loadSources({["override.lxc"] = "namespace BaseModTest { class BadProperty : CoG.BaseMod { protected override Name { get('read'); set('assign'); } } }"}, _G); end, "final member");

-- Compare the exact archived validation helpers, without loading the old class system.
local hReference = assert(io.open(_pCoG.."/legacy/cog/ModSystem/BaseMod.lua", "rb"));
local sReference = hReference:read("*a"); hReference:close();
local sPrefix = assert(sReference:match("^(.-)return class%(\"BaseMod\""));
local validateReference = assert(load(sPrefix.."\nreturn validateModInfo;", "@BaseMod-archived-validation", "t", _G))();
local tValid = metadata();
local tActual = assert(BaseModClass.validateModInfo(tValid));
check(equal(tActual, assert(validateReference(tValid))), "native validator matches archived normalized metadata");
check(tValid.id:sub(1, 8) == "ABCDEF00", "validation does not modify input");
for _, nVersion in ipairs({0.01, 999}) do
    local tBound = metadata(); tBound.version = nVersion;
    check(assert(BaseModClass.validateModInfo(tBound)).version == nVersion, "inclusive version bounds are retained");
end
local tStrings = metadata(); tStrings.contact, tStrings.website = 5, "   ";
local tStringInfo = assert(BaseModClass.validateModInfo(tStrings));
check(tStringInfo.contact == "" and tStringInfo.website == "", "optional strings retain legacy fallback rules");
local tAuthors = metadata(); tAuthors.authors = {"Bob", "Bob"};
check(#assert(BaseModClass.validateModInfo(tAuthors)).authors == 2, "author duplicates retain supplied order");
local tOptional = metadata(); tOptional.required, tOptional.conflicts, tOptional.blueprints = nil, nil, nil;
local tOptionalInfo = assert(BaseModClass.validateModInfo(tOptional));
check(#tOptionalInfo.required == 0 and #tOptionalInfo.conflicts == 0 and next(tOptionalInfo.blueprints) == nil, "omitted optional collections default empty");
local tDuplicate = metadata(); tDuplicate.required[2] = tDuplicate.required[1]:lower();
check(#assert(BaseModClass.validateModInfo(tDuplicate)).required == 1, "duplicate UUIDs collapse after normalization");
local tOrdered = metadata();
tOrdered.required = {"ffffffff-1234-4000-8000-000000000002", "aaaaaaaa-1234-4000-8000-000000000002"};
check(ModClass(tOrdered).getInfo().required[1]:sub(1, 8) == "aaaaaaaa", "returned UUID lists are sorted");

local tBreakers = {
    function(t) t.id = "not-a-uuid"; end,
    function(t) t.name = "  "; end,
    function(t) t.description = false; end,
    function(t) t.authors = {}; end,
    function(t) t.authors = {[2] = "Bob"}; end,
    function(t) t.authors = {name = "Bob"}; end,
    function(t) t.authors = {"Bob", false}; end,
    function(t) t.required = {"not-a-uuid"}; end,
    function(t) t.conflicts = {"not-a-uuid"}; end,
    function(t) t.required = false; end,
    function(t) t.conflicts = {[2] = t.id}; end,
    function(t) t.released = "2023-02-29"; end,
    function(t) t.updated = "2026-13-01"; end,
    function(t) t.version = 0; end,
    function(t) t.version = 1000; end,
    function(t) t.version = math.huge; end,
    function(t) t.version = 0 / 0; end,
    function(t) t.blueprints = false; end,
    function(t) setmetatable(t, {}); end,
};
for _, fBreak in ipairs(tBreakers) do
    local tInvalid = metadata(); fBreak(tInvalid);
    local tNative, sNative = BaseModClass.validateModInfo(tInvalid);
    local tOld, sOld = validateReference(tInvalid);
    check(tNative == nil and tOld == nil and sNative == sOld, "invalid metadata matches archived rejection reason");
    local nWarnings = #BaseModClass.getWarnings();
    local bOK, oInvalid = pcall(ModClass, tInvalid);
    check(bOK and class.isa(oInvalid, BaseModClass), "invalid metadata does not throw or replace the instance");
    check(rawequal(oInvalid.getID(), null) and rawequal(oInvalid.getName(), null) and next(oInvalid.getInfo().blueprints) == nil, "failure commits no scalar or blueprint metadata");
    check(#BaseModClass.getWarnings() == nWarnings + 1, "failure retains exactly one warning");
    check(BaseModClass.validateModInfo(oInvalid.getInfo()) == nil, "invalidity is queried from metadata, not a flag");
end
for _, vInput in ipairs({false, 12, "invalid"}) do
    local bOK, oInvalid = pcall(ModClass, vInput);
    check(bOK and rawequal(oInvalid.getName(), null), "non-table metadata remains a non-throwing invalid object");
end
local oEmpty = ModClass(nil);
check(rawequal(oEmpty.getName(), null), "missing metadata retains null defaults");
oEmpty.writeProtectedName(null);
oEmpty.writeProtectedName("First assignment");
check(oEmpty.readProtectedName() == "First assignment", "unset protected fields permit their first later non-null assignment");
reject(function() return oMod.activate; end, "Unknown member");
reject(function() return oMod.deactivate; end, "Unknown member");
reject(function() return oMod.isActive; end, "Unknown member");
reject(function() oEmpty.writeProtectedName("second"); end, "read-only");
reject(function() ModClass(nil).writeProtectedName(nil); end, "cannot be nil");
check(#tLogged > 0 and tLogged[1]:find("BaseMod:", 1, true) == 1, "supplied callback receives contextual warnings");
local tWarnings = BaseModClass.getWarnings();
local sFirst = tWarnings[1]; tWarnings[1] = "Changed result";
check(BaseModClass.getWarnings()[1] == sFirst, "warning retrieval returns a copy");
local bSet, sSetReason = BaseModClass.setLog(3);
check(not bSet and rawtype(sSetReason) == "string", "invalid logger is rejected without changing the callback");
local nLogged = #tLogged; ModClass({});
check(#tLogged == nLogged + 1, "invalid logger selection preserves previous logger");
check(BaseModClass.setLog(function()
    check(not pcall(function() return BaseModClass._tWarnings; end), "external logger cannot borrow class-private rights");
    error("host logger failed");
end), "replacement logging callback is accepted");
check(rawequal(ModClass({}).getID(), null), "logger failure cannot interrupt invalid construction");
check(BaseModClass.validateModInfo(ModClass(metadata()).getInfo()) ~= nil, "valid construction recovers after malformed input and logger errors");

local oClone = clone(oMod);
check(not rawequal(oClone, oMod) and class.isa(oClone, ModClass) and oClone.getID() == oMod.getID(), "clone preserves concrete class and readonly scalar values");
reject(function() oClone.writeProtectedName("changed"); end, "read-only");
oClone.getInfo().blueprints.sample.value = 10;
check(oMod.getInfo().blueprints.sample.value == 3, "native clone copies mutable blueprint graph state");
local tGraph = {mod = oMod, alias = oMod}; tGraph.self = tGraph;
local tLoaded = deserialize(serialize(tGraph));
check(rawequal(tLoaded.mod, tLoaded.alias) and rawequal(tLoaded.self, tLoaded), "save/load preserves graph aliases and cycles");
check(tLoaded.mod.getName() == oMod.getName() and tLoaded.mod.getPath() == "mods/example", "save/load preserves metadata and path");
reject(function() tLoaded.mod.writeProtectedID("changed"); end, "read-only");
local oUnsetLoaded = deserialize(serialize(ModClass({})));
check(rawequal(oUnsetLoaded.getName(), null), "native persistence retains an unset invalid object's readonly fields");
oUnsetLoaded.writeProtectedName("First after load");
check(oUnsetLoaded.getName() == "First after load", "restored unset fields retain first-assignment behavior");
reject(function() oUnsetLoaded.writeProtectedName("second"); end, "read-only");
check(rawequal(clone(BaseModClass), BaseModClass) and rawequal(deserialize(serialize(BaseModClass)), BaseModClass), "class references remain canonical");

if (_sMode == "logging") then
    local BaseLogClass = class.getbyname("LuaEx.Classes.BaseLog");
    local tObjectLog = {};
    check(BaseModClass.setLog({log = function(sMessage, eLevel) tObjectLog[#tObjectLog + 1] = {sMessage, eLevel}; end}), "logger object replaces callback without slot type restriction");
    ModClass({});
    check(#tObjectLog == 1 and rawequal(tObjectLog[1][2], BaseLogClass.LEVEL.WARNING), "object logger receives BaseLog warning level");
    local fOpen, tWrites = io.open, {};
    io.open = function(pFile, sMode, ...)
        if (pFile == "BaseMod.log") then
            check(sMode == "a", "lazy default log uses append mode");
            return {close = function() end, write = function(_, sText) tWrites[#tWrites + 1] = sText; end};
        end
        return fOpen(pFile, sMode, ...);
    end;
    check(BaseModClass.setLog(nil), "nil restores lazy default logging");
    local bLogged, oInvalid = pcall(ModClass, {});
    io.open = fOpen;
    check(bLogged and rawequal(oInvalid.getName(), null), "actual native BaseLog fallback does not interrupt construction");
    check(#tWrites == 1 and tWrites[1]:find("rejected", 1, true) and tWrites[1]:find("WARNING", 1, true), "lazy default log writes the contextual warning without creating test files");
else
    check(BaseModClass.setLog(nil), "nil selects lazy default logging");
    check(rawequal(ModClass({}).getName(), null), "unavailable utility logger is contained at normal CoG load level");
end

print("PASS BaseMod (".._sMode.."): ".._nChecks.." checks.");
