--[[!
@fqxn CoG.Config.TIER
@desc Supplies the shared LXE tier declaration to ordinary configuration modules.
    LuaEx must discover cog/enums/TIER.lxe before CoG configuration is assembled.
@ret enum Canonical CoG.TIER collection.
!]]
assert(CoG and lxe.isEnum(CoG.TIER), "LuaEx must load CoG.TIER before CoG configuration.");
return CoG.TIER;
