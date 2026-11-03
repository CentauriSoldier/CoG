-- Native BaseDeck behavior compared with unchanged archived deck methods.
local pTests=assert(debug.getinfo(1,"S").source:match("^@(.+)[/\\][^/\\]+$"));
local pCoG=pTests.."/..";
package.path=pCoG.."/?.lua;"..pCoG.."/../LuaEx/?.lua;"..package.path;
require("LuaEx.load")(3);require("cog.load")();
local Deck,Card=CoG.BaseDeck,CoG.BaseCard;local checks=0;
local function check(condition,message) assert(condition,message);checks=checks+1;end
local function reject(action,fragment)
    local ok,err=pcall(action);
    check(not ok and (not fragment or tostring(err):find(fragment,1,true)),
        "Expected rejection "..tostring(fragment)..", got "..tostring(err));
end
local function same(a,b)
    if rawequal(a,b) then return true;end
    if rawtype(a)~="table" or rawtype(b)~="table" then return false;end
    for k,v in pairs(a) do if not same(v,b[k]) then return false;end;end
    for k in pairs(b) do if a[k]==nil then return false;end;end
    return true;
end
local references=setmetatable({},{__mode="k"});local Reference;
local environment=setmetatable({BaseCard=Card},{__index=_G});
environment.class=setmetatable({
    isinstance=class.isinstance,
    getname=function(v) return (v==Reference or references[v]) and "CoG.BaseDeck" or class.getname(v);end,
    ischildorself=function(name,parent)
        local c=class.getbyname(name);return rawequal(c,parent) or class.ischild(c,parent);
    end,
},{__call=function(_,name,meta,static,private,protected,public)
    return function(cards)
        local object={};local data={pri={cards={},busy=false}};references[object]=true;
        for method,fn in pairs(public) do
            if method~=name then object[method]=function(...) return fn(object,data,...);end;end
        end
        setmetatable(object,{__len=function() return meta.__len(object,data);end,
            __pairs=function() return meta.__pairs(object,data);end});
        public[name](object,data,function() end,cards);return object;
    end;
end});
Reference=assert(loadfile(pCoG.."/legacy/cog/CardSystem/BaseDeck.lua","t",environment))();environment.BaseDeck=Reference;
check(class.is(Deck) and class.getname(Deck)=="CoG.BaseDeck","native discovery");
check(rawget(_G,"BaseDeck")==nil,"no short alias");
check(class.isa(Deck(),CoG.CoGBase),"native foundation ancestry");
local cards={};for i=1,12 do cards[i]=Card("Card "..i,"Deck test");end
local source={cards[1],cards[2],cards[3]};local deck=Deck(source);source[1]=cards[4];
check(rawequal(deck.peek(),cards[1]) and #deck==3,"constructor copies list, retaining identities");
local snapshot=deck.getCards();snapshot[1]=cards[4];check(rawequal(deck.peek(),cards[1]));
local iter,list,index=deck.eachCard();deck.reverse();
check(rawequal(select(2,iter(list,index)),cards[1]),"iteration snapshots old order");
local n=0;for _,card in pairs(deck) do n=n+1;check(rawequal(card,deck.peek(n)));end
check(n==3);deck.reverse();
local native,old=Deck({cards[1],cards[2],cards[3]}),Reference({cards[1],cards[2],cards[3]});
local function compare(method,...)
    local a,b=table.pack(native[method](...)),table.pack(old[method](...));
    for i=1,a.n do if rawequal(a[i],native) then a[i]="self";end;end
    for i=1,b.n do if rawequal(b[i],old) then b[i]="self";end;end
    check(same(a,b),"archived return values: "..method);
    check(same(native.getCards(),old.getCards()),"archived order: "..method);
    check(#native==#old and native.isEmpty()==old.isEmpty(),"archived count: "..method);
end
for step=1,360 do
    local action=step%9;local card=cards[1+(step*7)%#cards];
    if action==0 then compare("addCard",card,step%2==0);
    elseif action==1 then compare("draw",1+step%15);
    elseif action==2 then compare("removeCard",card);
    elseif action==3 then compare("peek",1+step%15);
    elseif action==4 then compare("drawMany",step%5);
    elseif action==5 then compare("reverse");
    elseif action==6 then compare("shuffle",function(lo,hi) return lo+(step%hi);end);
    elseif action==7 then compare("containsCard",card);
    else compare("addCard",card);end
end
compare("clear");compare("draw");compare("drawMany",0);
local empty=Deck();check(empty.isEmpty() and empty.peek()==nil and empty.draw()==nil);
local drawn,ok=deck.drawMany(4);check(not ok and #drawn==0 and #deck==3,"draw-many failure is atomic");
drawn,ok=deck.drawMany(2);check(ok and rawequal(drawn[1],cards[1]) and rawequal(drawn[2],cards[2]) and #deck==1);
local _,added=deck.addCard(cards[3]);check(not added);
for _,bad in ipairs({false,1,"bad",Card(),{cards[1],cards[1]}, {[2]=cards[1]}, {cards[1],false}}) do
    reject(function() Deck(bad);end);
end
for _,bad in ipairs({false,"1",0,-1,0.5,math.huge,0/0}) do
    reject(function() deck.peek(bad);end);reject(function() deck.draw(bad);end);
end
for _,bad in ipairs({false,"1",-1,0.5,math.huge,0/0}) do reject(function() deck.drawMany(bad);end);end
reject(function() deck.addCard(cards[1],1);end,"Top flag");reject(function() deck.containsCard({});end,"BaseCard");
reject(function() return deck.cards;end,"private");
local shuffled=Deck(cards);local before=shuffled.getCards();
for _,random in ipairs({function() return 0;end,function() return 100;end,function() return 1.5;end,
    function() error("random failure");end}) do
    reject(function() shuffled.shuffle(random);end);
    check(same(shuffled.getCards(),before),"bad random source preserves order");
end
reject(function() shuffled.shuffle(false);end,"Random source");
local mutations={function() shuffled.draw();end,function() shuffled.drawMany(0);end,
    function() shuffled.addCard(Card());end,function() shuffled.removeCard(cards[1]);end,
    function() shuffled.reverse();end,function() shuffled.clear();end,function() shuffled.shuffle();end};
for _,mutate in ipairs(mutations) do
    reject(function() shuffled.shuffle(function() mutate();return 1;end);end,"shuffle callback");
    check(same(shuffled.getCards(),before),"reentry preserves order and unlocks");
end
check(rawequal(shuffled.shuffle(function(lo,hi) return hi;end),shuffled) and same(shuffled.getCards(),before));
local single=Deck({cards[1]});local calls=0;
single.shuffle(function() calls=calls+1;return 1;end);check(calls==0,"single-card shuffle never calls random source");
local copied=clone(shuffled);check(not rawequal(copied,shuffled) and #copied==#shuffled);
for i,card in copied.eachCard() do
    check(not rawequal(card,cards[i]) and card.getName()==cards[i].getName(),"deep clone retains order");
end
copied.peek().reveal();check(not shuffled.peek().isFaceUp(),"cloned cards are independent");
local LXC=require("LuaEx.lib.lxc");
LXC.loadSources({["DeckTest.lxc"]=[=[namespace DeckTest {
    class Child : CoG.BaseDeck {
        private extra=7;
        public Child(cards) { base(cards); }
        public getExtra() { return this.extra; }
    }
    class CardChild : CoG.BaseCard {
        public CardChild() { base("Child","Explicit copy required"); }
    }
    class Cloneable : CoG.BaseDeck {
        public Cloneable() { base(); }
        public override operator clone() { return Cloneable(); }
    }
}]=]},_G);
local child=DeckTest.Child({cards[1]});reject(function() clone(child);end,"subclasses must implement __clone");
check(class.isinstanceof(clone(DeckTest.Cloneable()),DeckTest.Cloneable));
local uncopyable=Deck({cards[1],DeckTest.CardChild()});reject(function() clone(uncopyable);end,"subclasses must implement __clone");
check(#uncopyable==2 and rawequal(uncopyable.peek(),cards[1]),"card clone failure preserves source deck");
local graph={deck=shuffled,alias=shuffled,card=cards[1],child=child};graph.self=graph;
local loaded=deserialize(serialize(graph));
check(rawequal(loaded.deck,loaded.alias) and rawequal(loaded.self,loaded),"graph aliases and cycles");
check(rawequal(loaded.card,loaded.deck.peek()) and rawequal(loaded.child.peek(),loaded.card),"shared cards preserve graph identity");
check(class.isinstanceof(loaded.child,DeckTest.Child) and loaded.child.getExtra()==7,"concrete subclass persistence");
loaded.deck.draw();check(#shuffled==12 and #loaded.deck==11,"restored deck storage is independent");
check(#deserialize(serialize(Deck()))==0,"empty deck persistence");
-- A save taken while the callback runs must restore without the temporary lock.
local during;
shuffled.shuffle(function(lo,hi) if not during then during=serialize(shuffled);end;return hi;end);
local unlocked=deserialize(during);check(unlocked.draw()~=nil and #unlocked==11,"transient shuffle lock is not persisted");
check(rawequal(clone(Deck),Deck) and rawequal(deserialize(serialize(Deck)),Deck),"canonical class references");
-- Forge simple native field projections to test the production snapshot validator.
local Serializer=require("LuaEx.lib.serializer");
local function forged(list,busy)
    local marker={};local adapter={project=function(value)
        if rawequal(value,marker) then
            return {Kind="instance",Class="CoG.BaseDeck",Fields={
                ["CoG.BaseDeck:cards"]={Index=1,Type="table",ClassType=false,Locked=false},
                ["CoG.BaseDeck:busy"]={Index=2,Type="boolean",ClassType=false,Locked=false},
            }},{list,busy};
        end
    end,checkFunction=function() end,checkGraph=function() end,
    allocate=function() error("No allocation while encoding");end,finish=function() error("No restore while encoding");end};
    return "--LXC:3\n"..Serializer.serializeStaged(marker,adapter);
end
reject(function() deserialize(forged({false},false));end,"BaseCard");
reject(function() deserialize(forged({[2]=false},false));end,"BaseCard");
local restoredEmpty=deserialize(forged({},true));check(restoredEmpty.isEmpty());
check(select(2,restoredEmpty.addCard(Card())),"restore clears the saved busy flag");
print("PASS BaseDeck: "..checks.." checks.");
