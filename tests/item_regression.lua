-- Native item/container integration, transaction and graph-persistence checks.
local pTests = assert(debug.getinfo(1, "S").source:match("^@(.+)[/\\][^/\\]+$"));
local pCoG = pTests.."/..";
package.path = pCoG.."/?.lua;"..pCoG.."/../LuaEx/?.lua;"..package.path;
require("LuaEx.load")(3);
require("cog.load")();
local nChecks = 0;
local function check(bCondition, sMessage)
    assert(bCondition, sMessage); nChecks = nChecks + 1;
end
local function reject(fAction, sFragment)
    local bOK, vError = pcall(fAction);
    check(not bOK and (not sFragment or tostring(vError):find(sFragment, 1, true)),
        "Expected rejection "..tostring(sFragment)..", got "..tostring(vError));
end
local function success(oContainer, sMethod, ...)
    local oSelf, bOK, vResult, sReason = oContainer[sMethod](...);
    check(rawequal(oSelf, oContainer) and bOK, sReason or sMethod);
    return vResult;
end
local function denied(oContainer, sMethod, ...)
    local oSelf, bOK = oContainer[sMethod](...);
    check(rawequal(oSelf, oContainer) and bOK == false, "Expected denied "..sMethod);
end
local LXC = require("LuaEx.lib.lxc");
LXC.loadSources({["InventoryTest.lxc"] = [=[namespace InventoryTest {
    class Item : CoG.CoGItem {
        public Item(t) {
            base("Test item", "An individual item", nil, nil,
                t and t.attach, t and t.consume, t and t.damage, t and t.detach,
                t and t.equip, t and t.scope, t and t.conflicts, t and t.inimitable,
                t and t.remove, t and t.repair, t and t.store,
                t and t.tradeBy, t and t.tradeTo, t and t.unequip,
                t and t.upgrade, t and t.downgrade, t and t.durability,
                t and t.size, t and t.value, t and t.weight,
                t and t.host, t and t.location, t and t.pattern);
            if (t == nil or t.store == nil) then
                this.Storable_In.add(CoG.ItemSystem);
                this.Storable_In.add(CoG.ItemStashSystem);
            end
        }
        public readProtectedSize() { return this.Size; }
    }
    class Raw : CoG.CoGItem {
        public Raw() { base("Raw item", "Unconfigured storage"); }
    }
    class Cloneable : CoG.CoGItem {
        public Cloneable() { base("Cloneable", "Explicit copy policy"); }
        public override operator clone() { return Cloneable(); }
    }
}]=]}, _G);
local Item, Slot, Slots, Inventory, Stash = InventoryTest.Item,
    CoG.ItemSlot, CoG.ItemSlotSystem, CoG.ItemSystem, CoG.ItemStashSystem;
local Registry, ClassRegistry = CoG.CoGRegistry, LuaEx.Classes.ClassRegistry;
for _, sName in ipairs({"CoGItem", "ItemSlot", "ItemSlotSystem", "ItemSystem", "ItemStashSystem"}) do
    check(class.is(CoG[sName]), "native class "..sName);
    check(rawget(_G, sName) == nil, "no short alias "..sName);
end
reject(function() CoG.CoGItem("item", "description"); end, "constructor");
reject(function() LXC.loadSources({["FinalSlot.lxc"] = "namespace InventoryTest { class BadSlot : CoG.ItemSlot {} }"}, _G); end, "final");
local first, second = Item(), Item();
check(first.getName() == "Test item" and class.isa(first, CoG.CoGObject), "real superclass metadata");
local tComponents = {"getAttachableToRegistry", "getConsumableByRegistry", "getDamageableByRegistry",
    "getDetachableByRegistry", "getEquippableByRegistry", "getExclusiveInRegistry", "getExclusiveWithRegistry",
    "getRemovableByRegistry", "getRepairableByRegistry", "getStorableInRegistry", "getTradableByRegistry",
    "getTradableToRegistry", "getUnequippableByRegistry", "getUpgradeableByRegistry", "getDowngradableByRegistry",
    "getDurabilityPool", "getSizePool", "getValuePool", "getWeightPool", "getSlotPattern"};
for _, sMethod in ipairs(tComponents) do
    check(class.isinstance(first[sMethod]()) and not rawequal(first[sMethod](), second[sMethod]()), "fresh component "..sMethod);
end
check(rawequal(first.readProtectedSize(), first.getSizePool()), "protected storage name preserved");
check(first.getDurabilityPool().get() == 1 and first.getSizePool().get() == 0
    and first.getValuePool().get() == 0 and first.getWeightPool().get() == 0, "pool defaults");
check(first.getLocation() == null and first.getAttached_To() == null and not first.isInimitable(), "reference and flag defaults");
check(#first.getSlotPattern() == 0 and first.getAttachableToRegistry().getCount() == 0, "empty permissions and footprint");
local target, otherTarget = Slots(), Slots();
check(first.getExclusiveInRegistry().allows(target), "default container scopes");
local scoped = Item({scope = target});
check(scoped.getExclusiveInRegistry().allows(target) and not scoped.getExclusiveInRegistry().allows(otherTarget), "specific instance scope");
local damage, size, pattern = Registry({Item}), CoG.Pool(10, 3), CoG.SlotPattern({{x=0,y=0}});
local supplied = Item({damage=damage,size=size,pattern=pattern,inimitable=true});
check(rawequal(supplied.getDamageableByRegistry(), damage) and rawequal(supplied.getSizePool(), size)
    and rawequal(supplied.getSlotPattern(), pattern) and supplied.isInimitable(), "supplied component identities");
for _, tBad in ipairs({{damage=false},{consume=4},{scope=first},{conflicts=Registry()},
    {inimitable="bad"},{host=Slots()},{location={}},{pattern=4},{pattern=CoG.SlotPattern},{size=Registry()}}) do
    reject(function() Item(tBad); end);
end
reject(function() clone(first); end, "must implement __clone");
check(class.isinstanceof(clone(InventoryTest.Cloneable()), InventoryTest.Cloneable), "explicit subclass clone policy");
for _, oContainer in ipairs({Slot(), Slots(), Inventory(), Stash()}) do
    reject(function() clone(oContainer); end, "Clone concrete items");
end
local raw = InventoryTest.Raw();
denied(Inventory(), "addItem", raw);
check(raw.getLocation() == null, "empty storage registry denies inventory placement");

-- Stacking, replacement and atomic capacity changes.
local a,b,c = Item(),Item(),Item(); local slot = Slot(nil,2,nil,"stack");
check(slot.getName() == "stack" and slot.getCapacity() == 2 and not slot.isOccupied());
success(slot,"set",a); denied(slot,"set",a); success(slot,"set",b); denied(slot,"set",c);
denied(slot,"setCapacity",1); check(slot.getCapacity() == 2);
check(rawequal(success(slot,"set",c,true), a) and a.getLocation() == null and #slot == 2);
slot.setLocked(true); denied(slot,"remove",b); slot.setLocked(false);
success(slot,"clear"); check(#slot == 0 and b.getLocation() == null and c.getLocation() == null);

-- Hierarchy-wide exclusivity, movement, owners and rollback.
local owner=Item(); local stash=Stash(owner,2,3);
local left,right=stash.getTab(1),stash.getTab(2);
check(rawequal(left.getOwner(),owner) and #stash==2);
local unique=Item({scope=ClassRegistry({stash}),conflicts=ClassRegistry({Item})});
success(left,"addItem",unique); denied(right,"addItem",Item());
success(left,"transferItemTo",right,unique); check(#left==0 and #right==1 and rawequal(unique.getLocation(),right));
stash.setLocked(true); denied(right,"removeItem",unique); stash.setLocked(false);
denied(stash,"removeTab",2); success(stash,"clear"); success(stash,"removeTab",2); denied(stash,"removeTab",1);
local full=Inventory(1); local resident,traveler=Item(),Item();
success(full,"addItem",resident); success(left,"addItem",traveler);
denied(left,"transferItemTo",full,traveler);
check(rawequal(traveler.getLocation(),left) and rawequal(resident.getLocation(),full), "failed transfer restores both endpoints");
check(rawequal(success(left,"transferItemTo",full,traveler,true),resident) and resident.getLocation()==null);
denied(full,"setMaxItems",0); check(full.getMaxItems()==1);
local initial=Item(); local initialized=Inventory(2,{initial});
check(rawequal(initial.getLocation(),initialized));
local failedInitial=Item(); reject(function() Inventory(0,{failedInitial}); end);
check(failedInitial.getLocation()==null);
reject(function() Inventory(2,{failedInitial,failedInitial}); end); check(failedInitial.getLocation()==null);
local s1,s2=Slot(nil,2),Slot(nil,2); local equipment=Slots({s1,s2},owner);
local one=Item({scope=equipment,conflicts=ClassRegistry({Item})});
success(s1,"set",one); denied(s2,"set",Item()); denied(Slots(),"addItemSlot",s1);
denied(equipment,"removeItemSlot",1); success(equipment,"clear"); success(equipment,"removeItemSlot",1);
check(s1.getItemSlotSystem()==null);
local callbackItem=Item();
local callbackSlot=Slot(Registry({Item},function() full.clear(); return true; end));
denied(callbackSlot,"set",callbackItem); check(rawequal(traveler.getLocation(),full) and callbackItem.getLocation()==null);
local throwSlot=Slot(Registry({Item},function() error("callback failure"); end));
denied(throwSlot,"set",callbackItem); check(#throwSlot==0);
local bypass=Slot(Registry({Item},function() traveler.setLocation(null,full); return true; end));
denied(bypass,"set",callbackItem); check(rawequal(traveler.getLocation(),full));
local preview=Slot(); check(preview.canAccept(callbackItem) and callbackItem.getLocation()==null and #preview==0);

-- Grids reserve full footprints, including locked non-anchor cells.
local cells={}; for i=1,9 do cells[i]=Slot(); end
local grid=Slots(cells); success(grid,"configureGrid",3,3);
local shape=CoG.SlotPattern({{x=0,y=0},{x=0,y=1},{x=1,y=1}});
local shaped=Item({pattern=shape}); success(grid,"placeItem",shaped,0,0);
check(rawequal(grid.getOccupantAt(1,1),shaped) and grid.getItemCount()==1);
local blocked=Item(); denied(grid,"placeItem",blocked,1,1); success(grid,"placeItem",blocked,2,0);
denied(grid,"placeItem",Item({pattern=shape}),2,2);
cells[5].setLocked(true); denied(grid,"removeItem",shaped); denied(grid,"clear");
cells[5].setLocked(false); success(grid,"removeItem",shaped);
check(grid.getOccupantAt(1,1)==nil and shaped.getLocation()==null);
local mutable=CoG.SlotPattern({{x=0,y=0}}); local mutableItem=Item({pattern=mutable});
success(grid,"placeItem",mutableItem,0,0); mutable.setSlots({{x=0,y=0},{x=0,y=1}});
check(rawequal(grid.getOccupantAt(0,1),mutableItem));
mutable.setSlots({{x=0,y=0},{x=2,y=0}}); check(not grid.validate());
mutable.setSlots({{x=0,y=0}}); check(grid.validate());

-- Actor permissions and attachment cycles.
local actor,outsider=Item(),Item(); local permitted=Registry({actor});
local host,gem=Item(),Item({attach=Registry({Item}),detach=permitted});
success(gem,"attachTo",host); check(rawequal(gem.getAttached_To(),host));
denied(host,"attachTo",gem); denied(gem,"detach",outsider); success(gem,"detach",actor);
success(gem,"attachTo",host); local nAttachments=0;
for _, child in host.eachAttachment() do check(rawequal(child,gem)); nAttachments=nAttachments+1; end
check(nAttachments==1); success(gem,"detach",actor);
local potion=Item({consume=permitted,remove=permitted}); local potions=Slot(nil,2);
success(potions,"set",potion); denied(potions,"consumeItem",potion,outsider); success(potions,"consumeItem",potion,actor);
check(#potions==0 and potion.getLocation()==null);
local gear=Item({equip=permitted,unequip=permitted,tradeBy=permitted,tradeTo=Registry({outsider})});
local equip=Slots({Slot()}); success(left,"addItem",gear);
denied(equip,"equipItem",gear,outsider,1); success(equip,"equipItem",gear,actor,1);
denied(equip,"unequipItem",gear,outsider,left); success(equip,"unequipItem",gear,actor,left);
local recipient=Inventory(2); denied(left,"tradeItemTo",recipient,gear,outsider,actor);
success(left,"tradeItemTo",recipient,gear,actor,outsider);

-- Native persistence: owners omitted, inverse links rebuilt, callbacks retained.
local saved=Stash(owner,2,4); local savedItem=Item(); success(saved.getTab(1),"addItem",savedItem);
local beforeLocation=savedItem.getLocation(); local encoded=serialize(saved);
check(rawequal(saved.getOwner(),owner) and rawequal(savedItem.getLocation(),beforeLocation)
    and rawequal(saved.getTab(1).getItemStashSystem(),saved), "saving does not mutate live holders");
local loaded=deserialize(encoded); local loadedItem=loaded.getTab(1).getItemAt(1);
check(loaded.getOwner()==null and loaded.getTabCount()==2 and loaded.getItemCount()==1);
check(not rawequal(loadedItem,savedItem) and rawequal(loadedItem.getLocation(),loaded.getTab(1)));
loaded.setOwner(owner); check(rawequal(loaded.getTab(1).getOwner(),owner));
success(loaded.getTab(1),"transferItemTo",loaded.getTab(2),loadedItem);
check(deserialize(serialize(loaded)).getTab(2).getItemCount()==1);
local gate={allowed=true}; local gated=Slot(Registry({Item},function() return gate.allowed,"saved gate"; end),2);
success(gated,"set",Item()); gate.allowed=false;
local loadedGate=deserialize(serialize(gated)); denied(loadedGate,"set",Item()); check(#loadedGate==1);
local graph={item=savedItem,stash=saved,alias=savedItem}; graph.self=graph;
savedItem.getExclusiveInRegistry().add(saved);
local saveGraph=serialize(graph); local g1,g2=deserialize(saveGraph),deserialize(saveGraph);
check(rawequal(g1.item,g1.alias) and rawequal(g1.self,g1));
check(rawequal(g1.item.getLocation(),g1.stash.getTab(1)) and not rawequal(g1.item,g2.item));
local bFound=false;
for _, entry in g1.item.getExclusiveInRegistry().eachEntry() do bFound=bFound or rawequal(entry,g1.stash); end
check(bFound,"specific registry entries point to restored containers");
local attachedHost,attachedChild=Item(),Item({attach=Registry({Item}),detach=permitted});
success(attachedChild,"attachTo",attachedHost); local hostInventory=Inventory(); success(hostInventory,"addItem",attachedHost);
local hostLoaded=deserialize(serialize(hostInventory)).getItemAt(1); local childLoaded;
for _, child in hostLoaded.eachAttachment() do childLoaded=child; end
check(childLoaded and rawequal(childLoaded.getAttached_To(),hostLoaded) and not rawequal(childLoaded,attachedChild));
check(rawequal(attachedChild.getAttached_To(),attachedHost),"saving preserves the live attachment holder");
check(deserialize(serialize(grid)).getItemCount()==grid.getItemCount(),"grid occupancy rebuilds after restoration");
reject(function() loaded.setOwner("bad"); end); check(rawequal(loaded.getOwner(),owner));
-- Replay inventory transfers while independently checking conservation and locations.
local bags={Inventory(8),Inventory(8),Inventory(8)};
local items={};
for i=1,12 do items[i]=Item(); success(bags[1+(i-1)%3],"addItem",items[i]); end
for step=1,180 do
    local item=items[1+(step*7)%#items];
    local source=item.getLocation();
    local destination=bags[1+step%#bags];
    if (not rawequal(source,destination)) then
        success(source,"transferItemTo",destination,item);
    end
    local seen={}; local total=0;
    for _, bag in ipairs(bags) do
        check(bag.validate(),"replay hierarchy validates");
        for _, member in bag.eachItem() do
            check(not seen[member] and rawequal(member.getLocation(),bag),"one membership and exact location");
            seen[member]=true; total=total+1;
        end
    end
    check(total==#items,"transfers conserve items");
end

-- Untrusted native container field projections must pass the production hooks.
local Serializer=require("LuaEx.lib.serializer");
local function state(kind)
    return {persistenceID=1,kind=kind,capacity=4,owner=null,
        items={},children={},enabled=true,locked=false};
end
local function forged(tState,sClass)
    local marker={};
    if (tState.parent=="SELF") then tState.parent=marker; end
    local adapter={
        project=function(value)
            if (rawequal(value,marker)) then
                return {Kind="instance",Class=sClass or "CoG.ItemSystem",Fields={
                    [(sClass or "CoG.ItemSystem")..":state"]={Index=1,Type="table",ClassType=false,Locked=false},
                }},{tState};
            end
        end,
        checkFunction=function() end,checkGraph=function() end,
        allocate=function() error("Cannot restore during encoding."); end,
        finish=function() error("Cannot restore during encoding."); end,
    };
    return "--LXC:3\n"..Serializer.serializeStaged(marker,adapter);
end
local breakers={
    function(t) t.kind="slot"; end,
    function(t) t.capacity=-1; end,
    function(t) t.capacity=0.5; end,
    function(t) t.enabled="bad"; end,
    function(t) t.locked=1; end,
    function(t) t.owner={}; end,
    function(t) t.items={false}; end,
    function(t) t.items={[2]=false}; end,
    function(t) t.children={false}; end,
    function(t) t.parent="SELF"; end,
    function(t) t.width=2; end,
    function(t) t.width=2;t.height=2; end,
};
for _, breakState in ipairs(breakers) do
    local t=state("inventory");breakState(t);
    reject(function() deserialize(forged(t)); end);
end
check(deserialize(forged(state("inventory"))).getItemCount()==0,"valid restoration survives malformed saves");
check(saved.getItemCount()==1 and rawequal(savedItem.getLocation(),saved.getTab(1)),"failed restores preserve live graphs");
print("PASS inventory: "..nChecks.." checks.");
