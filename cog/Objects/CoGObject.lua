local _tMaster = {
    forbidden = {
        "class"
    },
    required = {
        id   = {"string"},
        name = {"string"},
    },
};

--[[!
    @fqxn CoG.CoGObject
    @desc Shared CoG object metadata, tags and event dispatch. Concrete subclasses call the protected constructor.
    Names and descriptions must contain non-whitespace text. Rarity falls back to the first configured level.
    <ul>
    <li>getName() and getDescription() expose protected strings; no replacement setters are generated.</li>
    <li>getRarity() exposes rarity; setRarity(eRarity) checks the owned AffixSystem before changing it.</li>
    <li>getAffixSystem() returns the owned component; affix behavior resides in AffixSystem.</li>
    <li>getTagSystem() is final and returns the mutable per-object TagSystem; no replacement setter is generated.</li>
    <li>fireEvent(eEventID, ...) is final and delegates to this object's eventrix.</li>
    </ul>
!]]
return class("CoGObject",
{--METAMETHODS

},
{--STATIC PUBLIC
    CoGObject = function(stapub)
        --stapub.RARITY = enum("CoGObject.RARITY", tRarity.rarity, tRarity.colors, true);
    end,
},
{--PRIVATE
    eventrix            = null,
},
{--PROTECTED
    AffixSystem__RO         = null,
    eventrix__RO            = null,
    --[[!
        @fqxn CoG.CoGObject.Methods.getDescription
        @pulsarlua function CoGObject.getDescription
        @desc Returns the stored description. Generated non-final getter; no public setter.
        @ret string vValue Stored value/reference.
    !]]
    Description__autoA_     = "",
    --[[!
        @fqxn CoG.CoGObject.Methods.getName
        @pulsarlua function CoGObject.getName
        @desc Returns the stored name. Generated non-final getter; no public setter.
        @ret string vValue Stored value/reference.
    !]]
    Name__autoA_            = "", --leave as non-final so subclasses can alter it but create a public accessor only
    --[[!
        @fqxn CoG.CoGObject.Methods.getRarity
        @pulsarlua function CoGObject.getRarity
        @desc Returns the current rarity reference. Generated non-final getter.
        @ret Rarity.LEVEL vValue Stored value/reference.
    !]]
    --[[!
        @fqxn CoG.CoGObject.Methods.setRarity
        @pulsarlua function CoGObject.setRarity
        @desc Rejects a rarity change when the owned AffixSystem cannot accommodate its applied entries.
        @param Rarity.LEVEL eRarity Replacement rarity.
        @ret CoGObject this This object, followed by success, rarity or nil, and reason.
    !]]
    Rarity__autoA_          = null,
    --[[!
        @fqxn CoG.CoGObject.Methods.getTagSystem
        @pulsarlua function CoGObject.getTagSystem
        @desc Returns the mutable tag component by reference. Final getter; no replacement setter.
        @ret TagSystem vValue Stored value/reference.
    !]]
    TagSystem__autoAF       = null,
    --[[!
    @fqxn CoG.CoGObject.Methods.CoGObject
    @desc Protected constructor. Creates a fresh eventrix, TagSystem and owned AffixSystem after validating the name and description.
    @param string sName The name of the object.
    @param string sDescription The description of the object.
    @param Rarity.LEVEL|nil eRarity Configured rarity member; other values use Rarity.LEVEL[1].
    @param string|nil wEventrix Optional registered event environment name.
    @throws Blank/non-string metadata or inherited/eventrix initialization errors.
    !]]
    CoGObject = function(this, cdat, super, sName, sDescription, eRarity, wEventrix)
        local pri = cdat.pri;
        local pro = cdat.pro;
        type.assert.string(sName, "%S+");
        type.assert.string(sDescription, "%S+");

        super();
        pri.eventrix   = eventrix(wEventrix); --TODO clone these?
        pro.eventrix   = pri.eventrix;

        pro.Name        = sName;
        pro.Description = sDescription;
        pro.Rarity      = Rarity.LEVEL.__hasa(eRarity) and eRarity or Rarity.LEVEL[1];

        pro.TagSystem   = TagSystem();
        pro.AffixSystem = AffixSystem(this, pro.Rarity, wEventrix, true);
    end,
},
{--PUBLIC
    --[[!
        @fqxn CoG.CoGObject.Methods.ownsAffixSystem
        @pulsarlua function CoGObject.ownsAffixSystem
        @desc Tests exact component identity without reconnecting or changing it.
        Used by AffixSystem to reject rebinding an owned component.
        @param AffixSystem oSystem Candidate component.
        @ret boolean bOwned True when this object owns the exact component.
    !]]
    ownsAffixSystem__FNL = function(this, cdat, oSystem)
        return rawequal(cdat.pro.AffixSystem, oSystem);
    end,

    --[[!
        @fqxn CoG.CoGObject.Methods.getAffixSystem
        @desc Returns the owned AffixSystem with no replacement setter. Reconnects
        its external owner after loading, without invoking gameplay callbacks.
    !]]
    getAffixSystem__FNL = function(this, cdat)
        local oSystem = cdat.pro.AffixSystem;
        if (not rawequal(oSystem.getOwner(), this)) then
            local _, bBound, _, sReason = oSystem.setOwner(this);
            assert(bBound, sReason);
        end
        return oSystem;
    end,

    --[[!
        @fqxn CoG.CoGObject.Methods.setRarity
        @desc Delegates affix eligibility to the owned component. Rejection leaves
        rarity and applications unchanged. Returns this, success, rarity or nil, reason.
    !]]
    setRarity__FNL = function(this, cdat, eRarity)
        local bAllowed, sReason = this.getAffixSystem().canSetRarity(eRarity);
        if (not bAllowed) then
            return this, false, nil, sReason;
        end

        cdat.pro.Rarity = eRarity;
        return this, true, eRarity, nil;
    end,
    --[[!
        @fqxn CoG.CoGObject.Methods.fireEvent
        @pulsarlua function CoGObject.fireEvent
        @desc Dispatches an event through this object's eventrix. Final method.
        @param enumitem eEventID Event identifier.
        @param varargs ... Arguments forwarded to hooks.
        @ret table tResults Hook results/errors, as returned by eventrix.fire.
    !]]
    fireEvent__FNL = function(this, cdat, eEventID, ...)
        return cdat.pri.eventrix.fire(eEventID, ...);
    end,

},
CoG,   --extending class
false, --if the class is final (or (if a table is provided) limited to certain subclasses)
nil    --interface(s) (either nil, or interface(s))
);
