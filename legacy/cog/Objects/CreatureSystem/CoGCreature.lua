--LOCALIZATION
local class = class;

--[[!
    @fqxn CoG.CreatureSystem.CoGCreature
    @desc Generic CoGObject subclass owning independent XP, HP, inventory, equipment,
    status and targeting components. Components are created in the constructor and
    exposed through final getters without replacement setters. Their own APIs remain
    mutable. XPSystem owns level calculation; subclasses define gameplay behavior.
    No species, faction, age, mana, stamina, damage, death or resource-cycling policy
    is imposed. Required XP/HP values and a configured status category come from the caller.
!]]
return class("CoGCreature",
{--METAMETHODS
    --[[!
        @fqxn CoG.CreatureSystem.CoGCreature.Methods.__clone
        @desc Requires concrete subclasses to define copying of creature state,
        component ownership, inherited metadata and runtime callbacks.
        @throws Always unless a subclass supplies its own __clone.
    !]]
    __clone = function()
        error("CoGCreature subclasses must define __clone for their creature state.");
    end,

},
{--STATIC PUBLIC
},
{--PRIVATE
},
{--PROTECTED
    XP                    = null,
    HP                    = null,
    Inventory             = null,
    Equipment             = null,
    --[[!
        @fqxn CoG.CreatureSystem.CoGCreature.Methods.getStatusTracker
        @pulsarlua function CoGCreature.getStatusTracker
        @desc Final getter for the creature's configured-scope status tracker. No replacement setter.
        @ret StatusTracker oStatuses Independent initially inactive status storage.
    !]]
    StatusTracker__autoAF = null,
    --[[!
        @fqxn CoG.CreatureSystem.CoGCreature.Methods.getTargetor
        @pulsarlua function CoGCreature.getTargetor
        @desc Final getter for the creature's initially empty targeting component. No replacement setter.
        @ret Targetor oTargetor Independent mutable targeting categories.
    !]]
    Targetor__autoAF      = null,
},
{--PUBLIC
    --[[!
        @fqxn CoG.CreatureSystem.CoGCreature.Methods.getXPSystem
        @desc Final getter for this creature's owned XPSystem; no replacement setter.
        @ret XPSystem oComponent Mutable owned component.
    !]]
    getXPSystem__FNL = function(this, cdat)
        return cdat.pro.XP;
    end,

    --[[!
        @fqxn CoG.CreatureSystem.CoGCreature.Methods.getItemSystem
        @desc Final getter for this creature's owned ItemSystem; no replacement setter.
        @ret ItemSystem oComponent Mutable owned component.
    !]]
    getItemSystem__FNL = function(this, cdat)
        return cdat.pro.Inventory;
    end,

    --[[!
        @fqxn CoG.CreatureSystem.CoGCreature.Methods.getItemSlotSystem
        @desc Final getter for this creature's owned ItemSlotSystem; no replacement setter.
        @ret ItemSlotSystem oComponent Mutable owned component.
    !]]
    getItemSlotSystem__FNL = function(this, cdat)
        return cdat.pro.Equipment;
    end,

    --[[!
        @fqxn CoG.CreatureSystem.CoGCreature.Methods.getHP
        @desc Returns the owned HP Pool by default, or a selected Pool value. No replacement setter.
        @param Pool.ASPECT|nil eAspect Requested aspect; omission returns the Pool.
        @param Pool.MODIFIER|nil eModifier Optional modifier passed to Pool.get.
        @ret Pool|number vValue Owned Pool or selected value.
    !]]
    getHP__FNL = function(this, cdat, eAspect, eModifier)
        local oHP = cdat.pro.HP;

        -- Delegate value defaults and validation to the Pool component.
        if (eAspect ~= nil or eModifier ~= nil) then
            return oHP.get(eAspect, eModifier);
        end

        return oHP;
    end,

    --[[!
        @fqxn CoG.CreatureSystem.CoGCreature.Methods.CoGCreature
        @pulsarlua function CoGCreature
        @desc Initializes inherited metadata and constructs fresh components using existing system APIs.
        The options table supplies configuration, never replacement component instances.
        <ul>
        <li>XP: table containing Type, LevelOneXP, MaxLevel and Progression, all required by XPSystem. Optional StepSize uses XPSystem's default of 2.</li>
        <li>HP: table containing explicit numeric Max and Current, validated/clamped by Pool.</li>
        <li>StatusScope: actual configured StatusTracker category enum. No default category is invented; subclasses supply their own scope.</li>
        </ul>
        Inventory and equipment use their existing empty defaults and associate this creature as owner.
        @param string sName Nonblank name passed to CoGObject.
        @param string sDescription Nonblank description passed to CoGObject.
        @param Rarity.LEVEL|nil eRarity Rarity passed to CoGObject.
        @param string|nil wEventrix Registered event environment name passed to CoGObject.
        @param table tOptions Required XP, HP and StatusScope configuration described above.
        @throws Missing/invalid options, a nonconfigured status scope, or an inherited/component constructor error.
    !]]
    CoGCreature = function(this, cdat, super, sName, sDescription, eRarity, wEventrix, tOptions)
        type.assert.table(tOptions);
        type.assert.table(tOptions.XP);
        type.assert.table(tOptions.HP);
        type.assert.number(tOptions.HP.Max);
        type.assert.number(tOptions.HP.Current);

        super(sName, sDescription, eRarity, wEventrix);

        local pro = cdat.pro;
        local tXP = tOptions.XP;
        local tHP = tOptions.HP;

        pro.XP            = XPSystem(tXP.Type, tXP.LevelOneXP, tXP.MaxLevel, tXP.Progression, tXP.StepSize);
        pro.HP            = Pool(tHP.Max, tHP.Current);
        pro.Inventory     = ItemSystem(nil, nil, this);
        pro.Equipment     = ItemSlotSystem(nil, this);
        pro.StatusTracker = StatusTracker(tOptions.StatusScope);
        pro.Targetor      = Targetor();
    end,

},
CoGObject,
false,
nil
);

--[[!
    @fqxn CoG.CreatureSystem.CoGCreature.InheritedCoGObject
    @inheritdoc CoG.CoGObject
!]]
