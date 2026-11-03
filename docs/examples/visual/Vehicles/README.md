# Vehicle garage

Open the repository's `docs/Examples.html`, choose **CoG → Vehicles**, and select
**Visual**. The **Code** tab runs an independent tutorial; edits and trips in
one tab do not alter the other tab's objects.

The three illustrated presets are Trailwarden (rover), Cloudrunner (airship)
and Stillwater (unmanned survey skiff). Select an illustration to inspect it.

## Things to explore

- Spend or add fuel, reserve tank capacity, and take a distance-based trip.
  Insufficient fuel rejects the trip before changing either fuel or distance.
- Install, remove, damage and repair real objects in every configured component
  slot. This framework configuration supplies `BODY`; the example does not
  invent additional slots. A component is a Pool whose value is its condition.
- Share the first other vehicle's component, damage it, then select that other
  vehicle to see shared object identity. Snapshot testing verifies that changing
  a returned binding table does not change the vehicle's actual bindings.
- Change name, description, rarity, value, efficiency, speed, all five flags,
  owner presence and event environment. Apply validates a replacement vehicle
  before publishing it. Fuel/component/owner references survive the replacement;
  tag membership and enabled status are copied. Inspection count starts fresh.
- Add/remove inherited tags and dispatch an inspection event. The concrete
  subclass installs one fresh hook per instance. A Pool supplies the minimal
  owner class instance for each preset; it represents crew identity, not fuel.
- Clone the selected concrete vehicle. Change its fuel and component condition,
  then compare with the original. Owners are shared; fuel, components and tags
  are copied. Trip and inspection counters start at zero. Up to twelve vehicle
  records are allowed before a reset is required.
- Try cloning the base class, invalid constructor values, an unknown component
  slot, a plain table component, and native serialization. Results appear in the
  status message and bounded operation journal.

Movement, units, trip counters, condition, images and concrete clone choices are
example policy. CoGVehicle supplies validated storage and inherited identity.
`Tradeable` covers selling. Flags do not automatically enforce game rules.

## Persistence and callback environments

Native snapshots restore the vehicle, its fuel/components and its inspection hook.
The callback is defined in Events.lua rather than as a compiled LXC closure;
compiled LXC code cannot be serialized as application callback data. The restored
callback targets the restored instance, and the tutorial verifies that the original
instance is unaffected.

Registered Eventrix environments do not rewrite a callback's lexical environment.
The inspector shows configured and observed environments separately. Copying
recreates the inspection hook; arbitrary user hooks and affix policy are outside
this example's copy contract.

## Sources and verification

- `browser.lua`: live Lua model and action dispatch.
- `Vehicle.lxc`: native concrete subclass and explicit copy policy.
- `Vehicle.lua` and `Events.lua`: environment registration and ordinary Lua callbacks.
- `../../cog/Vehicles.lua`: standalone tutorial.
- `../../code/cog/Vehicles.lua`: independent Code-tab copy of that tutorial.
- `../../api/workbench/vehicles-view.js` and `vehicles.css`: inspector UI.
- `../../resources/vehicles`: generated illustration assets and art prompts.

From the repository root:

```powershell
node docs/examples/api/workbench/verify-vehicles.cjs
.\examples\api\node\node.exe examples/api/workbench/bundle.cjs
```

The verifier runs real Wasmoon Lua sessions, exercises state transitions and
expected failures, and runs the independent tutorial. It updates only this
example's entry in `examples/verification.json`. The bundle command refreshes
the offline catalog and embedded files.
