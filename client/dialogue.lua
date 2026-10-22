-- Dialogue system — triggered from pedRegister when cfg.dialogue is defined
-- openDialogue(spec, ped, dlgCfg) is called by ped.lua

local dialogActive    = false
local currentDialogue = nil   -- { spec, ped, dlgCfg }
local dialogCam       = nil

function IsDialogueActive()
    return dialogActive
end
local dialogElements  = {}
local dialogHistory   = {}    -- stack { message, elements (raw) }
local dialogCurMsg    = ""
local dialogCurElems  = {}

local voiceLines = {
    "GENERIC_HI", "GENERIC_HOWS_IT_GOING", "CHAT_STATE", "CHAT_RESP",
    "GREET_ACROSS_STREET", "GENERIC_YES", "GENERIC_THANKS",
    "PHONE_CONV1_INTRO", "PHONE_CONV2_INTRO", "PHONE_CONV3_INTRO",
}

local function randomVoiceLine()
    return voiceLines[math.random(#voiceLines)]
end

local function filterElements(elements)
    local out = {}
    for _, v in ipairs(elements) do
        if v.canInteract then
            local ok, result = pcall(v.canInteract)
            if ok and result then
                out[#out + 1] = v
            end
        else
            out[#out + 1] = v
        end
    end
    return out
end

local function safeElements(elements)
    local out = {}
    for _, v in ipairs(elements) do
        out[#out + 1] = { label = v.label }
    end
    return out
end

local function setDialogState(msg, rawElements, pushHistory)
    if pushHistory then
        dialogHistory[#dialogHistory + 1] = { message = dialogCurMsg, elements = dialogCurElems }
    end
    dialogCurMsg   = msg
    dialogCurElems = rawElements

    local withBack = {}
    for _, v in ipairs(rawElements) do
        withBack[#withBack + 1] = v
    end
    if #dialogHistory > 0 then
        withBack[#withBack + 1] = {
            label  = Config.Defaults.dialogueBack,
            action = function()
                local prev = table.remove(dialogHistory)
                if prev then setDialogState(prev.message, prev.elements, false) end
            end
        }
    end

    local filtered = filterElements(withBack)
    dialogElements = filtered
    SendNUIMessage({
        action = "changeDialogue",
        data   = { message = msg, elements = safeElements(filtered) }
    })
end

local function changeDialogFn(msg, elements)
    setDialogState(msg, elements, true)
end

local function closeDialogue(callback)
    if not dialogActive then return end
    dialogActive = false

    SetNuiFocus(false, false)
    SendNUIMessage({ action = "closeDialogue", data = {} })

    if currentDialogue then
        local ped  = currentDialogue.ped
        local spec = currentDialogue.spec

        if ped and DoesEntityExist(ped) then
            PlayPedAmbientSpeechAndCloneNative(ped, "GENERIC_BYE", "SPEECH_PARAMS_FORCE")

            -- Restore the ped base animation
            if spec.anim then
                local anim = spec.anim
                if type(anim) == "table" and anim.dict then
                    RequestAnimDict(anim.dict)
                    local deadline = GetGameTimer() + 3000
                    while not HasAnimDictLoaded(anim.dict) and GetGameTimer() < deadline do
                        Wait(0)
                    end
                    if HasAnimDictLoaded(anim.dict) then
                        ClearPedTasks(ped)
                        TaskPlayAnim(ped, anim.dict, anim.name or "idle", 8.0, 0.0, -1, 1, 0, false, false, false)
                    end
                elseif type(anim) == "string" then
                    ClearPedTasks(ped)
                    TaskStartScenarioInPlace(ped, anim, 0, true)
                end
            end
        end
    end

    -- Restore the camera
    RenderScriptCams(false, true, 700, true, false)
    SetTimeout(800, function()
        if dialogCam then
            DestroyCam(dialogCam, false)
            dialogCam = nil
        end
    end)

    -- Restore player visibility
    local playerPed = PlayerPedId()
    ResetEntityAlpha(playerPed)
    SetEntityVisible(playerPed, true, false)
    SetEntityAlpha(playerPed, 255, false)

    currentDialogue = nil
    dialogElements  = {}
    dialogHistory   = {}
    dialogCurMsg    = ""
    dialogCurElems  = {}

    -- Restore the HUD
    SetHudVisible(true)

    -- Per-choice callback (passed through close(fn), absent when closed by Escape or distance)
    if callback and type(callback) == "function" then
        callback()
    end

end

function openDialogue(spec, ped, dlgCfg)
    if dialogActive then return end
    dialogActive    = true
    currentDialogue = { spec = spec, ped = ped, dlgCfg = dlgCfg }

    -- Camera focus on the NPC
    local px, py, pz = table.unpack(GetEntityCoords(ped, true))
    local fx         = GetEntityForwardX(ped)
    local fy         = GetEntityForwardY(ped)
    local cx, cy, cz = px + fx * 1.2, py + fy * 1.2, pz + 0.35
    local rot        = GetEntityRotation(ped, 2)
    dialogCam        = CreateCamWithParams(
        "DEFAULT_SCRIPTED_CAMERA",
        cx, cy, cz,
        rot + vector3(0.0, 0.0, 181.0),
        GetGameplayCamFov()
    )
    SetCamActive(dialogCam, true)
    RenderScriptCams(true, true, 700, 1, 1)

    -- Hide the HUD
    SetHudVisible(false)

    -- Opening voice line
    PlayPedAmbientSpeechAndCloneNative(ped, randomVoiceLine(), "SPEECH_PARAMS_FORCE")

    -- Make the player locally invisible
    local playerPed = PlayerPedId()
    SetEntityAlpha(playerPed, 0, false)
    SetEntityVisible(playerPed, false, false)

    -- NPC animation played while the interaction runs
    local interactAnim = dlgCfg.interactAnim
    if interactAnim then
        if interactAnim.scenario then
            ClearPedTasks(ped)
            TaskStartScenarioInPlace(ped, interactAnim.scenario, 0, true)
        elseif interactAnim.dict then
            RequestAnimDict(interactAnim.dict)
            local deadline = GetGameTimer() + 3000
            while not HasAnimDictLoaded(interactAnim.dict) and GetGameTimer() < deadline do
                Wait(0)
            end
            if HasAnimDictLoaded(interactAnim.dict) then
                TaskPlayAnim(ped, interactAnim.dict, interactAnim.name or "idle", 8.0, 0.0, -1, 1, 0, false, false, false)
            end
        end
    end

    SetNuiFocus(true, true)

    dialogHistory   = {}
    dialogCurMsg    = dlgCfg.startMsg or ""
    dialogCurElems  = dlgCfg.elements or {}

    local filtered = filterElements(dlgCfg.elements or {})
    dialogElements = filtered

    SendNUIMessage({
        action = "showDialogue",
        data   = {
            npcName  = dlgCfg.name     or "",
            npcTag   = dlgCfg.tag      or "",
            message  = dlgCfg.startMsg or "",
            elements = safeElements(filtered),
        }
    })
end

-- Click on a dialogue option
RegisterNUICallback("dialogClick", function(data, cb)
    cb("ok")
    local idx = (tonumber(data) or 0) + 1
    local el  = dialogElements and dialogElements[idx]
    if not el then return end

    -- Answer voice line
    if currentDialogue and currentDialogue.ped and DoesEntityExist(currentDialogue.ped) then
        PlayPedAmbientSpeechAndCloneNative(currentDialogue.ped, randomVoiceLine(), "SPEECH_PARAMS_FORCE")
    end

    if el.action then
        el.action(changeDialogFn, function(cb) closeDialogue(cb) end)
    end
end)

-- Fermeture depuis l'UI (Escape)
RegisterNUICallback("dialogClose", function(_, cb)
    cb("ok")
    closeDialogue()
end)
