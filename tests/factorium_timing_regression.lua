-- Native declarations queue contracts; registration waits for publication.
local pTests = assert(debug.getinfo(1, "S").source:match("^@(.+)[/\\][^/\\]+$"));
local pCoG = pTests .. "/..";
package.path = pCoG .. "/?.lua;" .. pCoG .. "/../LuaEx/?.lua;"
    .. pCoG .. "/../Dox/?.lua;" .. pCoG .. "/../wxLuma/?.lua;" .. package.path;
require("LuaEx.load")(5);
require("cog.load")();

local LXC = require("LuaEx.lib.lxc");
LXC.loadSources({["FactoriumTimingFixture.lxc"] = [=[
namespace TimingLifecycleTest {
    class Parent : CoG.CoGBase requires(CoG.Factorium) {
        public static EarlyFailed = false;
        public static EarlyReason = "";
        public static ParentChecks = 0;
        public static FactoryCalls = 0;

        static Parent() {
            assert(CoG.Factorium.declareClass(Parent, {
                Blueprint = {ParentValue = 10},
                validateBlueprint = function(bp)
                    Parent.ParentChecks = Parent.ParentChecks + 1;
                    return type(bp.ParentValue) == "number";
                end,
                fromBlueprint = function(bp)
                    Parent.FactoryCalls = Parent.FactoryCalls + 1;
                    return bp;
                end,
            }));
            local ok, reason = CoG.Factorium.registerDeclaredClasses();
            Parent.EarlyFailed = not ok;
            Parent.EarlyReason = reason or "";
        }
    }

    class Child : Parent {
        public static ChildChecks = 0;

        static Child() {
            assert(CoG.Factorium.declareClass(Child, {
                Blueprint = {ChildValue = 20},
                validateBlueprint = function(bp)
                    Child.ChildChecks = Child.ChildChecks + 1;
                    return type(bp.ChildValue) == "number";
                end,
                fromBlueprint = function(bp)
                    Parent.FactoryCalls = Parent.FactoryCalls + 1;
                    return bp;
                end,
            }));
        }
    }

    class Unrelated {
    }

    class PrivateOwner {
        private class Hidden : CoG.CoGBase {
        }
        public static declareHidden() {
            return CoG.Factorium.declareClass(PrivateOwner.Hidden, {
                Blueprint = {},
                validateBlueprint = function() return true; end,
                fromBlueprint = function() return {}; end,
            });
        }
        public static hiddenRegistered() {
            return CoG.Factorium.isClassRegistered(PrivateOwner.Hidden);
        }
    }
}

]=]}, _G);

local Factorium = CoG.Factorium;
local Test = TimingLifecycleTest;
local nChecks = 0;
local function check(bCondition, sMessage)
    assert(bCondition, sMessage);
    nChecks = nChecks + 1;
end

Factorium.setLog(function() end);
check(Test.Parent.EarlyFailed and Test.Parent.EarlyReason:find("publication", 1, true),
    "early registration must report unavailable publication");
check(Test.Parent.ParentChecks == 0 and Test.Child.ChildChecks == 0
    and Test.Parent.FactoryCalls == 0, "declaration invokes no validator or factory");
check(not Factorium.isClassRegistered(Test.Parent)
    and not Factorium.isClassRegistered(Test.Child), "declared is not registered");
check(class.ischild(Test.Child, CoG.CoGBase), "native ancestry remains valid");
check(Factorium.registerDeclaredClasses(), "post-publication registration");
check(Factorium.isClassRegistered(Test.Parent)
    and Factorium.isClassRegistered(Test.Child), "both contracts registered");
check(Factorium.registerDeclaredClasses(), "empty finalization is repeatable");
check(Factorium.declareClass(Test.Child, {}), "first accepted declaration retained");
check(not Factorium.declareClass({}, {}), "nonclass declaration rejected");
check(not Factorium.declareClass(Test.Unrelated, {}), "incomplete contract rejected");
check(Test.Parent.ParentChecks == 0 and Test.Child.ChildChecks == 0
    and Test.Parent.FactoryCalls == 0, "registration invokes no gameplay callback");

local tMod = {
    id = "11111111-1111-4111-8111-111111111111",
    name = "Timing test", authors = {"test"}, description = "Test",
    released = "2026-11-01", updated = "2026-11-01", version = 1,
    contact = "", website = "", required = {}, conflicts = {},
    blueprints = {{id = "child", class = "TimingLifecycleTest.Child", ChildValue = 30}},
};
local bImported, tReport = Factorium.importMod(tMod);
check(bImported and tReport.loaded == 1 and tReport.skipped == 0, "definition import");
check(Test.Parent.ParentChecks == 1 and Test.Child.ChildChecks == 1,
    "all ancestor validators run");
check(Test.Parent.FactoryCalls == 0, "import does not construct gameplay objects");
check(Factorium.finalizeImports().accepted == 1, "mod publication");
local tBlueprint = Factorium.getBlueprint(Test.Child, "child");
check(tBlueprint.ParentValue == 10 and tBlueprint.ChildValue == 30,
    "inherited defaults and explicit overrides");
check(tMod.blueprints[1].ParentValue == nil, "input definition unchanged");

check(not Factorium.registerClass(Test.Unrelated, {
    Blueprint = {}, validateBlueprint = function() return true; end,
    fromBlueprint = function() return {}; end,
}), "unrelated class rejected by unchanged registration validation");
check(Test.PrivateOwner.declareHidden(), "private declaration only queues a request");
local bRegistered, sReason = Factorium.registerDeclaredClasses();
check(not bRegistered and type(sReason) == "string", "inaccessible class rejected");
check(not Test.PrivateOwner.hiddenRegistered(), "private class not allowlisted");
check(class.getbyname("TimingLifecycleTest.PrivateOwner.Hidden") == nil,
    "private class remains inaccessible");
print("PASS Factorium declaration timing: " .. nChecks .. " checks");
