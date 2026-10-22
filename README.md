# Avenida — Interact

3D interaction points for FiveM. Register a ped, a world coordinate or any existing entity, and get a
clean in-world prompt with a hold-to-interact key, multi-choice menus and a full dialogue system.
The prompt is rendered as a DUI sprite in the world — no fullscreen NUI, no focus stealing.

## Features

- **Peds** — spawn an NPC by distance with its animation, blip and interaction, all from one table
- **Entities** — attach an interaction to every prop of a given model (ATMs, doors, machines…)
- **Positions** — attach an interaction to a world coordinate
- **Dynamic points** — create and remove an interaction at runtime (`interactCreate` / `interactRemove`)
- **Multi-choice** — several keys on one point, each with its own label, color and condition
- **Dialogues** — branching NPC dialogue with camera focus, voice lines and per-answer callbacks
- **24 built-in icons** — pin, car, bank, house, work, phone, storage, combat, gym, talk…
- **Resolution aware** — the sprite keeps its proportions on 16:9, ultrawide and 4K
- **Self-cleaning** — points, peds, blips and DUIs of a resource are dropped when it stops or restarts

## Requirements

**None.** No framework, no ox_lib, no dependency at all. DUI handling, proximity points and wait
helpers are implemented natively in `bridges/compat.lua`.

If you would rather have ox_lib do that work, set `Config.UseOxLib = true` and uncomment the
`'@ox_lib/init.lua'` line in `fxmanifest.lua`.

The resource is framework agnostic: it draws the prompt and calls your callback, whatever runs
behind it.

## Installation

1. Drop the folder into your `resources/` directory.
2. Add `ensure avenida_interact` to your `server.cfg`.
3. Tune `config/config.lua` if you want other defaults.
4. Restart the server.

## Usage

### A ped with a dialogue

```lua
exports["avenida_interact"]:pedRegister({
    coords      = vector4(-1393.81, -1064.09, 3.17, 266.09),
    model       = "a_f_y_vinewood_04",
    message     = "Talk with Maria",
    hintIcon    = "talk",
    canInteract = 3.0,
    dialogue    = { name = "Maria", ... },
})
```

### Every ATM in the map

```lua
exports["avenida_interact"]:entityRegisterByHash("prop_atm_01", {
    canInteract = 1.2,
    hintIcon    = "bank",
    offsetZ     = 1.0,
    choices = {
        { bind = "E", message = "Use the ATM", onInteract = function() ... end },
        { bind = "G", message = "Rob the ATM", hintColor = "red",
          condition = function() return HasDrill() end,
          onInteract = function(entity) ... end },
    },
})
```

### A world position

```lua
exports["avenida_interact"]:positionRegister({
    coords      = vector3(112.58, -1287.04, 29.26),
    canInteract = 1.5,
    message     = "Dance",
    onInteract  = function() ... end,
})
```

Working examples ship in `config/peds/`, `config/entities/` and `config/positions/` — delete them
once you have your own.

## Exports

| Export | Purpose |
|---|---|
| `pedRegister(spec)` | Register a ped, returns its index |
| `pedRemove(idx)` | Despawn a ped and drop its registration |
| `positionRegister(spec)` | Register an interaction on a coordinate |
| `entityRegister(entity, cfg)` | Register an interaction on one entity handle |
| `entityRegisterByHash(model, cfg)` | Register on every entity of a model |
| `entityRemove(idx)` | Drop an entity registration |
| `interactCreate(spec)` | Create a runtime point, returns its index |
| `interactRemove(idx)` | Remove a runtime point |
| `unlockLastInteract()` | Re-arm the last used point (end of an action) |
| `IsDuiVisible()` | Whether a prompt is currently shown |

## Icons

Set with `hintIcon` on any point. Available values:

`pin` `car` `camion` `moto` `velo` `bateau` `avion` `cloak` `bank` `house` `work` `phone` `cart`
`combat` `gym` `game` `hunting` `peche` `storage` `duty` `talk` `search` `interact` `teleport`

Any unknown value is drawn as text, so you can pass an emoji directly.

## Configuration

`config/config.lua` — escrow exempt, edit freely:

| Option | Purpose |
|---|---|
| `Config.Debug` | Print internal errors to the client console |
| `Config.UseOxLib` | Use ox_lib instead of the native implementation (off by default) |
| `Config.Hud` | Which HUD to hide during a dialogue — see `bridges/hud.lua` |
| `Config.Defaults` | Default label, key, distances, icon, color of a point |
| `Config.HoldRange` | Fallback interaction range |
| `Config.Colors` | Named colors usable in place of a hex value |
| `Config.PedDefaults` | Model and animation used when a ped entry omits them |
| `Config.PedSpawnRange` | Distance at which peds spawn and despawn |
| `Config.Keys` | Bind label to control index mapping |

## Bridges

| File | API | Targets |
|---|---|---|
| `bridges/compat.lua` | `Compat.Dui`, `Compat.Point`, `Compat.WaitFor`, `Compat.Ped` | native, ox_lib |
| `bridges/hud.lua` | `SetHudVisible(visible)` | `auto`, `standalone`, `custom` |

`standalone` uses the native `DisplayHud` / `DisplayRadar`. Set `Config.Hud = 'custom'` and edit the
`custom` branch to call your own HUD resource instead.

## Escrow

Cfx escrow protected. These files stay readable and editable:

- `config/*.lua` and `config/**/*.lua`
- `bridges/*.lua`
- `README.md`, `CHANGELOG.md`

## Support

Avenida Scripts — see the Tebex product page for support.
