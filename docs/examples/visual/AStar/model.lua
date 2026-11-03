-- Locate CoG and sibling LuaEx before loading the shared navigation model.
local pSource = debug.getinfo(1, "S").source:sub(2):gsub("\\", "/");
local pExamples = assert(pSource:match("^(.*)/visual/AStar/model%.lua$"));
dofile(pExamples.."/support/bootstrap.lua");
return require("examples.visual.AStar.fantasy");
