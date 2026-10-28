--[[!
@fqxn CoG.Tests.ScalerRegression
@desc Exercises optional host debounce without a GUI, native timers or file writes.
    Run with a LuaEx root argument; optional second argument 'global' tests a
    user-configured default adapter in a fresh Lua process.
!]]
local pSource = debug.getinfo(1, "S").source:sub(2):gsub("\\", "/");
local pCoG = pSource:match("^(.*)/tests/[^/]+$") or ".";
local pLuaEx = arg and arg[1] or pCoG.."/..";
local bGlobal = arg and arg[2] == "global";
package.path = pCoG.."/?.lua;"..pCoG.."/?/init.lua;"..pLuaEx.."/?.lua;"..pLuaEx.."/?/init.lua;"..package.path;
local nChecks = 0;

--[[!
@fqxn CoG.Tests.ScalerRegression.check
@desc Counts an observable contract and identifies a failed expectation.
!]]
local function check(bOK, sMessage)
    assert(bOK, sMessage);
    nChecks = nChecks + 1;
end

--[[!
@fqxn CoG.Tests.ScalerRegression.scheduler
@desc Supplies a deterministic virtual clock and cancellable host jobs.
!]]
local function scheduler()
    local tClock = {Now = 0, Jobs = {}, CancelCalls = 0};
    tClock.Schedule = function(nDelay, fCallback)
        local tJob = {Due = tClock.Now + nDelay, Callback = fCallback, Cancelled = false, Ran = false};
        tClock.Jobs[#tClock.Jobs + 1] = tJob;
        return tJob;
    end;
    tClock.Cancel = function(tJob)
        tClock.CancelCalls = tClock.CancelCalls + 1;
        tJob.Cancelled = true;
    end;
    tClock.advance = function(nElapsed)
        tClock.Now = tClock.Now + nElapsed;
        local tDue = {};
        for _, tJob in ipairs(tClock.Jobs) do
            if (not tJob.Cancelled and not tJob.Ran and tJob.Due <= tClock.Now) then tDue[#tDue + 1] = tJob; end
        end
        for _, tJob in ipairs(tDue) do tJob.Ran = true; tJob.Callback(); end
    end;
    return tClock;
end

local tGlobalClock = scheduler();
require("LuaEx.load")();
local fLoadFile = loadfile;
if (bGlobal) then
    loadfile = function(pPath, ...)
        if (pPath:match("/ScalerRegressionConfig%.lua$")) then
            return function()
                return {Scaler = {Debounce = {DelayMS = 50, Schedule = tGlobalClock.Schedule, Cancel = tGlobalClock.Cancel}}};
            end;
        end
        return fLoadFile(pPath, ...);
    end;
end
local bLoaded, vCoG = pcall(require("cog.load"), bGlobal and 1 or 0, "ScalerRegressionConfig");
loadfile = fLoadFile;
assert(bLoaded, vCoG);

local oDefault = scaler(100, 100, 200, 100, false);
check(oDefault.isDebounceEnabled() == (bGlobal == true), "Instances inherit resolved config defaults.");
local oDisabled = scaler(100, 100, 200, 100, false, {Debounce = false});
check(not oDisabled.isDebounceEnabled(), "False disables even configured global defaults.");

local tEvents = {};
oDisabled.setOnMoveStart(function(oSource, tEvent)
    check(oSource == oDisabled and tEvent.Phase == "start" and tEvent.Output == nil, "Start context.");
    check(tEvent.Screen.width == 200 and tEvent.Viewport.x == 50, "Screen and viewport context.");
    tEvent.Input.x = 999;
    tEvent.Screen.width = 999;
    tEvents[#tEvents + 1] = "start";
end);
oDisabled.setOnMoveEnd(function(_, tEvent)
    check(tEvent.Input.x == 5 and tEvent.Output.x == 55 and tEvent.Screen.width == 200, "End owns detached event snapshots.");
    tEvents[#tEvents + 1] = "end";
end);
local tAdjusted = oDisabled.adjustPos(5, 6);
check(tAdjusted.x == 55 and table.concat(tEvents, ",") == "start,end", "Disabled debounce delivers synchronously without changing calculations.");

local tClock = scheduler();
local tOptions = {DelayMS = 100, Schedule = tClock.Schedule, Cancel = tClock.Cancel};
local oFirst = scaler(100, 100, 200, 100, false, {Debounce = tOptions});
local oSecond = scaler(100, 100, 200, 100, false, {Debounce = tOptions});
local nStarts, nEnds, tLast = 0, 0, nil;
oFirst.setOnMoveStart(function() nStarts = nStarts + 1; end);
oFirst.setOnMoveEnd(function(_, tEvent) nEnds = nEnds + 1; tLast = tEvent; end);
oFirst.adjustPos(1, 2);
local tStale = tClock.Jobs[1];
tClock.advance(60);
local tImmediate = oFirst.adjustPos(3, 4);
check(tImmediate.x == 53 and nStarts == 1 and nEnds == 0, "Debounce never delays returned geometry or repeats Start inside a burst.");
check(tStale.Cancelled, "A later adjustment cancels the previous wakeup.");
tStale.Callback();
check(nEnds == 0, "A cancelled wakeup cannot deliver stale End.");
tClock.advance(99);
check(nEnds == 0, "End waits for the full quiet period after the latest input.");
tClock.advance(1);
check(nEnds == 1 and tLast.Input.x == 3 and tLast.Output.x == 53 and tLast.InitialInput.x == 1, "End reports latest result and first input.");
tClock.Jobs[2].Callback();
check(nEnds == 1, "Duplicate wakeups cannot deliver twice.");
oFirst.adjustPos(9, 10);
check(nStarts == 2, "The next burst starts independently.");

local nSecondEnds = 0;
oSecond.setOnMoveEnd(function() nSecondEnds = nSecondEnds + 1; end);
oSecond.adjustPos(7, 8);
oFirst.cancelPendingCallbacks();
tClock.advance(100);
check(nSecondEnds == 1 and nEnds == 1, "One instance cannot cancel another instance's jobs.");
local nResizeEnds = 0;
oFirst.setOnResizeEnd(function() nResizeEnds = nResizeEnds + 1; end);
oFirst.adjustPos(1, 1);
oFirst.adjustSize(10, 20);
check(not tClock.Jobs[#tClock.Jobs - 1].Cancelled, "Move and resize do not cancel one another.");
tClock.advance(100);
check(nEnds == 2 and nResizeEnds == 1, "Move and resize finish independently.");

local tSettings = oFirst.getDebounce();
tSettings.DelayMS = 999;
tOptions.DelayMS = 999;
check(oFirst.getDebounce().DelayMS == 100, "Settings are copied on input and output.");
for _, tBad in ipairs({{DelayMS = -1}, {DelayMS = 0/0}, {DelayMS = math.huge}, {Schedule = false}, {Unknown = 1}}) do
    check(not pcall(oFirst.setDebounce, tBad) and oFirst.getDebounce().DelayMS == 100, "Invalid settings leave current configuration intact.");
end
check(not pcall(scaler, 100, 100, 100, 100, false, {Debounce = {Schedule = function() end, Cancel = null}}), "An incomplete adapter is rejected.");

oFirst.adjustPos(2, 2);
local tPending = tClock.Jobs[#tClock.Jobs];
oFirst.setDebounce(false);
tPending.Callback();
check(tPending.Cancelled and nEnds == 2 and not oFirst.isDebounceEnabled(), "Changing configuration invalidates pending delivery.");
oFirst.setDebounce(nil);
check(oFirst.isDebounceEnabled() == (bGlobal == true), "Nil restores global defaults.");

local nCalls = 0;
oDisabled.setOnMoveStart(nil);
oDisabled.setOnMoveEnd(function() nCalls = nCalls + 1; oDisabled.adjustPos(2, 2); end);
oDisabled.adjustPos(1, 1);
check(nCalls == 1, "Nested same-channel adjustments do not recursively invoke callbacks.");
oDisabled.setOnMoveEnd(function() error("callback failure"); end);
check(not pcall(oDisabled.adjustPos, 1, 1), "Callback errors propagate.");
oDisabled.setOnMoveEnd(function() nCalls = nCalls + 1; end);
oDisabled.adjustPos(1, 1);
check(nCalls == 2, "A failing callback does not leave notification state locked.");

local nNoAdapterEnds = 0;
local oNoAdapter = scaler(100, 100, 100, 100, false, {Debounce = {DelayMS = 100, Schedule = null, Cancel = null}});
oNoAdapter.setOnResizeEnd(function() nNoAdapterEnds = nNoAdapterEnds + 1; end);
oNoAdapter.adjustSize(1, 1);
check(nNoAdapterEnds == 1 and not oNoAdapter.isDebounceEnabled(), "Positive delay without an adapter remains synchronous.");
local oBroken = scaler(100, 100, 100, 100, false, {Debounce = {DelayMS = 1,
    Schedule = function() error("scheduler failed"); end, Cancel = function() end}});
oBroken.setOnMoveEnd(function() end);
check(not pcall(oBroken.adjustPos, 1, 1), "Scheduler failures are reported.");
oBroken.setDebounce(false);
check(pcall(oBroken.adjustPos, 1, 1), "Scheduler failure does not prevent later use.");
oBroken.setDebounce({DelayMS = 1, Schedule = function(_, fCallback) fCallback(); return 1; end, Cancel = function() end});
check(not pcall(oBroken.adjustPos, 1, 1), "An inline scheduler is rejected clearly.");

oBroken.setDebounce({DelayMS = 1, Schedule = function() return nil; end, Cancel = function() end});
check(not pcall(oBroken.adjustPos, 1, 1), "A missing timer handle is rejected.");

local tFailureClock = scheduler();
local nCancelAttempts, nUnexpectedEnds = 0, 0;
local oCancelFailure = scaler(100, 100, 100, 100, false, {Debounce = {
    DelayMS = 1, Schedule = tFailureClock.Schedule,
    Cancel = function() nCancelAttempts = nCancelAttempts + 1; error("cancel failed"); end,
}});
oCancelFailure.setOnMoveEnd(function() nUnexpectedEnds = nUnexpectedEnds + 1; end);
oCancelFailure.setOnResizeEnd(function() nUnexpectedEnds = nUnexpectedEnds + 1; end);
local tRect = oCancelFailure.adjust({x = 2, y = 3, width = 4, height = 5});
check(tRect.x == 2 and tRect.width == 4 and #tFailureClock.Jobs == 2, "Rectangle adjustments schedule both channels and return geometry immediately.");
check(not pcall(oCancelFailure.cancelPendingCallbacks) and nCancelAttempts == 2, "Both host cancellations are attempted when cancellation raises.");
tFailureClock.advance(1);
check(nUnexpectedEnds == 0, "Failed host cancellation cannot revive invalidated callbacks.");

local nBeforeZero = #tClock.Jobs;
oSecond.setDebounce({DelayMS = 0, Schedule = tClock.Schedule, Cancel = tClock.Cancel});
oSecond.adjustPos(1, 1);
check(nSecondEnds == 2 and #tClock.Jobs == nBeforeZero, "Zero delay bypasses even a configured adapter.");

-- Validate overlay defaults without writing a configuration fixture to disk.
local fAssembler = assert(fLoadFile(pCoG.."/cog/config.lua"));
for _, tOverride in ipairs({{DelayMS = -1}, {Schedule = function() end},
    {DelayMS = 25, Schedule = tClock.Schedule, Cancel = tClock.Cancel}}) do
    loadfile = function(pPath, ...)
        if (pPath == "virtual-scaler-config/Config.lua") then
            return function() return {Scaler = {Debounce = tOverride}}; end;
        end
        return fLoadFile(pPath, ...);
    end;
    local bOK, tConfig = pcall(fAssembler, "cog.config", {userDirectory = "virtual-scaler-config", userFilename = "Config.lua"});
    loadfile = fLoadFile;
    if (tOverride.Cancel) then
        check(bOK and tConfig.Scaler.Debounce.DelayMS == 25, "The user overlay can configure the global adapter.");
    else
        check(not bOK, "Invalid global debounce config is rejected at assembly.");
    end
end

oDefault.cancelPendingCallbacks();
oFirst.cancelPendingCallbacks();
oSecond.cancelPendingCallbacks();
oBroken.cancelPendingCallbacks();
print("Scaler debounce ("..(bGlobal and "global overlay" or "bundled defaults").."): "..nChecks.." checks passed.");
