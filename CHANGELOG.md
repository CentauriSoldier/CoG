# CoG changelog

## v2.1

### Added
- Standalone `cog.load` initializer with separate loading after LuaEx.
- Versioned documentation introduction and generated HTML API reference for GitHub Pages.
- A repository overview with gameplay examples and a dark pixel-art banner.

### Changed
- Configuration is assembled and locked before the CoG class is declared, then exposed as public static `CoG.config`.
- `require("cog.config")` returns the same read-only configuration table.
- CoG module imports use the standalone `cog.*` namespace.
- Initialization requires `LUAEX_INIT == true`; LuaEx remains a dependency.

### Fixed
- Internal AStar documentation links now use `CoG.*` FQXNs without the former LuaEx ownership prefix.
