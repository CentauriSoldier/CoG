--LOCALIZATION
local class = class;
local Persistence = require("cog.Objects.ItemSystem.ItemPersistence");
local Rules = require("cog.Objects.ItemSystem.ItemRules");

-- Build public component accessors without renaming protected storage used by subclasses and snapshots.
local function component(sField)

    return function(this, cdat)
        return cdat.pro[sField];
    end;
end

-- Build each permission method around its named registry, passing this item as additional context.
local function permission(sField)

    return function(this, cdat, oObject, ...)
        return cdat.pro[sField].allows(oObject, this, ...);
    end;
end

-- Create an independent default when omitted; retain a validated supplied component by identity.
local function acceptObject(vInput, cExpected, defaultFactory, sField)

    if (vInput == nil) then
        return defaultFactory();
    end

    assert(class.isinstance(vInput) and class.ischildorself(class.getname(vInput), cExpected),
           "CoGItem "..sField.." must be an instance of "..class.getname(cExpected)..".");

    return vInput;
end

-- Start action permissions empty so callers explicitly choose eligible actors or hosts.
local function defaultCoGRegistry()

    return CoGRegistry();
end

-- Create an independent empty storage/conflict registry.
local function defaultRegistry()

    return ClassRegistry();
end

-- Create an independent durability pool initially filled to its capacity of one.
local function defaultDurability()

    return Pool(1, 1);
end

-- Create a separate pool initially holding zero for each size, weight or value component.
local function defaultQuantity()

    return Pool(1, 0);
end

-- Create an independent empty footprint.
local function defaultSlotPattern()

    return SlotPattern();
end

--[[!
    @fqxn CoG.ItemSystem.CoGItem
    @desc Base class for individual items. CoGRegistry action permissions and ClassRegistry storage/conflict fields express eligibility;
    callers perform actions and enforce their gameplay consequences. Durability
    reaching zero does not imply destruction. Inimitable is metadata only.
    Every omitted registry/Pool/SlotPattern input creates a fresh object in the constructor;
    validated supplied objects are retained by reference. Stacking belongs to
    ItemSlot. Trading also covers selling; callers determine cost from Value.
!]]
local cCoGItem = class("CoGItem",
{--METAMETHODS

    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.__clone
        @desc Requires callers to choose how concrete items are cloned before populating another container.
    !]]
    __clone = function(this, cdat)

        --TODO Define copying of subclass state, attachments and CoGObject affixes.
        -- Inimitable is deliberately not enforced here.
        error("CoGItem subclasses must implement __clone for their item state.");
    end,

},
{--STATIC PUBLIC

    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.eachAttachmentOf
        @desc Validates a CoG host and iterates a copied list of its attached item references.
    !]]
    eachAttachmentOf = function(oHost)
        assert(class.isinstance(oHost) and class.ischildorself(class.getname(oHost), CoG), "Attachment host must be a CoG instance.");

        return ipairs(Rules.attachments(oHost));
    end,

},
{--PRIVATE
    location = {}, -- Optional reference can change between unrelated container classes.
    attachment = {},
    attachedItems = {}, -- Forward attachment membership retained in generated snapshots.
    identity = {}, -- Runtime self reference used to discover the concrete subclass when saving.
    persistenceID = 0,

    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.validateSnapshot
        @desc Validates saved identity and attachment/location holders before generated class restoration.
    !]]
    validateSnapshot = function(tState)
        Rules.integer(tState.pri.persistenceID, 1);
        type.assert.table(tState.pri.attachedItems);
        type.assert.table(tState.pri.location);
        type.assert.table(tState.pri.attachment);
        assert(type.isnull(tState.pri.location.value) or class.isinstance(tState.pri.location.value), "Invalid saved item location.");
        assert(type.isnull(tState.pri.attachment.host) or type.isCoG(tState.pri.attachment.host), "Invalid saved attachment host.");
    end,

    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.prepareSnapshot
        @desc Registers the concrete item adapter, wraps permission registries and omits inverse links from the
        copied snapshot.
    !]]
    prepareSnapshot = function(tState)
        local pri = tState.pri;

        -- A concrete subclass may be local; register its existing generated deserializer.
        Rules.registerPersistence(class.getbyname(class.getname(pri.identity.object), _ENV), true);

        -- Wrap registries so saved prerequisites survive the class snapshot's method-field exclusions.
        for sField, vValue in pairs(tState.pro) do
            if (type.isClassRegistry(vValue) or type.isCoGRegistry(vValue)) then
                tState.pro[sField] = Persistence.registry(vValue);
            end
        end

        -- Save forward membership only: containers own items and hosts own attached children.
        -- Reconnection reconstructs these omitted inverse links instead of serializing object cycles.
        pri.identity = nil;
        pri.location.value = null;
        pri.attachment.host = null;
    end,
},
{--PROTECTED
    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.getAttachableToRegistry
        @pulsarlua function CoGItem.getAttachableToRegistry
        @desc Returns the AttachableToRegistry component/value. Non-final getter; no replacement setter. Mutable components retain identity.
        @ret CoGRegistry vValue Stored value/reference.
    !]]
    Attachable_To   = null,
    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.getConsumableByRegistry
        @pulsarlua function CoGItem.getConsumableByRegistry
        @desc Returns the ConsumableByRegistry component/value. Non-final getter; no replacement setter. Mutable components retain identity.
        @ret CoGRegistry vValue Stored value/reference.
    !]]
    Consumable_By   = null,
    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.getDamageableByRegistry
        @pulsarlua function CoGItem.getDamageableByRegistry
        @desc Returns the DamageableByRegistry component/value. Non-final getter; no replacement setter. Mutable components retain identity.
        @ret CoGRegistry vValue Stored value/reference.
    !]]
    Damageable_By   = null,
    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.getDetachableByRegistry
        @pulsarlua function CoGItem.getDetachableByRegistry
        @desc Returns the DetachableByRegistry component/value. Non-final getter; no replacement setter. Mutable components retain identity.
        @ret CoGRegistry vValue Stored value/reference.
    !]]
    Detachable_By   = null,
    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.getEquippableByRegistry
        @pulsarlua function CoGItem.getEquippableByRegistry
        @desc Returns the EquippableByRegistry component/value. Non-final getter; no replacement setter. Mutable components retain identity.
        @ret CoGRegistry vValue Stored value/reference.
    !]]
    Equipable_By    = null,
    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.getExclusiveInRegistry
        @pulsarlua function CoGItem.getExclusiveInRegistry
        @desc Returns the ExclusiveInRegistry component/value. Non-final getter; no replacement setter. Mutable components retain identity.
        @ret ClassRegistry vValue Stored value/reference.
    !]]
    Exclusive_In    = null,
    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.getExclusiveWithRegistry
        @pulsarlua function CoGItem.getExclusiveWithRegistry
        @desc Returns the ExclusiveWithRegistry component/value. Non-final getter; no replacement setter. Mutable components retain identity.
        @ret ClassRegistry vValue Stored value/reference.
    !]]
    Exclusive_With  = null,
    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.isInimitable
        @pulsarlua function CoGItem.isInimitable
        @desc Returns the Inimitable component/value. Non-final getter; no replacement setter. Mutable components retain identity.
        @ret boolean vValue Stored value/reference.
    !]]
    Inimitable__autoA_is           = false,
    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.getRemovableByRegistry
        @pulsarlua function CoGItem.getRemovableByRegistry
        @desc Returns the RemovableByRegistry component/value. Non-final getter; no replacement setter. Mutable components retain identity.
        @ret CoGRegistry vValue Stored value/reference.
    !]]
    Removable_By    = null,
    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.getRepairableByRegistry
        @pulsarlua function CoGItem.getRepairableByRegistry
        @desc Returns the RepairableByRegistry component/value. Non-final getter; no replacement setter. Mutable components retain identity.
        @ret CoGRegistry vValue Stored value/reference.
    !]]
    Repairable_By   = null,
    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.getStorableInRegistry
        @pulsarlua function CoGItem.getStorableInRegistry
        @desc Returns the StorableInRegistry component/value. Non-final getter; no replacement setter. Mutable components retain identity.
        @ret ClassRegistry vValue Stored value/reference.
    !]]
    Storable_In     = null,
    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.getTradableByRegistry
        @pulsarlua function CoGItem.getTradableByRegistry
        @desc Returns the TradableByRegistry component/value. Non-final getter; no replacement setter. Mutable components retain identity.
        @ret CoGRegistry vValue Stored value/reference.
    !]]
    Tradable_By     = null,
    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.getTradableToRegistry
        @pulsarlua function CoGItem.getTradableToRegistry
        @desc Returns the TradableToRegistry component/value. Non-final getter; no replacement setter. Mutable components retain identity.
        @ret CoGRegistry vValue Stored value/reference.
    !]]
    Tradable_To     = null,
    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.getUnequippableByRegistry
        @pulsarlua function CoGItem.getUnequippableByRegistry
        @desc Returns the UnequippableByRegistry component/value. Non-final getter; no replacement setter. Mutable components retain identity.
        @ret CoGRegistry vValue Stored value/reference.
    !]]
    Unequippable_By = null,
    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.getUpgradeableByRegistry
        @pulsarlua function CoGItem.getUpgradeableByRegistry
        @desc Returns the UpgradeableByRegistry component/value. Non-final getter; no replacement setter. Mutable components retain identity.
        @ret CoGRegistry vValue Stored value/reference.
    !]]
    Upgradeable_By  = null,
    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.getDowngradableByRegistry
        @pulsarlua function CoGItem.getDowngradableByRegistry
        @desc Returns the DowngradableByRegistry component/value. Non-final getter; no replacement setter. Mutable components retain identity.
        @ret CoGRegistry vValue Stored value/reference.
    !]]
    Downgradable_By = null,

    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.getDurabilityPool
        @pulsarlua function CoGItem.getDurabilityPool
        @desc Returns the Durability component/value. Non-final getter; no replacement setter. Mutable components retain identity.
        @ret Pool vValue Stored value/reference.
    !]]
    Durability      = null,
    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.getSizePool
        @pulsarlua function CoGItem.getSizePool
        @desc Returns the Size component/value. Non-final getter; no replacement setter. Mutable components retain identity.
        @ret Pool vValue Stored value/reference.
    !]]
    Size            = null,
    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.getValuePool
        @pulsarlua function CoGItem.getValuePool
        @desc Returns the Value component/value. Non-final getter; no replacement setter. Mutable components retain identity.
        @ret Pool vValue Stored value/reference.
    !]]
    Value           = null,
    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.getWeightPool
        @pulsarlua function CoGItem.getWeightPool
        @desc Returns the Weight component/value. Non-final getter; no replacement setter. Mutable components retain identity.
        @ret Pool vValue Stored value/reference.
    !]]
    Weight          = null,

    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.getSlotPattern
        @pulsarlua function CoGItem.getSlotPattern
        @desc Returns the Slot_Pattern component/value. Non-final getter; no replacement setter. Mutable components retain identity.
        @ret SlotPattern vValue Stored value/reference.
    !]]
    Slot_Pattern    = null,

    --TODO Revisit blueprint identity and its relationship to item definitions.
    -- Container/attachment operations coordinate optional references. ClassRegistry
    -- and Pool replacement setters are deliberately not generated.

    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.CoGItem
        @desc Protected constructor invoked by concrete item subclasses.
        Registry/Pool arguments are optional objects, never booleans or numbers.
        vExclusiveIn accepts a ClassRegistry or a particular supported system instance;
        omission includes slot systems, inventories and stashes. Other registries start empty.
        Location and Attached_To accept class instances or null/nil; omitted values
        remain null. Attached_To identifies one CoG host. Inimitable defaults false.
    !]]
    CoGItem = function(this, cdat, super, sName, sDescription, eRarity, wEventrix,
                        oAttachableTo, oConsumableBy, oDamageableBy, oDetachableBy,
                        oEquippableBy, vExclusiveIn, oExclusiveWith, bInimitable,
                        oRemovableBy, oRepairableBy, oStorableIn,
                        oTradableBy, oTradableTo, oUnequippableBy,
                        oUpgradeableBy, oDowngradableBy,
                        oDurability, oSize, oValue, oWeight,
                        oAttachedTo, oLocation, oSlotPattern)
        local pro = cdat.pro;
        local tFields = {};

        -- Validate component inputs before publishing any of them as this item's fields.
        local tObjectRegistries = {
            {"Attachable_To", oAttachableTo}, {"Consumable_By", oConsumableBy},
            {"Damageable_By", oDamageableBy}, {"Detachable_By", oDetachableBy},
            {"Equipable_By", oEquippableBy}, {"Removable_By", oRemovableBy},
            {"Repairable_By", oRepairableBy}, {"Tradable_By", oTradableBy},
            {"Tradable_To", oTradableTo}, {"Unequippable_By", oUnequippableBy},
            {"Upgradeable_By", oUpgradeableBy}, {"Downgradable_By", oDowngradableBy},
        };

        for _, tField in ipairs(tObjectRegistries) do
            tFields[tField[1]] = acceptObject(tField[2], CoGRegistry, defaultCoGRegistry, tField[1]);
        end

        tFields.Exclusive_With = acceptObject(oExclusiveWith, ClassRegistry, defaultRegistry, "Exclusive_With");
        tFields.Storable_In = acceptObject(oStorableIn, ClassRegistry, defaultRegistry, "Storable_In");

        -- Default scopes match container classes. A supplied system instance narrows scope by identity.
        if (vExclusiveIn == nil) then
            tFields.Exclusive_In = ClassRegistry({ItemSlotSystem, ItemSystem, ItemStashSystem});
        elseif (class.isinstance(vExclusiveIn) and
                (class.ischildorself(class.getname(vExclusiveIn), ItemSlotSystem) or
                 class.ischildorself(class.getname(vExclusiveIn), ItemSystem) or
                 class.ischildorself(class.getname(vExclusiveIn), ItemStashSystem))) then
            tFields.Exclusive_In = ClassRegistry({vExclusiveIn});
        else
            tFields.Exclusive_In = acceptObject(vExclusiveIn, ClassRegistry, defaultRegistry, "Exclusive_In");
        end

        tFields.Durability = acceptObject(oDurability, Pool, defaultDurability, "Durability");
        tFields.Size = acceptObject(oSize, Pool, defaultQuantity, "Size");
        tFields.Value = acceptObject(oValue, Pool, defaultQuantity, "Value");
        tFields.Weight = acceptObject(oWeight, Pool, defaultQuantity, "Weight");
        assert(bInimitable == nil or rawtype(bInimitable) == "boolean", "Inimitable must be a boolean or nil.");

        if (oAttachedTo ~= nil and oAttachedTo ~= null) then
            assert(class.isinstance(oAttachedTo) and class.ischildorself(class.getname(oAttachedTo), CoG),
                   "Attached_To must be a CoG instance or null.");
        end

        if (oLocation ~= nil and oLocation ~= null) then
            assert(class.isinstance(oLocation), "Location must be a class instance or null.");
        end

        tFields.Slot_Pattern = acceptObject(oSlotPattern, SlotPattern, defaultSlotPattern, "Slot_Pattern");

        -- Construct inherited object state after the item-specific inputs have been checked.
        super(sName, sDescription, eRarity, wEventrix);

        for sField, oObject in pairs(tFields) do
            pro[sField] = oObject;
        end

        -- Hold inverse references inside tables so changing targets preserves each declared field type.
        pro.Inimitable = bInimitable == true;
        cdat.pri.attachment.host = oAttachedTo or null;
        cdat.pri.location.value = oLocation or null;
        cdat.pri.persistenceID = Persistence.identify(this);
        cdat.pri.identity.object = this;
        Rules.registerHost(this, cdat.pri.attachedItems);
        Rules.registerAttachment(this, cdat.pri.attachment);
    end,

},
{--PUBLIC

    getAttachableToRegistry = component("Attachable_To"),

    getConsumableByRegistry = component("Consumable_By"),

    getDamageableByRegistry = component("Damageable_By"),

    getDetachableByRegistry = component("Detachable_By"),

    getEquippableByRegistry = component("Equipable_By"),

    getExclusiveInRegistry = component("Exclusive_In"),

    getExclusiveWithRegistry = component("Exclusive_With"),

    getRemovableByRegistry = component("Removable_By"),

    getRepairableByRegistry = component("Repairable_By"),

    getStorableInRegistry = component("Storable_In"),

    getTradableByRegistry = component("Tradable_By"),

    getTradableToRegistry = component("Tradable_To"),

    getUnequippableByRegistry = component("Unequippable_By"),

    getUpgradeableByRegistry = component("Upgradeable_By"),

    getDowngradableByRegistry = component("Downgradable_By"),

    getDurabilityPool = component("Durability"),

    getSizePool = component("Size"),

    getValuePool = component("Value"),

    getWeightPool = component("Weight"),

    getSlotPattern = component("Slot_Pattern"),


    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.restoreItemRuntime
        @desc Internal save/load reconnection of location and attachment indexes.
        Membership restores exact decoded identities without permission callbacks.
    !]]
    restoreItemRuntime__FNL = function(this, cdat, tToken)

        -- Load tokens isolate identity reconnection between independent deserialization operations.
        if (tToken) then
            Persistence.reconnect(cdat.pri.persistenceID, this, tToken);
        end

        cdat.pri.persistenceID = Persistence.identify(this);
        cdat.pri.identity.object = this;
        Rules.registerHost(this, cdat.pri.attachedItems, tToken);
        Rules.registerAttachment(this, cdat.pri.attachment);

        -- Repeated reconnection must not insert this item into the same location twice.
        local oLocation = cdat.pri.location.value;

        if (oLocation ~= null) then
            oLocation.restoreRuntime();
            local tState = Rules.state(oLocation);

            if (not Rules.indexOf(oLocation, this)) then
                tState.items[#tState.items + 1] = this;
            end
        end
    end,

    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.canAttachTo
        @desc Checks the AttachableToRegistry registry with (oObject, this, ...); returns its boolean and optional
        reason.
    !]]
    canAttachTo = permission("Attachable_To"),

    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.canConsumeBy
        @desc Checks the ConsumableByRegistry registry with (oObject, this, ...); returns its boolean and optional
        reason.
    !]]
    canConsumeBy = permission("Consumable_By"),

    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.canDamageBy
        @desc Checks the DamageableByRegistry registry with (oObject, this, ...); returns its boolean and optional
        reason.
    !]]
    canDamageBy = permission("Damageable_By"),

    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.canDetachBy
        @desc Checks the DetachableByRegistry registry with (oObject, this, ...); returns its boolean and optional
        reason.
    !]]
    canDetachBy = permission("Detachable_By"),

    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.canEquipBy
        @desc Checks the EquippableByRegistry registry with (oObject, this, ...); returns its boolean and optional
        reason.
    !]]
    canEquipBy = permission("Equipable_By"),

    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.canRemoveBy
        @desc Checks the RemovableByRegistry registry with (oObject, this, ...); returns its boolean and optional
        reason.
    !]]
    canRemoveBy = permission("Removable_By"),

    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.canRepairBy
        @desc Checks the RepairableByRegistry registry with (oObject, this, ...); returns its boolean and optional
        reason.
    !]]
    canRepairBy = permission("Repairable_By"),

    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.canStoreIn
        @desc Checks the StorableInRegistry registry with (oObject, this, ...); returns its boolean and optional
        reason.
    !]]
    canStoreIn = permission("Storable_In"),

    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.canTradeBy
        @desc Checks the TradableByRegistry registry with (oObject, this, ...); returns its boolean and optional
        reason.
    !]]
    canTradeBy = permission("Tradable_By"),

    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.canTradeTo
        @desc Checks the TradableToRegistry registry with (oObject, this, ...); returns its boolean and optional
        reason.
    !]]
    canTradeTo = permission("Tradable_To"),

    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.canUnequipBy
        @desc Checks the UnequippableByRegistry registry with (oObject, this, ...); returns its boolean and optional
        reason.
    !]]
    canUnequipBy = permission("Unequippable_By"),

    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.canUpgradeBy
        @desc Checks the UpgradeableByRegistry registry with (oObject, this, ...); returns its boolean and optional
        reason.
    !]]
    canUpgradeBy = permission("Upgradeable_By"),

    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.canDowngradeBy
        @desc Checks the DowngradableByRegistry registry with (oObject, this, ...); returns its boolean and optional
        reason.
    !]]
    canDowngradeBy = permission("Downgradable_By"),

    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.getAttached_To
        @desc Returns this item's attachment host, or null when detached.
    !]]
    getAttached_To__FNL = function(this, cdat)
        return cdat.pri.attachment.host;
    end,

    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.eachAttachment
        @desc Iterates a copied list of items attached to this item.
    !]]
    eachAttachment = function(this)
        return ipairs(Rules.attachments(this));
    end,

    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.attachTo
        @desc Checks attachment permission and cycle rules before connecting this item to the host.
    !]]
    attachTo = function(this, cdat, oHost)
        local bOK, sReason = Rules.attach(this, oHost);

        return this, bOK, sReason;
    end,

    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.detach
        @desc Checks the actor's detach permission before removing this item from its current host.
    !]]
    detach = function(this, cdat, oActor)
        local bOK, sReason = Rules.detach(this, oActor);

        return this, bOK, sReason;
    end,

    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.getLocation
        @desc Returns the current leaf container, or null while the item is not stored.
    !]]
    getLocation__FNL = function(this, cdat)
        return cdat.pri.location.value;
    end,

    -- Coordinated container operations pass the expected previous location.

    --[[!
        @fqxn CoG.ItemSystem.CoGItem.Methods.setLocation
        @desc Changes the location only when the expected previous identity matches; transactions control writes
        during callbacks.
    !]]
    setLocation__FNL = function(this, cdat, oLocation, oExpectedLocation)
        assert(Rules.canWriteLocation(), "Location mutations are forbidden inside prerequisite callbacks.");
        assert(oLocation == null or class.isinstance(oLocation), "Location must be a class instance or null.");

        -- Refuse to overwrite a location whose exact identity changed since the operation began.
        assert(rawequal(cdat.pri.location.value, oExpectedLocation), "Item location changed; transfer rejected.");
        cdat.pri.location.value = oLocation;

        return this;
    end,

},
CoGObject, --extending class
false,      --if the class is final
nil         --interface(s)
);

return cCoGItem;

--[[!
    @fqxn CoG.ItemSystem.CoGItem.InheritedCoGObject
    @inheritdoc CoG.CoGObject
!]]
