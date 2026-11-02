# CoG migration handoff — updated 2026-10-30

## Authoritative roots and rules

- C:/Users/james.jones/Sync/Projects/CoG
- C:/Users/james.jones/Sync/Projects/LuaEx
- C:/Users/james.jones/Sync/Projects/Dox

Ignore lxc-prototype completely. Ignore the deprecated Documents/GitHub/LuaEx
checkout and Downloads ZIP. LXC is embedded under LuaEx/lib/lxc; LXE is under
LuaEx/lib/lxe. Do not claim complete framework understanding without evidence.

Obtain explicit permission before edits and stay within approved file scope.
Use existing README conventions, readable whitespace, meaningful DOx and local
comments. Opening braces stay on declaration lines. Only nested local functions
get f prefixes. Class-field naming cleanup remains a separate unfinished
discussion: avoid changing general LuaEx conventions. Do not add compatibility
aliases or old snapshot behavior.

The user wants one class at a time. Archive completed original Lua sources under
legacy/<original path>, preserving contents and directory structure. Never
overwrite legacy archives. LuaEx discovers both enum and class sources; cog.load
handles configuration and aliases only. Put the CoG root on package.path before
initializing LuaEx. Classes live directly under CoG, without a Classes namespace.

## Current stopping point

### BaseMod continuation — 2026-10-30

- `cog/ModSystem/BaseMod.lxc` defines `CoG.BaseMod`, discovered by LuaEx. The
  protected constructor, permanent DEFAULT_MOD_ID, MAX_VERSION, metadata validator,
  final public getters and protected scalar names are retained. No loader changes,
  global BaseMod or require alias were introduced.
- The nullable read-only mapping is intentional: final protected properties hold
  private backing records, expose scalar values, and lock the value on its first
  non-null assignment. Invalid metadata still logs without throwing and leaves
  null defaults. Subclasses retain direct protected reads and first assignment
  of an unset value. Do not replace this with non-null scalar finals, remove
  protected access, or change the LXC runtime to accommodate it.
- Metadata helper bodies were migrated from the archived source. UUID lists are
  copied, normalized and deduplicated; authors preserve order; getInfo returns
  copied metadata lists and the original raw blueprint reference. No validity or
  lifecycle state was added; Factorium retains ownership of those decisions.
- Logging callbacks work without utility-class initialization. Logger objects use
  the existing BaseLog warning level when utility classes are present; the default
  BaseLog is created lazily. Errors remain contained and warnings remain available.
- The original is archived unchanged at `legacy/cog/ModSystem/BaseMod.lua`.
  Backups of the original and the then-current README/HANDOFF are under
  `legacy/base-mod-migration-20261030-185458/`. Do not overwrite these archives.
- `tests/basemod_regression.lua` has defaults and logging modes. It tests archived
  validator parity, protected construction/access, read-only fields including null
  defaults, callbacks/objects/lazy logging, and native clone/save/load.
- Factorium remains legacy and separate work. Its use of global BaseMod and old
  class helpers must be addressed in its own migration, without adding an alias
  here. Existing legacy LuaEx BaseMod/Factorium tests are not native migration tests.
- The existing CoGBase overlay test still expects StatusTracker declarations in
  config. The user moved on without authorizing an edit to that separate test;
  it remains unchanged. Do not report that overlay mode as passing.

### StatusTracker continuation — 2026-10-30

- `cog/enums/EFFECT.lxe` supplies `CoG.EFFECT` marked `---@default`. All 64 names
  from the former config examples are active, in their original order. The user
  explicitly chose to retain EFFECT; do not rename it.
- `cog/StatusTracker.lxc` is a native class discovered and loaded by LuaEx.
  Use `CoG.StatusTracker(CoG.EFFECT)` or an embedded category of that selected
  enum. An application replaces the entire default enum with one ordinary
  declaration of the same FQN in the complete loading batch.
- The user explicitly rejected adding a loader entry or alias. `cog/load.lua`
  is unchanged. No global StatusTracker or require alias was introduced.
- The old factory is archived unchanged at `legacy/cog/StatusTracker.lua`;
  the active Lua source is removed after verification. Other originals were
  backed up under `legacy/status-tracker-migration-20261030-150056/`.
- Timer/activation/expiration/chaining behavior is preserved. Native cloning,
  graph serialization and snapshot validation replace the factory's custom
  snapshot mechanism. Do not restore legacy factory/snapshot compatibility.
- `cog/config.lua` rejects StatusTracker declaration overlays; the empty bundled
  config section remains. Configuration no longer constructs enum identities.
- `tests/statustracker_regression.lua` runs in defaults and override modes.
  It covers actual discovery without aliases, archived timer behavior, input
  validation, private state, snapshot iteration, native clone/save/load, shared
  graphs and nested application-defined scopes. Results are recorded below.
- Legacy CoGCreature remains separate work; its old StatusTracker short-name
  construction must be addressed during that module's migration, not by adding
  an alias here. Other loader entries have not been enabled by this work.

The enabled CoG classes have been migrated from legacy enum construction to LXE:

- cog/enums/TIER.lxe: public CoG.TIER, I through XX.
- cog/config/TIER.lua: ordinary config module returning that canonical enum.
  Original factory source was copied unchanged to legacy/cog/config/TIER.lua.
- Pool.lxc: inline public ASPECT, MODIFIER and EVENT, with preserved payloads.
  ON_RESERVE intentionally retains the established "OnReserve" storage key.
- AffixSystem.lxc: inline public TYPE (PREFIX/SUFFIX).
  Entries.lua uses cSystem.TYPE, canonical TIER membership and Ordinal. Old
  private-enum identity rebinding was removed. Operations.lua uses canonical
  rarity/tier membership; the highest-level special naming behavior uses VI
  identity rather than the old SINGULAR member name.
- Rarity.lxc: inline public LEVEL (I through VI), with getName(level).
  config/Rarity.lua uses NAME for display labels; colors, chance thresholds and
  affix limits remain settings. Default labels remain COMMON through SINGULAR.
- CoGVehicle.lxc: inline public COMPONENT, currently BODY. The old config-driven
  component builder was removed.
- CoGObject.lxc, cog/load.lua and affected tests use LXE membership/metadata.

Metadata is Value, Ordinal, Name and Parent. Avoid blanket replacement of .id,
.name or .values: many are ordinary affix IDs and data fields, not enum metadata.

Enum member names come from declaration sources, not late configuration.
cog/config.lua rejects old Rarity.LEVEL and CoGVehicle.COMPONENT declaration
overlays. TIER is the fixed canonical CoG.TIER reference. To change declarations,
edit sources before initialization. No late attachment to initialized classes.

cog/load.lua explicitly initializes rarity settings through getName(I) and affix
persistence services through MAX_TIER. Do not remove those calls: inline TYPE
and LEVEL no longer have getters whose side effects initialized those services.
Pool reservation settings still validate eagerly in the loader.

CoGStructure's original .lua has now been archived if its archive was absent;
the tested native .lxc remains active.

## What to do next

Continue the unfinished CoG modules in dependency order, one class at a time.
Do not enable all commented loader entries. Specifically:

1. StatusTracker is complete as described above. Continue with another module
   only when authorized; do not add a StatusTracker loader entry or alias.
2. AStar.lua contains an old commented enum sketch and is disabled/unconverted.
   Do not treat the commented sketch as a completed declaration specification.
3. Other disabled loaders/classes remain pending. Dox has not been migrated.
4. LuaEx now implements `@type` completion checks and `@default` declaration
   selection. Pulsar source and installed package passed their backend tests;
   live editor rendering remains unverified.
5. Previously requested class-field prefix/case cleanup is still pending; do not
   indiscriminately rename ordinary Lua local variables or data-record keys.

## LuaEx/LXE contract and documents

Enums initialize first, classes initialize afterward. Class-owned enums must
already exist when their owner initializes; class and enum declarations are
preflighted together. within explicitly identifies ownership, in .lxe and inline
.lxc forms. Extensions may use another file in the same loading batch and may
occur before/after their targets; they do not inherit across enum nesting.

Canonical enum types participate in LXC's existing field-type checks.
An initially null field can receive an existing enum later under normal typing
rules. This does not permit late declarations or unrestricted return to null.

Host-bound static save/load now uses the existing serializer bridge, preserving
canonical identities, private/protected access and atomic assignment planning.
Standalone LXC retains its restricted codec. No native enum dependencies or
thread proxies. Shared directives now follow the completion-only validation budget.

Current documents:
- LuaEx/docs/lxc/DESIGN.md, KEYWORDS.md, RULES.md (created for embedded LXC;
  do not edit ignored prototype docs as if they were current).
- LuaEx/docs/lxe/DESIGN.md, KEYWORDS.md, RULES.md.
- LuaEx/docs/directives.md (implemented directives and verification limits).
- LuaEx/docs/HANDOFF.md points here.

## Verification

Current BaseMod verification (2026-10-30), using the native Windows Lua 5.4
executable:

- Defaults: 167 checks at CoG's normal load level; logging: 172 checks with
  utility classes. The actual BaseLog append path is exercised through an
  in-memory file adapter, without writing a test log into the project.
- Tests compare metadata normalization and invalid-input reasons against the
  exact archived validator. They cover protected construction, scalar access,
  final getters, null/late-initialized read-only fields, immutable constants,
  independent lists, raw blueprint references, logger failures and native graphs.
- StatusTracker defaults/override: 2,251 / 82; Pool 1,674; Rarity defaults 585;
  objects/affixes 87; registry 82 pass after BaseMod migration.
- Native compilation of all collected CoG/framework LXC/LXE declarations passes.
- The original archive matches its pre-migration backup exactly. The loader hash
  is unchanged. Factorium integration and legacy factory tests are not claimed
  as passing; that class remains a separate migration.

Current StatusTracker verification (2026-10-30), using the native Windows Lua 5.4
executable:

- Defaults: 2,251 checks, including 200 operation sequences compared against the
  unchanged archived timer implementation, private access, invalid arguments,
  snapshot iteration, graph aliases/cycles and malformed native snapshot rejection.
- Application override: 82 checks with nested category declarations replacing
  the default CoG.EFFECT in a coordinated in-memory batch.
- Real discovery works before cog.load; no short global or require alias is added.
- Native Pulsar backend compilation of all collected CoG/framework LXC/LXE sources
  passes without executing application bodies.
- Pool 1,674; Rarity defaults 585; objects/affixes 87; registry 82; ability 48;
  vehicle defaults 70; structure 36 pass after adding the native class.
- Live application UI and the complete repository-wide suite were not tested.

The older records below describe the earlier enum migration, not the current
StatusTracker run or current Pulsar package state.

Passing after enum migration:
- Pool: 1,674 checks against archived behavior.
- Rarity defaults: 585; overlay/equal-chances: 586 each; six invalid modes: 4 each.
  The updated test uses an independent threshold model instead of a legacy enum
  factory baseline. The old source archives remain unchanged.
- CoGBase defaults 53; RNG 520; objects/affixes 87; ability 48; vehicle defaults 70;
  structure 36. Vehicle overlay mode now verifies rejection of late declarations.
- LuaEx LXE regression: 112 checks, rerun after CoG integration.
- Native Pulsar worker: standalone LXE, inline enum, missing dependency,
  extension collision and payload non-execution checks passed.
- Pulsar main/project/runner/highlight/test JavaScript syntax checks passed.

The full Pulsar Node subprocess suite could not start a usable Lua executable
in this sandbox (spawn/runtime environment issue). Do not claim it passed or
that a live Pulsar session was verified. Installed package, source and ZIP were
updated; reload Pulsar to activate. The installed installation.json now supplies
the authoritative LuaEx root and preserves other preferences.

Existing broader test-runner issues from before this migration: missing
prettylua_regression.lua and cog_serializer_contract.lua; legacy factory use in
class_scope_regression.lua; disabled/missing scaler for scaler_regression.lua.
Do not silently rewrite unrelated systems to make those tests green.

Tests are ordinary Lua 5.4 files in CoG/tests and LuaEx/tests/lxe. Native lua.exe
launching has failed on this machine; checks were run through the existing
wxLuma/Win/Bin/lua54.dll using an in-memory C# P/Invoke test host. No native
production dependency was added. Other hosts remain unverified.

## Pulsar package

Source: LuaEx/tools/pulsar/linter-lxc (version 0.2.0)
ZIP: LuaEx/tools/pulsar/linter-lxc.zip
Installed: C:/Users/james.jones/.pulsar/packages/linter-lxc

The worker now reads LuaEx/lib/lxc modules, with LXE parsing/validation support.
It never initializes applications, evaluates enum payloads or invokes extensions.
.lxe uses source.lxe. enum, extension, within and enum metadata are highlighted.
Project collection includes .lxe/.lxc, ignores legacy and lxc-prototype.
Hover type inference, signature help and directives were not added.
