--[[!
@fqxn CoG.Tests.Registry
@desc Exercises CoGRegistry after real LuaEx discovery, including identity-based
    matching, callbacks, cloning, and shared-graph persistence.
    Run in a fresh Lua 5.4 process: lua tests/cog_registry_regression.lua
!]]
local _pTests = assert(debug.getinfo(1, "S").source:match("^@(.+)[/\\][^/\\]+$"));
local _pCoG = _pTests.."/..";
local _nChecks = 0;

--[[!
@fqxn CoG.Tests.Registry.check
@desc Counts a successful assertion or raises its failure description.
@param boolean bCondition Expected true result.
@param string sMessage Failure description.
!]]
local function check(bCondition, sMessage)
    assert(bCondition, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn CoG.Tests.Registry.rejects
@desc Confirms invalid operations raise an error.
@param function fOperation Operation which must fail.
@param string sMessage Failure description if it succeeds.
!]]
local function rejects(fOperation, sMessage)
    check(not pcall(fOperation), sMessage);
end

-- The project is discoverable before LuaEx runs; CoGBase does not load class files.
package.path = _pCoG.."/?.lua;".._pCoG.."/../LuaEx/?.lua;"..package.path;
require("LuaEx.load")(3);
local _cRegistry = class.getbyname("CoG.CoGRegistry");
check(class.is(_cRegistry), "LuaEx must discover CoGRegistry.lxc.");
check(CoGRegistry == nil, "Discovery must leave alias publication to cog.load.");
require("cog.load")();
check(rawequal(CoGRegistry, _cRegistry), "The loader must publish the discovered class.");
check(rawequal(require("cog.CoGRegistry"), CoGRegistry), "The require alias must retain class identity.");
check(not class.ischild(CoGRegistry, CoGBase), "The registry must retain its independent class hierarchy.");

lxc.loadSources({["RegistryFixtures.lxc"] = [[
    namespace CoGRegistryTests {
        class Actor : CoG.CoGBase {
            private nID = 0;
            public Actor(nID) { this.nID = nID; }
            public getID() { return this.nID; }
        }

        class Child : Actor {
            public Child(nID) { base(nID); }
        }

        class Other : CoG.CoGBase {
            public Other() {}
        }

        class EqualActor : CoG.CoGBase {
            public EqualActor() {}
            public operator ==(other) { return class.isa(other, EqualActor); }
        }

        class Foreign {
            public Foreign() {}
        }
    }
]]}, _G);

local _cActor = CoGRegistryTests.Actor;
local _cChild = CoGRegistryTests.Child;
local _oActor = _cActor(1);
local _oChild = _cChild(2);
local _oOther = CoGRegistryTests.Other();
local _oForeign = CoGRegistryTests.Foreign();
local _oRegistry = CoGRegistry();

check(#_oRegistry == 0 and _oRegistry.getCount() == 0, "A new registry must be empty.");
local _bAllowed, _sReason = _oRegistry.allows(_oActor);
check(not _bAllowed and _sReason == "Object does not match a registered entry.", "Empty registries must deny.");
check(_oRegistry.isDefaultPrerequisiteAllowed(), "The default prerequisite must allow.");
check(_oRegistry.getPrerequisite()(_oActor), "The default callback must be callable by its owner.");
rejects(function() return _oRegistry.entries; end, "Entry storage must be private.");
rejects(function() return _oRegistry.prerequisite; end, "Callback storage must be private.");

local _oReturned, _bChanged = _oRegistry.add(_cActor);
check(rawequal(_oReturned, _oRegistry) and _bChanged, "add must return this and true for a new entry.");
check(_oRegistry.allows(_oActor) and _oRegistry.allows(_oChild), "Class entries must match self and descendants.");
check(not _oRegistry.allows(_oOther), "Class entries must reject unrelated CoGBase branches.");
check(_oRegistry.contains(_cActor) and not _oRegistry.contains(_cChild), "contains must use exact identity.");
_oReturned, _bChanged = _oRegistry.add(_cActor);
check(rawequal(_oReturned, _oRegistry) and not _bChanged and #_oRegistry == 1, "Duplicates must be ignored.");
_oReturned, _bChanged = _oRegistry.remove(_cChild);
check(not _bChanged and #_oRegistry == 1, "remove must not remove an ancestor entry.");
_oReturned, _bChanged = _oRegistry.remove(_cActor);
check(rawequal(_oReturned, _oRegistry) and _bChanged and #_oRegistry == 0, "remove must remove the exact entry.");

_oRegistry.add(_oActor);
check(_oRegistry.allows(_oActor) and not _oRegistry.allows(_cActor(1)), "Instance entries must match exact identity.");
local _oEqual1 = CoGRegistryTests.EqualActor();
local _oEqual2 = CoGRegistryTests.EqualActor();
check(_oEqual1 == _oEqual2 and not rawequal(_oEqual1, _oEqual2), "The equality fixture must have equal distinct instances.");
local _oExact = CoGRegistry({_oEqual1});
check(not _oExact.allows(_oEqual2) and not _oExact.contains(_oEqual2), "Registry identity must ignore overloaded equality.");
_oExact.add(_oEqual2);
check(#_oExact == 2, "Equal distinct objects must remain distinct entries.");
_oExact.remove(_oEqual2);
check(_oExact.contains(_oEqual1) and not _oExact.contains(_oEqual2), "Removal must use raw identity.");

local _oAll = CoGRegistry({CoGBase});
check(_oAll.allows(_oActor) and _oAll.allows(_oOther), "Registering CoGBase must allow every CoGBase subtype.");
for _, vInvalid in ipairs({CoGBase, _cActor, {}, 7, "Actor", _oForeign}) do
    local bAllowed, sReason = _oAll.allows(vInvalid);
    check(not bAllowed and sReason == "Object must be a CoGBase instance.", "Invalid candidates must return the CoGBase reason.");
end

for _, vInvalid in ipairs({{}, 7, "Actor", CoGRegistry, _oRegistry, CoGRegistryTests.Foreign, _oForeign}) do
    rejects(function() _oRegistry.add(vInvalid); end, "Non-CoGBase entries must be rejected.");
end
rejects(function() _oRegistry.add(nil); end, "Nil entries must be rejected.");
rejects(function() CoGRegistry({[2] = _cActor}); end, "Sparse lists must fail.");
rejects(function() CoGRegistry({[-1] = _cActor}); end, "Negative indices must fail.");
rejects(function() CoGRegistry({[1.5] = _cActor}); end, "Fractional indices must fail.");
rejects(function() CoGRegistry({actor = _cActor}); end, "Named indices must fail.");
rejects(function() CoGRegistry(false); end, "Non-table entry lists must fail.");
rejects(function() CoGRegistry(nil, nil, 1); end, "Nonboolean defaults must fail.");
rejects(function() CoGRegistry(nil, true); end, "Nonfunction callbacks must fail.");
local _oDeduplicated = CoGRegistry({_cActor, _cActor});
check(#_oDeduplicated == 1, "Constructor duplicates must be ignored.");

-- Iterators own a snapshot of the ordered entry list.
_oRegistry.clear();
_oRegistry.add(_cActor);
_oRegistry.add(_oOther);
local _iterate = _oRegistry.eachEntry();
_oRegistry.clear();
local _nIndex, _vEntry = _iterate();
check(_nIndex == 1 and rawequal(_vEntry, _cActor), "Iterator order must survive registry edits.");
_nIndex, _vEntry = _iterate();
check(_nIndex == 2 and rawequal(_vEntry, _oOther), "Iterator must include instance entries.");
check(_iterate() == nil, "Iterator must terminate.");
_oRegistry.add(_cActor);
_nIndex, _vEntry = _oRegistry.eachClass()();
check(_nIndex == 1 and rawequal(_vEntry, _cActor), "eachClass must retain its public alias behavior.");

local _nCalls = 0;
local _callback = function(oObject, ...)
    _nCalls = _nCalls + 1;
    local tArguments = table.pack(...);
    check(rawequal(oObject, _oChild), "The callback must receive the candidate.");
    check(tArguments.n == 3 and tArguments[1] == "context" and tArguments[2] == nil and
        tArguments[3] == 7, "Callback context must preserve nil arguments.");
    return true, "ignored on success";
end;
local _oCallbacks = CoGRegistry({_cActor, _cChild, _oChild}, _callback, false);
_bAllowed, _sReason = _oCallbacks.allows(_oChild, "context", nil, 7);
check(_bAllowed and _sReason == nil and _nCalls == 1, "Multiple matches must call the prerequisite once.");
check(not _oCallbacks.allows(_oOther) and _nCalls == 1, "Unmatched objects must not call the prerequisite.");
_oCallbacks.setDefaultPrerequisite(true);
check(rawequal(_oCallbacks.getPrerequisite(), _callback), "Changing the default must retain a custom callback.");
_oCallbacks.setPrerequisite();
check(_oCallbacks.allows(_oChild), "Nil must select the current default callback.");
_oCallbacks.setDefaultPrerequisite(false);
_bAllowed, _sReason = _oCallbacks.allows(_oChild);
check(not _bAllowed and _sReason == "Prerequisite not met.", "Changing an active default must update it immediately.");
check(not _oCallbacks.isDefaultPrerequisiteAllowed(), "The default flag must be observable.");
check(rawequal(_oCallbacks.clear(), _oCallbacks) and not _oCallbacks.isDefaultPrerequisiteAllowed(),
    "clear must retain prerequisite settings.");
rejects(function() _oCallbacks.setDefaultPrerequisite(1); end, "Default setters must reject nonbooleans.");
rejects(function() _oCallbacks.setPrerequisite(1); end, "Callback setters must reject nonfunctions.");
_oCallbacks.add(_cActor);
_oCallbacks.setPrerequisite(function() return false, "denied"; end);
_bAllowed, _sReason = _oCallbacks.allows(_oActor);
check(not _bAllowed and _sReason == "denied", "Custom denial reasons must be preserved.");
_oCallbacks.setPrerequisite(function() return "yes"; end);
rejects(function() _oCallbacks.allows(_oActor); end, "Nonboolean results must raise an error.");
_oCallbacks.setPrerequisite(function() return false, 7; end);
rejects(function() _oCallbacks.allows(_oActor); end, "Nonstring reasons must raise an error.");
_oCallbacks.setPrerequisite(function() error("callback failure"); end);
rejects(function() _oCallbacks.allows(_oActor); end, "Callback errors must propagate.");

-- Clones own the array but retain exact entries and the original callback reference.
local _oOriginal = CoGRegistry({_oActor, _cActor}, _callback, false);
local _oCopy = clone(_oOriginal);
check(_oCopy ~= _oOriginal and #_oCopy == 2, "A clone must own a new registry.");
check(_oCopy.contains(_oActor) and _oCopy.contains(_cActor), "A clone must retain entry identities.");
check(rawequal(_oCopy.getPrerequisite(), _callback), "A clone must share the callback reference.");
check(not _oCopy.isDefaultPrerequisiteAllowed(), "A clone must retain the default setting.");
_oCopy.clear();
check(#_oOriginal == 2, "Editing a clone must not edit the original entry array.");

-- Defaults are reconstructed rather than exporting private compiled callbacks.
for _, bDefault in ipairs({true, false}) do
    local oRegistry = CoGRegistry({_cActor}, nil, bDefault);
    local oLoaded = deserialize(serialize(oRegistry));
    check(oLoaded.allows(_oActor) == bDefault, "Default callbacks must survive save/load.");
    check(oRegistry.allows(_oActor) == bDefault, "Saving must not edit the live callback box.");
    check(oLoaded.isDefaultPrerequisiteAllowed() == bDefault, "The saved default setting must survive.");
end

--[[!
@fqxn CoG.Tests.Registry.prerequisiteID
@desc Plain application callback used to verify custom callback persistence.
@param CoGBase oObject Candidate with a public getID method.
@param number nID Required ID.
@ret boolean bAllowed Whether the IDs match.
!]]
local function prerequisiteID(oObject, nID)
    return oObject.getID() == nID;
end

local _oGraph = deserialize(serialize({
    actor = _oActor,
    registry = CoGRegistry({_oActor}, prerequisiteID, false),
}));
check(_oGraph.registry.contains(_oGraph.actor), "Restored instance entries must share the restored graph identity.");
check(not _oGraph.registry.contains(_oActor), "Restored instance entries must not retain the original identity.");
check(_oGraph.registry.allows(_oGraph.actor, 1), "Custom callbacks must survive save/load.");
check(not _oGraph.registry.allows(_oGraph.actor, 2), "Restored callbacks must retain their behavior.");
check(not _oGraph.registry.isDefaultPrerequisiteAllowed(), "Custom callbacks must retain the configured default.");
_oGraph.registry.setPrerequisite();
check(not _oGraph.registry.allows(_oGraph.actor), "Clearing a restored callback must select its saved default.");

print("PASS CoGRegistry: ".._nChecks.." checks.");
