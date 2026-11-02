--[[!
@fqxn CoG.Tests.Foundation
@desc Runs the CoGBase foundation regression checks in a fresh Lua 5.4 process.
    CoGBase is on package.path before LuaEx initializes; no CoGBase class is loaded here.
    Run from the CoGBase root: lua tests/cog_regression.lua
    Add overlay as the first argument to exercise a user configuration overlay.
    The overlay is supplied in memory and does not write a user configuration file.
!]]
local _sMode = ... or "defaults";
local _pTests = assert(debug.getinfo(1, "S").source:match("^@(.+)[/\\][^/\\]+$"),
    "Run this test as a saved Lua file.");
local _pCoG = _pTests.."/..";
local _nChecks = 0;
local _loadfile = loadfile;

--[[!
@fqxn CoG.Tests.Foundation.check
@desc Counts a successful assertion or stops at the first failed contract.
@param boolean bCondition Expected true condition.
@param string sMessage Failure description.
!]]
local function check(bCondition, sMessage)
    assert(bCondition, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn CoG.Tests.Foundation.rejects
@desc Confirms an invalid operation raises an error.
@param function fOperation Operation which must fail.
@param string sMessage Failure description when the operation succeeds.
!]]
local function rejects(fOperation, sMessage)
    check(not pcall(fOperation), sMessage);
end

-- Both sibling projects must be discoverable before LuaEx's initializer runs.
package.path = _pCoG.."/?.lua;".._pCoG.."/../LuaEx/?.lua;"..package.path;
require("LuaEx.load")(3);

local _cCoG = class.getbyname("CoG.CoGBase");
check(class.is(_cCoG), "LuaEx must discover CoGBase.lxc.");
check(CoGBase == nil, "Discovery must leave the public CoGBase alias for cog.load.");
rejects(function() return _cCoG.config; end, "Discovery must not initialize configuration.");

local _init = require("cog.load");
local _sPackagePath = package.path;

rejects(function() _init(-1); end, "Negative parent levels must fail.");
rejects(function() _init(0, "bad.lua"); end, "A configuration basename cannot contain an extension.");
check(package.path == _sPackagePath, "Invalid options must preserve package.path.");

if (_sMode == "overlay") then
    -- Let the real assembler load a synthetic user chunk in its real environment.
    loadfile = function(pFile, sMode, tEnvironment)
        if (pFile:match("[/\\]CoGReviewConfig%.lua$")) then
            return load([[
                return {
                    app = {name = "CoGBase regression", path = CoGBase.purge({save = "saves/"})},
                    StatusTracker = {regression = true},
                };
            ]], "@"..pFile, sMode, tEnvironment);
        end

        return _loadfile(pFile, sMode, tEnvironment);
    end
end

local _bSuccess, _vResult = pcall(_init, _sMode == "overlay" and 1 or 0, "CoGReviewConfig");
loadfile = _loadfile;
assert(_bSuccess, _vResult);

check(rawequal(_vResult, _cCoG), "The initializer must return the discovered class.");
check(rawequal(CoGBase, _cCoG), "The public alias must be the discovered class.");
check(rawequal(require("cog.CoGBase"), CoGBase), "The class require alias must retain identity.");
check(package.path == _sPackagePath, "Initialization must restore package.path.");
check(rawequal(_init(-1, "ignored.lua"), CoGBase), "Successful repeat initialization must be cached.");

local _tConfig = CoGBase.config;
check(rawequal(_tConfig, require("cog.config")), "Configuration references must match.");
rejects(function() CoGBase.config = {}; end, "The config property must be read-only.");
rejects(function() CoGBase.config.app = {}; end, "Configuration sections must be read-only.");
rejects(function() CoGBase.config.app.path.save = "changed"; end, "Nested settings must be read-only.");
rejects(function() return CoGBase(); end, "The base constructor must remain protected.");
rejects(function() return CoGBase._tConfig; end, "The captured configuration must be private.");
rejects(function() return CoGBase.IsLeapYear(2024); end, "Calendar helpers must remain private.");

if (_sMode == "overlay") then
    check(_tConfig.app.name == "CoGBase regression", "The user overlay must apply.");
    check(_tConfig.app.path.save == "saves/", "A purged branch must retain supplied values.");
    check(_tConfig.app.path.data == nil, "A purged branch must omit old defaults.");
    check(_tConfig.StatusTracker.regression == true, "StatusTracker must use the user hierarchy.");
else
    check(_tConfig.app.name == "", "Default settings must remain intact.");
    check(_tConfig.app.path.data == "", "Default nested settings must remain intact.");
end

-- The class captures one reference; later cache edits must not rebind its config.
package.loaded["cog.config"] = {};
check(rawequal(CoGBase.config, _tConfig), "Cache replacement must not replace CoGBase.config.");
package.loaded["cog.config"] = _tConfig;

local _tBranch = {value = 7};
local _tMeta = {__metatable = "protected", marker = "keep"};
setmetatable(_tBranch, _tMeta);
check(rawequal(CoGBase.purge(_tBranch), _tBranch), "purge must return the original table.");
check(_tMeta.__purge == true and _tMeta.marker == "keep", "purge must preserve metatable values.");
check(_tBranch.value == 7, "purge must preserve branch values.");
local _tPlain = {};
CoGBase.purge(_tPlain);
check(getmetatable(_tPlain).__purge == true, "purge must create a missing metatable.");
rejects(function() CoGBase.purge(7); end, "purge must reject non-tables.");

-- Fix the clock so ordinal dates and hour padding are reproducible.
local _date = os.date;
local _bDates, _sDateError = pcall(function()
    local function fExpectDate(nYear, nMonth, nDay, nHour, sExpected)
        os.date = function() return {year = nYear, month = nMonth, day = nDay, hour = nHour}; end;
        check(CoGBase.BuildVersionID() == sExpected, "Unexpected ordinal version ID.");
    end

    fExpectDate(2024, 3, 1, 7, "2024.61.07");
    check(CoGBase.BuildVersionID("v", "-x") == "v2024.61.07-x", "Version decorations must be retained.");
    check(CoGBase.BuildVersionID(false, {}) == "2024.61.07", "Non-string decorations must be ignored.");
    check(BuildVersionID() == "2024.61.07", "The standalone helper must remain available.");
    fExpectDate(1900, 3, 1, 0, "1900.60.00");
    fExpectDate(2000, 3, 1, 23, "2000.61.23");
    fExpectDate(2023, 12, 31, 1, "2023.365.01");
    fExpectDate(2024, 12, 31, 1, "2024.366.01");

    os.date = function() return false; end;
    rejects(function() CoGBase.BuildVersionID(); end, "A failed clock lookup must raise an error.");
    os.date = function() return {year = 2023, month = 2, day = 29, hour = 1}; end;
    rejects(function() CoGBase.BuildVersionID(); end, "An invalid calendar date must raise an error.");
end);
os.date = _date;
assert(_bDates, _sDateError);

check(CoGBase.VersionIDIsNewer("2024.61.07", "2024.60.23"), "Newer IDs must compare correctly.");
check(CoGBase.VersionIDIsOlder("2024.60.23", "2024.61.07"), "Older IDs must compare correctly.");
check(CoGBase.VersionIDIsSame("1.02", "10.2"), "Comparison must retain period-removal behavior.");
check(not CoGBase.VersionIDIsNewer("1.02", "10.2"), "Equal IDs cannot be newer.");
check(CoGBase.VersionIDIsSame("bad", "also bad"), "Existing nonnumeric equality behavior must remain.");
rejects(function() CoGBase.VersionIDIsOlder("bad", "1.0"); end, "Invalid numeric ordering must fail.");

-- A small derived fixture checks the protected base call and inherited persistence.
lxc.loadSources({["CoGRegressionChild.lxc"] = [[
    namespace CoGTests {
        class FoundationChild : CoG.CoGBase {
            private nValue = 0;

            public FoundationChild(nValue) {
                this.nValue = nValue;
            }

            public getValue() {
                return this.nValue;
            }
        }
    }
]]}, _G);

local _oChild = CoGTests.FoundationChild(42);
local _oRestored = deserialize(serialize(_oChild));
local _oCopy = clone(_oChild);
check(class.isa(_oChild, CoGBase), "The fixture must inherit CoGBase.");
check(_oChild.getValue() == 42, "The derived constructor must run.");
check(class.isa(_oRestored, CoGBase), "Restored instances must retain CoGBase ancestry.");
check(_oRestored.getValue() == 42, "Save/load must retain declared instance data.");
check(_oRestored ~= _oChild, "Save/load must produce a distinct instance.");
check(_oCopy.getValue() == 42 and _oCopy ~= _oChild, "Clone must retain data independently.");
check(rawequal(deserialize(serialize(CoGBase)), CoGBase), "Class references must retain identity through save/load.");
check(rawequal(CoGBase.config, _tConfig), "Instance persistence must not replace static configuration.");

-- CoG must remain a namespace so later batches can add classes at runtime.
check(type(CoG) == "table" and not class.is(CoG), "CoG must remain a namespace.");
check(rawequal(CoG.CoGBase, CoGBase), "The namespace must expose CoGBase.");
lxc.loadSources({["NamespaceProbe.lxc"] = [[
    namespace CoG.Tests {
        class NamespaceProbe : CoG.CoGBase {
            public NamespaceProbe() {}
        }
    }
]]}, _G);
check(class.isa(CoG.Tests.NamespaceProbe(), CoGBase), "Runtime loading into CoG must remain possible.");

print("PASS CoGBase foundation (".._sMode.."): ".._nChecks.." checks.");
