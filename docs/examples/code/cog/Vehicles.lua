-- Locate the shared bootstrap relative to this tutorial, regardless of cwd.
local pSource = debug.getinfo(1, "S").source:sub(2):gsub("\\", "/");
local pExamples = assert(pSource:match("^(.*)/code/[^/]+/[^/]+%.lua$"));
local tPaths = dofile(pExamples.."/support/bootstrap.lua");
local pDocs = tPaths.docs;

local _cBase = CoG.CoGVehicle;
local _cVehicle = require("examples.visual.Vehicles.Vehicle");
local D         = require("examples.support.tutorial").new("Vehicles", "Identity, fuel, flags, configured component objects and explicit concrete copying.");
local oFuel     = Pool(80, 60);
local oBody     = Pool(100, 100);
local oOwner    = Pool(); -- Any class instance can supply an owner identity.
local sSlot     = _cBase.COMPONENT[1].Name;

D.section("Defaults", "Omitted values allocate independent fuel and slot storage. Tradable defaults true; the other flags default false.");
local oDefault = _cBase();
D.equal("Default name",       oDefault.getName(), "Vehicle");
D.equal("Default efficiency", oDefault.getDistancePerFuelUnit(), 0);
D.check("Default tradable",  oDefault.isTradable());
D.check("Default owner null", type.isnull(oDefault.getOwner()));
D.check("Fuel independent",   not rawequal(oDefault.getFuelPool(), _cBase().getFuelPool()));

D.section("Concrete construction", "The example subclass translates named settings into CoGVehicle's positional constructor. Owner, component and fuel references are retained.");
local oVehicle = _cVehicle({
    name        = "Trailwarden",
    description = "An expedition rover.",
    fuel        = oFuel,
    components  = {[sSlot] = oBody},
    owner       = oOwner,
    efficiency  = 4,
    speed       = 72,
    value       = 18000,
    unmanned    = false,
    tradeable   = false,
    quest       = true,
    exclusive   = true,
    inimitable  = true,
    environment = "ExampleGarageWorkshop",
});
D.equal("Name",        oVehicle.getName(), "Trailwarden");
D.equal("Description", oVehicle.getDescription(), "An expedition rover.");
D.equal("Speed",       oVehicle.getMaxSpeed(), 72);
D.equal("Value",       oVehicle.getValue(), 18000);
D.check("Fuel identity",  rawequal(oFuel,  oVehicle.getFuelPool()));
D.check("Owner identity", rawequal(oOwner, oVehicle.getOwner()));
D.check("Explicit false preserved", not oVehicle.isTradable() and not oVehicle.isUnmanned());
D.check("Other flags preserved", oVehicle.isQuest() and oVehicle.isExclusive() and oVehicle.isInimitable());
D.check("Vehicle inheritance", class.isa(oVehicle, _cBase));

D.section("Movement is application policy", "For a 40 km journey at 4 km/unit, the example spends 10 units after checking fuel. CoGVehicle does not perform this calculation.");
local nDistance = 40;
local nCost     = nDistance / oVehicle.getDistancePerFuelUnit();
assert(nCost <= oFuel.get(), "Not enough fuel for the trip.");
oFuel.adjust(-nCost);
D.equal("Remaining fuel", oVehicle.getFuelPool().get(), 50);
oFuel.set(1000);
D.equal("Pool clamps to capacity", oFuel.get(), 80);
oFuel.set(10, Pool.ASPECT.RESERVED_FLAT);
D.equal("Reserved capacity", oFuel.get(Pool.ASPECT.AVAILABLE), 70);

D.section("Components and snapshots", "The slot table is copied, while each installed component retains identity. String and enum slot keys refer to the same configured slot.");
D.check("Component identity", rawequal(oVehicle.getComponent(_cBase.COMPONENT[1]), oBody));
local tSnapshot = oVehicle.getComponents();
tSnapshot[sSlot] = null;
D.check("Binding snapshot independent", rawequal(oVehicle.getComponent(sSlot), oBody));
local oOther = _cVehicle({components = {[sSlot] = oBody}});
oBody.adjust(-25);
D.equal("Shared condition", oOther.getComponent(sSlot).get(), 75);
oOther.setComponent(sSlot, nil);
D.check("Nil clears slot", type.isnull(oOther.getComponent(sSlot)));
D.check("Other binding unchanged", rawequal(oVehicle.getComponent(sSlot), oBody));

D.section("Inherited metadata", "Names, descriptions, rarity, tags and event dispatch come from CoGObject. The example uses the default event environment.");
oVehicle.getTagSystem().add("expedition");
D.check("Tag added", oVehicle.getTagSystem().contains("EXPEDITION"));
D.show("Rarity", oVehicle.getRarity().Name);
oVehicle.fireEvent(_cVehicle.EVENT.INSPECTION, oVehicle);
D.equal("Inspection hook ran", oVehicle.getInspectionCount(), 1);
D.equal("Configured event environment", oVehicle.getEventEnvironment(), "ExampleGarageWorkshop");
D.show("Observed callback lexical environment", oVehicle.getLastEnvironment());
D.note("Callbacks and copying are defined by this concrete example; vehicle flags remain caller-enforced metadata.");

D.section("Explicit clone policy", "The base rejects copying. This concrete subclass copies fuel, components and tags, retains the owner, and treats Inimitable as caller-enforced metadata.");
D.reject("Base clone requires subclass", function() clone(_cBase()); end);
local oCopy = clone(oVehicle);
D.check("Fresh instance", not rawequal(oCopy, oVehicle));
D.check("Fuel independent", not rawequal(oCopy.getFuelPool(), oFuel));
D.check("Body independent", not rawequal(oCopy.getComponent(sSlot), oBody));
D.check("Owner shared", rawequal(oCopy.getOwner(), oOwner));
D.equal("Fresh inspection count", oCopy.getInspectionCount(), 0);
oCopy.getFuelPool().adjust(-5);
oCopy.getComponent(sSlot).adjust(-10);
oCopy.getTagSystem().add("copy only");
D.equal("Original condition retained", oBody.get(), 75);
D.equal("Original fuel retained", oFuel.get(), 70);
D.check("Original tags independent", not oVehicle.getTagSystem().contains("COPY ONLY"));

D.section("Contract failures", "Invalid input is rejected. Unknown slots and plain tables never become component bindings.");
D.reject("Negative speed",    function() _cVehicle({speed = -1}); end);
D.reject("Nonfinite value",   function() _cVehicle({value = math.huge}); end);
D.reject("Wrong flag",        function() _cVehicle({tradeable = "yes"}); end);
D.reject("Wrong fuel",        function() _cVehicle({fuel = {}}); end);
D.reject("Wrong owner",       function() _cVehicle({owner = {}}); end);
D.reject("Unknown slot",      function() oVehicle.setComponent("UNKNOWN", oBody); end);
D.reject("Invalid component", function() oVehicle.setComponent(sSlot, {}); end);
D.check("Rejected component unchanged", rawequal(oVehicle.getComponent(sSlot), oBody));

D.section("Native persistence", "Ordinary Lua callbacks and shared component identities participate in native graph snapshots.");
local oRestored = deserialize(serialize(oVehicle));
D.equal("Restored fuel", oRestored.getFuelPool().get(), oVehicle.getFuelPool().get());
D.check("Restored owner is independent", not rawequal(oRestored.getOwner(), oVehicle.getOwner()));
local nBefore = oRestored.getInspectionCount();
oRestored.fireEvent(_cVehicle.EVENT.INSPECTION, oRestored);
D.equal("Restored callback targets restored vehicle", oRestored.getInspectionCount(), nBefore + 1);
D.equal("Original callback count unchanged", oVehicle.getInspectionCount(), 1);
D.finish();
