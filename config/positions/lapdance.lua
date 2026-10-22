local isDancing = false

local LapdanceAnims = {
    { dict = "mini@strip_club@lap_dance_2g@ld_2g_p3", name = "ld_2g_p3_s2" },
    { dict = "mini@strip_club@lap_dance_2g@ld_2g_p1", name = "ld_2g_p1_s2" },
    { dict = "mp_safehouse", name = "lap_dance_girl" },
    { dict = "oddjobs@assassinate@multi@yachttarget@lapdance", name = "yacht_ld_f" },
    { dict = "mp_am_stripper", name = "lap_dance_girl" },
    { dict = "mini@strip_club@lap_dance@ld_girl_a_song_a_p1", name = "ld_girl_a_song_a_p1_f" },
}

local PoleDanceAnim = { dict = "mini@strip_club@pole_dance@pole_dance1", name = "pd_dance_01" }

local LapdancePositions = {
    { pos = vector3(112.5841, -1287.0477, 29.2650), heading = 0.0, offset = vector3(0.015, 0.3, -0.8) }, -- Unicorn
}

local function StopDancing()
    if isDancing then
        local ped = PlayerPedId()
        ClearPedTasks(ped)
        if activeSyncScene then
            DeleteSynchronizedScene(activeSyncScene)
            activeSyncScene = nil
        end
        SetPedCanRagdoll(ped, true)
        isDancing = false
        exports["avenida_interact"]:unlockLastInteract()
    end
end

local function PlayLapdance()
    if isDancing then
        StopDancing()
        return
    end

    local anim = LapdanceAnims[math.random(#LapdanceAnims)]
    local ped = PlayerPedId()

    RequestAnimDict(anim.dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(anim.dict) do
        if GetGameTimer() > timeout then return end
        Wait(0)
    end

    isDancing = true
    TaskPlayAnim(ped, anim.dict, anim.name, 8.0, -8.0, -1, 1, 0.0, false, false, false)
end

local activeSyncScene = nil

local function PlayPoleDance(polePos, poleHeading, poleOffset)
    if isDancing then
        StopDancing()
        return
    end

    local ped = PlayerPedId()
    local anim = PoleDanceAnim

    RequestAnimDict(anim.dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(anim.dict) do
        if GetGameTimer() > timeout then return end
        Wait(0)
    end

    SetPedCanRagdoll(ped, false)

    -- Create a synchronized scene anchored on the pole (as GTA does natively)
    local scene = CreateSynchronizedScene(polePos.x + poleOffset.x, polePos.y + poleOffset.y, polePos.z + poleOffset.z, 0.0, 0.0, poleHeading, 2)
    SetSynchronizedSceneLooped(scene, true)
    SetSynchronizedScenePhase(scene, 0.0)
    activeSyncScene = scene

    isDancing = true
    TaskSynchronizedScene(ped, scene, anim.dict, anim.name, 8.0, -8.0, -1, 16, 1.0, 0)
end

CreateThread(function()
    for _, entry in ipairs(LapdancePositions) do
        local polePos = entry.pos
        exports["avenida_interact"]:positionRegister({
            coords      = entry.pos,
            canInteract = 1.5,
            hintIcon    = "interact",
            hintColor   = "#d303f3",
            choices     = {
                {
                    bind       = "E",
                    key        = 38,
                    message    = "Dance",
                    hintColor  = "#4a2e99",
                    onInteract = function()
                        PlayLapdance()
                    end,
                },
                {
                    bind       = "G",
                    key        = 47,
                    message    = "Pole Dance",
                    hintColor  = "#9217a5",
                    onInteract = function()
                        PlayPoleDance(polePos, entry.heading, entry.offset)
                    end,
                },
            },
        })
    end
end)