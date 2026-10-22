-- bridges/hud.lua
-- Hides the player HUD while a dialogue is open, and restores it on close.
-- Targets: auto | standalone | custom     -- set with Config.Hud in config/config.lua

local HUD = Config.Hud

if HUD == 'auto' then
    HUD = 'standalone'
end

---Hide the HUD when a dialogue opens.
local function hideStandalone()
    DisplayRadar(false)
    DisplayHud(false)
end

---Restore the HUD when the dialogue closes.
local function showStandalone()
    DisplayRadar(true)
    DisplayHud(true)
end

---@param visible boolean true when the dialogue closes, false when it opens
function SetHudVisible(visible)
    if HUD == 'standalone' then
        if visible then showStandalone() else hideStandalone() end

    elseif HUD == 'custom' then
        -- ▼▼▼ EDIT THIS BRANCH WITH YOUR OWN HUD ▼▼▼
        -- Call your own HUD resource here. Example:
        -- TriggerEvent('myhud:toggle', visible)
        if visible then showStandalone() else hideStandalone() end
        -- ▲▲▲ EDIT THIS BRANCH WITH YOUR OWN HUD ▲▲▲
    end
end
