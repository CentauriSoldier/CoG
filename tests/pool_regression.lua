--[[!
@fqxn CoG.Tests.Pool
@desc Verifies real discovery and checks native Pool behavior against archived
    methods, without installing the legacy class system. Covers modifiers,
    reservations, status, event order, deferred callbacks, operators and persistence.
    Run in a fresh Lua 5.4 process: lua tests/pool_regression.lua
!]]
local _pTests = assert(debug.getinfo(1, "S").source:match("^@(.+)[/\\][^/\\]+$"));
local _pCoG = _pTests.."/..";
local _nChecks = 0;

--[[!
@fqxn CoG.Tests.Pool.check
@desc Counts a successful assertion or raises its failure description.
!]]
local function check(bCondition, sMessage)
    assert(bCondition, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn CoG.Tests.Pool.rejects
@desc Requires an invalid operation to raise an error.
!]]
local function rejects(fOperation, sMessage)
    check(not pcall(fOperation), sMessage);
end

package.path = _pCoG.."/?.lua;".._pCoG.."/../LuaEx/?.lua;"..package.path;
require("LuaEx.load")(3);
local _cPool = class.getbyname("CoG.Pool");
check(class.is(_cPool) and Pool == nil, "LuaEx must discover Pool before alias publication.");
require("cog.load")();
check(rawequal(Pool, _cPool) and rawequal(require("cog.Pool"), Pool), "Pool aliases must retain class identity.");
local _loadReference = assert(loadfile(_pTests.."/support/LegacyPoolReference.lua"));
local _pOriginal = _pCoG.."/legacy/cog/Pool.lua";
local _handle = io.open(_pOriginal, "r");

if (_handle) then
    _handle:close();
else
    _pOriginal = _pCoG.."/cog/Pool.lua";
end

local _Reference = _loadReference()(_pOriginal, CoGBase);
local _native = Pool(200, 80);
local _reference = _Reference(200, 80);
local _tNativeEvents, _tReferenceEvents = {}, {};

--[[!
@fqxn CoG.Tests.Pool.attach
@desc Logs scalar callback arguments and verifies callbacks receive their Pool.
!]]
local function attach(oPool, Reference, tLog)
    for _, eEvent in Reference.EVENT() do
        local sName = Reference == Pool and eEvent.Name or eEvent.name;
        oPool.setEventCallback(eEvent, function(oReceived, ...)
            check(rawequal(oReceived, oPool), "Events must receive their own Pool.");
            local tArguments = table.pack(...);
            local tParts = {sName, tostring(tArguments.n)};

            for nIndex = 1, tArguments.n do
                tParts[#tParts + 1] = tostring(tArguments[nIndex]);
            end

            tLog[#tLog + 1] = table.concat(tParts, "|");
        end);
    end
end

attach(_native, Pool, _tNativeEvents);
attach(_reference, _Reference, _tReferenceEvents);

--[[!
@fqxn CoG.Tests.Pool.compare
@desc Checks all aspects/modifiers, status flags, markers and emitted event order.
!]]
local function compare()
    for _, eAspect in Pool.ASPECT() do
        local eOriginal = _Reference.ASPECT[eAspect.Name];
        check(_native.get(eAspect) == _reference.get(eOriginal), eAspect.Name.." changed its value.");

        if (eAspect.Name == "MAX" or eAspect.Name == "CYCLE_FLAT" or eAspect.Name == "CYCLE_PERCENT" or
            eAspect.Name == "RESERVED_FLAT" or eAspect.Name == "RESERVED_PERCENT") then
            for _, eModifier in Pool.MODIFIER() do
                check(_native.get(eAspect, eModifier) == _reference.get(eOriginal, _Reference.MODIFIER[eModifier.Name]),
                    eAspect.Name.."/"..eModifier.Name.." changed.");
            end
        end
    end

    for _, sMethod in ipairs({"isEmpty", "isFull", "isHigh", "isLow", "getLowMarker", "getHighMarker"}) do
        check(_native[sMethod]() == _reference[sMethod](), sMethod.." changed.");
    end

    check(table.concat(_tNativeEvents, "\n") == table.concat(_tReferenceEvents, "\n"), "Event order or callback arguments changed.");
end

local _tActions = {
    {10, "CYCLE_FLAT"}, {0.05, "CYCLE_PERCENT"}, {10, "RESERVED_FLAT"},
    {0.25, "RESERVED_PERCENT"}, {0.1, "MAX", "MULTIPLICATIVE_BONUS"},
    {20, "MAX", "BASE_BONUS"}, {5, "MAX", "BASE_PENALTY"},
    {2, "MAX", "ADDITIVE_BONUS"}, {1, "MAX", "ADDITIVE_PENALTY"},
    {3, "CYCLE_FLAT", "BASE_BONUS"}, {-2, "CYCLE_FLAT", "ADDITIVE_PENALTY"},
    {0.5, "CYCLE_FLAT", "MULTIPLICATIVE_BONUS"}, {5, "CYCLE_FLAT", "MAX"},
    {1000, "RESERVED_FLAT"}, {1, "RESERVED_PERCENT"}, {0, "MAX"},
    {10, "CURRENT"}, {0, "CURRENT"}, {1000, "CURRENT"}, {0, "RESERVED_FLAT"},
    {0, "RESERVED_PERCENT"},
};

compare();

for _, tAction in ipairs(_tActions) do
    local tActual = table.pack(_native.set(tAction[1], Pool.ASPECT[tAction[2]],
        tAction[3] and Pool.MODIFIER[tAction[3]] or nil));
    local tExpected = table.pack(_reference.set(tAction[1], _Reference.ASPECT[tAction[2]],
        tAction[3] and _Reference.MODIFIER[tAction[3]] or nil));
    check(rawequal(tActual[1], _native) and tActual[2] == tExpected[2] and tActual[3] == tExpected[3],
        "Mutation return values changed.");
    compare();
end

_native.cycle(2); _reference.cycle(2); compare();
_native.setLowMarker(0.2); _reference.setLowMarker(0.2); compare();
_native.setHighMarker(0.8); _reference.setHighMarker(0.8); compare();
_native.adjust(-23); _reference.adjust(-23); compare();

local _p = Pool(100, 40);
check(rawequal(_p + 10, _p) and _p.get() == 50, "Addition must mutate the left Pool.");
check(rawequal(_p - Pool(100, 20), _p) and _p.get() == 30, "Pool subtraction must use the right current value.");
check(rawequal(_p * 2, _p) and _p.get() == 60, "Multiplication must update current.");
check(rawequal(_p / 7, _p) and _p.get() == 8, "Division must floor.");
check(rawequal(_p % 200, _p) and _p.get(Pool.ASPECT.MAX) == 200, "Percent must set maximum.");
check(rawequal(-_p, _p) and _p.isEmpty(), "Unary minus must empty.");
check(#_p == 200 and _p.isFull(), "Length must fill available capacity.");
rejects(function() return _p / 0; end, "Division by zero must fail.");
rejects(function() return 1 + _p; end, "Numbers on the left remain unsupported.");

for _, vInvalid in ipairs({0/0, math.huge, -math.huge, false, "1"}) do
    rejects(function() _p.set(vInvalid); end, "Invalid numeric mutations must fail.");
end
rejects(function() Pool(0); end, "Maximum below one must fail.");
rejects(function() Pool(10, -1); end, "Negative initial current must fail.");
rejects(function() _p.set(1, Pool.ASPECT.AVAILABLE); end, "Calculated aspects must be read-only.");
rejects(function() _p.set(1, Pool.ASPECT.MAX, Pool.MODIFIER.FINAL); end, "Final modifiers must be read-only.");
rejects(function() _p.setLowMarker(0); end, "Markers must retain their bounds.");
rejects(function() return _p.current; end, "State must remain protected.");

local _nCalls = 0;
_p.setEventCallback(Pool.EVENT.ON_DECREASE, function() _nCalls = _nCalls + 1; end);
local _copy = clone(_p);
_copy.adjust(-1);
check(_nCalls == 1 and _p.get() == 200, "Clone must retain callbacks and own its numeric state.");
local _loaded = deserialize(serialize(_p));
_loaded.adjust(-1);
_loaded.setEventActive(Pool.EVENT.ON_DECREASE, true);
_loaded.adjust(-1);
check(_nCalls == 1, "Save/load must disable callbacks and restore placeholder events.");
_p.adjust(-1);
check(_nCalls == 2, "Saving must leave live callbacks active.");
check(_loaded.get() == 198, "Saved numeric state must remain usable.");

local _first, _second = Pool(100, 40), Pool(100, 40);
local _tOrder = {};
_first.setEventCallback(Pool.EVENT.ON_DECREASE, function()
    check(_first.get() == 30 and _second.get() == 30, "Deferred callbacks must observe all committed values.");
    _tOrder[#_tOrder + 1] = "first";
end);
_second.setEventCallback(Pool.EVENT.ON_DECREASE, function() _tOrder[#_tOrder + 1] = "second"; end);
local _tReturns = table.pack(Pool.withDeferredEvents(function()
    _first.adjust(-10);
    Pool.withDeferredEvents(function() _second.adjust(-10); end);
    check(#_tOrder == 0, "Nested actions must share the deferred queue.");
    return "result", nil, 3;
end));
check(_tReturns.n == 3 and _tReturns[1] == "result" and _tReturns[2] == nil and _tReturns[3] == 3,
    "Deferred actions must preserve return values.");
check(table.concat(_tOrder, ",") == "first,second", "Deferred events must retain order.");

_first.setEventCallback(Pool.EVENT.ON_DECREASE, function() error("callback error"); end);
local _bSecondCalled = false;
_second.setEventCallback(Pool.EVENT.ON_DECREASE, function() _bSecondCalled = true; end);
rejects(function()
    Pool.withDeferredEvents(function() _first.adjust(-1); _second.adjust(-1); end);
end, "Deferred callback errors must propagate.");
check(_bSecondCalled and _first.get() == 29 and _second.get() == 29,
    "All queued callbacks must run and committed state must remain.");

check(rawequal(deserialize(serialize(Pool.ASPECT.MAX)), Pool.ASPECT.MAX), "Enum identity must survive persistence.");
print("PASS Pool: ".._nChecks.." checks.");


