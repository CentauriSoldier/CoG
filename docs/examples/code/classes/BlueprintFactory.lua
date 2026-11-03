-- Locate the shared bootstrap relative to this tutorial, regardless of cwd.
local pSource = debug.getinfo(1, "S").source:sub(2):gsub("\\", "/");
local pExamples = assert(pSource:match("^(.*)/code/[^/]+/[^/]+%.lua$"));
local tPaths = dofile(pExamples.."/support/bootstrap.lua");
local pDocs = tPaths.docs;

local D = require("examples.support.tutorial").new(
    "Blueprint repository",
    "Register a class, import definitions, and let the class construct objects."
);

D.section("Class registration", "Each participating CoG class declares its defaults, validator and factory.")
local Item = Examples.BlueprintItem;
local tContract = {
    Blueprint = {name="Unnamed item", weight=1},
    validateBlueprint = function(tBlueprint)
        return rawtype(tBlueprint.name)=="string" and tBlueprint.name:find("%S")~=nil and
            rawtype(tBlueprint.weight)=="number" and tBlueprint.weight>=0,
            "Name must be nonblank and weight nonnegative.";
    end,
    fromBlueprint = function(tBlueprint) return Item(tBlueprint.name, tBlueprint.weight); end,
};
assert(CoG.Factorium.registerClass(Item, tContract));

D.section("Your blueprint", "The mod supplies only the fields it wants to override.")
local name = ("Trail boots" --[[ Edit name here ]]);
local weight = (2 --[[ Edit weight here ]]);
local record = { id = "trail_boots", class = "Examples.BlueprintItem", name = name, weight = weight };
D.show("Blueprint record", record);

local bImported, tReport = CoG.Factorium.importMod({
    id = CoG.BaseMod.DEFAULT_MOD_ID,
    name = "Blueprint tutorial",
    authors = { "CoG" },
    description = "Two content definitions backed by one class.",
    released = "2026-10-13",
    updated = "2026-10-13",
    version = 1,
    blueprints = {
        record,
        { id = "light_pack", class = "Examples.BlueprintItem", name = "Light pack", weight = 0.5 },
    },
});
D.check("Mod imported", bImported);
D.equal("Blueprints accepted", tReport.loaded, 2);
CoG.Factorium.finalizeImports();

D.section("Build an instance", "Factorium supplies a copy; the class's factory creates the object.")
local boots = tContract.fromBlueprint(CoG.Factorium.getBlueprint(Item, record.id));
D.check("Instance created", boots ~= nil);
D.equal("Name", boots.getName(), name);
D.equal("Weight", boots.getWeight(), weight);

D.section("Multiple instances", "One stored definition can initialize independent objects.")
local second = tContract.fromBlueprint(CoG.Factorium.getBlueprint(Item, record.id));
D.check("Different object identities", boots ~= second);
D.equal("Same initial weight", second.getWeight(), weight);

D.section("Another record", "Queries return definitions for the exact class supplied by the caller.")
local pack = tContract.fromBlueprint(CoG.Factorium.getBlueprint(Item, "light_pack"));
D.equal("Second record name", pack.getName(), "Light pack");
D.check("Class catalog contains boots", CoG.Factorium.getBlueprints(Item).trail_boots ~= nil);

D.section("Unknown identifier", "Missing definitions return nil without constructing anything.")
D.equal("Missing result", CoG.Factorium.getBlueprint(Item, "missing"), nil);
D.finish();
