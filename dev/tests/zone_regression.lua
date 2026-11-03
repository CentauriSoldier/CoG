--[[!
@fqxn CoG.Tests.Zone
@desc Exercises explicit membership, Eventrix ordering/errors, reentrancy, synchronized
    hierarchy, snapshots and native persistence. Writes no fixture or output files.
    Run from the CoG root: lua dev/tests/zone_regression.lua.
!]]
local pTests = assert(debug.getinfo(1, "S").source:match("^@(.+)[/\\][^/\\]+$"));
local pCoG = pTests.."/../..";
package.path = pCoG.."/?.lua;"..pCoG.."/../LuaEx/?.lua;"..package.path;
require("LuaEx.init");
require("cog.load")();

local Zone = CoG.CoGZone;
local nChecks = 0;

--[[!
@fqxn CoG.Tests.Zone.check
@desc Counts an assertion and reports the behavioral invariant it checks.
!]]
local function check(bCondition, sMessage)
    assert(bCondition, sMessage);
    nChecks = nChecks + 1;
end

--[[!
@fqxn CoG.Tests.Zone.reject
@desc Requires an invalid operation to raise an error.
!]]
local function reject(fAction, sMessage)
    check(not pcall(fAction), sMessage);
end

local oRegion = Zone("Region", "Membership tests");
local oRoom = Zone("Room", "Hierarchy tests");
local oOther = Zone("Other", "Independent zone");
local oNested = Zone("Nested", "Nested zone");
local oFirst = CoG.BaseCard("First", "Object member");
local oSecond = CoG.BaseCard("Second", "Object member");
local tEvents = {};

-- Hooks observe committed membership. Record only scalar data, not captured owning zones.
local function recordEnter(oZone, oMember)
    check(oZone.contains(oMember), "enter observes committed membership");
    tEvents[#tEvents + 1] = "enter:"..oMember.getName();
end
local function recordExit(oZone, oMember)
    check(not oZone.contains(oMember), "exit observes committed removal");
    tEvents[#tEvents + 1] = "exit:"..oMember.getName();
end

oRegion.addHook(Zone.EVENT.ENTER, recordEnter);
oRegion.addHook(Zone.EVENT.EXIT, recordExit);
check(class.isa(oRegion, CoG.CoGObject), "generic object foundation");
check(oRegion.getMemberCount() == 0 and type.isnull(oRegion.getParentZone()), "empty root defaults");
check(select(2, oRegion.addMember(oFirst)), "first insertion");
check(not select(2, oRegion.addMember(oFirst)), "duplicate insertion is inert");
check(#tEvents == 1, "duplicate emits no event");
check(select(2, oRegion.addMember(oSecond)), "second insertion");
check(oRegion.getMembers()[1] == oFirst and oRegion.getMembers()[2] == oSecond, "insertion order");
check(oRegion.getMemberCount() == 2, "member count");
oOther.addMember(oFirst);
check(oRegion.contains(oFirst) and oOther.contains(oFirst), "multiple-zone membership");
local tSnapshot = oRegion.getMembers();
tSnapshot[1] = nil;
check(oRegion.getMemberCount() == 2, "list copy protects membership");
local fIterator = oRegion.eachMember();
oRegion.removeMember(oFirst);
local nIndex, oSnapshotMember = fIterator();
check(nIndex == 1 and oSnapshotMember == oFirst, "iteration snapshot survives removal");
check(oOther.contains(oFirst), "removal affects only this zone");
check(not select(2, oRegion.removeMember(oFirst)), "absent removal is inert");
check(table.concat(tEvents, ",") == "enter:First,enter:Second,exit:First", "event order");
reject(function() oRegion.addMember(oRegion); end, "self membership");
reject(function() oRegion.addMember({}); end, "non-object membership");
check(not oRegion.contains({}), "arbitrary contains query");
reject(function() return oRegion.state; end, "private membership state");

-- Failed callback mutation is returned as a hook error, after the entry committed.
local function reenter(oZone, oMember)
    oZone.removeMember(oMember);
end
local function failHook()
    error("expected zone callback failure");
end
local nLaterCalls = 0;
local function laterHook()
    nLaterCalls = nLaterCalls + 1;
end
oRegion.addHook(Zone.EVENT.ENTER, reenter);
oRegion.addHook(Zone.EVENT.ENTER, failHook);
oRegion.addHook(Zone.EVENT.ENTER, laterHook);
local _, bAdded, tResults = oRegion.addMember(oFirst);
check(bAdded and oRegion.contains(oFirst), "callback errors do not undo entry");
check(type(tResults[2]) == "string" and tResults[2]:find("during notification", 1, true), "reentrant mutation is rejected");
check(type(tResults[3]) == "string" and tResults[3]:find("expected zone callback failure", 1, true), "callback failure reported");
check(nLaterCalls == 1, "later hooks still run");
oRegion.removeHook(Zone.EVENT.ENTER, reenter);
oRegion.removeHook(Zone.EVENT.ENTER, failHook);
oRegion.removeHook(Zone.EVENT.ENTER, laterHook);
check(select(2, oRegion.removeMember(oFirst)), "notification guard clears after failure");
reject(function() oRegion.addHook(CoG.EFFECT.CREATURE.HASTENED, laterHook); end, "foreign event type");

-- Zone hierarchy has one parent, independent of explicit memberships.
oRoom.setParentZone(oRegion);
oRoom.addChildZone(oNested);
check(rawequal(oRegion.getChildZones()[1], oRoom), "child-side parenting updates parent");
check(rawequal(oNested.getParentZone(), oRoom), "parent-side adoption updates child");
check(not oRegion.contains(oRoom) and not oRoom.contains(oSecond), "hierarchy does not imply membership");
oRegion.addChildZone(oRoom);
check(#oRegion.getChildZones() == 1, "repeated adoption has no duplicate");
reject(function() oRegion.setParentZone(oNested); end, "long ancestry cycle");
reject(function() oRoom.addChildZone(oRoom); end, "self parenting");
check(type.isnull(oRegion.getParentZone()) and rawequal(oRoom.getParentZone(), oRegion), "rejected cycle preserves links");
check(not select(2, oOther.removeChildZone(oRoom)), "unrelated detach is inert");
for n = 1, 16 do
    local oParent = n % 2 == 0 and oRegion or oOther;
    local oPrevious = n % 2 == 0 and oOther or oRegion;
    oParent.addChildZone(oRoom);
    check(rawequal(oRoom.getParentZone(), oParent), "reparented zone pointer");
    check(#oParent.getChildZones() == 1 and #oPrevious.getChildZones() == 0, "old/new child lists synchronized");
end
local tChildren = oRegion.getChildZones();
tChildren[1] = nil;
check(#oRegion.getChildZones() == 1, "child list is a snapshot");

-- Remove test harness hooks before save; remaining state exercises cyclic hierarchy
-- and object identities shared across multiple explicit membership lists.
oRegion.removeHook(Zone.EVENT.ENTER, recordEnter);
oRegion.removeHook(Zone.EVENT.EXIT, recordExit);
oRegion.addMember(oFirst);
local nEnterCount = 0;
local function persistentHook()
    nEnterCount = nEnterCount + 1;
end
oRegion.addHook(Zone.EVENT.ENTER, persistentHook);
local sSaved = serialize({region = oRegion, other = oOther, first = oFirst, room = oRoom});
local tLoaded = deserialize(sSaved);
check(nEnterCount == 0, "saving/restoring emits no events");
check(rawequal(tLoaded.region.getChildZones()[1], tLoaded.room), "restored child identity");
check(rawequal(tLoaded.room.getParentZone(), tLoaded.region), "restored parent identity");
check(rawequal(tLoaded.room.getChildZones()[1].getParentZone(), tLoaded.room), "restored grandchild");
check(tLoaded.region.contains(tLoaded.first) and tLoaded.other.contains(tLoaded.first), "shared restored member identity");
tLoaded.region.removeMember(tLoaded.first);
check(oRegion.contains(oFirst) and tLoaded.other.contains(tLoaded.first), "restored membership is independent");
check(select(2, tLoaded.region.addMember(CoG.BaseCard("Third", "Restored event"))), "restored zone accepts members");
check(nEnterCount == 0, "restored callback upvalues are independent");
check(select(2, tLoaded.region.removeChildZone(tLoaded.room)), "restored hierarchy can detach");
check(type.isnull(tLoaded.room.getParentZone()), "restored detach clears parent");
reject(function() clone(oRegion); end, "base copying requires a graph policy");
print("PASS CoGZone: "..nChecks.." checks; membership, notifications, hierarchy, reentrancy and persistence.");
