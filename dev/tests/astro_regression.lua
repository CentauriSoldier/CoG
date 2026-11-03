--[[!
@fqxn CoG.Tests.Astro
@desc Checks coherent user units, astronomical helpers, synchronized orbital links,
    cycles, cross-instance private access and native graph persistence without files.
    Run from the CoG root: lua dev/tests/astro_regression.lua.
!]]
local pTests = assert(debug.getinfo(1, "S").source:match("^@(.+)[/\\][^/\\]+$"));
local pCoG = pTests.."/../..";
package.path = pCoG.."/?.lua;"..pCoG.."/../LuaEx/?.lua;"..package.path;
require("LuaEx.init");
require("cog.load")();

local Astro = CoG.CoGAstro;
local nChecks = 0;

--[[!
@fqxn CoG.Tests.Astro.check
@desc Counts an observable invariant and identifies its failure.
!]]
local function check(bCondition, sMessage)
    assert(bCondition, sMessage);
    nChecks = nChecks + 1;
end

--[[!
@fqxn CoG.Tests.Astro.near
@desc Compares floating-point calculations using a relative tolerance.
!]]
local function near(nActual, nExpected, sMessage)
    check(math.abs(nActual - nExpected) <= 1e-10 * math.max(1, math.abs(nExpected)), sMessage);
end

--[[!
@fqxn CoG.Tests.Astro.reject
@desc Requires an unsupported request to raise without treating that as success.
!]]
local function reject(fAction, sMessage)
    check(not pcall(fAction), sMessage);
end

--[[!
@fqxn CoG.Tests.Astro.body
@desc Creates an independent named fixture in abstract units.
!]]
local function body(sName, nMass, nRadius)
    return Astro(sName, "Astro regression", nil, nil,
        {Mass = nMass or 1, Radius = nRadius or 1});
end

local oStar = body("Star", 1000, 10);
local oPlanet = body("Planet", 1, 1);
local oMoon = body("Moon", 0.1, 0.1);
local oOther = body("Other", 2, 2);
check(class.isa(oStar, CoG.CoGObject), "shared object foundation");
check(oStar.getUnits().Mass == "units" and oStar.getUnits().GravitationalConstant == 1, "abstract unit defaults");
near(oStar.getDiameter(), 20, "diameter");
near(oStar.getSurfaceArea(), 400 * math.pi, "surface area");
near(oStar.getVolume(), (4000 / 3) * math.pi, "volume");
near(oStar.getDensity(), 1000 / ((4000 / 3) * math.pi), "density");
near(oStar.getGravitationalParameter(), 1000, "gravitational parameter");
near(oStar.getSurfaceGravity(), 10, "surface gravity");
near(oStar.getEscapeVelocity(), math.sqrt(200), "escape velocity");
near(oStar.getGravitationalAcceleration(20), 2.5, "exterior gravity");
near(oStar.getGravitationalForce(oPlanet, 10), 10, "gravitational force");
near(oStar.getGravitationalForce(oPlanet, 10), oPlanet.getGravitationalForce(oStar, 10), "force symmetry");
near(oStar.getBarycenterDistance(oPlanet, 10) + oPlanet.getBarycenterDistance(oStar, 10), 10, "barycenter distances sum to separation");
local nPeriod = 2 * math.pi * math.sqrt(10 ^ 3 / 1001);
near(oStar.getOrbitalPeriod(oPlanet, 10), nPeriod, "two-body period includes both masses");
near(oStar.getSynchronousRotationPeriod(oPlanet, 10), nPeriod, "explicit synchronous rotation assumption");
near(oStar.getCircularOrbitalSpeed(oPlanet, 10), math.sqrt(1001 / 10), "relative circular speed");
near(oStar.getSemiMajorAxisForPeriod(oPlanet, nPeriod), 10, "inverse period calculation");
check(oStar.getRotationPeriod() == 0 and oStar.getAngularVelocity() == 0 and oStar.getEquatorialSpeed() == 0, "no-rotation convention");
oStar.setRotationPeriod(20);
near(oStar.getAngularVelocity(), math.pi / 10, "angular speed");
near(oStar.getEquatorialSpeed(), math.pi, "equatorial speed");
near(oStar.getRotationPeriodForSpeed(math.pi), 20, "rotation from surface speed");
check(oStar.getRotationPeriod() == 20, "calculation helpers do not mutate spin");

local tUnits = {Mass = "mass-unit", Length = "length-unit", Time = "time-unit", GravitationalConstant = 3};
local oCustom = Astro("Custom", "User units", nil, nil, {Mass = 8, Radius = 2, Units = tUnits});
near(oCustom.getSurfaceGravity(), 6, "custom G");
tUnits.GravitationalConstant = 99;
local tView = oCustom.getUnits();
tView.GravitationalConstant = 50;
check(oCustom.getUnits().GravitationalConstant == 3, "unit settings are independent copies");
reject(function() oCustom.getOrbitalPeriod(oPlanet, 10); end, "incompatible unit systems");

-- Both public mutation directions delegate to the same private graph operation.
check(type.isnull(oPlanet.getOrbitalParent()), "initial root");
oPlanet.setOrbitalParent(oStar);
check(rawequal(oStar.getOrbitingBodies()[1], oPlanet), "child-side assignment updates parent");
oStar.addOrbitingBody(oPlanet);
check(#oStar.getOrbitingBodies() == 1, "repeated adoption has no duplicate");
oPlanet.addOrbitingBody(oMoon);
reject(function() oStar.setOrbitalParent(oMoon); end, "long ancestry cycle");
reject(function() oPlanet.addOrbitingBody(oPlanet); end, "self cycle");
check(type.isnull(oStar.getOrbitalParent()) and rawequal(oMoon.getOrbitalParent(), oPlanet), "rejected cycles preserve graph");
local _, bRemoved = oOther.removeOrbitingBody(oPlanet);
check(not bRemoved and rawequal(oPlanet.getOrbitalParent(), oStar), "unrelated removal is inert");
for n = 1, 20 do
    local oParent = n % 2 == 0 and oStar or oOther;
    local oPrevious = n % 2 == 0 and oOther or oStar;
    oParent.addOrbitingBody(oPlanet);
    check(rawequal(oPlanet.getOrbitalParent(), oParent), "reparented child pointer");
    check(#oParent.getOrbitingBodies() == 1 and #oPrevious.getOrbitingBodies() == 0, "old/new lists synchronized");
end
local tChildren = oStar.getOrbitingBodies();
tChildren[1] = nil;
check(#oStar.getOrbitingBodies() == 1, "returned lists do not expose private storage");
reject(function() return oStar.orbit; end, "private relationship storage");
reject(function() oStar.setOrbitalParent({}); end, "invalid parent");

-- Parent and child form a serialization graph cycle, not an ancestry cycle.
local tRestored = deserialize(serialize({star = oStar, planet = oPlanet, alias = oPlanet, custom = oCustom}));
check(rawequal(tRestored.planet, tRestored.alias), "shared graph identity");
check(rawequal(tRestored.planet.getOrbitalParent(), tRestored.star), "restored parent");
check(rawequal(tRestored.star.getOrbitingBodies()[1], tRestored.planet), "restored child");
check(rawequal(tRestored.planet.getOrbitingBodies()[1].getOrbitalParent(), tRestored.planet), "restored grandchild");
near(tRestored.custom.getSurfaceGravity(), 6, "custom units survive persistence");
tRestored.planet.setOrbitalParent(nil);
check(#tRestored.star.getOrbitingBodies() == 0 and #oStar.getOrbitingBodies() == 1, "restored changes are independent");
check(type.isnull(tRestored.planet.getOrbitalParent()), "detach via nil");
oStar.removeOrbitingBody(oPlanet);
check(type.isnull(oPlanet.getOrbitalParent()) and #oStar.getOrbitingBodies() == 0, "parent-side detach");
reject(function() clone(oStar); end, "base clone requires explicit graph policy");

for _, nBad in ipairs({0, -1, math.huge, 0/0}) do
    reject(function() oStar.setMass(nBad); end, "invalid mass");
    reject(function() oStar.setRadius(nBad); end, "invalid radius");
    reject(function() oStar.getOrbitalPeriod(oPlanet, nBad); end, "invalid orbital distance");
end
reject(function() oStar.getGravitationalAcceleration(1); end, "interior gravity requires a density model");
check(oStar.getMass() == 1000 and oStar.getRadius() == 10, "failed setters preserve physics");
print("PASS CoGAstro: "..nChecks.." checks; units, calculations, synchronized graphs, cycles and persistence.");
