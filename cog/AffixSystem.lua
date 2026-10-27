local CoG = CoG;
local _eTier           = CoG.config.TIER;
local _eMaxTier        = CoG.config.Rarity.Affix.maxTier;
local _eType           = enum("AffixSystem.TYPE", {"PREFIX", "SUFFIX"}, nil, true);
local _mSerializer     = require("LuaEx.lib.serializer");
local _tEntries        = setmetatable({}, {__mode = "k"});
local _tOwners         = setmetatable({}, {__mode = "k"});
local _tSystems        = setmetatable({}, {__mode = "k"});
local _tMethods        = setmetatable({}, {__mode = "k"});
local _tOwnerFactories = setmetatable({}, {__mode = "k"});
local _tDefinitions    = {};
local _cSystem;
local _tEntryMeta;
local _tJournalMeta;
local _tTokenMeta;

--[[!
    @fqxn CoG.AffixSystem.Internal.Functions.dummy
    @pulsarlua function dummy
    @desc Shared no-op used to initialize callbacks and reset them when a setter receives nil.
    @scope local
    @vis Private
!]]
local function dummy()
end

--[[!
    @fqxn CoG.AffixSystem.Internal.Functions.errorText
    @pulsarlua function errorText
    @desc Formats arbitrary callback errors without allowing a failing __tostring
    metamethod to interrupt compensation or leave a lifecycle operation locked.
    @param any vError Callback error value.
    @ret string sError Safe error description.
    @scope local
    @vis Private
!]]
local function errorText(vError)
    local bFormatted, sError = pcall(tostring, vError);
    return bFormatted and sError or "Unformattable callback error.";
end

--[[!
    @fqxn CoG.AffixSystem.Internal.Functions.registerOwnerClass
    @pulsarlua function registerOwnerClass
    @desc Uses existing serializer adapters to reconnect owned components before
    a restored host is returned. Item classes retain the inventory restore adapter.
    @param string sName Loaded concrete CoGObject class name.
    @scope local
    @vis Private
!]]
local function registerOwnerClass(sName)
    local cOwner = class.getbyname(sName, _ENV);
    assert(cOwner and class.ischildorself(cOwner, CoGObject), "Unknown affix owner class.");

    if (type(CoGItem) == "class" and class.ischildorself(cOwner, CoGItem)) then
        require("cog.Objects.ItemSystem.ItemRules").registerPersistence(cOwner, true);
    elseif (not _tOwnerFactories[cOwner]) then
        --[[!
            @fqxn CoG.AffixSystem.Internal.Functions.registerOwnerClass.restore
            @pulsarlua function fRestore
            @desc Restores the normal class snapshot, then reconnects its component.
            @param table tState Saved host hierarchy.
            @ret CoGObject oOwner Restored host with connected affix ownership.
            @scope local
        !]]
        local function fRestore(tState)
            local oOwner = cOwner.deserialize(tState);
            oOwner.getAffixSystem();
            return oOwner;
        end

        _mSerializer.registerFactory(cOwner, {name = sName, types = {sName}, restore = fRestore});
        _tOwnerFactories[cOwner] = true;
    end
end

--[[!
    @fqxn CoG.AffixSystem.Internal.Functions.denseLength
    @pulsarlua function denseLength
    @desc Validates a dense list without accepting holes or nonnumeric keys.
    @param table tList Candidate dense list.
    @ret number nCount Validated or matching entry count.
    @scope local
    @vis Private
!]]
local function denseLength(tList)
    type.assert.table(tList);

    local nCount = 0;
    for nIndex in pairs(tList) do
        assert(rawtype(nIndex) == "number" and nIndex > 0 and nIndex % 1 == 0, "Expected a dense list.");
        nCount = nCount + 1;
    end

    for nIndex = 1, nCount do
        assert(tList[nIndex] ~= nil, "List contains a hole.");
    end

    return nCount;
end

--[[!
    @fqxn CoG.AffixSystem.Internal.Functions.entry
    @pulsarlua function entry
    @desc Gets private affix state or rejects an unrelated object.
    @param AffixSystemEntry oAffix Affix instance.
    @ret table tState Private affix state.
    @scope local
    @vis Private
!]]
local function entry(oAffix)
    local tState = _tEntries[oAffix];
    assert(tState, "Expected an affix created by AffixSystem.createAffix.");

    return tState;
end

--[[!
    @fqxn CoG.AffixSystem.Internal.Functions.definitionKey
    @pulsarlua function definitionKey
    @desc Validates an opaque ID and folds case with Lua's string.lower. No tier,
    namespace or gameplay meaning is inferred; spaces and punctuation are retained.
    @param string sID Identifier containing non-whitespace text.
    @ret string sKey Case-insensitive registry/application lookup key.
!]]
local function definitionKey(sID)
    type.assert.string(sID, "%S+");
    return sID:lower();
end

--[[!
    @fqxn CoG.AffixSystem.Internal.Functions.copyValues
    @pulsarlua function copyValues
    @desc Copies generic plain Lua data without interpreting its keys or values.
    Preserves aliases/cycles; rejects functions, typed objects and metatables so
    mutable application objects cannot become shared definition state.
    @param any vValue Plain table or primitive data.
    @param table|nil tCopies Internal source-to-copy map.
    @ret any vCopy Independent data graph.
!]]
local function copyValues(vValue, tCopies)
    local sType = rawtype(vValue);
    if (sType ~= "table") then
        assert(sType == "nil" or sType == "boolean" or sType == "number" or sType == "string", "Affix values must be plain Lua data.");
        return vValue;
    end
    assert(getmetatable(vValue) == nil, "Affix values cannot have a metatable.");

    tCopies = tCopies or {};
    if (not tCopies[vValue]) then
        local tCopy = {};
        tCopies[vValue] = tCopy;
        for k, v in pairs(vValue) do
            local sKeyType = rawtype(k);
            assert(sKeyType == "string" or sKeyType == "number" or sKeyType == "boolean", "Affix value keys must be strings, numbers or booleans.");
            tCopy[k] = copyValues(v, tCopies);
        end
    end
    return tCopies[vValue];
end

--[[!
    @fqxn CoG.AffixSystem.Internal.Functions.owner
    @pulsarlua function owner
    @desc Resolves an external host without introducing a saved object cycle.
    @param AffixSystemToken tToken External ownership token.
    @ret CoGObject|nil oOwner Live external host.
    @scope local
    @vis Private
!]]
local function owner(tToken)
    local tReference = _tOwners[tToken];
    return tReference and tReference[1] or nil;
end

--[[!
    @fqxn CoG.AffixSystem.Internal.Functions.validateEntry
    @pulsarlua function validateEntry
    @desc Checks fixed metadata and saved application state. Private configured
    tiers are rebound by collection name, ordinal and member name after loading.
    @param table tState Definition, application or serializer state.
    @param boolean bRestoring Whether saved private tiers may be rebound to configuration.
    @scope local
    @vis Private
!]]
local function validateEntry(tState, bRestoring)
    type.assert.table(tState);
    assert(_eType.__hasa(tState.kind), "Invalid affix type.");

    local eTier = tState.tier;
    if (bRestoring and not _eTier.__hasa(eTier)) then
        assert(subtype(eTier) == "enumitem" and eTier.parent.__name == _eTier.__name and
               eTier.id >= 1 and eTier.id <= _eTier.__count, "Invalid saved affix tier.");

        local eConfigured = _eTier[eTier.id];
        assert(eTier.name == eConfigured.name, "Saved affix tier differs from configuration.");
        tState.tier = eConfigured;
    end

    assert(_eTier.__hasa(tState.tier) and tState.tier.id <= _eMaxTier.id, "Invalid affix tier.");
    type.assert.string(tState.id, "%S+");
    type.assert.string(tState.name, "%S+");
    assert(tState.name == tState.name:match("^%s*(.-)%s*$"), "Affix text has surrounding whitespace.");
    type.assert.string(tState.description, "%S+");
    assert(rawtype(tState.priority) == "number" and tState.priority == tState.priority and
           math.abs(tState.priority) < math.huge, "Naming priority must be finite.");
    assert(denseLength(tState.classes) > 0, "Affix requires a compatible class.");

    for _, cClass in ipairs(tState.classes) do
        assert(class.is(cClass), "Invalid compatible class.");
    end

    assert(tState.token == false or type(tState.token) == "AffixSystemToken", "Invalid affix ownership.");
    assert(type(tState.journal) == "AffixSystemJournal", "Invalid affix journal.");
    -- Legacy entries predate generic payloads; retain their metadata and journals.
    if (bRestoring and tState.values == nil) then
        tState.values = {};
    end
    type.assert.table(tState.values);
    copyValues(tState.values);
end

--[[!
    @fqxn CoG.AffixSystem.Internal.Functions.prepareDefinition
    @pulsarlua function prepareDefinition
    @desc Validates/copies an entire pattern before registry mutation. Tier keys
    must be actual configured enum members and each payload is developer data.
    @param string sID Opaque definition ID; registered spelling is preserved.
    @param table tPattern Type, name, classes, tiers and optional priority/description.
    @ret table tDefinition Private validated definition.
!]]
local function prepareDefinition(sID, tPattern)
    definitionKey(sID);
    type.assert.table(tPattern);
    local tAllowed = {type = true, name = true, classes = true, tiers = true, priority = true, description = true};
    for sField in pairs(tPattern) do
        assert(tAllowed[sField], "Unknown affix definition field: "..tostring(sField));
    end

    local tClasses = {};
    for nIndex = 1, denseLength(tPattern.classes) do
        tClasses[nIndex] = tPattern.classes[nIndex];
    end
    type.assert.table(tPattern.tiers);
    local tDefinition = {
        kind        = tPattern.type,
        name        = tPattern.name,
        classes     = tClasses,
        id          = sID,
        priority    = tPattern.priority == nil and 0 or tPattern.priority,
        description = tPattern.description == nil and tPattern.name or tPattern.description,
        tiers       = {},
    };
    local nCount = 0;
    local tValueCopies = {};
    for eTier, tValues in pairs(tPattern.tiers) do
        assert(_eTier.__hasa(eTier) and eTier.id <= _eMaxTier.id, "Definition tier must be a supported configured tier enum member.");
        type.assert.table(tValues);
        local tCopy = copyValues(tValues, tValueCopies);
        validateEntry({
            kind        = tDefinition.kind,
            name        = tDefinition.name,
            classes     = tClasses,
            id          = sID,
            priority    = tDefinition.priority,
            description = tDefinition.description,
            tier        = eTier,
            values      = tCopy,
            token       = false,
            journal     = setmetatable({}, _tJournalMeta),
        }, false);
        tDefinition.tiers[eTier] = tCopy;
        nCount = nCount + 1;
    end
    assert(nCount > 0, "Affix definition requires at least one tier.");
    return tDefinition;
end

--[[!
    @fqxn CoG.AffixSystem.Internal.Functions.newEntry
    @pulsarlua function newEntry
    @desc Builds a read-only affix object around private metadata/application state.
    Its journal is deliberately mutable; metadata and ownership have no setters.
    @param table tState Definition, application or serializer state.
    @ret AffixSystemEntry oAffix Independent read-only affix object.
    @scope local
    @vis Private
!]]
local function newEntry(tState)
    local oAffix = {};
    _tEntries[oAffix] = tState;
    _tMethods[oAffix] = {};

    return setmetatable(oAffix, _tEntryMeta);
end

local _tEntryMethods = {
    --[[!
        @fqxn CoG.AffixSystem.Affix.Methods.getDefinitionID
        @pulsarlua function AffixSystemEntry.getDefinitionID
        @desc Returns the stable identity shared by instances of this affix definition.
        @ret string sDefinitionID Stable definition identity.
    !]]
    getDefinitionID = function(oAffix)
        return entry(oAffix).id;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Affix.Methods.getName
        @pulsarlua function AffixSystemEntry.getName
        @desc Returns this affix's display text without composing the owner's name.
        @ret string sName Display name.
    !]]
    getName = function(oAffix)
        return entry(oAffix).name;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Affix.Methods.getDescription
        @pulsarlua function AffixSystemEntry.getDescription
        @desc Returns this affix's immutable description.
        @ret string sDescription Affix description.
    !]]
    getDescription = function(oAffix)
        return entry(oAffix).description;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Affix.Methods.getType
        @pulsarlua function AffixSystemEntry.getType
        @desc Returns the immutable prefix/suffix classification.
        @ret AffixSystem.TYPE eType Prefix or suffix member.
    !]]
    getType = function(oAffix)
        return entry(oAffix).kind;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Affix.Methods.getTier
        @pulsarlua function AffixSystemEntry.getTier
        @desc Returns the immutable configured tier member.
        @ret TIER eTier Configured affix tier.
    !]]
    getTier = function(oAffix)
        return entry(oAffix).tier;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Affix.Methods.getValues
        @pulsarlua function AffixSystemEntry.getValues
        @desc Returns an independent copy of this entry's selected tier payload.
        The host interprets its meaning. Edits cannot alter this entry or registry.
        @ret table tValues Generic selected-tier data with aliases/cycles preserved.
    !]]
    getValues = function(oAffix)
        return copyValues(entry(oAffix).values);
    end,

    --[[!
        @fqxn CoG.AffixSystem.Affix.Methods.getNamingPriority
        @pulsarlua function AffixSystemEntry.getNamingPriority
        @desc Returns the priority used to resolve display selection when tiers tie.
        @ret number nPriority Finite naming priority.
    !]]
    getNamingPriority = function(oAffix)
        return entry(oAffix).priority;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Affix.Methods.getJournal
        @pulsarlua function AffixSystemEntry.getJournal
        @desc Returns the mutable journal for this application. The system replaces it on a fresh application and after successful removal.
        @ret AffixSystemJournal tJournal Mutable application state.
    !]]
    getJournal = function(oAffix)
        return entry(oAffix).journal;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Affix.Methods.getOwner
        @pulsarlua function AffixSystemEntry.getOwner
        @desc Returns the live external owner, or nil when detached or not yet reconnected after loading.
        @ret CoGObject|nil oOwner Live external owner.
    !]]
    getOwner = function(oAffix)
        local tToken = entry(oAffix).token;

        return tToken and owner(tToken) or nil;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Affix.Methods.getSystem
        @pulsarlua function AffixSystemEntry.getSystem
        @desc Returns the live owning system, or nil when detached or not yet reconnected after loading.
        @ret AffixSystem|nil oSystem Live owning system.
    !]]
    getSystem = function(oAffix)
        local tToken = entry(oAffix).token;
        local tReference = tToken and _tSystems[tToken];

        return tReference and tReference[1] or nil;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Affix.Methods.isApplied
        @pulsarlua function AffixSystemEntry.isApplied
        @desc Determines whether this affix is currently applied to a system.
        @ret boolean bResult True when the documented condition holds.
    !]]
    isApplied = function(oAffix)
        return entry(oAffix).token ~= false;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Affix.Methods.isPrefix
        @pulsarlua function AffixSystemEntry.isPrefix
        @desc Determines whether this affix is a prefix.
        @ret boolean bResult True when the documented condition holds.
    !]]
    isPrefix = function(oAffix)
        return entry(oAffix).kind == _eType.PREFIX;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Affix.Methods.isSuffix
        @pulsarlua function AffixSystemEntry.isSuffix
        @desc Determines whether this affix is a suffix.
        @ret boolean bResult True when the documented condition holds.
    !]]
    isSuffix = function(oAffix)
        return entry(oAffix).kind == _eType.SUFFIX;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Affix.Methods.isCompatibleWithClass
        @pulsarlua function AffixSystemEntry.isCompatibleWithClass
        @desc Tests a listed compatible class or its descendant by class object or registered name.
        Invalid class arguments return false. Name queries do not expose class objects.
        @param class|string cClass Candidate owner class or registered name.
        @ret boolean bResult True when the documented condition holds.
    !]]
    isCompatibleWithClass = function(oAffix, cClass)
        if (class.is(cClass) or (rawtype(cClass) == "string" and class.exists(cClass))) then
            for _, cAllowed in ipairs(entry(oAffix).classes) do
                if (class.ischildorself(cClass, cAllowed)) then
                    return true;
                end
            end
        end

        return false;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Affix.Methods.eachCompatibleClass
        @pulsarlua function AffixSystemEntry.eachCompatibleClass
        @desc Returns an index/class iterator over a copy of this definition's compatibility list.
        @ret function fIterator Iterator function.
        @ret table tValues Copied values used as iterator state.
        @ret number nIndex Initial iterator index.
    !]]
    eachCompatibleClass = function(oAffix)
        local tClasses = {};
        for nIndex, cClass in ipairs(entry(oAffix).classes) do
            tClasses[nIndex] = cClass;
        end

        return ipairs(tClasses);
    end,
};

_tEntryMeta = {
    __type = "AffixSystemEntry",

    --[[!
        @fqxn CoG.AffixSystem.Internal.EntryMeta.Methods.__index
        @pulsarlua function EntryMeta.__index
        @desc Returns a cached method bound to this exact affix instance.
        Unknown member names raise an error; cached functions remain private.
        @param AffixSystemEntry oAffix Affix instance.
        @param string sKey Requested method name.
        @ret function fMethod Method bound to this affix.
    !]]
    __index = function(oAffix, sKey)
        local fMethod = _tEntryMethods[sKey];
        if (fMethod) then
            -- Keep bound methods outside the public table, preserving read-only
            -- members while avoiding one new closure on every getter lookup.
            local tMethods = _tMethods[oAffix];
            if (not tMethods[sKey]) then
                tMethods[sKey] = function(...)
                    return fMethod(oAffix, ...);
                end;
            end

            return tMethods[sKey];
        end

        error("Unknown affix member: "..tostring(sKey), 2);
    end,

    --[[!
        @fqxn CoG.AffixSystem.Internal.EntryMeta.Methods.__newindex
        @pulsarlua function EntryMeta.__newindex
        @desc Rejects direct modification of affix metadata and ownership.
    !]]
    __newindex = function()
        error("Affix metadata and ownership are read-only.", 2);
    end,

    --[[!
        @fqxn CoG.AffixSystem.Internal.EntryMeta.Methods.__serialize
        @pulsarlua function EntryMeta.__serialize
        @desc Provides detached metadata while retaining journal/token identity for
        hook upvalues and ownership. Snapshot consumers cannot mutate shared definitions.
        @param AffixSystemEntry oAffix Affix instance.
        @ret table tState Serializer state; external owner references are omitted from tokens.
    !]]
    __serialize = function(oAffix)
        local tState = entry(oAffix);
        local tClasses = {};
        for nIndex, cClass in ipairs(tState.classes) do
            tClasses[nIndex] = cClass;
        end
        return {
            kind        = tState.kind,
            name        = tState.name,
            tier        = tState.tier,
            classes     = tClasses,
            id          = tState.id,
            priority    = tState.priority,
            description = tState.description,
            values      = copyValues(tState.values),
            token       = tState.token,
            journal     = tState.journal,
        };
    end,

    --[[!
        @fqxn CoG.AffixSystem.Internal.EntryMeta.Methods.__tostring
        @pulsarlua function EntryMeta.__tostring
        @desc Returns this affix's display text.
        @param AffixSystemEntry oAffix Affix instance.
        @ret string sName Affix display text.
    !]]
    __tostring = function(oAffix)
        return entry(oAffix).name;
    end,
};

_tJournalMeta = {
    __type = "AffixSystemJournal",

    --[[!
        @fqxn CoG.AffixSystem.Internal.JournalMeta.Methods.__serialize
        @pulsarlua function JournalMeta.__serialize
        @desc Provides serializer state while preserving the supported shared object relationships.
        @param AffixSystemJournal tJournal Mutable application journal.
        @ret table tState Serializer state; external owner references are omitted from tokens.
    !]]
    __serialize = function(tJournal)
        local tState = {};
        for k, v in pairs(tJournal) do
            tState[k] = v;
        end

        return tState;
    end,
};

_tTokenMeta = {
    __type = "AffixSystemToken",

    --[[!
        @fqxn CoG.AffixSystem.Internal.TokenMeta.Methods.__serialize
        @pulsarlua function TokenMeta.__serialize
        @desc Provides serializer state while preserving the supported shared object relationships.
        @param AffixSystemToken tToken Shared component ownership token.
        @ret table tState Owner class and lock flag; the external host is omitted.
    !]]
    __serialize = function(tToken)
        return {ownerClass = tToken.ownerClass, locked = tToken.locked};
    end,
};

-- Private callable factories reuse the serializer's existing extension protocol.
-- Tokens preserve sharing, journals preserve hook upvalues, and entries preserve identity.
local _oEntryFactory = setmetatable({}, {
    --[[!
        @fqxn CoG.AffixSystem.Internal.EntryFactory.Methods.__call
        @pulsarlua function EntryFactory.__call
        @desc Private callable marker required by serializer registration; the restore adapter creates runtime values.
        @vis Private
    !]]
    __call = function()
    end
});

local _oJournalFactory = setmetatable({}, {
    --[[!
        @fqxn CoG.AffixSystem.Internal.JournalFactory.Methods.__call
        @pulsarlua function JournalFactory.__call
        @desc Private callable marker required by serializer registration; the restore adapter creates runtime values.
        @vis Private
    !]]
    __call = function()
    end
});

local _oTokenFactory = setmetatable({}, {
    --[[!
        @fqxn CoG.AffixSystem.Internal.TokenFactory.Methods.__call
        @pulsarlua function TokenFactory.__call
        @desc Private callable marker required by serializer registration; the restore adapter creates runtime values.
        @vis Private
    !]]
    __call = function()
    end
});
_mSerializer.registerFactory(_oEntryFactory, {
    name  = "AffixSystemEntry",
    types = {"AffixSystemEntry"},

    --[[!
        @fqxn CoG.AffixSystem.Internal.EntryFactory.Methods.restore
        @pulsarlua function EntryFactory.restore
        @desc Validates and reconstructs decoded serializer state without invoking gameplay callbacks.
        @param table tState Definition, application or serializer state.
        @ret AffixSystemEntry oRestored Restored runtime value.
        @vis Private
    !]]
    restore = function(tState)
        validateEntry(tState, true);

        return newEntry(tState);
    end,
});
_mSerializer.registerFactory(_oJournalFactory, {
    name  = "AffixSystemJournal",
    types = {"AffixSystemJournal"},

    --[[!
        @fqxn CoG.AffixSystem.Internal.JournalFactory.Methods.restore
        @pulsarlua function JournalFactory.restore
        @desc Validates and reconstructs decoded serializer state without invoking gameplay callbacks.
        @param table tState Definition, application or serializer state.
        @ret AffixSystemJournal oRestored Restored runtime value.
        @vis Private
    !]]
    restore = function(tState)
        type.assert.table(tState);

        return setmetatable(tState, _tJournalMeta);
    end,
});
_mSerializer.registerFactory(_oTokenFactory, {
    name  = "AffixSystemToken",
    types = {"AffixSystemToken"},

    --[[!
        @fqxn CoG.AffixSystem.Internal.TokenFactory.Methods.restore
        @pulsarlua function TokenFactory.restore
        @desc Validates and reconstructs decoded serializer state without invoking gameplay callbacks.
        @param table tState Definition, application or serializer state.
        @ret AffixSystemToken oRestored Restored runtime value.
        @vis Private
    !]]
    restore = function(tState)
        type.assert.table(tState);
        -- Older saves used empty tokens and continue to reconnect on access.
        local sOwnerClass = tState.ownerClass == nil and "" or tState.ownerClass;
        local bLocked = tState.locked == true;
        type.assert.string(sOwnerClass);
        assert(tState.locked == nil or rawtype(tState.locked) == "boolean", "Invalid owner lock.");
        for sKey in pairs(tState) do
            assert(sKey == "ownerClass" or sKey == "locked", "Invalid affix ownership token.");
        end

        if (sOwnerClass ~= "") then
            registerOwnerClass(sOwnerClass);
        end

        return setmetatable({ownerClass = sOwnerClass, locked = bLocked}, _tTokenMeta);
    end,
});

--[[!
    @fqxn CoG.AffixSystem.Internal.Functions.find
    @pulsarlua function find
    @desc Finds an applied instance by identity, never by display text.
    @param table tRecords Application records.
    @param AffixSystemEntry oAffix Affix instance.
    @ret number|nil nIndex Matching record position, or nil.
    @ret table|nil tRecord Matching application record.
    @scope local
    @vis Private
!]]
local function find(tRecords, oAffix)

    for nIndex, tRecord in ipairs(tRecords) do
        if (rawequal(tRecord.affix, oAffix)) then
            return nIndex, tRecord;
        end
    end
end

--[[!
    @fqxn CoG.AffixSystem.Internal.Functions.count
    @pulsarlua function count
    @desc Counts one affix group, optionally excluding an outgoing instance.
    @param table tRecords Application records.
    @param AffixSystem.TYPE eType Prefix or suffix group; nil includes both when supported.
    @param AffixSystemEntry|nil oExcluded Outgoing instance excluded from duplicate/count checks.
    @ret number nCount Validated or matching entry count.
    @scope local
    @vis Private
!]]
local function count(tRecords, eType, oExcluded)
    local nCount = 0;
    for _, tRecord in ipairs(tRecords) do
        if (not rawequal(tRecord.affix, oExcluded) and (eType == nil or tRecord.affix.getType() == eType)) then
            nCount = nCount + 1;
        end
    end

    return nCount;
end

--[[!
    @fqxn CoG.AffixSystem.Internal.Functions.hooks
    @pulsarlua function hooks
    @desc Validates a complete enum-keyed hook map before registering any hook.
    @param eventrix kEvents Dispatcher checked for existing hooks.
    @param table|nil vHooks Enum-keyed hook functions or ordered function lists.
    @ret table tHooks Validated event/callback records.
    @scope local
    @vis Private
!]]
local function hooks(kEvents, vHooks)
    local tHooks = {};
    if (vHooks == nil) then
        return tHooks;
    end

    type.assert.table(vHooks);

    for eEvent, vFunctions in pairs(vHooks) do
        assert(subtype(eEvent) == "enumitem", "Affix event keys must be enum members.");

        local tFunctions = rawtype(vFunctions) == "function" and {vFunctions} or vFunctions;
        local nCount = denseLength(tFunctions);
        local tSeen = {};
        for nIndex = 1, nCount do
            local fHook = tFunctions[nIndex];
            type.assert["function"](fHook);
            assert(not tSeen[fHook] and kEvents.getHookOrdinal(eEvent, fHook) == -1, "Affix hook is already registered.");
            tSeen[fHook] = true;
            tHooks[#tHooks + 1] = {event = eEvent, callback = fHook};
        end
    end

    return tHooks;
end

--[[!
    @fqxn CoG.AffixSystem.Internal.Functions.add
    @pulsarlua function add
    @desc Claims an instance before calling onAdd(affix, journal, ...), making its
    owner/system inspectable. On error attempts onRemove compensation. If undo
    also fails, retains the application and returns it for explicit recovery.
    @param AffixSystem oSystem System performing the application.
    @param table pri System private state.
    @param AffixSystemEntry oAffix Affix instance.
    @param function fAdd Captured add callback.
    @param function fRemove Captured removal callback.
    @param varargs ... Developer-defined arguments forwarded to lifecycle callbacks or event hooks.
    @ret boolean bSuccess True when the lifecycle operation succeeds.
    @ret AffixSystemEntry|nil oResult Affected or retained recovery affix.
    @ret string|nil sReason Failure/recovery explanation; nil on success.
    @scope local
    @vis Private
!]]
local function add(oSystem, pri, oAffix, fAdd, fRemove, ...)
    local tState = entry(oAffix);
    tState.token = pri.token;
    tState.journal = setmetatable({}, _tJournalMeta);

    local tRecord = {
        affix    = oAffix,
        hooks    = {},
        onAdd    = fAdd,
        onRemove = fRemove,
        arguments = table.pack(...)
    };
    pri.records[#pri.records + 1] = tRecord;
    pri.nameCache = {};

    local bAdded, vHooks = pcall(fAdd, oAffix, tState.journal, ...);
    if (bAdded) then
        bAdded, vHooks = pcall(hooks, pri.events, vHooks);
    end

    if (bAdded) then
        tRecord.hooks = vHooks;

        for _, tHook in ipairs(vHooks) do
            pri.events.addHook(tHook.event, tHook.callback);
        end

        return true, oAffix, nil;
    end

    local bUndone, sUndoError = pcall(fRemove, oAffix, tState.journal, ...);
    if (not bUndone) then
        return false, oAffix, "Add failed: "..errorText(vHooks).."; undo failed: "..errorText(sUndoError);
    end

    table.remove(pri.records, #pri.records);
    tState.token = false;
    tState.journal = setmetatable({}, _tJournalMeta);

    return false, nil, "Add failed: "..errorText(vHooks);
end

--[[!
    @fqxn CoG.AffixSystem.Internal.Functions.remove
    @pulsarlua function remove
    @desc Calls captured onRemove while ownership/hooks remain available. Success
    unregisters only this entry's hooks and releases ownership; errors retain state.
    @param table pri System private state.
    @param number nIndex Application record index.
    @param varargs ... Developer-defined arguments forwarded to lifecycle callbacks or event hooks.
    @ret boolean bSuccess True when the lifecycle operation succeeds.
    @ret AffixSystemEntry|nil oResult Affected or retained recovery affix.
    @ret string|nil sReason Failure/recovery explanation; nil on success.
    @scope local
    @vis Private
!]]
local function remove(pri, nIndex, ...)
    local tRecord = pri.records[nIndex];
    local tState = entry(tRecord.affix);
    local bRemoved, sError = pcall(tRecord.onRemove, tRecord.affix, tState.journal, ...);
    if (not bRemoved) then
        return false, nil, "Remove failed: "..errorText(sError);
    end

    for _, tHook in ipairs(tRecord.hooks) do
        pri.events.removeHook(tHook.event, tHook.callback);
    end

    table.remove(pri.records, nIndex);
    pri.nameCache = {};
    tState.token = false;
    tState.journal = setmetatable({}, _tJournalMeta);

    return true, tRecord.affix, nil;
end

--[[!
    @fqxn CoG.AffixSystem.Internal.Functions.each
    @pulsarlua function each
    @desc Iterates a copied list, preserving internal collection ownership.
    @param table tRecords Application records.
    @param AffixSystem.TYPE eType Prefix or suffix group; nil includes both when supported.
    @ret function fIterator Iterator function.
    @ret table tValues Copied values used as iterator state.
    @ret number nIndex Initial iterator index.
    @scope local
    @vis Private
!]]
local function each(tRecords, eType)
    local tEntries = {};
    for _, tRecord in ipairs(tRecords) do
        if (eType == nil or tRecord.affix.getType() == eType) then
            tEntries[#tEntries + 1] = tRecord.affix;
        end
    end

    return ipairs(tEntries);
end

--[[!
    @fqxn CoG.AffixSystem.Internal.Functions.selected
    @pulsarlua function selected
    @desc Selects one naming candidate by tier, priority, then stable definition ID.
    @param table tRecords Application records.
    @param AffixSystem.TYPE eType Prefix or suffix group; nil includes both when supported.
    @ret string|nil sText Selected group display text, or nil.
    @scope local
    @vis Private
!]]
local function selected(tRecords, eType)
    local oSelected;
    for _, tRecord in ipairs(tRecords) do
        local oAffix = tRecord.affix;
        if (oAffix.getType() == eType) then
            local bSelect = oSelected == nil;
            if (oSelected) then
                local nTier, nOtherTier = oAffix.getTier().id, oSelected.getTier().id;
                local nPriority, nOtherPriority = oAffix.getNamingPriority(), oSelected.getNamingPriority();
                local bEarlierID = definitionKey(oAffix.getDefinitionID()) < definitionKey(oSelected.getDefinitionID());
                bSelect = nTier > nOtherTier or (nTier == nOtherTier and (nPriority > nOtherPriority or
                          (nPriority == nOtherPriority and bEarlierID)));
            end

            if (bSelect) then
                oSelected = oAffix;
            end
        end
    end

    return oSelected and oSelected.getName() or nil;
end

--[[!
    @fqxn CoG.AffixSystem
    @pulsarlua class AffixSystem
    @desc Standalone owned CoGObject component for prefixes and suffixes. All affix
    metadata, applications, journals, callbacks, events, limits and composed naming
    live in this file. The host defines gameplay effects through callbacks receiving
    (affix, journal, ...); affix.getOwner() exposes that host. Each application
    captures its callback pair so later setter calls cannot change its undo logic.
    Callback errors signal failure; arbitrary gameplay writes cannot be rolled back
    automatically. Undo must handle partial adds and be safe to retry after failure.
    Owners are external runtime references, as with inventory systems. Serializer
    adapters reconnect owned components before returning their hosts. Direct class
    deserialization and older saves still reconnect through getAffixSystem().
    Detached standalone systems use setOwner(host); owned components cannot rebind.
    Callbacks/effects are never replayed during loading.
    Save callbacks must not capture their host/system or create object-hook cycles;
    use the affix's owner/system getters instead. Hooks may capture their journal.
    Original application arguments are retained for replacement recovery and saving;
    do not pass the owning host/system back into their own saved argument graph.
!]]
_cSystem = class("AffixSystem",
{--METAMETHODS
},
{--STATIC PUBLIC
    TYPE     = _eType,
    MAX_TIER = _eMaxTier,

    --[[!
        @fqxn CoG.AffixSystem.Methods.registerDefinition
        @pulsarlua function AffixSystem.registerDefinition
        @desc Copies a validated definition into the static registry. Rejects
        duplicate IDs regardless of case; registration never replaces a definition.
        @param string sID Opaque ID containing non-whitespace text.
        @param table tPattern Required type, name, classes and tiers. tiers maps
        configured tier enum members to generic plain-data tables. Optional
        priority defaults to zero; description defaults to name.
        @ret class cSystem AffixSystem for chaining.
        @throws Invalid pattern or duplicate ID; registry remains unchanged.
    !]]
    registerDefinition = function(sID, tPattern)
        local sKey = definitionKey(sID);
        assert(not _tDefinitions[sKey], "Affix definition ID is already registered.");
        local tDefinition = prepareDefinition(sID, tPattern);
        _tDefinitions[sKey] = tDefinition;
        return _cSystem;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.registerDefinitions
        @pulsarlua function AffixSystem.registerDefinitions
        @desc Atomically imports an ID-keyed table of patterns. Validates every
        pattern and case-insensitive collision before committing any definition.
        @param table tPatterns Definition ID to pattern map, e.g. require output.
        @ret class cSystem AffixSystem for chaining.
        @throws Invalid input or duplicate ID; no partial registration occurs.
    !]]
    registerDefinitions = function(tPatterns)
        type.assert.table(tPatterns);
        local tPending = {};
        for sID, tPattern in pairs(tPatterns) do
            local sKey = definitionKey(sID);
            assert(not _tDefinitions[sKey] and not tPending[sKey], "Affix definition ID is already registered.");
            tPending[sKey] = prepareDefinition(sID, tPattern);
        end
        for sKey, tDefinition in pairs(tPending) do
            _tDefinitions[sKey] = tDefinition;
        end
        return _cSystem;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.hasDefinition
        @pulsarlua function AffixSystem.hasDefinition
        @desc Tests whether an opaque ID is registered, ignoring its case.
        @param string sID Definition ID.
        @ret boolean bRegistered Whether the ID exists.
    !]]
    hasDefinition = function(sID)
        return _tDefinitions[definitionKey(sID)] ~= nil;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.getDefinition
        @pulsarlua function AffixSystem.getDefinition
        @desc Returns a detached pattern copy, preserving canonical class/enum
        references. Modifying it cannot change the registered definition.
        @param string sID Case-insensitive definition ID.
        @ret table|nil tPattern Pattern copy, or nil when unregistered.
    !]]
    getDefinition = function(sID)
        local tDefinition = _tDefinitions[definitionKey(sID)];
        if (not tDefinition) then
            return nil;
        end
        local tClasses, tTiers = {}, {};
        local tValueCopies = {};
        for nIndex, cClass in ipairs(tDefinition.classes) do
            tClasses[nIndex] = cClass;
        end
        for eTier, tValues in pairs(tDefinition.tiers) do
            tTiers[eTier] = copyValues(tValues, tValueCopies);
        end
        return {
            type        = tDefinition.kind,
            name        = tDefinition.name,
            classes     = tClasses,
            tiers       = tTiers,
            priority    = tDefinition.priority,
            description = tDefinition.description,
        };
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.createAffix
        @pulsarlua function AffixSystem.createAffix
        @desc Creates an independent detached entry from a registered definition
        and an explicitly selected enum tier. IDs carry no tier/gameplay meaning.
        Entries privately share validated immutable metadata; owner/journal state
        remains independent. Saves contain selected metadata/values, not a live
        registry lookup, so restoring never substitutes current definition data.
        @param string sID Registered ID, matched case-insensitively.
        @param TIER eTier Configured enum member present in this definition.
        @ret AffixSystemEntry oAffix New entry with getValues and existing getters.
        @throws Unknown ID, invalid/unavailable tier or wrong argument count.
    !]]
    createAffix = function(...)
        assert(select("#", ...) == 2, "createAffix expects exactly an ID and a tier enum member.");
        local sID, eTier = ...;
        local tDefinition = assert(_tDefinitions[definitionKey(sID)], "Unknown affix definition ID.");
        assert(_eTier.__hasa(eTier) and eTier.id <= _eMaxTier.id, "Expected a supported configured tier enum member.");
        local tValues = assert(tDefinition.tiers[eTier], "Affix definition does not provide the requested tier.");
        return newEntry({
            kind        = tDefinition.kind,
            name        = tDefinition.name,
            tier        = eTier,
            classes     = tDefinition.classes,
            id          = tDefinition.id,
            priority    = tDefinition.priority,
            description = tDefinition.description,
            values      = tValues,
            token       = false,
            journal     = setmetatable({}, _tJournalMeta),
        });
    end,
},
{--PRIVATE
    token           = null,
    records         = {},
    events          = null,
    rarity          = null,
    explicitName    = "",
    busy            = false,
    callbacks       = {
        onAdd    = dummy,
        onRemove = dummy
    },
    nameCache       = {}, -- Runtime-only composition cache; omitted from snapshots.

    --[[!
        @fqxn CoG.AffixSystem.Methods.prepareSnapshot
        @pulsarlua function AffixSystem.prepareSnapshot
        @desc Rejects in-progress saves and captures current host rarity. External
        owners are intentionally absent from tokens, preventing inverse object cycles.
        @param table tState Definition, application or serializer state.
        @vis Private
    !]]
    prepareSnapshot = function(tState)
        assert(not tState.pri.busy, "Cannot save during an affix operation.");
        tState.pri.nameCache = nil;

        local oOwner = owner(tState.pri.token);
        if (oOwner) then
            tState.pri.rarity = oOwner.getRarity();
        end
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.validateSnapshot
        @pulsarlua function AffixSystem.validateSnapshot
        @desc Validates application identities, ownership, hooks, counts and tiers
        without running gameplay callbacks or changing loaded objects.
        @param table tState Definition, application or serializer state.
        @vis Private
    !]]
    validateSnapshot = function(tState)
        local pri = tState.pri;
        assert(type(pri.token) == "AffixSystemToken" and type(pri.events) == "eventrix", "Invalid affix component.");
        assert(pri.busy == false and Rarity.LEVEL.__hasa(pri.rarity), "Invalid saved affix limits.");
        type.assert.string(pri.explicitName);
        type.assert.table(pri.callbacks);
        type.assert["function"](pri.callbacks.onAdd);
        type.assert["function"](pri.callbacks.onRemove);

        local tIDs, tHooks = {}, {};
        for nIndex = 1, denseLength(pri.records) do
            local tRecord = pri.records[nIndex];
            type.assert.table(tRecord);

            local tEntry = entry(tRecord.affix);
            assert(rawequal(tEntry.token, pri.token), "Saved affix ownership mismatch.");
            local sKey = definitionKey(tEntry.id);
            assert(not tIDs[sKey], "Duplicate saved affix definition.");
            tIDs[sKey] = true;
            assert(tEntry.tier.id <= Rarity.getMaxAffixTier(pri.rarity).id, "Saved affix exceeds rarity tier.");
            type.assert["function"](tRecord.onAdd);
            type.assert["function"](tRecord.onRemove);
            -- Saves written before argument retention have no original context.
            if (tRecord.arguments == nil) then
                tRecord.arguments = {n = 0};
            end
            type.assert.table(tRecord.arguments);
            local nArguments = tRecord.arguments.n;
            assert(rawtype(nArguments) == "number" and nArguments >= 0 and nArguments % 1 == 0,
                   "Invalid saved affix arguments.");
            for nArgument in pairs(tRecord.arguments) do
                assert(nArgument == "n" or (rawtype(nArgument) == "number" and nArgument >= 1 and
                       nArgument <= nArguments and nArgument % 1 == 0), "Invalid saved affix argument index.");
            end

            for nHook = 1, denseLength(tRecord.hooks) do
                local tHook = tRecord.hooks[nHook];
                assert(pri.events.getHookOrdinal(tHook.event, tHook.callback) > 0, "Saved affix hook is missing.");
                tHooks[tHook.event] = tHooks[tHook.event] or {};
                assert(not tHooks[tHook.event][tHook.callback], "Saved hook has multiple owners.");
                tHooks[tHook.event][tHook.callback] = true;
            end
        end

        assert(count(pri.records, _eType.PREFIX) <= Rarity.getMaxPrefixCount(pri.rarity), "Too many saved prefixes.");
        assert(count(pri.records, _eType.SUFFIX) <= Rarity.getMaxSuffixCount(pri.rarity), "Too many saved suffixes.");
    end,
},
{--PROTECTED
},
{--PUBLIC

    --[[!
        @fqxn CoG.AffixSystem.Methods.AffixSystem
        @pulsarlua function AffixSystem
        @desc Creates an independent component with local dummy callbacks. Owner
        must be a CoGObject; nil creates a detached system. Defaults use owner rarity
        or the first configured rarity. The dispatcher uses the optional environment.
        @param CoGObject|nil oOwner External host, or nil to detach.
        @param Rarity.LEVEL|nil eRarity Initial rarity; defaults to owner rarity or the first level.
        @param string|nil sEnvironment Registered environment name for the owned eventrix.
        @param boolean|nil bOwnerLocked True for an owned CoGObject component.
    !]]
    AffixSystem = function(this, cdat, super, oOwner, eRarity, sEnvironment, bOwnerLocked)
        super();

        local pri = cdat.pri;
        assert(oOwner == nil or type.isCoGObject(oOwner), "AffixSystem owner must be a CoGObject.");
        assert(bOwnerLocked == nil or rawtype(bOwnerLocked) == "boolean", "Invalid owner lock.");
        -- Ownership needs only a name; do not recover an out-of-scope class object.
        local sOwnerClass = oOwner and bOwnerLocked and class.getname(oOwner) or "";
        pri.token = setmetatable({ownerClass = sOwnerClass, locked = bOwnerLocked == true}, _tTokenMeta);
        pri.events = eventrix(sEnvironment);
        pri.rarity = eRarity or (oOwner and oOwner.getRarity()) or Rarity.LEVEL[1];
        assert(Rarity.LEVEL.__hasa(pri.rarity), "Invalid affix rarity.");

        -- The host installs its component only after this constructor returns.
        _tOwners[pri.token] = setmetatable({oOwner}, {__mode = "v"});
        _tSystems[pri.token] = setmetatable({this}, {__mode = "v"});
        if (sOwnerClass ~= "") then
            registerOwnerClass(sOwnerClass);
        end
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.getOwner
        @pulsarlua function AffixSystem.getOwner
        @desc Returns the external CoGObject owner, or nil for a detached component.
        @ret CoGObject|nil oOwner Live external owner.
    !]]
    getOwner__FNL = function(this, cdat)
        return owner(cdat.pri.token);
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.setOwner
        @pulsarlua function AffixSystem.setOwner
        @desc Reconnects a detached/restored system after validating every entry.
        An owned component accepts only its exact owning CoGObject. An unlocked
        standalone system may transfer only after all effects have been removed.
        Returns this, success, owner or nil, reason.
        @param CoGObject|nil oOwner External host, or nil to detach.
        @ret AffixSystem this This system.
        @ret boolean bSuccess True when the change is accepted.
        @ret CoGObject|nil oOwner Accepted external owner.
        @ret string|nil sReason Rejection reason; nil on success.
    !]]
    setOwner__FNL = function(this, cdat, oOwner)
        assert(oOwner == nil or type.isCoGObject(oOwner), "AffixSystem owner must be a CoGObject.");

        local pri = cdat.pri;
        if (pri.busy) then
            return this, false, nil, "Affix operation is in progress.";
        end

        local oCurrent = owner(pri.token);
        if (pri.token.locked and (oOwner == nil or not oOwner.ownsAffixSystem(this) or
            (oCurrent and not rawequal(oCurrent, oOwner)))) then

            return this, false, nil, "Owned components cannot be detached or rebound.";
        end

        if (#pri.records > 0 and oCurrent and not rawequal(oCurrent, oOwner)) then
            return this, false, nil, "Remove applied affixes before changing owners.";
        end

        if (oOwner) then
            local eRarity = oOwner.getRarity();
            if (count(pri.records, _eType.PREFIX) > Rarity.getMaxPrefixCount(eRarity) or
                count(pri.records, _eType.SUFFIX) > Rarity.getMaxSuffixCount(eRarity)) then

                return this, false, nil, "Owner rarity cannot accommodate applied affixes.";
            end

            for _, tRecord in ipairs(pri.records) do
                if (not tRecord.affix.isCompatibleWithClass(class.getname(oOwner)) or
                    tRecord.affix.getTier().id > Rarity.getMaxAffixTier(eRarity).id) then

                    return this, false, nil, "Owner cannot accommodate an applied affix.";
                end
            end
        end

        _tOwners[pri.token] = setmetatable({oOwner}, {__mode = "v"});
        _tSystems[pri.token] = setmetatable({this}, {__mode = "v"});

        -- Upgrade legacy unlocked component tokens when their actual host first
        -- reconnects them. Standalone systems retain their transferable ownership.
        if (oOwner and oOwner.ownsAffixSystem(this)) then
            pri.token.locked = true;
            pri.token.ownerClass = class.getname(oOwner);
            registerOwnerClass(pri.token.ownerClass);
        end

        return this, true, oOwner, nil;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.getOnAddCallback
        @pulsarlua function AffixSystem.getOnAddCallback
        @desc Returns the callback used for future applications.
        @ret function fCallback Add callback used for future applications.
    !]]
    getOnAddCallback__FNL = function(this, cdat)
        return cdat.pri.callbacks.onAdd;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.setOnAddCallback
        @pulsarlua function AffixSystem.setOnAddCallback
        @desc Sets onAdd(affix, journal, ...); nil resets the file-local dummy.
        Return nil or enum-keyed hook lists. Throw an error to signal failure.
        @param function|nil fCallback Replacement callback, or nil to restore dummy.
        @ret AffixSystem this This system.
    !]]
    setOnAddCallback__FNL = function(this, cdat, fCallback)
        if (fCallback ~= nil) then
            type.assert["function"](fCallback);
        end

        cdat.pri.callbacks.onAdd = fCallback or dummy;

        return this;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.getOnRemoveCallback
        @pulsarlua function AffixSystem.getOnRemoveCallback
        @desc Returns the undo callback captured by future applications.
        @ret function fCallback Removal callback captured by future applications.
    !]]
    getOnRemoveCallback__FNL = function(this, cdat)
        return cdat.pri.callbacks.onRemove;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.setOnRemoveCallback
        @pulsarlua function AffixSystem.setOnRemoveCallback
        @desc Sets onRemove(affix, journal, ...); nil resets dummy. Existing entries
        retain their original callback pair. Callback return values are ignored.
        @param function|nil fCallback Replacement callback, or nil to restore dummy.
        @ret AffixSystem this This system.
    !]]
    setOnRemoveCallback__FNL = function(this, cdat, fCallback)
        if (fCallback ~= nil) then
            type.assert["function"](fCallback);
        end

        cdat.pri.callbacks.onRemove = fCallback or dummy;

        return this;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.getRarity
        @pulsarlua function AffixSystem.getRarity
        @desc Uses live owner rarity, or saved/configured rarity while detached.
        @ret Rarity.LEVEL eRarity Live owner rarity or detached fallback.
    !]]
    getRarity__FNL = function(this, cdat)
        local oOwner = this.getOwner();

        return oOwner and oOwner.getRarity() or cdat.pri.rarity;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.canSetRarity
        @pulsarlua function AffixSystem.canSetRarity
        @desc Checks maximum tier and independent prefix/suffix limits. Minimum
        generation tiers/counts do not prohibit incremental application or removal.
        @param Rarity.LEVEL eRarity Proposed or initial rarity member.
        @ret boolean bAllowed True when the operation is eligible.
        @ret string|nil sReason Rejection reason; nil when eligible.
    !]]
    canSetRarity__FNL = function(this, cdat, eRarity)
        assert(Rarity.LEVEL.__hasa(eRarity), "Expected a configured rarity member.");

        local pri = cdat.pri;
        if (pri.busy) then
            return false, "Affix operation is in progress.";
        end

        if (this.getPrefixCount() > Rarity.getMaxPrefixCount(eRarity) or this.getSuffixCount() > Rarity.getMaxSuffixCount(eRarity)) then
            return false, "Applied affix count exceeds the proposed rarity limit.";
        end

        for _, tRecord in ipairs(pri.records) do
            if (tRecord.affix.getTier().id > Rarity.getMaxAffixTier(eRarity).id) then
                return false, "Applied affix tier exceeds the proposed rarity limit.";
            end
        end

        return true, nil;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.setRarity
        @pulsarlua function AffixSystem.setRarity
        @desc Validates limits and delegates an attached change to the owner.
        Returns this, success, rarity or nil, reason. Rejection changes no state.
        @param Rarity.LEVEL eRarity Proposed or initial rarity member.
        @ret AffixSystem this This system.
        @ret boolean bSuccess True when the change is accepted.
        @ret Rarity.LEVEL|nil eRarity Accepted rarity; nil on rejection.
        @ret string|nil sReason Rejection reason; nil on success.
    !]]
    setRarity__FNL = function(this, cdat, eRarity)
        local bAllowed, sReason = this.canSetRarity(eRarity);
        if (not bAllowed) then
            return this, false, nil, sReason;
        end

        local oOwner = this.getOwner();
        if (oOwner) then
            local _, bChanged, _, sError = oOwner.setRarity(eRarity);
            if (bChanged == false) then
                return this, false, nil, sError;
            end
        end

        cdat.pri.rarity = eRarity;

        return this, true, eRarity, nil;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.canApplyAffix
        @pulsarlua function AffixSystem.canApplyAffix
        @desc Checks ownership, duplicate ID, compatibility, tier and group capacity.
        Optional outgoing instance is used internally by replacement checks.
        @param AffixSystemEntry oAffix Affix instance.
        @param AffixSystemEntry|nil oExcluded Outgoing instance excluded from duplicate/count checks.
        @ret boolean bAllowed True when the operation is eligible.
        @ret string|nil sReason Rejection reason; nil when eligible.
    !]]
    canApplyAffix__FNL = function(this, cdat, oAffix, oExcluded)
        entry(oAffix);

        local pri = cdat.pri;
        if (pri.busy) then
            return false, "Affix operation is in progress.";
        end

        if (oAffix.isApplied()) then
            return false, "Affix already belongs to a system.";
        end

        local oOwner = this.getOwner();
        if (not oOwner) then
            return false, "AffixSystem has no owner.";
        end

        if (not oAffix.isCompatibleWithClass(class.getname(oOwner))) then
            return false, "Affix is incompatible with its owner.";
        end

        for _, tRecord in ipairs(pri.records) do
            if (not rawequal(tRecord.affix, oExcluded) and definitionKey(tRecord.affix.getDefinitionID()) == definitionKey(oAffix.getDefinitionID())) then
                return false, "Affix definition is already applied.";
            end
        end

        local eRarity = this.getRarity();
        if (oAffix.getTier().id > Rarity.getMaxAffixTier(eRarity).id) then
            return false, "Affix tier exceeds rarity limit.";
        end

        local nLimit = oAffix.isPrefix() and Rarity.getMaxPrefixCount(eRarity) or Rarity.getMaxSuffixCount(eRarity);
        if (count(pri.records, oAffix.getType(), oExcluded) >= nLimit) then
            return false, "Affix count exceeds rarity limit.";
        end

        return true, nil;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.canReplaceAffix
        @pulsarlua function AffixSystem.canReplaceAffix
        @desc Checks replacement eligibility with the outgoing definition/count excluded.
        @param AffixSystemEntry oOld Applied instance to replace.
        @param AffixSystemEntry oNew Detached replacement instance.
        @ret boolean bAllowed True when the operation is eligible.
        @ret string|nil sReason Rejection reason; nil when eligible.
    !]]
    canReplaceAffix__FNL = function(this, cdat, oOld, oNew)
        entry(oOld);
        entry(oNew);

        if (not find(cdat.pri.records, oOld)) then
            return false, "Outgoing affix is not applied.";
        end

        return this.canApplyAffix(oNew, oOld);
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.applyAffix
        @pulsarlua function AffixSystem.applyAffix
        @desc Returns this, success, affix or nil, reason. Eligibility rejection
        leaves state unchanged. A failed compensation returns the retained affix.
        @param AffixSystemEntry oAffix Affix instance.
        @param varargs ... Developer-defined arguments forwarded to lifecycle callbacks or event hooks.
        @ret AffixSystem this This system.
        @ret boolean bSuccess True when the operation succeeds.
        @ret AffixSystemEntry|nil oResult Affected or retained recovery affix.
        @ret string|nil sReason Failure/recovery explanation; nil on success.
    !]]
    applyAffix__FNL = function(this, cdat, oAffix, ...)
        local bAllowed, sReason = this.canApplyAffix(oAffix);
        if (not bAllowed) then
            return this, false, nil, sReason;
        end

        local pri = cdat.pri;
        pri.busy = true;

        local bAdded, oResult, sError = add(this, pri, oAffix, pri.callbacks.onAdd, pri.callbacks.onRemove, ...);
        pri.busy = false;

        return this, bAdded, oResult, sError;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.removeAffix
        @pulsarlua function AffixSystem.removeAffix
        @desc Returns this, success, removed affix or nil, reason. Absent entries
        never invoke callbacks. A throwing undo preserves ownership, journal and hooks.
        @param AffixSystemEntry oAffix Affix instance.
        @param varargs ... Developer-defined arguments forwarded to lifecycle callbacks or event hooks.
        @ret AffixSystem this This system.
        @ret boolean bSuccess True when the operation succeeds.
        @ret AffixSystemEntry|nil oResult Affected or retained recovery affix.
        @ret string|nil sReason Failure/recovery explanation; nil on success.
    !]]
    removeAffix__FNL = function(this, cdat, oAffix, ...)
        entry(oAffix);

        local pri = cdat.pri;
        if (pri.busy) then
            return this, false, nil, "Affix operation is in progress.";
        end

        local nIndex = find(pri.records, oAffix);
        if (not nIndex) then
            return this, false, nil, "Affix is not applied.";
        end

        pri.busy = true;

        local bRemoved, oResult, sError = remove(pri, nIndex, ...);
        pri.busy = false;

        return this, bRemoved, oResult, sError;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.replaceAffix
        @pulsarlua function AffixSystem.replaceAffix
        @desc Preflights, removes, then applies. A failed new add with successful
        compensation attempts the original callback pair using its original arguments.
        Recovery is reapplication, not exact rollback of arbitrary effects or journal
        history. A retained failed replacement leaves the original detached.
        @param AffixSystemEntry oOld Applied instance to replace.
        @param AffixSystemEntry oNew Detached replacement instance.
        @param varargs ... Developer-defined arguments forwarded to lifecycle callbacks or event hooks.
        @ret AffixSystem this This system.
        @ret boolean bSuccess True when the operation succeeds.
        @ret AffixSystemEntry|nil oResult Affected or retained recovery affix.
        @ret string|nil sReason Failure/recovery explanation; nil on success.
    !]]
    replaceAffix__FNL = function(this, cdat, oOld, oNew, ...)
        local bAllowed, sReason = this.canReplaceAffix(oOld, oNew);
        if (not bAllowed) then
            return this, false, nil, sReason;
        end

        local pri = cdat.pri;
        local nIndex, tOld = find(pri.records, oOld);
        pri.busy = true;

        local bRemoved, _, sError = remove(pri, nIndex, ...);
        if (not bRemoved) then
            pri.busy = false;

            return this, false, nil, sError;
        end

        local bAdded, oResult, sAddError = add(this, pri, oNew, pri.callbacks.onAdd, pri.callbacks.onRemove, ...);
        if (not bAdded and oResult == nil) then
            local tArguments = tOld.arguments;
            local bRecovered, oRecovery, sRecovery = add(this, pri, oOld, tOld.onAdd, tOld.onRemove,
                                                        table.unpack(tArguments, 1, tArguments.n));
            oResult = bRecovered and oOld or oRecovery;
            sAddError = sAddError..(bRecovered and "; original reapplied." or "; recovery failed: "..errorText(sRecovery));
        end

        pri.busy = false;

        return this, bAdded, oResult, sAddError;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.hasAffix
        @pulsarlua function AffixSystem.hasAffix
        @desc Tests instance identity without exposing application records.
        @param AffixSystemEntry oAffix Affix instance.
        @ret boolean bResult True when the documented condition holds.
    !]]
    hasAffix__FNL = function(this, cdat, oAffix)
        return find(cdat.pri.records, oAffix) ~= nil;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.getAffixByDefinitionID
        @pulsarlua function AffixSystem.getAffixByDefinitionID
        @desc Returns the unique applied definition instance, ignoring ID case, or nil.
        @param string sID Stable definition identity to find.
        @ret AffixSystemEntry|nil oAffix Matching applied definition, or nil.
    !]]
    getAffixByDefinitionID__FNL = function(this, cdat, sID)
        local sKey = definitionKey(sID);

        for _, tRecord in ipairs(cdat.pri.records) do
            if (definitionKey(tRecord.affix.getDefinitionID()) == sKey) then
                return tRecord.affix;
            end
        end
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.eachAffix
        @pulsarlua function AffixSystem.eachAffix
        @desc Iterates index/affix pairs from a copied application-order list.
        @ret function fIterator Iterator function.
        @ret table tValues Copied values used as iterator state.
        @ret number nIndex Initial iterator index.
    !]]
    eachAffix__FNL = function(this, cdat)
        return each(cdat.pri.records);
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.eachPrefix
        @pulsarlua function AffixSystem.eachPrefix
        @desc Iterates index/affix pairs for applied prefixes from a copy.
        @ret function fIterator Iterator function.
        @ret table tValues Copied values used as iterator state.
        @ret number nIndex Initial iterator index.
    !]]
    eachPrefix__FNL = function(this, cdat)
        return each(cdat.pri.records, _eType.PREFIX);
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.eachSuffix
        @pulsarlua function AffixSystem.eachSuffix
        @desc Iterates index/affix pairs for applied suffixes from a copy.
        @ret function fIterator Iterator function.
        @ret table tValues Copied values used as iterator state.
        @ret number nIndex Initial iterator index.
    !]]
    eachSuffix__FNL = function(this, cdat)
        return each(cdat.pri.records, _eType.SUFFIX);
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.getAffixCount
        @pulsarlua function AffixSystem.getAffixCount
        @desc Returns the total number of applied affixes.
        @ret number nCount Applied affix count.
    !]]
    getAffixCount__FNL = function(this, cdat)
        return #cdat.pri.records;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.getPrefixCount
        @pulsarlua function AffixSystem.getPrefixCount
        @desc Returns the applied prefix count.
        @ret number nCount Applied prefix count.
    !]]
    getPrefixCount__FNL = function(this, cdat)
        return count(cdat.pri.records, _eType.PREFIX);
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.getSuffixCount
        @pulsarlua function AffixSystem.getSuffixCount
        @desc Returns the applied suffix count.
        @ret number nCount Applied suffix count.
    !]]
    getSuffixCount__FNL = function(this, cdat)
        return count(cdat.pri.records, _eType.SUFFIX);
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.getMaxPrefixes
        @pulsarlua function AffixSystem.getMaxPrefixes
        @desc Returns the current rarity's maximum prefix count.
        @ret number nMaximum Current rarity prefix limit.
    !]]
    getMaxPrefixes__FNL = function(this)
        return Rarity.getMaxPrefixCount(this.getRarity());
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.getMaxSuffixes
        @pulsarlua function AffixSystem.getMaxSuffixes
        @desc Returns the current rarity's maximum suffix count.
        @ret number nMaximum Current rarity suffix limit.
    !]]
    getMaxSuffixes__FNL = function(this)
        return Rarity.getMaxSuffixCount(this.getRarity());
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.getName
        @pulsarlua function AffixSystem.getName
        @desc Composes selected prefix/base/suffix without changing host metadata.
        All affixes retain effects regardless of which text wins naming selection.
        An optional base name supports detached systems; otherwise uses owner name.
        @param string|nil sBaseName Base name; omission uses the live owner name.
        @ret string sName Display name.
    !]]
    getName__FNL = function(this, cdat, sBaseName)
        local pri = cdat.pri;
        if (this.getRarity().name == "SINGULAR" and pri.explicitName ~= "") then
            return pri.explicitName;
        end

        if (sBaseName == nil) then
            local oOwner = this.getOwner();
            assert(oOwner, "Detached naming requires a base name.");
            sBaseName = oOwner.getName();
        end

        type.assert.string(sBaseName, "%S+");
        local tCache = pri.nameCache;
        if (tCache.base == sBaseName) then
            return tCache.name;
        end

        local tParts = {};
        local sPrefix, sSuffix = selected(pri.records, _eType.PREFIX), selected(pri.records, _eType.SUFFIX);
        if (sPrefix) then
            tParts[#tParts + 1] = sPrefix;
        end

        tParts[#tParts + 1] = sBaseName;

        if (sSuffix) then
            tParts[#tParts + 1] = sSuffix;
        end

        local sName = table.concat(tParts, " ");
        pri.nameCache = {base = sBaseName, name = sName};
        return sName;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.getExplicitName
        @pulsarlua function AffixSystem.getExplicitName
        @desc Returns the stored SINGULAR override, or nil when unset.
        @ret string|nil sName Stored SINGULAR override, or nil.
    !]]
    getExplicitName__FNL = function(this, cdat)
        return cdat.pri.explicitName ~= "" and cdat.pri.explicitName or nil;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.setExplicitName
        @pulsarlua function AffixSystem.setExplicitName
        @desc Stores a nonblank SINGULAR display override; nil clears it.
        @param string|nil sName Nonblank display text; nil clears an optional override.
        @ret AffixSystem this This system.
    !]]
    setExplicitName__FNL = function(this, cdat, sName)
        if (sName ~= nil) then
            type.assert.string(sName, "%S+");
        end

        cdat.pri.explicitName = sName or "";
        cdat.pri.nameCache = {};

        return this;
    end,

    --[[!
        @fqxn CoG.AffixSystem.Methods.fireEvent
        @pulsarlua function AffixSystem.fireEvent
        @desc Fires the component's affix hooks. Hosts choose which gameplay events
        to forward; no event forwarding behavior is imposed on CoGObject.
        @param enumitem eEvent Event identifier.
        @param varargs ... Developer-defined arguments forwarded to lifecycle callbacks or event hooks.
        @ret table tResults Ordered eventrix hook results and errors.
    !]]
    fireEvent__FNL = function(this, cdat, eEvent, ...)
        return cdat.pri.events.fire(eEvent, ...);
    end,
},
CoG, false, nil);

_mSerializer.registerFactory(_cSystem, {name = "AffixSystem", types = {"AffixSystem"}});

return _cSystem;
