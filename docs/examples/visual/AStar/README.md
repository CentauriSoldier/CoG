# AStar laboratory

Open CoG's docs/Examples.html and select AStar. The browser frontend runs the real
CoG.AStar model: paint terrain, build parties, compare passage/cost rules, preview
routes, move by steps or turns, and save/restore the map in page memory.
Pool, TagSystem, RNG and navigation belong to CoG; Potentiometer, Protean, enums
and serialization come from LuaEx. Planning does not spend movement points.

The browser model and its startup are covered by api/workbench/verify.cjs.
Tiled's additional route/cave/editing checks are in verify-tiled-visual.cjs.

The retained main.lua/pixel_font.lua frontend is an optional Budo experiment.
It is not needed by Examples.html. Budo is not bundled or validated here.
To try it, supply a Budo executable explicitly:

```powershell
powershell -File docs/examples/visual/AStar/run.ps1 -BudoPath C:/path/to/budo.exe
```

Its rendering checks under check/ likewise require Budo. Browser map saves remain
in memory; the optional native frontend uses its saved folder.
