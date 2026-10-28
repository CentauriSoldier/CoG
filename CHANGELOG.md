# CoG changelog

## [**v0.50**] (*in progress*)

### Added
- Standalone `cog.load` initializer with separate loading after LuaEx.
- Versioned documentation introduction and generated HTML API reference for GitHub Pages.
- A repository overview with gameplay examples and a dark pixel-art banner.
- Scaler move and resize Start/End callbacks with final getters and setters; passing nil to a setter restores its no-op callback.
- Optional host-provided scaler debounce through CoG configuration, with per-instance overrides, independent move/resize timers, and pending-callback cancellation. Debounce is disabled by default.
- Scaler callback event snapshots containing input/output geometry, screen dimensions, and viewport information.
- Scaler debounce usage examples and regression coverage for bundled defaults and global configuration overrides.

### Changed
- Configuration is assembled and locked before the CoG class is declared, then exposed as public static `CoG.config`.
- `require("cog.config")` returns the same read-only configuration table.
- CoG module imports use the standalone `cog.*` namespace.
- Initialization requires `LUAEX_INIT == true`; LuaEx remains a dependency.
- **Pool** documentation identified the class as version **2.1**.
- Scaler adjustment methods invoke the corresponding Start/End callbacks while returning calculated geometry immediately.
- Replaced scaler `getViewport()` with `getViewportDimensions()`, `getViewportSize()`, and `getViewportPosition()`.
- Removed the old combined `onResize()` and `setOnResizeCallback()` APIs in favor of separate resize Start/End callbacks.

### Fixed
- Internal AStar documentation links now use `CoG.*` FQXNs without the former LuaEx ownership prefix.
- Scaler `getScreenSize()` returns screen dimensions rather than fitted viewport dimensions.

---

## [**v0.40**]

### Added
- Interactive examples for AStar, cards, inventory, Pool, Tiled, and vehicles.
- Regression tests and supporting verification scripts for game-system examples.

### Changed
- Added documentation and example resources for inventory, cards, Tiled, and related systems.

### Removed
- Bundled **CoG** implementation and configuration modules from the current framework tree; earlier changelog entries are retained as historical records.

---

## [**v0.30**]

### Added
- Expanded AStar map origins/stagger configuration, port connections, rover movement-point pools, and layer/map movement APIs.
- **Pool.withDeferredEvents**, value adjustment, and configurable high/low thresholds.
- Per-module COG configuration files, including application, AStar, Pool, Rarity, StatusSystem, and object/mod/vehicle settings.

### Changed
- Reworked **AStar** map/layer/node/rover behavior, aspect lookup, passability, ownership, movement costs, and committed-move callbacks.
- Reworked **Pool** capacity, reservations, modifiers, regeneration, threshold status, event ordering, arithmetic, and independent cloning.
- Updated **RNG** to use the shared random stream with caller-controlled seeding, explicit argument validation, and nil-only defaults.
- Moved rarity settings into dedicated configuration and validated rarity/affix limits.
- Reworked **TagSystem** around unique normalized tags, alphabetical iteration, enabled-state preservation, and independent restoration.
- Reworked **Targetor** category/group management, wildcard matching, immunity/interdictor precedence, validated batch updates, and independent clone/serialization state.
- Reworked **XPSystem** cumulative level thresholds, progression curves, remaining-XP queries, explicit refresh, and modifier-aware level assignment.
- Updated COG date/version helpers.

### Fixed
- COG numeric validation and state handling across Pool, RNG, and XPSystem.
- AStar case-insensitive aspect/type lookup and movement state/callback consistency.
- TagSystem normalization and saved enabled-state handling; Targetor validation before category mutations.

---

## [**v0.20**]

### Fixed
- **CoG** not allowing recursive access to *config* table.

---

## [**v0.10**]

### Added
- Created **CoG** (*Code of Gaming*) framework by combining several, once-disparate modules.
