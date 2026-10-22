-- Runtime options for avenida_interact.
-- Exempt from escrow: everything a server owner may want to tune lives here.

Config = Config or {}

-- Prints internal errors (dead callbacks, DUI failures) to the client console.
Config.Debug = false

-- Route DUI, proximity points and wait helpers through ox_lib instead of the native
-- implementation in bridges/compat.lua. Leave false to run without any dependency.
-- If you set this to true, also uncomment '@ox_lib/init.lua' in fxmanifest.lua.
Config.UseOxLib = false

-- Which HUD system to hide while a dialogue is open.
-- 'auto' | 'standalone' | 'custom'   -- see bridges/hud.lua
Config.Hud = 'auto'

-- Defaults applied to every interaction point when the caller does not pass its own value.
Config.Defaults = {
    message     = "Press to interact",  -- label shown next to the key
    dialogueMsg = "Talk to %s",         -- label for a ped that opens a dialogue (%s = ped name)
    dialogueBack = "Go back",           -- answer that returns to the previous dialogue step
    key         = 38,                   -- control index, 38 = E
    showIcon    = 4.0,                  -- distance (m) at which the icon fades in
    canInteract = 1.5,                  -- distance (m) at which the label appears
    hintIcon    = "pin",
    hintColor   = "#feae00",
    offsetZ     = 2.0,                  -- height above the point where the sprite is drawn
}

-- Fallback range used when a point does not declare a numeric canInteract.
Config.HoldRange = 1.5

-- Named colors usable in place of a hex value, e.g. hintColor = "red".
-- Add your own entries freely.
Config.Colors = {
    red    = "#b82121",
    blue   = "#3b7ea2",
    green  = "#4e914e",
    gold   = "#feae00",
    purple = "#c084fc",
    white  = "#ffffff",
}

-- Ped spawned by pedRegister when the entry does not specify a model or an animation.
Config.PedDefaults = {
    model    = "mp_m_weapexp_01",
    animDict = "amb@world_human_stand_mobile@male@text@base",
    animName = "base",
    animFlag = 1,
}

-- Distance (m) at which registered peds spawn and despawn.
Config.PedSpawnRange = 50.0

-- Bind label -> control index. Extend if you need a key that is not listed.
Config.Keys = {
    ["E"] = 38,  ["Q"] = 44,  ["G"] = 47,  ["H"] = 74,
    ["F"] = 23,  ["R"] = 45,  ["X"] = 73,  ["C"] = 26,
    ["Z"] = 20,  ["T"] = 245, ["Y"] = 246, ["U"] = 303,
    ["B"] = 29,  ["N"] = 249, ["M"] = 244, ["L"] = 182,
    ["1"] = 157, ["2"] = 158, ["3"] = 160, ["4"] = 164,
    ["5"] = 165, ["6"] = 159, ["7"] = 161, ["8"] = 162,
    ["9"] = 163, ["0"] = 56,
    ["F1"] = 288, ["F2"] = 289, ["F3"] = 170, ["F5"] = 166,
}
