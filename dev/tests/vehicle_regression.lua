--[[!
@fqxn CoG.Tests.Vehicle
@desc Verifies vehicle defaults, metadata, components, shared fuel/owner graphs and
    application-defined cloning. Run in a fresh Lua 5.4 process:
    lua tests/vehicle_regression.lua
    Optional overlay mode verifies that configuration cannot add enum declarations.
!]]
local _sMode = ... or "defaults";
local _pTests = assert(debug.getinfo(1, "S").source:match("^@(.+)[/\\][^/\\]+$"));
local _pCoG = _pTests.."/..";
local _nChecks = 0;
local _loadfile = loadfile;

--[[!
@fqxn CoG.Tests.Vehicle.check
@desc Counts a successful assertion or raises a descriptive failure.
!]]
local function check(bCondition, sMessage)
    assert(bCondition, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn CoG.Tests.Vehicle.rejects
@desc Requires an invalid operation to raise an error.
!]]
local function rejects(fOperation, sMessage)
    check(not pcall(fOperation), sMessage);
end

package.path = _pCoG.."/?.lua;".._pCoG.."/../LuaEx/?.lua;"..package.path;
require("LuaEx.load")(3);
local _cVehicle = class.getbyname("CoG.CoGVehicle");
check(class.is(_cVehicle) and CoGVehicle == nil, "LuaEx must discover the vehicle before alias publication.");
local _init = require("cog.load");

if (_sMode == "overlay") then
    loadfile = function(pFile, sMode, tEnvironment)
        if (pFile:match("[/\\]VehicleReviewConfig%.lua$")) then
            return load([[return {CoGVehicle = {
                COMPONENT = CoGBase.purge({"BODY", "ENGINE"}),
            }};]], "@"..pFile, sMode, tEnvironment);
        end

        if (tEnvironment ~= nil) then return _loadfile(pFile, sMode, tEnvironment); end
        return _loadfile(pFile, sMode);
    end
end

local _bLoaded, _vResult = pcall(_init, _sMode == "overlay" and 1 or 0, "VehicleReviewConfig");
loadfile = _loadfile;
if (_sMode == "overlay") then
    check(not _bLoaded and tostring(_vResult):find("COMPONENT declarations", 1, true),
        "Late configuration must not change declared component identities.");
    print("PASS CoGVehicle (overlay): ".._nChecks.." checks.");
    return;
end
assert(_bLoaded, _vResult);
check(rawequal(CoGVehicle, _cVehicle), "The short alias must retain class identity.");
check(rawequal(require("cog.Objects.VehicleSystem.CoGVehicle"), CoGVehicle), "The require alias must retain identity.");
check(not class.is(CoG) and rawequal(CoG.CoGVehicle, CoGVehicle), "CoG must remain the direct namespace.");

lxc.loadSources({["VehicleFixtures.lxc"] = [[
    namespace CoG.Tests {
        class VehiclePart {
            public VehiclePart() {}
        }

        class VehicleOwner {
            public vehicle = null;
            public VehicleOwner() {}
        }

        class VehicleFuel : CoG.Pool {
            public VehicleFuel(nMaximum, nCurrent) { base(nMaximum, nCurrent); }
        }

        class CustomVehicle : CoG.CoGVehicle {
            public CustomVehicle(oFuel, tComponents, oOwner) {
                base(oFuel, nil, nil, tComponents, nil, nil, nil, nil, nil, nil, oOwner);
            }

            public override getMaxSpeed() { return 99; }
            public override isTradable() { return false; }

            public override operator clone() {
                return CustomVehicle(this.getFuelPool(), this.getComponents(), this.getOwner());
            }
        }
    }
]]}, _G);

local _v = CoGVehicle();
local _other = CoGVehicle();
check(class.isa(_v, CoGObject) and class.isa(_v, CoGBase), "Vehicle ancestry must remain intact.");
check(_v.getName() == "Vehicle" and _v.getDescription() == "A vehicle.", "Metadata defaults must be retained.");
check(_v.getRarity() == CoG.LEVEL[1], "Default rarity must come from CoGObject.");
check(_v.getValue() == 0 and _v.getMaxSpeed() == 0 and _v.getDistancePerFuelUnit() == 0, "Numeric defaults must be zero.");
check(_v.isTradable(), "Trading metadata must default to true.");
check(not _v.isUnmanned() and not _v.isQuest() and not _v.isExclusive() and not _v.isInimitable(),
    "Other flags must default to false.");
check(type.isnull(_v.getOwner()), "Omitted owners must become null.");
check(class.isa(_v.getFuelPool(), Pool) and _v.getFuelPool().get() == 1, "Omitted fuel must be a fresh default Pool.");
check(not rawequal(_v.getFuelPool(), _other.getFuelPool()), "Default fuel must be independent.");
_v.getFuelPool().setEmpty();
check(_other.getFuelPool().get() == 1, "Default fuel mutations must not affect other vehicles.");
check(type.isnull(_v.getComponent("BODY")) and type.isnull(_v.getComponent(CoGVehicle.COMPONENT.BODY)),
    "Omitted component bindings must be null.");

local _fuel = Pool(100, 40);
local _owner = CoG.Tests.VehicleOwner();
local _parts = {BODY = _fuel};
local _custom = CoGVehicle(_fuel, true, 2.5, _parts, 150, false, true, true, true,
    30, _owner, "Rover", "A rover", CoG.LEVEL.THREE);
_owner.vehicle = _custom;
check(rawequal(_custom.getFuelPool(), _fuel), "Supplied fuel identity must be retained.");
check(rawequal(_custom.getOwner(), _owner), "Supplied owner identity must be retained.");
check(rawequal(_custom.getComponent("BODY"), _fuel), "Supplied component identity must be retained.");
check(_custom.getName() == "Rover" and _custom.getDescription() == "A rover" and
    _custom.getRarity() == CoG.LEVEL.THREE, "Trailing metadata arguments must be forwarded.");
check(_custom.getDistancePerFuelUnit() == 2.5 and _custom.getValue() == 150 and _custom.getMaxSpeed() == 30,
    "Numeric metadata must be retained.");
check(_custom.isUnmanned() and _custom.isQuest() and _custom.isExclusive() and _custom.isInimitable() and
    not _custom.isTradable(), "Boolean metadata must preserve true and explicit false.");
_parts.BODY = null;
check(rawequal(_custom.getComponent("BODY"), _fuel), "Initializer slot tables must be copied.");

local _copySlots = _custom.getComponents();
_copySlots.BODY = null;
check(rawequal(_custom.getComponent("BODY"), _fuel), "Component getters must return copied bindings.");
local _part = CoG.Tests.VehiclePart();
check(rawequal(_v.setComponent(CoGVehicle.COMPONENT.BODY, _part), _v), "Component setters must support chaining.");
check(rawequal(_v.getComponent("BODY"), _part), "Component setters must retain instances.");
_v.setComponent("BODY", nil);
check(type.isnull(_v.getComponent("BODY")), "Nil must clear a slot.");
_v.setComponent("BODY", null);
check(type.isnull(_v.getComponent("BODY")), "Explicit null must clear a slot.");
rejects(function() _v.getComponent("body"); end, "Slot names must remain case-sensitive.");
rejects(function() _v.setComponent("UNKNOWN", _part); end, "Unknown slots must fail.");
rejects(function() _v.setComponent("BODY", {}); end, "Plain tables cannot be components.");
rejects(function() CoGVehicle(nil, nil, nil, {BODY = _part, [CoGVehicle.COMPONENT.BODY] = _part}); end,
    "Duplicate logical slots must fail.");
rejects(function() return _v.Components; end, "Slot storage must remain protected.");

local _tInvalid = {
    {1, false}, {1, null}, {1, {}}, {2, 1}, {3, -1}, {3, math.huge},
    {4, false}, {5, -1}, {5, 0/0}, {6, 0}, {7, "true"}, {8, 1}, {9, 1},
    {10, -1}, {10, math.huge}, {11, false}, {11, {}}, {12, ""}, {13, " "}, {15, false},
};

for _, tCase in ipairs(_tInvalid) do
    local tArguments = {n = tCase[1], [tCase[1]] = tCase[2]};
    rejects(function() CoGVehicle(table.unpack(tArguments, 1, tArguments.n)); end,
        "Invalid vehicle argument "..tostring(tCase[1]).." must fail.");
end

local _subFuel = CoG.Tests.VehicleFuel(50, 20);
check(rawequal(CoGVehicle(_subFuel).getFuelPool(), _subFuel), "Fuel subclasses must be accepted.");
local _subLoaded = deserialize(serialize(CoGVehicle(_subFuel)));
check(class.isinstanceof(_subLoaded.getFuelPool(), CoG.Tests.VehicleFuel) and
    _subLoaded.getFuelPool().get() == 20, "Fuel subtype identity and values must survive save/load.");
rejects(function() CoGVehicle(_part); end, "Other class instances cannot be fuel.");

-- Native graph persistence must preserve sharing and explicit owner cycles.
local _nFuelCallbacks = 0;
_fuel.setEventCallback(Pool.EVENT.ON_DECREASE, function() _nFuelCallbacks = _nFuelCallbacks + 1; end);
local _graph = deserialize(serialize({vehicle = _custom, fuel = _fuel, owner = _owner}));
check(rawequal(_graph.vehicle.getFuelPool(), _graph.fuel), "Restored fuel aliases must share identity.");
check(rawequal(_graph.vehicle.getComponent("BODY"), _graph.fuel), "Restored component aliases must share fuel identity.");
check(rawequal(_graph.vehicle.getOwner(), _graph.owner), "Restored owner aliases must share identity.");
check(rawequal(_graph.owner.vehicle, _graph.vehicle), "Explicit owner cycles must survive.");
check(rawequal(_graph.vehicle.getAffixSystem().getOwner(), _graph.vehicle), "Inherited affix ownership must reconnect.");
check(_graph.vehicle.getName() == "Rover" and _graph.vehicle.getValue() == 150 and
    _graph.vehicle.getRarity() == CoG.LEVEL.THREE, "Metadata must survive save/load.");
check(_graph.vehicle.isUnmanned() and not _graph.vehicle.isTradable(), "Flags must survive save/load.");
_graph.fuel.adjust(-1);
check(_nFuelCallbacks == 0 and _fuel.get() == 40, "Restored Pool callbacks must be inactive and fuel independent.");

_v.setComponent("BODY", _v);
local _self = deserialize(serialize(_v));
check(rawequal(_self.getComponent("BODY"), _self), "Self component references must survive.");
rejects(function() clone(_custom); end, "Base vehicles must retain their explicit clone policy.");
rejects(function() clone(_other); end, "Inimitable=false must not invent a generic copying policy.");
local _derived = CoG.Tests.CustomVehicle(_fuel, {BODY = _part}, _owner);
check(_derived.getMaxSpeed() == 99 and not _derived.isTradable(), "Metadata getters must remain overridable.");
local _derivedCopy = clone(_derived);
check(class.isinstanceof(_derivedCopy, CoG.Tests.CustomVehicle) and not rawequal(_derivedCopy, _derived),
    "Subclasses must be able to define a concrete clone operator.");
check(rawequal(_derivedCopy.getFuelPool(), _fuel), "Application clone policy must control sharing.");



check(rawequal(deserialize(serialize(CoGVehicle.COMPONENT.BODY)), CoGVehicle.COMPONENT.BODY),
    "Component enum identity must survive persistence.");
print("PASS CoGVehicle (".._sMode.."): ".._nChecks.." checks.");


