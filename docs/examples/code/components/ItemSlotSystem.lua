-- Locate the shared bootstrap relative to this tutorial, regardless of cwd.
local pSource = debug.getinfo(1, "S").source:sub(2):gsub("\\", "/");
local pExamples = assert(pSource:match("^(.*)/code/[^/]+/[^/]+%.lua$"));
local tPaths = dofile(pExamples.."/support/bootstrap.lua");
local pDocs = tPaths.docs;

local D = require("examples.support.tutorial").new("Complete item containers", "Individual items, stacks, stash-wide exclusivity, transfers, equipment permissions and coordinate footprints.");

-- Edit these values, then Run code.
local nStackCapacity = 3;
local nStashTabs = 2;
local nItemsPerTab = 4;

local tItemEnvironment = setmetatable({}, {__index=_G});
lxc.loadSources({["ContainerExampleItem.lxc"] = [[
namespace Examples {
    class ContainerExampleItem : CoG.CoGItem {
        public ContainerExampleItem(sName, tOptions) {
            base(sName, "A separate item instance", nil, nil,
              nil,(tOptions or {}).consume,nil,nil,(tOptions or {}).equip,(tOptions or {}).scope,(tOptions or {}).conflicts,nil,nil,nil,
              (tOptions or {}).storage or ClassRegistry({CoG.ItemSystem, CoG.ItemStashSystem}),(tOptions or {}).tradeBy,(tOptions or {}).tradeTo,(tOptions or {}).unequip,nil,nil,
              nil,nil,nil,nil,nil,nil,(tOptions or {}).pattern);
        }
    }
}
]]}, tItemEnvironment);
local ExampleItem = tItemEnvironment.Examples.ContainerExampleItem;

D.section("Individual instances in one stack", "The slot owns capacity; items remain separate objects. Removing one preserves the others.");
local stack = CoG.ItemSlot(nil, nStackCapacity);
local apple = ExampleItem("Apple");
local pear = ExampleItem("Pear");
D.check("Insert apple", select(2, stack.set(apple)));
D.check("Insert pear", select(2, stack.set(pear)));
D.equal("Actual instance count", stack.getItemCount(), 2);
D.check("Duplicate instance rejected", not select(2, stack.set(apple)));
D.check("Location points to the actual slot", rawequal(apple.getLocation(), stack));
D.check("Remove apple", select(2, stack.remove(apple)));
D.equal("Remaining count", #stack, 1);
D.check("Removed location becomes null", apple.getLocation() == null);

D.section("Eligibility and state", "Registries can permit exact instances, classes and prerequisite callbacks. Locked or disabled slots reject changes.");
local specific = CoG.ItemSlot(CoG.CoGRegistry({apple}));
D.check("Exact apple accepted", select(2, specific.set(apple)));
D.check("Another instance rejected", not specific.canAccept(ExampleItem("Other apple")));
specific.setLocked(true);
D.check("Locked removal rejected", not select(2, specific.remove()));
specific.setLocked(false).setEnabled(false);
D.check("Disabled removal rejected", not select(2, specific.remove()));
specific.setEnabled(true);
D.check("Enabled removal succeeds", select(2, specific.remove()));

D.section("One kite across the entire stash", "Exclusive_In selects a context; Exclusive_With selects conflicting items. Direct tab insertion still checks every stash tab.");
local stash = CoG.ItemStashSystem(nil, nStashTabs, nItemsPerTab);
local kite = ExampleItem("Unique kite", {scope = ClassRegistry({stash}), conflicts = ClassRegistry({ExampleItem})});
local secondKite = ExampleItem("Second kite");
D.check("First kite stored", select(2, stash.addItem(kite, 1)));
local targetTab = math.min(2, nStashTabs);
local _, accepted, _, reason = stash.getTab(targetTab).addItem(secondKite);
D.check("Conflicting item rejected in another tab", not accepted);
D.note("Rejection reason: "..tostring(reason));
D.equal("Stash count stays one", stash.getItemCount(), 1);
D.check("Rejected item stays detached", secondKite.getLocation() == null);

D.section("Transfers commit or leave everything intact", "Transfers validate the final layout. Moving within the same stash does not conflict with the item's old position.");
if nStashTabs > 1 then
    D.check("Move kite between tabs", select(2, stash.getTab(1).transferItemTo(stash.getTab(2), kite)));
end
local limited = CoG.ItemSystem(1);
D.check("Fill a one-item inventory", select(2, limited.addItem(ExampleItem("Resident"))));
local source = kite.getLocation();
D.check("Transfer to full inventory rejected", not select(2, source.transferItemTo(limited, kite)));
D.check("Failed transfer preserves original location", rawequal(kite.getLocation(), source));
D.check("Remove kite from stash", select(2, stash.removeItem(kite)));
D.check("Former conflict now allowed", select(2, stash.addItem(secondKite)));

D.section("Actor permissions and consuming one item", "Administrative containment calls manage contents. Named action methods also check the corresponding actor registry; the caller implements gameplay effects.");
local actor = ExampleItem("Adventurer");
local permitsActor = CoG.CoGRegistry({actor});
local potion = ExampleItem("Potion", {consume = permitsActor});
local inventory = CoG.ItemSystem(4);
D.check("Store potion", select(2, inventory.addItem(potion)));
D.check("Wrong actor cannot consume", not select(2, inventory.consumeItem(potion, ExampleItem("Stranger"))));
D.check("Permitted actor consumes the instance", select(2, inventory.consumeItem(potion, actor)));
D.equal("Inventory now empty", inventory.getItemCount(), 0);
local sword = ExampleItem("Sword", {equip = permitsActor, unequip = permitsActor});
local equipment = CoG.ItemSlotSystem({CoG.ItemSlot()});
D.check("Store sword", select(2, inventory.addItem(sword)));
D.check("Equip transfers from inventory", select(2, equipment.equipItem(sword, actor, 1)));
D.check("Unequip transfers back", select(2, equipment.unequipItem(sword, actor, inventory)));

D.section("Pure patterns and grid placement", "SlotPattern contains relative coordinates only. ItemSlotSystem checks bounds and footprint overlap; one shaped item is counted once.");
local gridSlots = {};
for i = 1, 9 do gridSlots[i] = CoG.ItemSlot(); end
local grid = CoG.ItemSlotSystem(gridSlots);
D.check("Configure 3 by 3 grid", select(2, grid.configureGrid(3, 3)));
local pattern = CoG.SlotPattern({{x = 0, y = 0}, {x = 0, y = 1}, {x = 1, y = 1}});
local shaped = ExampleItem("L-shaped item", {pattern = pattern});
D.equal("Pattern occupied coordinate count", pattern.getSlotCount(), 3);
D.check("Place at zero-based origin", select(2, grid.placeItem(shaped, 0, 0)));
D.equal("Actual item count", grid.getItemCount(), 1);
D.check("Offset cell refers to the same item", rawequal(grid.getOccupantAt(1, 1), shaped));
D.check("Overlapping placement rejected", not select(2, grid.placeItem(ExampleItem("Blocked"), 1, 1)));
D.check("Grid consistency", grid.validate());

D.section("Ground and shop inventories", "The same ItemSystem class can represent any inventory. Its owner is metadata; item legality and prices are application policy.");
local merchant = ExampleItem("Merchant");
local ground = CoG.ItemSystem(20);
local shop = CoG.ItemSystem(8, nil, merchant);
local goods = ExampleItem("Trade goods", {tradeBy = CoG.CoGRegistry({merchant}), tradeTo = CoG.CoGRegistry({actor})});
D.check("Place stock in the shop", select(2, shop.addItem(goods)));
D.check("Shop retains its owner", rawequal(shop.getOwner(), merchant));
D.check("Ground has no owner", ground.getOwner() == null);
D.check("Wrong trader is rejected without moving stock", not select(2, shop.tradeItemTo(inventory, goods, actor, actor)));
D.check("Merchant can trade to the allowed recipient", select(2, shop.tradeItemTo(inventory, goods, merchant, actor)));
D.check("Successful trade updates actual location", rawequal(goods.getLocation(), inventory));
D.check("Drop through an administrative transfer", select(2, inventory.transferItemTo(ground, goods)));
D.equal("Ground item count", ground.getItemCount(), 1);

D.section("Capacity, clearing and live edits", "Containers reject capacity reductions that would lose items. Registries and Pools remain mutable objects exposed through getters.");
D.check("Cannot shrink ground below its contents", not select(2, ground.setMaxItems(0)));
goods.getWeightPool().set(0.5);
D.equal("Editable item Pool", goods.getWeightPool().get(), 0.5);
local _, cleared, removed = ground.clear();
D.check("Clear succeeds", cleared);
D.equal("Clear returns exactly one removed instance", #removed, 1);
D.check("Cleared item becomes unplaced", goods.getLocation() == null);
D.note("Durability zero does not destroy an item. Prices, damage/repair effects and upgrade effects are caller policy. Concrete item subclasses define copying.");
D.section("Save, load and reconnect the owner", "Generated class snapshots keep contents and settings. Owners remain external, so the caller reconnects them after loading.");
local oSavedStash = CoG.ItemStashSystem(actor, 2, 4);
local oSavedItem = ExampleItem("Saved compass", {
    scope = ClassRegistry({oSavedStash}), conflicts = ClassRegistry({ExampleItem})
});
D.check("Put the compass in tab two", select(2, oSavedStash.getTab(2).addItem(oSavedItem)));
oSavedStash.setLocked(true);

-- Save the inventory graph, then change the original to make restoration visible.
local sInventorySave = serialize(oSavedStash);
oSavedStash.setLocked(false);
D.check("Remove the original compass after saving", select(2, oSavedStash.removeItem(oSavedItem)));
local oLoadedStash = deserialize(sInventorySave);
local oLoadedItem = oLoadedStash.getTab(2).getItemAt(1);
D.equal("Saved item count restored", oLoadedStash.getItemCount(), 1);
D.check("Saved lock restored", oLoadedStash.isLocked());
D.check("Loaded item is a new instance", not rawequal(oLoadedItem, oSavedItem));
D.check("Loaded location is the loaded tab", rawequal(oLoadedItem.getLocation(), oLoadedStash.getTab(2)));
D.check("Owner starts null", oLoadedStash.getOwner() == null);

-- Reconnect the external owner after loading; all tabs resolve it through the stash.
oLoadedStash.setOwner(actor);
D.check("Caller reconnects the owner", rawequal(oLoadedStash.getOwner(), actor));
D.check("Tab inherits the reconnected owner", rawequal(oLoadedStash.getTab(2).getOwner(), actor));
local bLoadedScope = false;

for _, vScope in oLoadedItem.getExclusiveInRegistry().eachEntry() do
    bLoadedScope = bLoadedScope or rawequal(vScope, oLoadedStash);
end

D.check("Specific registry entry targets the loaded stash", bLoadedScope);
oLoadedStash.setLocked(false);
D.check("Loaded exclusivity still spans tabs", not select(2, oLoadedStash.getTab(1).addItem(ExampleItem("Conflicting compass"))));
D.check("A loaded inventory can be saved again", #serialize(oLoadedStash) > 0);
D.note("The Visual tab also saves and restores the laboratory's inventories, actors, coins and edits for this session.");

D.finish();
