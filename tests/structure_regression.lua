--[[!
@fqxn CoG.Tests.Structure
@desc Verifies marker inheritance, protected construction, independent inherited
    components and persistence of concrete structures. Run in a fresh Lua 5.4 process:
    lua tests/structure_regression.lua
!]]
local _pTests = assert(debug.getinfo(1, "S").source:match("^@(.+)[/\\][^/\\]+$"));
local _pCoG = _pTests.."/..";
local _nChecks = 0;

--[[!
@fqxn CoG.Tests.Structure.check
@desc Counts a successful assertion or raises a descriptive failure.
!]]
local function check(bCondition, sMessage)
    assert(bCondition, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn CoG.Tests.Structure.rejects
@desc Confirms an invalid operation raises an error.
!]]
local function rejects(fOperation, sMessage)
    check(not pcall(fOperation), sMessage);
end

package.path = _pCoG.."/?.lua;".._pCoG.."/../LuaEx/?.lua;"..package.path;
require("LuaEx.load")(3);
local _cStructure = class.getbyname("CoG.CoGStructure");
check(class.is(_cStructure) and CoGStructure == nil, "LuaEx must discover the structure before alias publication.");
require("cog.load")();
check(rawequal(CoGStructure, _cStructure), "The short alias must retain class identity.");
check(rawequal(CoG.CoGStructure, CoGStructure), "Structures must live directly in CoG.");
check(rawequal(require("cog.Objects.StructureSystem.CoGStructure"), CoGStructure), "The require alias must retain identity.");
rejects(function() CoGStructure("Structure", "Description"); end, "The marker constructor must remain protected.");

lxc.loadSources({["StructureFixtures.lxc"] = [[
    namespace CoG.Tests {
        class Building : CoG.CoGStructure {
            private nFloors = 1;

            public Building(sName, sDescription, eRarity, nFloors) {
                base(sName, sDescription, eRarity);
                this.nFloors = nFloors == nil and 1 or nFloors;
            }

            public getFloors() { return this.nFloors; }
            public rename(sName) { this.Name = sName; }
            public addHook(eEvent, fHook) { this.eventrix.addHook(eEvent, fHook); }
        }

        class Tower : Building {
            public Tower() { base("Tower", "A tower", nil, 4); }
            public override getName() { return "Watchtower"; }
        }
    }
]]}, _G);

local _building = CoG.Tests.Building("Hall", "A hall", Rarity.LEVEL.III, 2);
local _other = CoG.Tests.Building("Barn", "A barn");
local _tower = CoG.Tests.Tower();
check(class.isa(_building, CoGStructure) and class.isa(_building, CoGObject) and class.isa(_building, CoGBase),
    "Structures must retain their complete ancestry.");
check(type.isCoGStructure(_building) and type.isCoGStructure(_tower), "The marker predicate must recognize descendants.");
check(not type.isCoGStructure(CoGAbility("Ability", "An ability")), "Other object branches must not match the marker.");
check(_building.getName() == "Hall" and _building.getDescription() == "A hall", "Metadata must be forwarded.");
check(_building.getRarity() == Rarity.LEVEL.III, "Configured rarity must be retained.");
check(_other.getRarity() == Rarity.LEVEL[1], "Omitted rarity must use the first level.");
check(_building.getFloors() == 2 and _tower.getFloors() == 4, "Concrete state must initialize through multiple base calls.");
check(_tower.getName() == "Watchtower", "Inherited metadata getters must remain overridable.");
_building.rename("Great Hall");
check(_building.getName() == "Great Hall", "Concrete classes must retain protected metadata access.");
rejects(function() return _building.Name; end, "Protected metadata must not become public.");
rejects(function() return _building.nFloors; end, "Concrete state must remain private.");
rejects(function() CoG.Tests.Building("", "Description"); end, "Inherited name validation must run.");
rejects(function() CoG.Tests.Building("Name", " "); end, "Inherited description validation must run.");

_building.getTagSystem().add("BUILDING");
check(_building.getTagSystem().contains("BUILDING") and not _other.getTagSystem().contains("BUILDING"),
    "Tag components must be independent.");
check(not rawequal(_building.getAffixSystem(), _other.getAffixSystem()), "Affix components must be independent.");
check(rawequal(_building.getAffixSystem().getOwner(), _building), "Owned affixes must use the concrete structure.");
local _, _bBound = _building.getAffixSystem().setOwner(_other);
check(not _bBound, "Owned affix components must not rebind to another structure.");

enum("StructureTestEvent", {"TICK"});
local _nEvents = 0;
_building.addHook(StructureTestEvent.TICK, function() _nEvents = _nEvents + 1; end);
_building.fireEvent(StructureTestEvent.TICK);
check(_nEvents == 1, "Inherited event dispatch must work.");

local _registry = CoGRegistry({CoGStructure});
check(_registry.allows(_building) and _registry.allows(_tower), "Registry class entries must match all structures.");
check(not _registry.allows(CoGAbility("Other", "Another ability")), "Structure registries must reject other branches.");

local _loaded = deserialize(serialize(_building));
check(class.isinstanceof(_loaded, CoG.Tests.Building) and type.isCoGStructure(_loaded),
    "Persistence must retain the concrete class and structure marker.");
check(_loaded.getFloors() == 2 and _loaded.getName() == "Great Hall", "Concrete and inherited data must survive.");
check(_loaded.getTagSystem().contains("BUILDING"), "Inherited tags must survive.");
check(_loaded.getRarity() == Rarity.LEVEL.III, "Rarity identity must survive.");
check(rawequal(_loaded.getAffixSystem().getOwner(), _loaded), "Loaded affix ownership must reconnect.");
check(not rawequal(_loaded.getAffixSystem(), _building.getAffixSystem()), "Loaded components must be independent.");
_loaded.rename("Restored Hall");
check(_building.getName() == "Great Hall", "Restored metadata changes must remain independent.");
local _loadedTower = deserialize(serialize(_tower));
check(_loadedTower.getFloors() == 4 and _loadedTower.getName() == "Watchtower",
    "Indirect structure descendants must retain state and overrides.");
check(rawequal(deserialize(serialize(CoGStructure)), CoGStructure), "Class references must retain persistence identity.");

check(not type.isCoGStructure(nil) and not type.isCoGStructure(CoGStructure) and not type.isCoGStructure({}),
    "The marker predicate must reject noninstances.");
local _predicate = deserialize(serialize(type.isCoGStructure));
check(_predicate(_building) and _predicate(_tower), "The marker predicate must remain serializable application code.");

print("PASS CoGStructure: ".._nChecks.." checks.");

