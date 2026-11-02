-- BaseCard migration: archived presentation behavior and native components/persistence.
local pTests=assert(debug.getinfo(1,"S").source:match("^@(.+)[/\\][^/\\]+$"));
local pCoG=pTests.."/..";
package.path=pCoG.."/?.lua;"..pCoG.."/../LuaEx/?.lua;"..package.path;
require("LuaEx.load")(3);require("cog.load")();
local Card=CoG.BaseCard;local nChecks=0;
local function check(condition,message)
    assert(condition,message);nChecks=nChecks+1;
end
local function reject(action,fragment)
    local ok,err=pcall(action);
    check(not ok and (not fragment or tostring(err):find(fragment,1,true)),
        "Expected rejection "..tostring(fragment)..", got "..tostring(err));
end
-- Bind the original card methods to a small reference object. The superclass
-- adapter supplies metadata and tags only; native base components are tested below.
local objects=setmetatable({},{__mode="k"});
local environment=setmetatable({},{__index=_G});
local Reference;
environment.class=setmetatable({getname=function(v)
    if (v==Reference or objects[v]) then return "CoG.BaseCard";end
    return class.getname(v);
end},{__call=function(_,name,meta,static,private,protected,public)
    return function(...)
        local data={pro={FaceUp=false,Enabled=true}};local object={};objects[object]=true;
        object.isFaceUp=function() return data.pro.FaceUp;end;
        object.isEnabled=function() return data.pro.Enabled;end;
        for method,fn in pairs(public) do
            if (method~=name) then object[method]=function(...) return fn(object,data,...);end;end
        end
        local function parent(sName,sDescription,rarity)
            type.assert.string(sName,"%S+");type.assert.string(sDescription,"%S+");
            local tags=require("cog.TagSystem")();
            object.getName=function() return sName;end;
            object.getDescription=function() return sDescription;end;
            object.getRarity=function() return lxe.isMember(rarity,CoG.Rarity.LEVEL) and rarity or CoG.Rarity.LEVEL[1];end;
            object.getTagSystem=function() return tags;end;
        end
        public[name](object,data,parent,...);
        return object;
    end;
end});
Reference=assert(loadfile(pCoG.."/legacy/cog/CardSystem/BaseCard.lua","t",environment))();
environment.BaseCard=Reference;
check(class.is(Card) and class.getname(Card)=="CoG.BaseCard","native discovery");
check(rawget(_G,"BaseCard")==nil,"no global alias");
local empty=Card();check(empty.getName()=="Card" and empty.getDescription()=="A card.");
check(not empty.isFaceUp() and empty.isEnabled());
check(class.isa(empty,CoG.CoGObject) and class.isa(empty,CoG.CoGBase),"native ancestry");
for _,method in ipairs({"getSuit","getRank","getValue"}) do reject(function() return empty[method];end,"Unknown member");end
for _,face in ipairs({false,true}) do
    for _,enabled in ipairs({false,true}) do
        local native,old=Card("Spell","A spell.",CoG.Rarity.LEVEL.II,nil,face,enabled),
            Reference("Spell","A spell.",CoG.Rarity.LEVEL.II,nil,face,enabled);
        check(native.isFaceUp()==old.isFaceUp() and native.isEnabled()==old.isEnabled());
        check(native.getName()==old.getName() and native.getDescription()==old.getDescription()
            and rawequal(native.getRarity(),old.getRarity()));
        for step=1,120 do
            local method=({"flip","reveal","hide","setFaceUp","setEnabled"})[1+step%5];
            local value=step%2==0;
            check(rawequal(native[method](value),native) and rawequal(old[method](value),old),"chainable action");
            check(native.isFaceUp()==old.isFaceUp() and native.isEnabled()==old.isEnabled(),"archived flag behavior");
            check(native.getName()=="Spell" and native.getDescription()=="A spell.","presentation does not alter metadata");
        end
    end
end
local fallback=Card(false,false,false);
check(fallback.getName()=="Card" and fallback.getDescription()=="A card." and rawequal(fallback.getRarity(),CoG.Rarity.LEVEL.I));
for _,bad in ipairs({1,"false",{},null}) do
    reject(function() Card("Bad","Invalid flags",nil,nil,bad);end,"FaceUp must be a boolean");
    reject(function() Card("Bad","Invalid flags",nil,nil,nil,bad);end,"Enabled must be a boolean");
    local beforeFace,beforeEnabled=empty.isFaceUp(),empty.isEnabled();
    reject(function() empty.setFaceUp(bad);end,"FaceUp must be a boolean");
    reject(function() empty.setEnabled(bad);end,"Enabled must be a boolean");
    check(empty.isFaceUp()==beforeFace and empty.isEnabled()==beforeEnabled,"invalid setters preserve state");
end
reject(function() empty.setFaceUp(nil);end);reject(function() empty.setEnabled(nil);end);
reject(function() Card("","valid");end);reject(function() Card("valid","");end);
local originalEventrix=_G.eventrix;local constructed=0;
_G.eventrix=function(...) constructed=constructed+1;return originalEventrix(...);end;
local flagsOK=pcall(Card,"Bad","Bad",nil,nil,"invalid");
_G.eventrix=originalEventrix;
check(not flagsOK and constructed==0,"flag validation precedes superclass component allocation");
local original=Card("Fireball","A spell.",CoG.Rarity.LEVEL.III,nil,true,false);
original.getTagSystem().add("ENABLED");original.getTagSystem().add("DISABLED",true);
CoG.AffixSystem.registerDefinition("CardTestGlow",{type=CoG.AffixSystem.TYPE.PREFIX,
    name="Glowing",classes={Card},tiers={[CoG.TIER.I]={}}});
original.getAffixSystem().setOnAddCallback(function() return {};end);
original.getAffixSystem().setOnRemoveCallback(function() end);
local _,applied=original.getAffixSystem().applyAffix(CoG.AffixSystem.createAffix("CardTestGlow",CoG.TIER.I));
check(applied and original.getAffixSystem().getAffixCount()==1,"base card owns applied affixes");
local copy=clone(original);
check(not rawequal(copy,original) and class.isinstanceof(copy,Card));
check(copy.getName()==original.getName() and copy.getDescription()==original.getDescription()
    and rawequal(copy.getRarity(),original.getRarity()) and copy.isFaceUp() and not copy.isEnabled());
check(not rawequal(copy.getTagSystem(),original.getTagSystem()) and not rawequal(copy.getAffixSystem(),original.getAffixSystem()),"fresh clone components");
check(rawequal(copy.getAffixSystem().getOwner(),copy) and rawequal(original.getAffixSystem().getOwner(),original));
check(copy.getAffixSystem().getAffixCount()==0 and original.getAffixSystem().getAffixCount()==1,"plain card clone omits affixes as before");
local tags={};for tag,enabled in copy.getTagSystem().eachTag() do tags[tag]=enabled;end
check(tags.ENABLED==true and tags.DISABLED==false,"clone preserves enabled and disabled tags");
copy.getTagSystem().remove("ENABLED");copy.hide().setEnabled(true);
check(original.getTagSystem().contains("ENABLED") and original.isFaceUp() and not original.isEnabled(),"clone changes are independent");
local LXC=require("LuaEx.lib.lxc");
LXC.loadSources({["CardTest.lxc"]=[=[namespace CardTest {
    class Child : CoG.BaseCard {
        private extra=7;
        public Child() { base("Child","Concrete card.",nil,nil,true,false); }
        public getExtra() { return this.extra; }
        public addHook(event,callback) { return this.eventrix.addHook(event,callback); }
    }
    class Cloneable : CoG.BaseCard {
        private extra=9;
        public Cloneable() { base("Copyable","Explicit policy."); }
        public getExtra() { return this.extra; }
        public override operator clone() { return Cloneable(); }
    }
}]=]},_G);
local child=CardTest.Child();
reject(function() clone(child);end,"subclasses must implement __clone");
check(class.isinstanceof(clone(CardTest.Cloneable()),CardTest.Cloneable),"explicit subclass cloning");
local graph={card=original,alias=original,child=child};graph.self=graph;
local loaded=deserialize(serialize(graph));
check(rawequal(loaded.card,loaded.alias) and rawequal(loaded.self,loaded),"graph sharing and cycles");
check(loaded.card.isFaceUp() and not loaded.card.isEnabled() and loaded.card.getTagSystem().contains("ENABLED"));
check(class.isinstanceof(loaded.child,CardTest.Child) and loaded.child.getExtra()==7,"subclass persistence");
check(rawequal(loaded.card.getAffixSystem().getOwner(),loaded.card),"restored component ownership");
check(loaded.card.getAffixSystem().getAffixCount()==1,"native persistence retains applied affixes");
loaded.card.hide().setEnabled(true);loaded.card.getTagSystem().remove("DISABLED");
check(original.isFaceUp() and not original.isEnabled(),"restoration is independent");
local reloaded=deserialize(serialize(loaded));check(not reloaded.card.isFaceUp() and reloaded.card.isEnabled());
check(rawequal(clone(Card),Card) and rawequal(deserialize(serialize(Card)),Card),"canonical class references");
print("PASS BaseCard: "..nChecks.." checks.");
