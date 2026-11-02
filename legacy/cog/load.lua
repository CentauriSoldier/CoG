-- ON-DEMAND CODE OF GAMING LOADER
-- Lives at the Cog root alongside CoG.lua and config.lua.
local _sModule = ...;
local _G        = _G;
local assert    = assert;
local debug     = debug;
local error     = error;
local loadfile  = loadfile;
local math      = math;
local package   = package;
local pcall     = pcall;
local require   = require;
local select    = select;
local string    = string;
local tostring  = tostring;

local nCoGConfigParentLevels = 0;
local bInitialized = false;

--[[!
@fqxn CoG.init
@pulsarlua function init
@desc Initializes CoG after LuaEx. Requiring cog.load only returns this function. Successful subsequent calls return the existing CoG class without reconfiguration.
@param number|nil nConfigParentLevels Parent levels above the Cog root directory for the user configuration overlay; defaults to 0 for bundled defaults only.
@param string|nil sConfigFilename User configuration name without an extension; non-string values default to config. Blank names, extensions and directory components are rejected.
@ret class The CoG class, with read-only configuration exposed through CoG.config.
@throws LuaEx or its class dependencies are not initialized, invalid options or module/configuration load errors. Failed initialization may leave loaded modules and globals; package.path is restored.
@ex local init = require("cog.load"); init(2, "CoGConfig");
!]]
local function init(...)
    assert(_G.LUAEX_INIT == true, "Initialize LuaEx before loading CoG.");

    if (bInitialized) then
        return _G.CoG;
    end

    assert(_G.class and _G.ClassRegistry and _G.Potentiometer and _G.Protean,
           "CoG requires LuaEx class-load level 3 or higher.");
    assert(select("#", ...) <= 2, "CoG init accepts at most two options.");
    local nConfigParentLevels, sConfigFilename = ...;
    local type = _G.type;
    local sSource = debug.getinfo(1, "S").source;
    local pSourceDirectory = sSource:match("^@(.+)[/\\][^/\\]+$") or ".";
    local sOriginalPackagePath = package.path;

    if (nConfigParentLevels == nil) then
        nConfigParentLevels = nCoGConfigParentLevels;
    end
    if (type(sConfigFilename) ~= "string") then
        sConfigFilename = "config";
    end
    assert(type(nConfigParentLevels) == "number" and
           nConfigParentLevels >= 0 and nConfigParentLevels < math.huge and
           nConfigParentLevels % 1 == 0,
           "CoG config parent levels must be zero or a positive whole number.");
    assert(type(sConfigFilename) == "string" and #sConfigFilename > 0 and
           sConfigFilename:find("%S") and
           not sConfigFilename:find("[./\\:%z]"),
           "CoG config filename must be a nonblank name without an extension or directory components.");

    package.path = package.path..";"..pSourceDirectory.."/../?.lua";
    local bSuccess, vResult = pcall(function()
        local pCoG = type(_sModule) == "string" and _sModule:match("^(.*)%.[^.]+$") or "cog";

        local function fLoadCoGConfig(purge)
            -- Always execute the bundled assembler. It owns default sections,
            -- loads the optional user overlay and locks the combined result.
            local pConfigFile = pSourceDirectory.."/config.lua";
            local configLoader, sError = loadfile(pConfigFile);
            assert(configLoader, "Unable to load CoG config at '"..pConfigFile.."': "..tostring(sError));
            local tConfigOptions = {userFilename = sConfigFilename..".lua", purge = purge};

            if (nConfigParentLevels > 0) then
                -- Resolve the user's file independently of the working directory.
                tConfigOptions.userDirectory = pSourceDirectory..
                                               string.rep("/..", nConfigParentLevels);
            end

            local tConfig = configLoader(pCoG..".config", tConfigOptions);
            type.assert.custom(tConfig, "table", "CoG config must return a table.");

            -- A later require must observe the same assembled config as CoG.config.
            package.loaded[pCoG..".config"] = tConfig;
            return tConfig;
        end

        -- Configurable enums are loaded by the CoG config assembler.

        -- The CoG module builds the locked config before declaring the class.
        -- Its purge helper is available locally while the user overlay runs.
        local pClassFile = pSourceDirectory.."/CoG.lua";
        local classLoader, sError = loadfile(pClassFile);
        assert(classLoader, "Unable to load CoG class at '"..pClassFile.."': "..tostring(sError));
        CoG = classLoader(pCoG..".CoG", fLoadCoGConfig);
        package.loaded[pCoG..".CoG"] = CoG;
        scaler          = require(pCoG..".scaler");
        Shuffler        = require(pCoG..".Shuffler");
        Rarity          = require(pCoG..".Rarity");
        RNG             = require(pCoG..".RNG");
        BaseMod         = require(pCoG..".ModSystem.BaseMod");
        Factorium       = require(pCoG..".ModSystem.Factorium");
        Tiled           = require(pCoG..".Tiled");

        --interfaces
        IEquippable     = require(pCoG..".Interfaces.IEquippable");
        IConsumable     = require(pCoG..".Interfaces.IConsumable");

        TagSystem       = require(pCoG..".TagSystem");
        Targetor        = require(pCoG..".Targetor");

        -- Register lightweight instance types with their exact names.
        type.TagSystem = true;
        type.Targetor = true;

        --affix system
        AffixSystem         = require(pCoG..".AffixSystem");

        Pool            = require(pCoG..".Pool");
        StatusTracker   = require(pCoG..".StatusTracker");
        AStar           = require(pCoG..".AStar");

        --objects
        local pCoGObjects   = pCoG..".Objects";
        CoGRegistry         = require(pCoG..".CoGRegistry");
        CoGObject           = require(pCoGObjects..".CoGObject");
        CoGAbility          = require(pCoGObjects..".CoGAbility");
        CoGVehicle          = require(pCoGObjects..".VehicleSystem.CoGVehicle");
        CoGStructure        = require(pCoGObjects..".StructureSystem.CoGStructure");
        BaseCard            = require(pCoG..".CardSystem.BaseCard");
        BaseDeck            = require(pCoG..".CardSystem.BaseDeck");

        --item system
        local pItemSystem   = pCoGObjects..".ItemSystem";
        SlotPattern         = require(pItemSystem..".SlotPattern");
        CoGItem             = require(pItemSystem..".CoGItem");
        ItemSlot            = require(pItemSystem..".ItemSlot");
        ItemSlotSystem      = require(pItemSystem..".ItemSlotSystem");
        ItemSystem          = require(pItemSystem..".ItemSystem");
        ItemStashSystem     = require(pItemSystem..".ItemStashSystem");

        XPSystem        = require(pCoG..".XPSystem");

        -- Creature composition requires inventory, Rover and XP components first.
        CoGCreature    = require(pCoGObjects..".CreatureSystem.CoGCreature");
        return CoG;
    end);
    package.path = sOriginalPackagePath;
    if (not bSuccess) then
        error(vResult, 0);
    end
    bInitialized = true;
    return vResult;
end

return init;
