--[[!
@fqxn CoG.Tests.StatusTracker
@desc Checks native discovery, timers against the archived factory, encapsulation,
    snapshot iteration, native graph persistence and application enum replacement.
    Run with Lua 5.4; optional argument override selects a nested application enum.
!]]
local _sMode = ... or "defaults";
local _pTests = assert(debug.getinfo(1, "S").source:match("^@(.+)[/\\][^/\\]+$"));
local _pCoG = _pTests.."/..";
local _nChecks = 0;

--[[!
@fqxn CoG.Tests.StatusTracker.check
@desc Counts an observable behavior assertion.
!]]
local function check(bCondition, sMessage)
    assert(bCondition, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn CoG.Tests.StatusTracker.reject
@desc Requires an invalid operation to fail with an optional diagnostic fragment.
!]]
local function reject(fOperation, sFragment)
    local bOK, vError = pcall(fOperation);
    check(not bOK and (not sFragment or tostring(vError):find(sFragment, 1, true)),
        "Expected rejection "..tostring(sFragment).."; got "..tostring(vError));
end

--[[!
@fqxn CoG.Tests.StatusTracker.readSource
@desc Reads an existing declaration or legacy reference without creating fixtures.
!]]
local function readSource(pFile)
    local hFile = assert(io.open(pFile, "rb"));
    local sSource = hFile:read("*a");
    hFile:close();
    return sSource;
end

package.path = _pCoG.."/../LuaEx/?.lua;"..package.path;
local _cTracker, _eEffect;

if (_sMode == "override") then
    require("LuaEx.load")(0);
    local LXC = require("LuaEx.lib.lxc");
    LXC.bindHost(_G);
    local tHost = setmetatable({}, {__index = _G});
    LXC.loadSources({
        ["default.lxe"] = readSource(_pCoG.."/cog/enums/EFFECT.lxe"),
        ["StatusTracker.lxc"] = readSource(_pCoG.."/cog/StatusTracker.lxc"),
        ["application.lxe"] = [=[namespace CoG {
            public enum EFFECT {
                PEOPLE { TIMED; FOREVER; CONFUSED; }
                WEAPONS { ONE_HANDED { DULL; } TWO_HANDED { HEAVY; } }
            }
        }]=],
    }, tHost);
    _cTracker, _eEffect = tHost.CoG.StatusTracker, tHost.CoG.EFFECT;
    check(#_eEffect == 2 and lxe.getByName(_eEffect, "HASTENED") == nil,
        "application enum replaces, rather than merges, the default");
else
    assert(_sMode == "defaults", "Unknown StatusTracker test mode.");
    package.path = _pCoG.."/?.lua;"..package.path;
    require("LuaEx.load")(3);
    _cTracker, _eEffect = CoG.StatusTracker, CoG.EFFECT;
    check(#_eEffect == 64, "all 64 default effect names are active");
end

check(class.is(_cTracker) and rawequal(class.getbyname("CoG.StatusTracker"), _cTracker),
    "LuaEx discovers the real LXC class");
check(rawget(_G, "StatusTracker") == nil, "no short class alias is published");
local _eScope = _sMode == "override" and _eEffect.PEOPLE or _eEffect;
local _sTimed = _sMode == "override" and "TIMED" or "HASTENED";
local _sForever = _sMode == "override" and "FOREVER" or "POISONED";
local _oStatuses = _cTracker(_eScope);
check(class.isinstance(_oStatuses) and class.isa(_oStatuses, _cTracker), "constructor returns a native instance");
check(#_oStatuses == 0 and not _oStatuses.isActive(_eScope[_sTimed]), "initial state is inactive");
check(_oStatuses.getDuration(_sTimed) == 0 and _oStatuses.doesExpire(_sTimed), "initial duration and expiration");
check(rawequal(_oStatuses.setDuration(_sTimed, 5), _oStatuses), "setDuration chains");
check(not _oStatuses.isActive(_sTimed), "setting duration does not activate");
check(_oStatuses.activate(_eScope[_sTimed]), "activation uses the canonical member");
check(#_oStatuses == 1 and _oStatuses.cycle(2) == 0 and _oStatuses.getDuration(_sTimed) == 3, "active timer advances");
check(_oStatuses.cycle(100) == 1 and not _oStatuses.isActive(_sTimed) and _oStatuses.getDuration(_sTimed) == 0, "expiration clamps at zero");
check(_oStatuses.activate(_sForever, 0, false), "indefinite status activates at zero");
check(_oStatuses.cycle() == 0 and _oStatuses.isActive(_sForever), "indefinite zero status survives cycling");
_oStatuses.setDuration(_sForever, 2).adjustDuration(_sForever, -10);
check(_oStatuses.getDuration(_sForever) == 0 and _oStatuses.isActive(_sForever), "negative adjustment clamps without expiring indefinite status");
check(rawequal(_oStatuses.setDoesExpire(_sForever, true), _oStatuses) and not _oStatuses.isActive(_sForever), "enabling expiration at zero deactivates");
_oStatuses.setDoesExpire(_sForever, false);
check(not _oStatuses.isActive(_sForever), "disabling expiration does not activate");
check(_oStatuses.activate(_sForever) and _oStatuses.deactivate(_sForever) and not _oStatuses.deactivate(_sForever), "explicit deactivation reports previous state");
check(_oStatuses.activate(_sTimed, 3, true), "timed status can reactivate");
reject(function() _oStatuses.activate(_sTimed, 8, "bad"); end, "expiration flag");
check(_oStatuses.getDuration(_sTimed) == 3 and _oStatuses.isActive(_sTimed), "invalid activation changes nothing");

for _, vInvalid in ipairs({-1, math.huge, -math.huge, 0 / 0, false, "1"}) do
    reject(function() _oStatuses.setDuration(_sTimed, vInvalid); end, "finite nonnegative");
    reject(function() _oStatuses.cycle(vInvalid); end, "finite nonnegative");
    reject(function() _oStatuses.adjustDuration(_sTimed, vInvalid == -1 and math.huge or vInvalid); end, "finite");
end
reject(function() _oStatuses.getDuration("UNKNOWN"); end, "outside this scope");
reject(function() _oStatuses.getDuration({Name = _sTimed}); end, "outside this scope");
reject(function() _cTracker(); end, "scope must be");
reject(function() _cTracker({}); end, "scope must be");
reject(function() _cTracker(_eScope[_sTimed]); end, "scope must be");
reject(function() return _oStatuses._tStatuses; end, "private member");
reject(function() return _oStatuses._eScope; end, "private member");
reject(function() return _cTracker._tScopes; end, "private member");
reject(function() _oStatuses.cycle = function() end; end, "replace a method");
reject(function() _oStatuses._tStatuses = {}; end, "private member");
check(_oStatuses.getDuration(tostring(_eScope[_sTimed])) == 3, "fully qualified effect path resolves");

local fIterator = _oStatuses.eachStatus();
_oStatuses.setDuration(_sTimed, 9);
local tSnapshot, tOrder = {}, {};
for sName, tStatus in fIterator do
    tSnapshot[sName] = tStatus;
    tOrder[#tOrder + 1] = sName;
end
check(tSnapshot[_sTimed].duration == 3, "iterator owns a snapshot from creation time");
tSnapshot[_sTimed].duration = 100;
check(_oStatuses.getDuration(_sTimed) == 9, "returned records cannot mutate private storage");
check(_cTracker(_eScope).getDuration(_sTimed) == 0, "instances own independent records");
local nPairs = 0;
for sName, tStatus in pairs(_oStatuses) do
    nPairs = nPairs + 1;
    check(sName == tOrder[nPairs] and rawtype(tStatus.active) == "boolean", "pairs follows declared scope order");
end
check(nPairs == #tOrder, "iteration includes all inactive and active effects");

check(_oStatuses.activate(_sForever, 0, false), "prepare indefinite saved state");
local _oCopy = clone(_oStatuses);
check(class.isa(_oCopy, _cTracker) and not rawequal(_oCopy, _oStatuses), "native clone preserves concrete class");
check(_oCopy.isActive(_sForever) and not _oCopy.doesExpire(_sForever), "clone preserves explicit false expiration");
check(_oCopy.clear() == 2 and #_oStatuses == 2, "clone mutation is independent");
local _tGraph = {first = _oStatuses, alias = _oStatuses, member = _eScope[_sTimed]};
_tGraph.self = _tGraph;
local _tLoaded = deserialize(serialize(_tGraph));
check(rawequal(_tLoaded.first, _tLoaded.alias) and rawequal(_tLoaded.self, _tLoaded), "native save preserves graph aliases and cycles");
check(rawequal(_tLoaded.member, _eScope[_sTimed]), "saved effect retains canonical identity");
check(_tLoaded.first.getDuration(_sTimed) == 9 and _tLoaded.first.isActive(_sForever)
    and not _tLoaded.first.doesExpire(_sForever), "native restoration preserves timers and flags");
_tLoaded.first.clear();
check(#_oStatuses == 2, "restored state is independent");
check(rawequal(clone(_cTracker), _cTracker) and rawequal(deserialize(serialize(_cTracker)), _cTracker), "native class references retain identity");

-- Construct untrusted native field projections through the serializer's explicit
-- test adapter. Production restoration must still enforce the class definition.
local Serializer = require("LuaEx.lib.serializer");
local function forgedSnapshot(eScope, tStatuses)
    local oMarker = {};
    local tAdapter = {
        project = function(vValue)
            if (rawequal(vValue, oMarker)) then
                return {Kind = "instance", Class = "CoG.StatusTracker", Fields = {
                    ["CoG.StatusTracker:_eScope"] = {Index = 1, Type = type(eScope), ClassType = false, Locked = false},
                    ["CoG.StatusTracker:_tStatuses"] = {Index = 2, Type = "table", ClassType = false, Locked = false},
                }}, {eScope, tStatuses};
            end
        end,
        checkFunction = function() end,
        checkGraph = function() end,
        allocate = function() error("Encoding must not allocate restored instances."); end,
        finish = function() error("Encoding must not restore instances."); end,
    };
    return "--LXC:3\n"..Serializer.serializeStaged(oMarker, tAdapter);
end

for _, tInvalid in ipairs({
    {duration = -1, active = false, doesExpire = true},
    {duration = 0, active = true, doesExpire = true},
    {duration = 1, active = "bad", doesExpire = true},
    {duration = 1, active = false, doesExpire = "bad"},
    {duration = 1, active = false, doesExpire = true, extra = true},
}) do
    reject(function() deserialize(forgedSnapshot(_eScope, {[_sTimed] = tInvalid})); end);
end
reject(function() deserialize(forgedSnapshot(_eScope, {UNKNOWN = {duration = 1, active = false, doesExpire = true}})); end, "outside the selected scope");
reject(function() deserialize(forgedSnapshot(_eScope[_sTimed], {})); end, "scope must be");
local oDefaulted = deserialize(forgedSnapshot(_eScope, {}));
check(oDefaulted.getDuration(_sTimed) == 0 and not oDefaulted.isActive(_sTimed) and oDefaulted.doesExpire(_sTimed),
    "missing saved effects receive independent inactive defaults");
check(deserialize(serialize(_oStatuses)).getDuration(_sTimed) == 9, "failed restoration leaves later valid restoration usable");

if (_sMode == "override") then
    local oAll = _cTracker(_eEffect);
    local oWeapon = _cTracker(_eEffect.WEAPONS.ONE_HANDED);
    check(oAll.activate(_eEffect.PEOPLE.TIMED, 2, true), "root scope accepts descendant identity");
    check(oAll.getDuration("PEOPLE.TIMED") == 2, "root scope uses relative descendant paths");
    check(oAll.getDuration("CoG.EFFECT.PEOPLE.TIMED") == 2, "root scope accepts full descendant paths");
    check(oWeapon.activate(_eEffect.WEAPONS.ONE_HANDED.DULL, 1, true), "deep embedded category is a valid scope");
    reject(function() _oStatuses.activate(_eEffect.WEAPONS.ONE_HANDED.DULL, 1, true); end, "outside this scope");
    reject(function() oAll.activate(_eEffect.PEOPLE, 1, true); end, "outside this scope");
    reject(function() oWeapon.activate("CoG.EFFECT.WEAPONS.TWO_HANDED.HEAVY", 1, true); end, "outside this scope");
    check(deserialize(serialize(oWeapon)).getDuration("DULL") == 1, "embedded enum scope round-trips canonically");
else
    require("cog.load")();
    check(rawget(_G, "StatusTracker") == nil, "CoG loader remains unchanged and creates no alias");

    -- Run the archived timer implementation without registering its old factory.
    local tNames = {};
    for _, eMember in _eEffect() do tNames[#tNames + 1] = eMember.Name; end
    local tLegacyEnvironment = setmetatable({
        CoG = {config = {StatusTracker = {EFFECT = tNames}}},
        require = function(sModule)
            if (sModule == "LuaEx.lib.serializer") then return {registerFactory = function() end}; end
            return require(sModule);
        end,
    }, {__index = _G});
    local Reference = assert(loadfile(_pCoG.."/legacy/cog/StatusTracker.lua", "t", tLegacyEnvironment))();
    local oReference, oNative = Reference(Reference.EFFECT), _cTracker(_eEffect);
    local tCompared = {"HASTENED", "POISONED", "GUARDED"};

    for nStep = 1, 200 do
        local sName = tCompared[nStep % #tCompared + 1];
        local nAction = nStep % 7;
        if (nAction == 0) then
            check(oNative.activate(sName, nStep % 9, nStep % 2 == 0) == oReference.activate(sName, nStep % 9, nStep % 2 == 0), "legacy activation result");
        elseif (nAction == 1) then
            check(oNative.cycle((nStep % 3) / 2) == oReference.cycle((nStep % 3) / 2), "legacy expiration count");
        elseif (nAction == 2) then
            check(oNative.deactivate(sName) == oReference.deactivate(sName), "legacy deactivation result");
        elseif (nAction == 3) then
            oNative.setDuration(sName, nStep % 11); oReference.setDuration(sName, nStep % 11);
        elseif (nAction == 4) then
            oNative.adjustDuration(sName, nStep % 5 - 3); oReference.adjustDuration(sName, nStep % 5 - 3);
        elseif (nAction == 5) then
            oNative.setDoesExpire(sName, nStep % 2 == 0); oReference.setDoesExpire(sName, nStep % 2 == 0);
        else
            check(oNative.clear() == oReference.clear(), "legacy clear count");
        end

        for _, sEffect in ipairs(tCompared) do
            check(oNative.getDuration(sEffect) == oReference.getDuration(sEffect), "legacy duration");
            check(oNative.isActive(sEffect) == oReference.isActive(sEffect), "legacy active flag");
            check(oNative.doesExpire(sEffect) == oReference.doesExpire(sEffect), "legacy expiration flag");
        end
        check(#oNative == #oReference, "legacy active count");
    end

    local fLoadFile = loadfile;
    local fConfig = assert(fLoadFile(_pCoG.."/cog/config.lua"));
    loadfile = function(pFile, ...)
        if (pFile == "__status_tracker_old_config__/config.lua") then
            return function() return {StatusTracker = {EFFECT = {"OLD_CONFIG"}}}; end;
        end
        return fLoadFile(pFile, ...);
    end;
    local bConfig, vConfig = pcall(fConfig, "cog.config", {userDirectory = "__status_tracker_old_config__", purge = CoGBase.purge});
    loadfile = fLoadFile;
    check(not bConfig and tostring(vConfig):find("CoG.EFFECT, not configuration", 1, true), "old configuration enum declarations are rejected clearly");
end

print("PASS StatusTracker (".._sMode.."): ".._nChecks.." checks.");
