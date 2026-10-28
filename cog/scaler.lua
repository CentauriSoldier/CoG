--[[
    Deferred considerations:
    * The loader exports scaler although the class is named Scaler.
    * The coordinate policies of adjust and adjustPos require separate review.
]]
local assert    = assert;
local class     = class;
local math      = math;
local rawtype   = rawtype;
local fitrect   = math.geometry.fitrect;
local CoG       = CoG;
local pcall     = pcall;
local error     = error;
local type      = type;

--[[!
@fqxn CoG.Scaler.Helpers.dummy
@desc Supplies the default no-op callback without invoking application behavior.
!]]
local function dummy() end

--[[!
@fqxn CoG.Scaler.Helpers.copyFields
@desc Returns detached geometry/settings fields without cloning host functions.
!]]
local function copyFields(tSource)
    local tCopy = {};
    for sKey, vValue in pairs(tSource) do tCopy[sKey] = vValue; end
    return tCopy;
end

--[[!
@fqxn CoG.Scaler.Helpers.resolveDebounce
@desc Copies global defaults and applies one instance's overrides. False disables
    scheduling; nil inherits defaults. Runtime handles never enter configuration.
!]]
local function resolveDebounce(vOptions)
    local tResult = copyFields(CoG.config.Scaler.Debounce);
    assert(vOptions == nil or vOptions == false or rawtype(vOptions) == "table", "Debounce must be a table, false or nil.");

    if (vOptions == false) then
        tResult.DelayMS, tResult.Schedule, tResult.Cancel = 0, null, null;
    elseif (vOptions ~= nil) then
        for sKey, vValue in pairs(vOptions) do
            assert(sKey == "DelayMS" or sKey == "Schedule" or sKey == "Cancel", "Unknown debounce option: "..tostring(sKey));
            tResult[sKey] = vValue;
        end
    end

    assert(rawtype(tResult.DelayMS) == "number" and tResult.DelayMS == tResult.DelayMS
        and tResult.DelayMS >= 0 and tResult.DelayMS < math.huge, "Debounce.DelayMS must be finite and nonnegative.");
    local bSchedule = rawtype(tResult.Schedule) == "function";
    local bCancel = rawtype(tResult.Cancel) == "function";
    local bScheduleUnset = tResult.Schedule == nil or type.isnull(tResult.Schedule);
    local bCancelUnset = tResult.Cancel == nil or type.isnull(tResult.Cancel);
    assert((bSchedule and bCancel) or (bScheduleUnset and bCancelUnset),
        "Debounce requires both Schedule and Cancel functions, or neither.");

    return tResult;
end

--[[!
@fqxn CoG.Scaler.Helpers.pending
@desc Creates independent state for one instance's move or resize burst.
!]]
local function pending()
    return {Active = false, Version = 0, HasHandle = false, Handle = null,
        Latest = null, InitialInput = null, Delivering = false};
end

--[[!
@fqxn CoG.Scaler.Helpers.invalidate
@desc Invalidates stale wakeups before external cancellation. Returns the previous
    handle and presence flag, including valid false-valued handles.
!]]
local function invalidate(tPending)
    local vHandle, bHadHandle = tPending.Handle, tPending.HasHandle;
    tPending.Version = tPending.Version + 1;
    tPending.Active, tPending.HasHandle = false, false;
    tPending.Handle, tPending.Latest, tPending.InitialInput = null, null, null;
    return vHandle, bHadHandle;
end

--[[!
@fqxn CoG.Scaler.Helpers.eventData
@desc Builds a callback-local event snapshot. Start omits Output; End contains
    the latest adjusted result and the burst's first input geometry.
!]]
local function eventData(tPending, sPhase)
    local tLatest = tPending.Latest;
    return {Operation = tLatest.Operation, Method = tLatest.Method, Phase = sPhase,
        Input = copyFields(tLatest.Input), InitialInput = copyFields(tPending.InitialInput),
        Output = sPhase == "end" and copyFields(tLatest.Output) or nil,
        Screen = copyFields(tLatest.Screen), Viewport = copyFields(tLatest.Viewport)};
end

--[[!
@fqxn CoG.Scaler.Helpers.deliver
@desc Restores delivery state even when application code raises. Nested geometry
    calculations are allowed but do not recursively notify the same channel.
!]]
local function deliver(this, tPending, fCallback, tEvent)
    tPending.Delivering = true;
    local bOK, sError = pcall(fCallback, this, tEvent);
    tPending.Delivering = false;
    if (not bOK) then error(sError, 0); end
end

--[[!
@fqxn CoG.Scaler.Helpers.finish
@desc Ends only the current generation and clears its state before invoking user code.
!]]
local function finish(this, cdat, sOperation, nVersion)
    local tPending = cdat.pri[sOperation.."Pending"];
    if (not tPending.Active or tPending.Version ~= nVersion) then return; end
    local tEvent = eventData(tPending, "end");
    invalidate(tPending);
    local fCallback = sOperation == "move" and cdat.pri.OnMoveEnd or cdat.pri.OnResizeEnd;
    deliver(this, tPending, fCallback, tEvent);
end

--[[!
@fqxn CoG.Scaler.Helpers.notify
@desc Notifies adjustment activity without delaying geometry results. A configured
    adapter groups successive updates into one Start/End burst per operation.
    Timer generations reject cancelled, duplicate and late wakeups.
!]]
local function notify(this, cdat, sOperation, sMethod, tInput, tOutput)
    local pri = cdat.pri;
    local tPending = pri[sOperation.."Pending"];
    if (tPending.Delivering) then return; end
    local fStart = sOperation == "move" and pri.OnMoveStart or pri.OnResizeStart;
    local fEnd = sOperation == "move" and pri.OnMoveEnd or pri.OnResizeEnd;
    if (not tPending.Active and fStart == dummy and fEnd == dummy) then return; end

    tPending.Latest = {Operation = sOperation, Method = sMethod, Input = copyFields(tInput),
        Output = copyFields(tOutput), Screen = this.getScreenSize(), Viewport = this.getViewportDimensions()};
    if (not tPending.Active) then
        tPending.Active = true;
        tPending.InitialInput = copyFields(tInput);
        local nVersion = tPending.Version;
        local bOK, sError = pcall(deliver, this, tPending, fStart, eventData(tPending, "start"));
        if (not bOK) then invalidate(tPending); error(sError, 0); end
        if (not tPending.Active or tPending.Version ~= nVersion) then return; end
    end

    local tSettings = pri.debounce;
    local vOldHandle, bHadHandle = tPending.Handle, tPending.HasHandle;
    tPending.Version = tPending.Version + 1;
    local nVersion = tPending.Version;
    tPending.Handle, tPending.HasHandle = null, false;
    if (bHadHandle) then
        local bOK, sError = pcall(tSettings.Cancel, vOldHandle);
        if (not bOK) then invalidate(tPending); error(sError, 0); end
        if (not tPending.Active or tPending.Version ~= nVersion) then return; end
    end

    if (tSettings.DelayMS == 0 or rawtype(tSettings.Schedule) ~= "function") then
        finish(this, cdat, sOperation, nVersion);
        return;
    end

    local bScheduling, bInline = true, false;
    local bOK, vHandle = pcall(tSettings.Schedule, tSettings.DelayMS, function()
        if (bScheduling) then bInline = true; return; end
        finish(this, cdat, sOperation, nVersion);
    end);
    bScheduling = false;
    local bValidHandle = vHandle ~= nil and not type.isnull(vHandle);
    if (not bOK or not bValidHandle or bInline) then
        invalidate(tPending);
        if (bOK and bValidHandle) then pcall(tSettings.Cancel, vHandle); end
        error(not bOK and vHandle or "Schedule must defer its callback and return a non-nil handle.", 0);
    end

    if (tPending.Active and tPending.Version == nVersion) then
        tPending.Handle, tPending.HasHandle = vHandle, true;
    else
        -- Configuration or cancellation may have changed inside Schedule.
        tSettings.Cancel(vHandle);
    end
end

return class("Scaler",
{--METAMETHODS

},
{--STATIC PUBLIC
    --Scaler = function(stapub) end,
},
{--PRIVATE
    debounce      = null,
    movePending   = null,
    resizePending = null,
    --[[!
    @fqxn CoG.Scaler.Properties.OnResizeStart
    @desc Application-owned resize-start callback, initialized to a no-op function.
        The auto directive generates final getOnResizeStart. The manual final
        setter accepts a function or nil to restore dummy. Setting the property
        does not invoke it. There is no combined resize dispatcher.
    !]]
    OnResizeStart__autoAF = null,

    --[[!
    @fqxn CoG.Scaler.Properties.OnResizeEnd
    @desc Application-owned resize-end callback, initialized to a no-op function.
        The auto directive generates final getOnResizeEnd. The manual final
        setter accepts a function or nil to restore dummy. Adjustment methods
        invoke it immediately or after the configured quiet period.
    !]]
    OnResizeEnd__autoAF   = null,

    --[[!
    @fqxn CoG.Scaler.Properties.OnMoveStart
    @desc Application-owned move-start callback, initialized to dummy. The auto
        directive generates a final getter; the manual final setter accepts a
        function or nil to restore dummy. Setting it does not invoke it.
    !]]
    OnMoveStart__autoAF   = null,

    --[[!
    @fqxn CoG.Scaler.Properties.OnMoveEnd
    @desc Application-owned move-end callback, initialized to dummy. The auto
        directive generates a final getter; the manual final setter accepts a
        function or nil to restore dummy. Position adjustments invoke it
        immediately or after the configured quiet period.
    !]]
    OnMoveEnd__autoAF     = null,

},
{--PROTECTED
    buildWidth      = 0,
    buildHeight     = 0,
    screenWidth     = 0,
    screenHeight    = 0,
    viewportWidth   = 0, --this will be scaled and centered
    viewportHeight  = 0, --this will be scaled and centered
    viewportX       = 0, --this will be scaled and centered
    viewportY       = 0, --this will be scaled and centered
    covXW           = 0,
    covYH           = 0,
    coordOffsetX    = 0,
    coordOffsetY    = 0,
},
{--PUBLIC
    --[[!
    @fqxn CoG.Scaler.Methods.Scaler
    @desc Creates a scaler with independent callback scheduling. Optional sixth
        argument is {Debounce = false} to disable, or {Debounce = {DelayMS = 100}}
        to override configured defaults. Omission inherits CoG.config.Scaler.
    !]]
    Scaler = function(this, cdat, nBuildWidth, nBuildHeight, nScreenWidth, nScreenHeight, bFullscreen, tOptions)
        local pro = cdat.pro;
        assert(rawtype(nBuildWidth)     == "number", "Build width must be of type number. Type given was '${w}'"      % {w = rawtype(nBuildWidth)});
        assert(rawtype(nBuildHeight)    == "number", "Build height must be of type number. Type given was '${h}'"     % {h = rawtype(nBuildHeight)});
        assert(rawtype(nScreenWidth)    == "number", "Screen width must be of type number. Type given was '${w}'"     % {w = rawtype(nScreenWidth)});
        assert(rawtype(nScreenHeight)   == "number", "Screen height must be of type number. Type given was '${h}'"    % {h = rawtype(nScreenHeight)});
        assert(nBuildWidth      > 0, "Build Width must be a positive number");
        assert(nBuildHeight     > 0, "Build Height must be a positive number");
        assert(nScreenWidth     > 0, "Screen Width must be a positive number");
        assert(nScreenHeight    > 0, "Screen Height must be a positive number");

        assert(tOptions == nil or rawtype(tOptions) == "table", "Scaler options must be a table or nil.");
        for sKey in pairs(tOptions or {}) do assert(sKey == "Debounce", "Unknown scaler option: "..tostring(sKey)); end
        cdat.pri.debounce = resolveDebounce(tOptions and tOptions.Debounce);
        cdat.pri.movePending, cdat.pri.resizePending = pending(), pending();

        -- Establish function-typed private fields for the callback properties.
        -- Private storage permits replacing functions without treating them as
        -- protected method overrides; the public property methods remain final.
        this.setOnResizeStart(nil);
        this.setOnResizeEnd(nil);
        this.setOnMoveStart(nil);
        this.setOnMoveEnd(nil);

        pro.buildWidth   = nBuildWidth;
        pro.buildHeight  = nBuildHeight;
        pro.screenWidth  = nScreenWidth;
        pro.screenHeight = nScreenHeight;

        --TODO app asserts
        --configure the app window
        --tScaler.app.width   = tApp.width;
        --tScaler.app.height  = tApp.height;
        --tScaler.app.x       = tApp.x;
        --tScaler.app.y       = tApp.y;

        --configure the viewport
        local tViewport = fitrect({width = nScreenWidth, height = nScreenHeight, x = 0, y = 0}, {width = nBuildWidth, height = nBuildHeight}, true);

        local nViewportWidth    = tViewport.width;
        local nViewportHeight   = tViewport.height;
        local nViewportX        = tViewport.x;
        local nViewportY        = tViewport.y;

        pro.viewportWidth   = nViewportWidth;
        pro.viewportHeight  = nViewportHeight;
        pro.viewportX       = nViewportX;
        pro.viewportY       = nViewportY;

        pro.covXW = nViewportWidth  / nBuildWidth;
        pro.covYH = nViewportHeight / nBuildHeight;

        if (bFullscreen) then
            pro.coordOffsetX = nViewportX;-- + math.abs(tScaler.viewport.width - nBuildWidth) + (nAdditionalXOffset or 0);
            pro.coordOffsetY = nViewportY;-- + math.abs(tScaler.viewport.height - nBuildHeight) + (nAdditionalYOffset or 0);
        end
    end,
    --[[!
    @fqxn CoG.Scaler.Methods.setOnResizeStart
    @desc Replaces the resize-start callback; nil restores the shared dummy.
        Invalid values leave the callback unchanged. Does not invoke callbacks.
    @param function|nil fCallback Replacement callback or nil.
    @ret Scaler this This scaler.
    !]]
    setOnResizeStart__FNL = function(this, cdat, fCallback)
        assert(fCallback == nil or rawtype(fCallback) == "function", "OnResizeStart must be a function or nil.");

        -- Always store a function, including when resetting the callback.
        cdat.pri.OnResizeStart = fCallback == nil and dummy or fCallback;

        return this;
    end,

    --[[!
    @fqxn CoG.Scaler.Methods.setOnResizeEnd
    @desc Replaces the resize-end callback; nil restores the shared dummy.
        Invalid values leave the callback unchanged. Does not invoke callbacks.
    @param function|nil fCallback Replacement callback or nil.
    @ret Scaler this This scaler.
    !]]
    setOnResizeEnd__FNL = function(this, cdat, fCallback)
        assert(fCallback == nil or rawtype(fCallback) == "function", "OnResizeEnd must be a function or nil.");

        -- Validate before changing the private callback reference.
        cdat.pri.OnResizeEnd = fCallback == nil and dummy or fCallback;

        return this;
    end,

    --[[!
    @fqxn CoG.Scaler.Methods.setOnMoveStart
    @desc Replaces the move-start callback; nil restores the shared dummy.
        Invalid values leave the callback unchanged. Does not invoke callbacks.
    @param function|nil fCallback Replacement callback or nil.
    @ret Scaler this This scaler.
    !]]
    setOnMoveStart__FNL = function(this, cdat, fCallback)
        assert(fCallback == nil or rawtype(fCallback) == "function", "OnMoveStart must be a function or nil.");

        -- Keep callbacks instance-owned while sharing only the no-op default.
        cdat.pri.OnMoveStart = fCallback == nil and dummy or fCallback;

        return this;
    end,

    --[[!
    @fqxn CoG.Scaler.Methods.setOnMoveEnd
    @desc Replaces the move-end callback; nil restores the shared dummy.
        Invalid values leave the callback unchanged. Does not invoke callbacks.
    @param function|nil fCallback Replacement callback or nil.
    @ret Scaler this This scaler.
    !]]
    setOnMoveEnd__FNL = function(this, cdat, fCallback)
        assert(fCallback == nil or rawtype(fCallback) == "function", "OnMoveEnd must be a function or nil.");

        -- Nil resets behavior without changing the backing field's function type.
        cdat.pri.OnMoveEnd = fCallback == nil and dummy or fCallback;

        return this;
    end,

    --[[!
    @fqxn CoG.Scaler.Methods.getDebounce
    @desc Returns a detached snapshot of this instance's resolved debounce settings.
    !]]
    getDebounce__FNL = function(this, cdat)
        return copyFields(cdat.pri.debounce);
    end,

    --[[!
    @fqxn CoG.Scaler.Methods.isDebounceEnabled
    @desc Reports whether this instance has both scheduler functions and a positive delay.
    !]]
    isDebounceEnabled__FNL = function(this, cdat)
        local tSettings = cdat.pri.debounce;
        return tSettings.DelayMS > 0 and rawtype(tSettings.Schedule) == "function" and rawtype(tSettings.Cancel) == "function";
    end,

    --[[!
    @fqxn CoG.Scaler.Methods.cancelPendingCallbacks
    @desc Invalidates both move/resize jobs before asking the host to cancel them.
        Does not fire End. Call before discarding a scaler with pending jobs.
        Both cancellations are attempted even if the host raises an error.
    @ret Scaler this This scaler.
    !]]
    cancelPendingCallbacks__FNL = function(this, cdat)
        local pri = cdat.pri;
        local vMove, bMove = invalidate(pri.movePending);
        local vResize, bResize = invalidate(pri.resizePending);
        local bMoveOK, sMoveError = true, nil;
        local bResizeOK, sResizeError = true, nil;
        if (bMove) then bMoveOK, sMoveError = pcall(pri.debounce.Cancel, vMove); end
        if (bResize) then bResizeOK, sResizeError = pcall(pri.debounce.Cancel, vResize); end
        if (not bMoveOK) then error(sMoveError, 0); end
        if (not bResizeOK) then error(sResizeError, 0); end
        return this;
    end,

    --[[!
    @fqxn CoG.Scaler.Methods.setDebounce
    @desc Replaces instance overrides after validation and cancels pending bursts.
        Nil restores global defaults; false disables. A table overlays global defaults.
    @ret Scaler this This scaler.
    !]]
    setDebounce__FNL = function(this, cdat, vOptions)
        local tSettings = resolveDebounce(vOptions);
        this.cancelPendingCallbacks();
        cdat.pri.debounce = tSettings;
        return this;
    end,

    --[[!
    @fqxn CoG.Scaler.Methods.adjust
    @desc Immediately calculates the same adjusted rectangle as before, then
        notifies move followed by resize activity. Start/End callbacks receive
        (this, event); event contains Input, Output on End, InitialInput, Screen,
        Viewport, Operation, Method and Phase. These are calculations, not native
        window move/resize notifications. Callback errors propagate.
    !]]
    adjust = function(this, cdat, tRect)
        local pro = cdat.pro;
        local nCOV_XW = pro.covXW;
        local nCOV_YH = pro.covYH;

        local tResult = {width   = tRect.width   * nCOV_XW,
                height  = tRect.height  * nCOV_YH,
                x       = tRect.x * nCOV_XW + pro.coordOffsetX,
                y       = tRect.y * nCOV_YH + pro.coordOffsetY};

        local tInput = {x = tRect.x, y = tRect.y, width = tRect.width, height = tRect.height};
        notify(this, cdat, "move", "adjust", tInput, tResult);
        notify(this, cdat, "resize", "adjust", tInput, tResult);
        return tResult;
    end,
    --[[!
    @fqxn CoG.Scaler.Methods.adjustSize
    @desc Immediately adjusts size and notifies the independent resize callback channel.
    !]]
    adjustSize = function(this, cdat, width, height)
        local pro = cdat.pro;
        local tResult = {width   = width *   pro.covXW,
                height  = height *  pro.covYH};
        notify(this, cdat, "resize", "adjustSize", {width = width, height = height}, tResult);
        return tResult;
    end,
    --[[!
    @fqxn CoG.Scaler.Methods.adjustPos
    @desc Immediately adjusts position and notifies the independent move callback channel.
    !]]
    adjustPos = function(this, cdat, x, y)
        local pro = cdat.pro;
        local tResult = {x   = x * pro.covXW + pro.viewportX,
                y   = y * pro.covYH + pro.viewportY};
        notify(this, cdat, "move", "adjustPos", {x = x, y = y}, tResult);
        return tResult;
    end,
    getBuildSize = function(this, cdat)
        local pro = cdat.pro;
        return {width = pro.buildWidth, height = pro.buildHeight};
    end,
    getCOV = function(this, cdat)
        local pro = cdat.pro;
        return {xw = pro.covXW, yh = pro.covYH};
    end,
    --[[!
    @fqxn CoG.Scaler.Methods.getScreenSize
    @desc Returns an independent table containing the stored screen width and
        height, including space outside the fitted viewport.
    @ret table tSize Screen width and height.
    !]]
    getScreenSize = function(this, cdat)
        local pro = cdat.pro;
        return {width = pro.screenWidth, height = pro.screenHeight};
    end,

    --[[!
    @fqxn CoG.Scaler.Methods.getViewportDimensions
    @desc Returns an independent table describing the fitted viewport bounds.
    @ret table tDimensions Viewport width, height, x and y.
    !]]
    getViewportDimensions = function(this, cdat)
        local pro   = cdat.pro;
        return {width = pro.viewportWidth, height = pro.viewportHeight, x = pro.viewportX, y = pro.viewportY};
    end,

    --[[!
    @fqxn CoG.Scaler.Methods.getViewportSize
    @desc Returns an independent table containing the fitted viewport size.
    @ret table tSize Viewport width and height.
    !]]
    getViewportSize = function(this, cdat)
        local pro = cdat.pro;
        return {width = pro.viewportWidth, height = pro.viewportHeight};
    end,

    --[[!
    @fqxn CoG.Scaler.Methods.getViewportPosition
    @desc Returns an independent table containing the fitted viewport origin.
    @ret table tPosition Viewport x and y.
    !]]
    getViewportPosition = function(this, cdat)
        local pro = cdat.pro;
        return {x = pro.viewportX, y = pro.viewportY};
    end
},
nil,   --extending class
false, --if the class is final
nil    --interface(s) (either nil, or interface(s))
);
