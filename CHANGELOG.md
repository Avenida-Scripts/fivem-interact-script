# Changelog

All notable changes to this resource are documented here.
This project follows [Semantic Versioning](https://semver.org/).

## [1.1.0] — 2026-08-18

### Changed
- **Reworked the interaction visuals.** The grey gradient panel is gone. The icon is now anchored on
  the world point and no longer moves between the hint state and the hold state; the label is
  revealed left to right out of the icon, with a plain white keycap and a tinted separator.
- Multi-choice prompts use a 2-column grid, so every message stays aligned whatever the key width is.
- Dialogue answer boxes double their height above 2560×1440, they were cramped on 4K screens.
- Runtime options moved out of the client code into `config/config.lua` — defaults, colors, hold
  range, ped model and spawn range, key mapping are all editable now.
- Named colors are in English (`red`, `blue`, `green`, plus `gold`, `purple`, `white`).

### Added
- **The resource no longer requires ox_lib.** `bridges/compat.lua` implements DUI creation,
  proximity points and wait helpers with plain natives, so avenida_interact now installs with zero
  dependency. Set `Config.UseOxLib = true` (and uncomment the manifest line) to go back to ox_lib.
- `pedRemove(idx)` export, to drop a temporary ped and its registration.
- `bridges/hud.lua` — controls which HUD is hidden during a dialogue.
- `Config.Debug` guard on internal error prints.

### Fixed
- **Prompt distortion on ultrawide and non-16:9 screens.** The DUI texture is now locked to 1920×1080
  and un-stretched at draw time against the real screen aspect. The icon also kept changing size with
  distance, it no longer does.
- **DUI leak and ghost prompts.** After a point was removed, a stale ox_lib tick could re-arm it up to
  300ms later, reviving an orphan hold instance with a dead callback and leaking a DUI.
- Calling a callback of a resource that just stopped or restarted no longer makes the engine log
  "Execution of function reference in script host failed" — the call is skipped instead.
- Callbacks are wrapped in `pcall`: a consumer error no longer breaks the interaction.
- Points of a resource are purged when that resource *starts* too, not only when it stops. No more
  restarting avenida_interact to make it forget a resource.
- `randomComponents` on a ped is now opt-out (`randomComponents = false`). Ped components are rolled
  client side, so a named vendor used to wear a different outfit for every player.
- Despawned entities are cleaned every 5s instead of 2s — same result, less work.

## [1.0.1]

### Added
- Multi-choice interactions on a single point.
- Dialogue system with camera focus and per-answer callbacks.

## [1.0.0]

- Initial release.
