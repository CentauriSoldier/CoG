--[[!
@fqxn CoG.Tests.Ability
@desc Verifies native ability discovery, cost ownership, callback forwarding,
    inheritance and graph persistence. Run in a fresh Lua 5.4 process:
    lua tests/ability_regression.lua
!]]
local _pTests = assert(debug.getinfo(1, "S").source:match("^@(.+)[/\\][^/\\]+$"));
local _pCoG = _pTests.."/..";
local _nChecks = 0;

--[[!
@fqxn CoG.Tests.Ability.check
@desc Counts a successful assertion or raises its descriptive failure.
!]]
local function check(bCondition, sMessage)
    assert(bCondition, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn CoG.Tests.Ability.rejects
@desc Confirms an invalid operation raises an error.
!]]
local function rejects(fOperation, sMessage)
    check(not pcall(fOperation), sMessage);
end

package.path = _pCoG.."/?.lua;".._pCoG.."/../LuaEx/?.lua;"..package.path;
require("LuaEx.load")(3);
local _tNamespace = CoG;
local _cAbility = class.getbyname("CoG.CoGAbility");
check(class.is(_cAbility), "LuaEx must discover CoGAbility.lxc.");
check(CoGAbility == nil, "The loader must publish the short alias after discovery.");
local _cBase = require("cog.load")();
check(rawequal(_cBase, CoGBase), "The loader must return CoGBase.");
check(rawequal(CoG, _tNamespace) and not class.is(CoG), "CoG must remain the namespace.");
check(rawequal(CoG.CoGBase, CoGBase), "The namespace must expose CoGBase.");
check(rawequal(CoGAbility, _cAbility), "The ability alias must retain discovered identity.");
check(rawequal(require("cog.Objects.CoGAbility"), CoGAbility), "The require alias must retain class identity.");

local _oAbility = CoGAbility("Spell", "A spell", Rarity.LEVEL.III);
local _oOther = CoGAbility("Other", "Another ability");
check(class.isa(_oAbility, CoGObject) and class.isa(_oAbility, CoGBase), "Ability ancestry must remain intact.");
check(_oAbility.getName() == "Spell" and _oAbility.getDescription() == "A spell", "Metadata must be inherited.");
check(_oAbility.getRarity() == Rarity.LEVEL.III, "The supplied rarity must be retained.");
check(rawequal(_oAbility.getAffixSystem().getOwner(), _oAbility), "Inherited component ownership must work.");
check(class.isa(_oAbility.getCost(), Protean), "Each cost must be a Protean.");
check(not rawequal(_oAbility.getCost(), _oOther.getCost()), "Abilities must own independent cost components.");
_oAbility.getCost().setValue(Protean.VALUE_BASE, 12);
check(_oAbility.getCost(Protean.VALUE_BASE) == 12, "Category queries must delegate to Protean.");
check(_oOther.getCost(Protean.VALUE_BASE) == 0, "Changing one cost must not change another.");
rejects(function() _oAbility.getCost(0); end, "Invalid categories must retain Protean validation.");
rejects(function() return _oAbility.Cost; end, "Cost storage must remain protected.");
rejects(function() return _oAbility.onUse; end, "Callback storage must remain private.");
rejects(function() return CoGAbility.dummy; end, "The shared default must remain private.");
check(select("#", _oAbility.use()) == 0, "The default callback must return no values.");
check(select("#", _oAbility.getOnUseCallback()()) == 0, "The default callback must be callable as a value.");

--[[!
@fqxn CoG.Tests.Ability.callback
@desc Returns the ability and every caller argument to exercise nil forwarding.
!]]
local function callback(oAbility, ...)
    return oAbility, ...;
end

check(rawequal(_oAbility.setOnUseCallback(callback), _oAbility), "Callback setters must support chaining.");
check(rawequal(_oAbility.getOnUseCallback(), callback), "The getter must return the current callback.");
local _tResults = table.pack(_oAbility.use("context", nil, 7, nil));
check(_tResults.n == 5 and rawequal(_tResults[1], _oAbility), "Use must pass this before all context.");
check(_tResults[2] == "context" and _tResults[3] == nil and _tResults[4] == 7 and _tResults[5] == nil,
    "Use must preserve interior and trailing nil arguments/results.");
check(_oAbility.getCost(Protean.VALUE_BASE) == 12, "Use must not automatically spend cost.");

rejects(function() _oAbility.setOnUseCallback(false); end, "Nonfunction callbacks must fail.");
check(rawequal(_oAbility.getOnUseCallback(), callback), "Invalid setters must retain the previous callback.");
rejects(function() CoGAbility("Bad", "Bad callback", nil, nil, 7); end, "Constructors must reject invalid callbacks.");
rejects(function() CoGAbility(" ", "Description"); end, "Inherited metadata validation must still run.");

_oAbility.setOnUseCallback(function() error("use failure"); end);
rejects(function() _oAbility.use(); end, "Callback errors must propagate.");
_oAbility.setOnUseCallback(nil);
check(select("#", _oAbility.use()) == 0, "Nil must restore the shared default.");
check(rawequal(_oAbility.getOnUseCallback(), _oOther.getOnUseCallback()), "Default callbacks must share identity.");

-- Empty default boxes reconstruct the no-op without serializing a compiled scope.
local _default = _oAbility.getOnUseCallback();
local _oDefaultLoaded = deserialize(serialize(_oAbility));
check(select("#", _oDefaultLoaded.use()) == 0, "The default callback must survive save/load.");
check(rawequal(_oAbility.getOnUseCallback(), _default), "Saving must not edit the live callback box.");
check(_oDefaultLoaded.getCost(Protean.VALUE_BASE) == 12, "Default saves must retain cost state.");
check(rawequal(_oDefaultLoaded.getAffixSystem().getOwner(), _oDefaultLoaded), "Loading must reconnect inherited ownership.");

_oAbility.setOnUseCallback(callback);
_oAbility.getTagSystem().add("MAGIC");
local _tGraph = deserialize(serialize({ability = _oAbility, cost = _oAbility.getCost()}));
check(rawequal(_tGraph.ability.getCost(), _tGraph.cost), "Shared cost identity must survive graph save/load.");
check(not rawequal(_tGraph.cost, _oAbility.getCost()), "Restored cost must be independent of the original.");
check(rawequal(_tGraph.ability.use(), _tGraph.ability), "Restored callbacks must receive the restored ability.");
check(_tGraph.ability.getTagSystem().contains("MAGIC"), "Inherited tags must survive save/load.");
_tGraph.cost.setValue(Protean.VALUE_BASE, 24);
check(_tGraph.ability.getCost(Protean.VALUE_BASE) == 24 and _oAbility.getCost(Protean.VALUE_BASE) == 12,
    "Restored cost changes must remain independent.");
_tGraph.ability.setOnUseCallback();
check(select("#", _tGraph.ability.use()) == 0, "Restored callbacks must support reset.");

lxc.loadSources({["AbilityFixtures.lxc"] = [[
    namespace CoG.Tests {
        class DerivedAbility : CoG.CoGAbility {
            public DerivedAbility() { base("Derived", "Derived ability"); }
            public replaceCost(nValue) { this.Cost = Protean(nValue); }
            public override use(...) { return "overridden", ...; }
        }
    }
]]}, _G);
local _oDerived = CoG.Tests.DerivedAbility();
_oDerived.replaceCost(9);
check(_oDerived.getCost(Protean.VALUE_BASE) == 9, "Subclasses must retain protected cost access.");
check(_oDerived.use() == "overridden", "Use must remain overridable.");
local _oDerivedLoaded = deserialize(serialize(_oDerived));
check(_oDerivedLoaded.getCost(Protean.VALUE_BASE) == 9 and _oDerivedLoaded.use() == "overridden",
    "Derived behavior and cost must survive save/load.");

rejects(function()
    lxc.loadSources({["BadAbility.lxc"] = [[
        namespace CoG.Tests {
            class BadAbility : CoG.CoGAbility {
                public override getCost(nType) {}
            }
        }
    ]]}, _G);
end, "getCost must remain final.");
check(rawequal(deserialize(serialize(CoGAbility)), CoGAbility), "Class references must retain persistence identity.");

print("PASS CoGAbility: ".._nChecks.." checks.");

