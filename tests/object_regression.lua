--[[!
@fqxn CoG.Tests.Objects
@desc Checks the CoGObject base and its owned AffixSystem with real gameplay
    callbacks, events, recovery and graph persistence. Uses actual components.
    Run in a fresh Lua 5.4 process: lua tests/object_regression.lua
!]]
local _pTests = assert(debug.getinfo(1, "S").source:match("^@(.+)[/\\][^/\\]+$"));
local _pCoG = _pTests.."/..";
local _nChecks = 0;

--[[!
@fqxn CoG.Tests.Objects.check
@desc Counts a successful assertion or raises a descriptive failure.
!]]
local function check(bCondition, sMessage)
    assert(bCondition, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn CoG.Tests.Objects.rejects
@desc Requires the supplied invalid operation to raise an error.
!]]
local function rejects(fOperation, sMessage)
    check(not pcall(fOperation), sMessage);
end

package.path = _pCoG.."/?.lua;".._pCoG.."/../LuaEx/?.lua;"..package.path;
require("LuaEx.load")(3);
require("cog.load")();
check(rawequal(CoGObject, class.getbyname("CoG.CoGObject")), "CoGObject must be discovered by LuaEx.");
check(rawequal(AffixSystem, class.getbyname("CoG.AffixSystem")), "AffixSystem must be discovered by LuaEx.");
check(rawequal(require("cog.Objects.CoGObject"), CoGObject), "The object require alias must retain identity.");
check(rawequal(require("cog.AffixSystem"), AffixSystem), "The affix require alias must retain identity.");

lxc.loadSources({["ObjectFixtures.lxc"] = [[
    namespace CoGObjectTests {
        class Thing : CoG.CoGObject {
            private nPower = 0;

            public Thing(sName, sDescription, eRarity) {
                base(sName, sDescription, eRarity);
            }

            public getPower() { return this.nPower; }
            public addPower(nDelta) { this.nPower = this.nPower + nDelta; }
            public rename(sName) { this.Name = sName; }
            public replaceComponent() { this.AffixSystem = this.AffixSystem; }
            public addHook(eEvent, fHook) { return this.eventrix.addHook(eEvent, fHook); }
        }

        class Other : CoG.CoGObject {
            public Other() { base("Other", "Another object"); }
        }

        class Named : Thing {
            public Named() { base("Plain", "Named object"); }
            public override getName() { return "Overridden"; }
        }
    }
]]}, _G);
enum("ObjectTestEvents", {"TICK"});

local _cThing = CoGObjectTests.Thing;
local _oObject = _cThing("Sword", "A sword", Rarity.LEVEL.III);
local _oOther = CoGObjectTests.Other();
local _oSystem = _oObject.getAffixSystem();
local _eTier = CoGBase.config.TIER;

check(class.isa(_oObject, CoGObject) and class.isa(_oObject, CoGBase), "Object ancestry must be preserved.");
check(_oObject.getName() == "Sword" and _oObject.getDescription() == "A sword", "Metadata must be preserved.");
check(_oObject.getRarity() == Rarity.LEVEL.III, "The supplied rarity must be retained.");
check(_oOther.getRarity() == Rarity.LEVEL[1], "Omitted rarity must use the first level.");
check(_cThing("Fallback", "Fallback rarity", {}).getRarity() == Rarity.LEVEL[1], "Invalid constructor rarity must fall back.");
check(CoGObjectTests.Named().getName() == "Overridden", "Metadata getters must remain overridable.");
rejects(function() CoGObject(); end, "The base constructor must remain protected.");
rejects(function() _cThing("", "Description"); end, "Blank names must fail.");
rejects(function() _cThing("Name", " "); end, "Blank descriptions must fail.");
rejects(function() _cThing(7, "Description"); end, "Nonstring metadata must fail.");
rejects(function() return _oObject.Name; end, "Protected metadata must not be public.");
rejects(function() return _oSystem._tState; end, "Component state must remain private.");
rejects(function() return AffixSystem._tRuntime; end, "Runtime services must remain private.");
rejects(function() _oObject.replaceComponent(); end, "Owned component bindings must remain final.");

for _, sMethod in ipairs({"getTagSystem", "getAffixSystem", "ownsAffixSystem", "setRarity"}) do
    local sParameters = (sMethod == "setRarity" and "eRarity") or
        (sMethod == "ownsAffixSystem" and "oSystem") or "";
    rejects(function()
        lxc.loadSources({["ForbiddenOverride.lxc"] =
            "namespace CoGObjectTests { class Bad"..sMethod..
            " : Thing { public override "..sMethod.."("..sParameters..") {} } }"}, _G);
    end, sMethod.." must remain final.");
end

_oObject.rename("Blade");
check(_oObject.getName() == "Blade", "Derived methods must access protected metadata.");
check(rawequal(_oSystem.getOwner(), _oObject), "Owned components must reference the actual object.");
check(_oObject.ownsAffixSystem(_oSystem) and not _oObject.ownsAffixSystem(_oOther.getAffixSystem()), "Ownership must use exact identity.");
local _, _bSuccess = _oSystem.setOwner(_oOther);
check(not _bSuccess and rawequal(_oSystem.getOwner(), _oObject), "Owned components cannot be rebound.");
_, _bSuccess = _oSystem.setOwner(nil);
check(not _bSuccess, "Owned components cannot be detached.");
check(AffixSystem.MAX_TIER == CoGBase.config.Rarity.Affix.maxTier, "The configured tier cap must be retained.");

_oObject.getTagSystem().add("Weapon");
check(_oObject.getTagSystem().contains("WEAPON"), "The tag component must remain mutable.");
check(not _oOther.getTagSystem().contains("WEAPON"), "Tag components must be per-object.");
_oObject.addHook(ObjectTestEvents.TICK, function() return "object hook"; end);
check(type(_oObject.fireEvent(ObjectTestEvents.TICK)) == "table", "Object events must delegate to eventrix.");

local _tPattern = {
    type = AffixSystem.TYPE.PREFIX, name = "Sharp", classes = {CoGObject},
    tiers = {[_eTier.I] = {amount = 2}}, priority = 1,
};
check(rawequal(AffixSystem.registerDefinition("Sharp", _tPattern), AffixSystem), "Registration must support chaining.");
_tPattern.tiers[_eTier.I].amount = 999;
check(AffixSystem.getDefinition("SHARP").tiers[_eTier.I].amount == 2, "Definitions must copy caller-owned data.");
local _tDetached = AffixSystem.getDefinition("sharp");
_tDetached.name = "Changed";
check(AffixSystem.getDefinition("sharp").name == "Sharp", "Definition getters must return detached copies.");
check(AffixSystem.hasDefinition("sHaRp") and not AffixSystem.hasDefinition("missing"), "Definition IDs must ignore case.");
rejects(function() AffixSystem.registerDefinition("SHARP", _tPattern); end, "Duplicate IDs must fail.");
rejects(function()
    AffixSystem.registerDefinitions({
        ["Would Be Added"] = _tPattern,
        invalid = {type = AffixSystem.TYPE.PREFIX},
    });
end, "Invalid imports must fail atomically.");
check(not AffixSystem.hasDefinition("Would Be Added"), "Invalid imports must leave no partial registrations.");

local _oAffix = AffixSystem.createAffix("sharp", _eTier.I);
local _oDuplicate = AffixSystem.createAffix("SHARP", _eTier.I);
check(_oAffix ~= _oDuplicate and _oAffix.getDefinitionID() == "Sharp", "Entries must be independent and retain registered spelling.");
check(_oAffix.getValues().amount == 2 and _oAffix.isPrefix(), "Selected metadata must be retained.");
check(_oAffix.isCompatibleWithClass(_cThing) and _oAffix.isCompatibleWithClass(class.getname(_cThing)), "Class and qualified-name queries must work.");
local _tValues = _oAffix.getValues();
_tValues.amount = 100;
check(_oAffix.getValues().amount == 2, "Entry payload getters must return copies.");
rejects(function() _oAffix.name = "Other"; end, "Affix metadata must be read-only.");

--[[!
@fqxn CoG.Tests.Objects.onAdd
@desc Applies a power delta and returns a hook capturing only the mutable journal.
!]]
local function onAdd(oAffix, tJournal, nDelta)
    nDelta = nDelta or oAffix.getValues().amount;
    tJournal.delta = nDelta;
    tJournal.hits = 0;
    oAffix.getOwner().addPower(nDelta);

    local function fTick(nAmount)
        tJournal.hits = tJournal.hits + nAmount;
        return tJournal.hits;
    end

    return {[ObjectTestEvents.TICK] = fTick};
end

--[[!
@fqxn CoG.Tests.Objects.onRemove
@desc Undoes the captured delta using the live owner; never captures the host.
!]]
local function onRemove(oAffix, tJournal)
    oAffix.getOwner().addPower(-tJournal.delta);
end

_oSystem.setOnAddCallback(onAdd);
_oSystem.setOnRemoveCallback(onRemove);
local _, _bApplied, _oResult = _oSystem.applyAffix(_oAffix, 3);
check(_bApplied and rawequal(_oResult, _oAffix), "Eligible affixes must apply.");
check(_oObject.getPower() == 3 and _oAffix.isApplied(), "Applications must run gameplay callbacks.");
check(rawequal(_oAffix.getOwner(), _oObject) and rawequal(_oAffix.getSystem(), _oSystem), "Applied entries must expose ownership.");
check(_oSystem.getName() == "Sharp Blade" and _oObject.getName() == "Blade", "Composed names must not alter base metadata.");
check(_oSystem.getAffixCount() == 1 and _oSystem.getPrefixCount() == 1 and _oSystem.getSuffixCount() == 0, "Group counts must be correct.");
check(not _oSystem.canApplyAffix(_oDuplicate), "Duplicate definition applications must fail.");
check(rawequal(_oSystem.getAffixByDefinitionID("SHARP"), _oAffix), "Definition lookup must return the applied entry.");
_oSystem.fireEvent(ObjectTestEvents.TICK, 4);
check(_oAffix.getJournal().hits == 4, "Affix hooks must use their application journal.");

-- Saving must retain shared entry/journal identities and reconnect external owners.
local _tLoaded = deserialize(serialize({object = _oObject, entry = _oAffix}));
local _oLoaded = _tLoaded.object;
local _oLoadedSystem = _oLoaded.getAffixSystem();
check(_oLoaded.getPower() == 3, "Loading must not replay application effects.");
check(_oLoaded.getTagSystem().contains("WEAPON"), "Object tags must survive save/load.");
check(rawequal(_oLoadedSystem.getOwner(), _oLoaded), "Loading must reconnect the component owner.");
check(rawequal(_tLoaded.entry.getOwner(), _oLoaded), "Entry ownership must reconnect.");
check(rawequal(_tLoaded.entry.getSystem(), _oLoadedSystem), "Entry system lookup must reconnect.");
check(rawequal(_oLoadedSystem.getAffixByDefinitionID("sharp"), _tLoaded.entry), "Shared entry references must survive.");
_oLoadedSystem.fireEvent(ObjectTestEvents.TICK, 2);
check(_tLoaded.entry.getJournal().hits == 6, "Restored hooks must share the restored journal.");
check(_oAffix.getJournal().hits == 4, "Restored journal edits must not change the original.");

-- Removal uses the callback captured on application, even after setters change.
_oSystem.setOnRemoveCallback(function() error("new callback must not run"); end);
local _, _bRemoved = _oSystem.removeAffix(_oAffix);
check(_bRemoved and _oObject.getPower() == 0 and not _oAffix.isApplied(), "Removal must use the captured undo callback.");
check(_oSystem.getName() == "Blade", "Removal must invalidate the name cache.");
_, _bRemoved = _oLoadedSystem.removeAffix(_tLoaded.entry);
check(_bRemoved and _oLoaded.getPower() == 0, "Saved captured callbacks must remain usable.");

-- A failing add must compensate; a failed undo must retain explicit recovery state.
_oSystem.setOnRemoveCallback(function(oAffix, tJournal)
    oAffix.getOwner().addPower(-(tJournal.delta or 0));
end);
_oSystem.setOnAddCallback(function(oAffix, tJournal)
    tJournal.delta = 7;
    oAffix.getOwner().addPower(7);
    error("add failure");
end);
local _, _bFailedAdd, _vRecovery = _oSystem.applyAffix(_oAffix);
check(not _bFailedAdd and _vRecovery == nil and _oObject.getPower() == 0, "Failed adds must compensate when undo succeeds.");
check(not _oAffix.isApplied() and _oSystem.getAffixCount() == 0, "Compensated adds must release ownership.");
_oSystem.setOnRemoveCallback(function() error("undo failure"); end);
_, _bFailedAdd, _vRecovery = _oSystem.applyAffix(_oAffix);
check(not _bFailedAdd and rawequal(_vRecovery, _oAffix), "Failed compensation must return its retained entry.");
check(_oAffix.isApplied() and _oSystem.getAffixCount() == 1, "Failed compensation must preserve recovery state.");

local _oStandalone = AffixSystem(nil, Rarity.LEVEL.I);
check(_oStandalone.getOwner() == nil, "Standalone systems may be detached.");
local _, _bAttached = _oStandalone.setOwner(_oOther);
check(_bAttached and rawequal(_oStandalone.getOwner(), _oOther), "Empty standalone systems may attach.");
_, _bAttached = _oStandalone.setOwner(nil);
check(_bAttached and _oStandalone.getOwner() == nil, "Unlocked standalone systems may detach.");
rejects(function() _oStandalone.getName(); end, "Detached naming requires a supplied base name.");
check(_oStandalone.getName("Base") == "Base", "Detached naming must accept a supplied base name.");
_oStandalone.setRarity(Rarity.LEVEL.VI);
_oStandalone.setExplicitName("Unique");
check(_oStandalone.getName("Base") == "Unique", "Singular names must honor explicit overrides.");

-- Replacement recovery must reuse the original callback pair and original arguments.
AffixSystem.registerDefinitions({
    Burning = {type = AffixSystem.TYPE.PREFIX, name = "Burning", classes = {CoGObject},
        tiers = {[_eTier.II] = {amount = 4}}},
    Failing = {type = AffixSystem.TYPE.PREFIX, name = "Failing", classes = {CoGObject},
        tiers = {[_eTier.II] = {amount = 8}}},
    Frost = {type = AffixSystem.TYPE.SUFFIX, name = "of Frost", classes = {CoGObject},
        tiers = {[_eTier.I] = {amount = 1}}},
});
local _oReplacement = _cThing("Staff", "A staff", Rarity.LEVEL.IV);
local _oReplacementSystem = _oReplacement.getAffixSystem();
_oReplacementSystem.setOnAddCallback(onAdd);
_oReplacementSystem.setOnRemoveCallback(onRemove);
local _oOld = AffixSystem.createAffix("Sharp", _eTier.I);
local _oNew = AffixSystem.createAffix("Burning", _eTier.II);
local _oFailing = AffixSystem.createAffix("Failing", _eTier.II);
local _oSuffix = AffixSystem.createAffix("Frost", _eTier.I);
_oReplacementSystem.applyAffix(_oOld, 5);
_oReplacementSystem.setOnAddCallback(function(oAffix, tJournal, nDelta)
    local tHooks = onAdd(oAffix, tJournal, nDelta);
    if (oAffix.getDefinitionID() == "Failing") then error("replacement failure"); end
    return tHooks;
end);
local _, _bReplaced, _oRecovered, _sRecovery = _oReplacementSystem.replaceAffix(_oOld, _oFailing, 17);
check(not _bReplaced and rawequal(_oRecovered, _oOld), "Failed replacements must recover the outgoing entry when possible.");
check(_oReplacement.getPower() == 5 and _oOld.getJournal().delta == 5, "Recovery must use original application arguments.");
check(_oOld.isApplied() and not _oFailing.isApplied(), "Recovered ownership must exclude the failed replacement.");
check(_sRecovery:find("original reapplied", 1, true) ~= nil, "Recovery status must be reported.");

_oReplacementSystem.setOnAddCallback(onAdd);
_, _bReplaced = _oReplacementSystem.replaceAffix(_oOld, _oNew, 9, nil, "context");
check(_bReplaced and not _oOld.isApplied() and _oNew.isApplied(), "Eligible replacements must transfer the application.");
check(_oReplacement.getPower() == 9, "Replacement must undo the old effect and apply the new effect once.");
check(_oReplacementSystem.getName() == "Burning Staff", "Replacement must invalidate composed naming.");

_oReplacementSystem.applyAffix(_oSuffix);
check(_oReplacementSystem.getName() == "Burning Staff of Frost", "Suffixes must compose after the base name.");
check(_oReplacementSystem.getSuffixCount() == 1, "Suffix counts must remain independent.");
local _, _bChanged = _oReplacement.setRarity(Rarity.LEVEL.I);
check(not _bChanged and _oReplacement.getRarity() == Rarity.LEVEL.IV, "Rarity reductions must reject incompatible applied tiers.");
_, _bChanged = _oReplacement.setRarity(Rarity.LEVEL.V);
check(_bChanged and _oReplacement.getRarity() == Rarity.LEVEL.V, "Compatible rarity changes must succeed.");

local _oReplacementLoaded = deserialize(serialize(_oReplacement));
check(_oReplacementLoaded.getPower() == 10, "Restoring a replacement must not replay effects.");
check(_oReplacementLoaded.getAffixSystem().getName() == "Burning Staff of Frost", "Replacement metadata must survive save/load.");

-- Mutation and serialization reentry must be rejected while callbacks run.
local _bSaveRejected, _bMutationRejected = false, false;
local _oBusyOwner = _cThing("Busy", "Busy owner", Rarity.LEVEL.III);
local _oBusySystem = _oBusyOwner.getAffixSystem();
_oBusySystem.setOnAddCallback(function(oAffix)
    local oSystem = oAffix.getSystem();
    _bSaveRejected = not pcall(serialize, oSystem);
    _bMutationRejected = not oSystem.canSetRarity(Rarity.LEVEL.I);
end);
local _, _bBusyApplied = _oBusySystem.applyAffix(AffixSystem.createAffix("Sharp", _eTier.I));
check(_bBusyApplied and _bSaveRejected, "Saving during an operation must fail without cancelling a valid application.");
check(_bMutationRejected, "Eligibility mutation reentry must be rejected while busy.");

print("PASS CoGObject and AffixSystem: ".._nChecks.." checks.");

