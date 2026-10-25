--LOCALIZATION
local class   = class;
local Protean = Protean;

-- The shared no-op initializes callbacks and restores their default behavior.
local function dummy() end

--[[!
    @fqxn CoG.CoGAbility
    @pulsarlua class CoGAbility
    @desc Generic CoGObject ability with one owned cost Protean and a configurable use callback.
    The developer defines targeting, requirements, payment and gameplay effects in the callback or subclasses.
!]]
return class("CoGAbility",
{--METAMETHODS
},
{--STATIC PUBLIC
},
{--PRIVATE
    onUse = dummy,
},
{--PROTECTED
    Cost = null,
},
{--PUBLIC
    --[[!
        @fqxn CoG.CoGAbility.Methods.CoGAbility
        @pulsarlua function CoGAbility
        @desc Initializes inherited metadata, a fresh cost Protean and the optional use callback.
        @param string sName Ability name.
        @param string sDescription Ability description.
        @param Rarity.LEVEL|nil eRarity Inherited rarity.
        @param string|nil wEventrix Registered event environment name.
        @param function|nil fOnUseCallback Use callback; omission selects dummy.
    !]]
    CoGAbility = function(this, cdat, super, sName, sDescription, eRarity, wEventrix, fOnUseCallback)
        type.assert.custom(fOnUseCallback == nil and dummy or fOnUseCallback, "function");
        super(sName, sDescription, eRarity, wEventrix);

        -- Allocate per-instance cost state; callers mutate it through getCost.
        cdat.pro.Cost = Protean();
        this.setOnUseCallback(fOnUseCallback);
    end,

    --[[!
        @fqxn CoG.CoGAbility.Methods.getCost
        @pulsarlua function CoGAbility.getCost
        @desc Final getter returning the owned Protean, or a selected value. No replacement setter.
        @param number|nil nType Protean value category; omission returns the component.
        @ret Protean|number vValue Owned cost component or selected value.
    !]]
    getCost__FNL = function(this, cdat, nType)
        local oCost = cdat.pro.Cost;

        -- Let Protean validate categories and resolve the requested value.
        return nType == nil and oCost or oCost.getValue(nType);
    end,

    --[[!
        @fqxn CoG.CoGAbility.Methods.getOnUseCallback
        @pulsarlua function CoGAbility.getOnUseCallback
        @desc Returns the current callback, including dummy after initialization or reset.
        @ret function fOnUseCallback Current use callback.
    !]]
    getOnUseCallback = function(this, cdat)
        return cdat.pri.onUse;
    end,

    --[[!
        @fqxn CoG.CoGAbility.Methods.setOnUseCallback
        @pulsarlua function CoGAbility.setOnUseCallback
        @desc Sets the use callback. Nil restores the file-scoped dummy; invalid input leaves it unchanged.
        @param function|nil fOnUseCallback Replacement callback or nil to reset.
        @ret CoGAbility this This ability.
    !]]
    setOnUseCallback = function(this, cdat, fOnUseCallback)
        -- Validate before replacing the existing callback.
        local fCallback = fOnUseCallback == nil and dummy or fOnUseCallback;
        type.assert.custom(fCallback, "function");
        cdat.pri.onUse = fCallback;

        return this;
    end,

    --[[!
        @fqxn CoG.CoGAbility.Methods.use
        @pulsarlua function CoGAbility.use
        @desc Calls the current callback with this ability followed by caller arguments.
        Returns all callback results unchanged; errors propagate. The callback owns gameplay policy.
        @param varargs ... Developer-defined context.
        @ret varargs ... Callback results.
    !]]
    use = function(this, cdat, ...)
        -- Direct forwarding preserves nil arguments and multiple return values.
        return cdat.pri.onUse(this, ...);
    end,
},
CoGObject,
false,
nil
);

--[[!
    @fqxn CoG.CoGAbility.InheritedCoGObject
    @inheritdoc CoG.CoGObject
!]]
