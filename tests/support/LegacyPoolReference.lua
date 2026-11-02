--[[!
@fqxn CoG.Tests.PoolReference
@desc Test-only reference runner for the archived Pool methods. Supplies plain Lua
    storage and method binding instead of loading or installing the old class system.
    Production code never imports this module.
@param string pSource Original or archived Pool.lua path.
@param class CoGBase Initialized native base, supplying the selected configuration.
@ret table Reference Callable test fixture exposing original Pool statics and methods.
!]]
return function(pSource, CoGBase)
    --[[!
    @fqxn CoG.Tests.PoolReference.copy
    @desc Copies the reference implementation's ordinary per-instance defaults.
    !]]
    local function fCopy(vValue)
        if (rawtype(vValue) ~= "table" or getmetatable(vValue) ~= nil) then
            return vValue;
        end

        local tCopy = {};

        for k, v in pairs(vValue) do
            tCopy[k] = fCopy(v);
        end

        return tCopy;
    end

    local wEnvironment = setmetatable({
        CoG = CoGBase,
        class = function(...) return table.pack(...); end,
    }, {__index = _G});
    local tDefinition = assert(loadfile(pSource, "t", wEnvironment))();
    local tInstances = setmetatable({}, {__mode = "k"});
    local Reference = {};

    for sName, vValue in pairs(tDefinition[3]) do
        Reference[sName:gsub("__RO$", "")] = vValue;
    end

    --[[!
    @fqxn CoG.Tests.PoolReference.build
    @desc Allocates a reference object and invokes the original public constructor.
    !]]
    local function fBuild(...)
        local oObject = {};
        local tData = {pri = {}, pro = fCopy(tDefinition[5]), ins = tInstances};
        local tMethods = {};
        tInstances[oObject] = tData;

        for sName, fMethod in pairs(tDefinition[6]) do
            if (sName ~= "Pool") then
                local fBound = fMethod;
                tMethods[sName] = function(...)
                    return fBound(oObject, tData, ...);
                end;
            end
        end

        local tMeta = {__type = "Pool", __index = tMethods};

        for sName, fOperator in pairs(tDefinition[2]) do
            local fBound = fOperator;

            if (sName == "__unm" or sName == "__len" or sName == "__clone") then
                tMeta[sName] = function(this) return fBound(this, tInstances[this]); end;
            else
                tMeta[sName] = function(this, other) return fBound(this, other, tInstances[this]); end;
            end
        end

        setmetatable(oObject, tMeta);
        tDefinition[6].Pool(oObject, tData, ...);

        return oObject;
    end

    wEnvironment.Pool = setmetatable(Reference, {__call = function(_, ...) return fBuild(...); end});

    return Reference;
end;
