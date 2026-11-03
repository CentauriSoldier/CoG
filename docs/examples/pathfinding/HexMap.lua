-- Locate the shared bootstrap relative to this tutorial, regardless of cwd.
local pSource = debug.getinfo(1, "S").source:sub(2):gsub("\\", "/");
local pExamples = assert(pSource:match("^(.*)/[^/]+/[^/]+%.lua$"));
local tPaths = dofile(pExamples.."/support/bootstrap.lua");
local pDocs = tPaths.docs;

local D=require("examples.support.tutorial").new("Hex maps","Compare flat and pointed hex geometry, inspect neighbors, plan routes and execute movement.")

D.section("Your dimensions", "Grid coordinates are integer cells; choose width and height independently.")
local width=D.input("width",6);local height=D.input("height",5)
D.section("Two orientations", "Flat and pointed hex layouts use different stagger axes.")
for _,config in ipairs({{"flat",ASTAR_MAP_TYPE_HEX_FLAT,"x"},{"pointed",ASTAR_MAP_TYPE_HEX_POINTED,"y"}}) do
 local map=CoG.AStar().newMap(config[1],config[2],{CoG.AStar.LayerConfig("ground")},width,height,{staggerAxis=config[3],staggerIndex="odd"})
 local start=map.getNode("ground",1,1);local goal=map.getNode("ground",width,height)
 D.section(config[1].." neighbors", "Physical neighbors reflect map boundaries and hex orientation.")
 local center=map.getNode("ground",2,2)
 D.show("Interior physical neighbor count",#center.getNeighbors(true))
 D.show("Corner physical neighbor count",#start.getNeighbors(true))
 local rover=start.createRover();rover.getMovePointPool().set(2000,Pool.ASPECT.MAX);rover.getMovePointPool().setFull()
 D.section(config[1].." route", "Planning returns a sequence without spending movement points.")
 local before=rover.getMovePoints();local route=CoG.AStar.Path(start,goal,rover)
 D.check("Route exists",route.hasPath());D.equal("Preview does not spend",rover.getMovePoints(),before)
 D.show("Node count",route.getNodeCount());D.show("Total cost",route.getCost(rover))
 for i,node in ipairs(route.getNodes()) do D.show("Route cell "..i,{x=node.getX(),y=node.getY()}) end
 D.section(config[1].." execution", "Each successful step moves the owner and charges its budget.")
 local steps=0;while route.getNextNode() do D.check("Move committed",route.step());steps=steps+1;assert(steps<=width*height+1) end
 D.check("Arrived at goal",rover.getOwner()==goal)
 D.equal("Executed moves",steps,route.getNodeCount()-1)
 D.section(config[1].." same node", "A route from a node to itself requires no movement.")
 local same=CoG.AStar.Path(goal,goal,rover);D.check("Same node route exists",same.hasPath())
 D.equal("Same node cost",same.getCost(rover),0)
end

D.finish()
