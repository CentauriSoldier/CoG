--[[!
    @fqxn CoG.StructureSystem.CoGStructure
    @pulsarlua class CoGStructure
    @desc Marker subclass identifying structures through type.isCoGStructure,
    including derived classes. Inherits CoGObject metadata, rarity, tags, events
    and an owned AffixSystem. Developers define additional gameplay state in
    subclasses; higher-level world systems manage position and placement.
    The protected constructor is called by concrete subclasses through super.
!]]
return class("CoGStructure",
{--METAMETHODS

},
{--STATIC PUBLIC
},
{--PRIVATE

},
{--PROTECTED
    --[[!
        @fqxn CoG.StructureSystem.CoGStructure.Methods.CoGStructure
        @pulsarlua function CoGStructure
        @desc Protected constructor. Concrete subclasses call it through super
        to initialize inherited CoGObject state and independent components.
        @vis Protected
        @param string sName Structure name containing non-whitespace text.
        @param string sDescription Structure description containing non-whitespace text.
        @param Rarity.LEVEL|nil eRarity Inherited rarity; defaults to the first configured level.
        @param string|nil wEventrix Optional registered event environment name.
        @throws Invalid metadata or inherited initialization errors.
    !]]
    CoGStructure = function(this, cdat, super, sName, sDescription, eRarity, wEventrix)
        -- Delegate shared state creation and validation to the owning base class.
        super(sName, sDescription, eRarity, wEventrix);
    end,
},
{--PUBLIC
},
CoGObject,  --extending class
false,       --if the class is final (or (if a table is provided) limited to certain subclasses)
nil          --interface(s) (either nil, or interface(s))
);

--[[!
    @fqxn CoG.StructureSystem.CoGStructure.InheritedCoGObject
    @inheritdoc CoG.CoGObject
!]]
