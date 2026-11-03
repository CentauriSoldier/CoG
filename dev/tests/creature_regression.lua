-- Native creature components, archived constructor/getter comparison and persistence.
local pTests=assert(debug.getinfo(1,"S").source:match("^@(.+)[/\\][^/\\]+$"));
local pCoG=pTests.."/..";
package.path=pCoG.."/?.lua;"..pCoG.."/../LuaEx/?.lua;"..package.path;
require("LuaEx.load")(3);require("cog.load")();
local Creature=CoG.CoGCreature;local checks=0;
local function check(condition,message) assert(condition,message);checks=checks+1;end
local function reject(action,fragment)
    local ok,err=pcall(action);
    check(not ok and (not fragment or tostring(err):find(fragment,1,true)),
        "Expected rejection "..tostring(fragment)..", got "..tostring(err));
end
local function options()
    return {XP={Type=CoG.XPSystem.TYPE.LINEAR,LevelOneXP=10,MaxLevel=5,Progression=2},
        HP={Max=80,Current=50},StatusScope=CoG.EFFECT};
end
check(class.is(Creature) and class.getname(Creature)=="CoG.CoGCreature");
check(rawget(_G,"CoGCreature")==nil and rawget(_G,"Targetor")==nil,"no new aliases");
local creature=Creature("Bob","A soldier.",nil,nil,options());
local other=Creature("Other","Another creature.",nil,nil,options());
check(class.isa(creature,CoG.CoGObject) and class.isa(creature,CoG.CoGBase));
check(creature.getName()=="Bob" and creature.getDescription()=="A soldier.");
check(rawequal(creature.getRarity(),CoG.LEVEL.ONE));
check(creature.getHP(CoG.Pool.ASPECT.MAX)==80 and creature.getHP().get()==50);
local getters={"getXPSystem","getHP","getItemSystem","getItemSlotSystem","getStatusTracker","getTargetor","getTagSystem"};
for _,method in ipairs(getters) do
    check(rawequal(creature[method](),creature[method]()) and not rawequal(creature[method](),other[method]()),"independent component "..method);
    reject(function() creature[method]=function() end;end);
end
check(rawequal(creature.getItemSystem().getOwner(),creature) and rawequal(creature.getItemSlotSystem().getOwner(),creature));
check(creature.getItemSystem().getItemCount()==0 and creature.getItemSystem().getMaxItems()==math.huge);
check(creature.getItemSlotSystem().getItemSlotCount()==0 and #creature.getStatusTracker()==0);
check(creature.getTargetor().Types.add({"CREATURE"})==1 and #other.getTargetor().Types==0);
creature.getItemSystem().setLocked(true);check(not other.getItemSystem().isLocked());creature.getItemSystem().setLocked(false);
check(select(2,creature.getItemSlotSystem().addItemSlot(CoG.ItemSlot())));
check(other.getItemSlotSystem().getItemSlotCount()==0);
check(creature.getStatusTracker().activate("HASTENED",3,true) and not other.getStatusTracker().isActive("HASTENED"));
reject(function() clone(creature);end,"subclasses must define __clone");
for _,method in ipairs({"getSpecies","getFaction","getLevel","getAge","getMana","takeDamage","heal","cycleResources"}) do
    reject(function() return creature[method];end,"Unknown member");
end
for _,input in ipairs({false,{}, {XP={}}, {XP={},HP={}}, {XP={},HP={Max="80",Current=50}},
    {XP={},HP={Max=80,Current="50"}}, {XP={},HP={Max=80,Current=50},StatusScope=CoG.EFFECT}}) do
    reject(function() Creature("Bad","Bad options",nil,nil,input);end);
end
reject(function() Creature();end);
local invalid=options();invalid.StatusScope="EFFECT";reject(function() Creature("Bad","Bad scope",nil,nil,invalid);end);
local originalEventrix=_G.eventrix;local allocated=0;
_G.eventrix=function(...) allocated=allocated+1;return originalEventrix(...);end;
local ok=pcall(Creature,"Bad","Bad shape",nil,nil,{});_G.eventrix=originalEventrix;
check(not ok and allocated==0,"option shape validation precedes superclass allocation");

-- Run the archived constructor and HP getter with a native receiver and native
-- component factories. The superclass adapter validates metadata only.
local captured;
local environment=setmetatable({class=function(name,meta,static,private,protected,public)
    captured=public;return public;
end,XPSystem=CoG.XPSystem,Pool=CoG.Pool,ItemSystem=CoG.ItemSystem,ItemSlotSystem=CoG.ItemSlotSystem,
    StatusTracker=CoG.StatusTracker,Targetor=require("cog.Targetor")},{__index=_G});
assert(loadfile(pCoG.."/legacy/cog/Objects/CreatureSystem/CoGCreature.lua","t",environment))();
local state={pro={}};
captured.CoGCreature(creature,state,function(name,description)
    type.assert.string(name,"%S+");type.assert.string(description,"%S+");
end,"Bob","A soldier.",nil,nil,options());
local reference=state.pro;
check(captured.getHP__FNL(creature,state,CoG.Pool.ASPECT.MAX)==creature.getHP(CoG.Pool.ASPECT.MAX));
for step=1,180 do
    local level=step%6;
    creature.getXPSystem().setLevel(level);reference.XP.setLevel(level);
    local delta=step%13-6;
    creature.getHP().adjust(delta);reference.HP.adjust(delta);
    creature.getStatusTracker().setDuration("POISONED",step%7);
    reference.StatusTracker.setDuration("POISONED",step%7);
    check(creature.getXPSystem().getLevel()==reference.XP.getLevel(),"archived XP component behavior");
    check(creature.getHP().get()==reference.HP.get(),"archived HP component behavior");
    check(creature.getHP(CoG.Pool.ASPECT.MAX)==captured.getHP__FNL(creature,state,CoG.Pool.ASPECT.MAX),"archived HP getter delegation");
    check(creature.getStatusTracker().getDuration("POISONED")==reference.StatusTracker.getDuration("POISONED"),"archived status component behavior");
end
local LXC=require("LuaEx.lib.lxc");
for _,method in ipairs(getters) do
    local source="namespace CreatureFinalTest { class Bad : CoG.CoGCreature { public override "..method.."() {} } }";
    reject(function() LXC.loadSources({["FinalGetter.lxc"]=source},_G);end,"final");
end
LXC.loadSources({["CreatureTest.lxc"]=[=[namespace CreatureTest {
    class Child : CoG.CoGCreature {
        private extra=7;
        public Child(options) { base("Child","Derived creature.",nil,nil,options); }
        public getExtra() { return this.extra; }
        public readProtectedHP() { return this.HP; }
    }
    class Cloneable : CoG.CoGCreature {
        public Cloneable(options) { base("Cloneable","Explicit copy policy.",nil,nil,options); }
        public override operator clone() {
            return Cloneable({XP={Type=CoG.XPSystem.TYPE.LINEAR,LevelOneXP=10,MaxLevel=5,Progression=2},
                HP={Max=80,Current=50},StatusScope=CoG.EFFECT});
        }
    }
    class Item : CoG.CoGItem {
        public Item() {
            base("Loot","A creature item");
            this.Storable_In.add(CoG.ItemSystem);
        }
    }
}]=]},_G);
LXC.loadSources({["CreatureScopes.lxe"]=[=[namespace CreatureScopes {
    public enum EFFECT { PEOPLE { TIMED; FOREVER; } OBJECTS { DAMAGED; } }
}]=]},_G);
local unrelatedScope=options();unrelatedScope.StatusScope=CreatureScopes.EFFECT.PEOPLE;
reject(function() Creature("Unrelated","Wrong enum identity.",nil,nil,unrelatedScope);end,
    "scope must be CoG.EFFECT");
local child=CreatureTest.Child(options());check(rawequal(child.readProtectedHP(),child.getHP()),"protected field names");
check(class.isinstanceof(clone(CreatureTest.Cloneable(options())),CreatureTest.Cloneable),"explicit subclass copy policy");
local loot=CreatureTest.Item();check(select(2,creature.getItemSystem().addItem(loot)));
creature.getStatusTracker().activate("HASTENED",9,true);
creature.getTargetor().Targetable.add({"BEAST"});
creature.getTagSystem().add("CREATURE");
local graph={creature=creature,alias=creature,child=child};graph.self=graph;
creature.getXPSystem().setLevel(3);
local encoded=serialize(graph);local loaded=deserialize(encoded);local again=deserialize(encoded);
check(rawequal(loaded.creature,loaded.alias) and rawequal(loaded.self,loaded),"graph aliases and cycles");
check(not rawequal(loaded.creature,again.creature),"independent graph loads");
check(loaded.creature.getName()=="Bob" and loaded.creature.getHP().get()==creature.getHP().get());
check(loaded.creature.getXPSystem().getLevel()==creature.getXPSystem().getLevel());
check(loaded.creature.getStatusTracker().getDuration("HASTENED")==9);
check(#loaded.creature.getTargetor().Types==1 and #loaded.creature.getTargetor().Targetable==1);
other.getTargetor().Types.add({"BEAST"});
check(loaded.creature.getTargetor().canTarget(other.getTargetor()),"restored targeting group values");
check(loaded.creature.getTagSystem().contains("CREATURE"));
check(rawequal(loaded.creature.getItemSystem().getOwner(),loaded.creature)
    and rawequal(loaded.creature.getItemSlotSystem().getOwner(),loaded.creature),"owned container reconnection");
local loadedLoot=loaded.creature.getItemSystem().getItemAt(1);
check(loadedLoot and rawequal(loadedLoot.getLocation(),loaded.creature.getItemSystem()),"inventory membership and inverse location");
check(loaded.creature.getItemSlotSystem().getItemSlotCount()==1);
check(class.isinstanceof(loaded.child,CreatureTest.Child) and loaded.child.getExtra()==7,"concrete subclass state");
loaded.creature.getHP().adjust(-1);check(loaded.creature.getHP().get()~=creature.getHP().get(),"restored components are independent");
check(deserialize(serialize(loaded)).creature.getName()=="Bob","resaving restored creature");
check(rawequal(creature.getItemSystem().getOwner(),creature),"saving preserves live owner");
check(rawequal(clone(Creature),Creature) and rawequal(deserialize(serialize(Creature)),Creature),"canonical class references");
print("PASS CoGCreature: "..checks.." checks.");
