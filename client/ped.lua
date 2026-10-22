Ped = {}

local REGISTER = {}
local REGISTER_COUNT = 0
local INDEX_BY_KEY = {}
local SPAWNED = {}
local POSITION_REGISTER = {}
local POSITION_COUNT = 0
local POSITION_INDEX_BY_KEY = {}
local ACTIVE_POINTS = {}

local SPAWN_RANGE  = Config.PedSpawnRange
local PED_DEFAULTS = Config.PedDefaults

local SPAWN_RANGE2 = SPAWN_RANGE * SPAWN_RANGE

local function sqrDist(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return dx * dx + dy * dy + dz * dz
end

local function loadModel(model)
    if type(model) == "string" then
        model = GetHashKey(model)
    end
    if not IsModelInCdimage(model) then
        return false
    end
    RequestModel(model)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(model) do
        if GetGameTimer() > t then
            return false
        end
        Wait(0)
    end
    return model
end

local function loadAnimDict(dict)
    RequestAnimDict(dict)
    local t = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > t then
            return false
        end
        Wait(0)
    end
    return true
end

local function playAnimIfAny(ped, anim)
    if not anim then
        return
    end
    if type(anim) == "string" then
        TaskStartScenarioInPlace(ped, anim, 0, true)
        return
    end
    local dict, name, flag
    if anim.dict then
        dict = anim.dict
        name = anim.name or "idle"
        flag = anim.flag or 1
    else
        dict = anim[1]
        name = anim[2]
        flag = anim[3] or 1
    end
    if dict and name and loadAnimDict(dict) then
        TaskPlayAnim(ped, dict, name, 8.0, -8.0, -1, flag, 0.0, false, false, false)
    end
end

local function createOne(spec)
    local model = loadModel(spec.model)
    if not model then
        return nil
    end

    local heading = tonumber(spec.pos.w) or spec.heading or 0.0
    local ped = CreatePed(4, model, spec.pos.x, spec.pos.y, spec.pos.z, heading, false, false)

    SetEntityAsMissionEntity(ped, true, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedKeepTask(ped, true)
    SetPedDiesWhenInjured(ped, false)
    SetPedCanRagdoll(ped, false)

    PlaceObjectOnGroundProperly(ped)
    FreezeEntityPosition(ped, true)

    if spec.randomComponents then
        SetPedRandomComponentVariation(ped, true)
        SetPedRandomProps(ped)
    end

    SetEntityHeading(ped, heading)
    playAnimIfAny(ped, spec.anim)
    SetModelAsNoLongerNeeded(model)

    return ped
end

local function attachInteractPoint(i, spec, ped)
    if not spec.interact then return end

    local cfg = Interact.resolveInteract(spec.interact)
    local holdDist = (type(cfg.canInteract) == "number" and cfg.canInteract) or Interact.HOLD_RANGE
    local groundCoords = vec3(spec.pos.x, spec.pos.y, spec.pos.z)
    local renderCoords = vec3(spec.pos.x, spec.pos.y, spec.pos.z + cfg.offsetZ)

    Interact.createInteractPoint({
        store        = SPAWNED,
        key          = i,
        groundCoords = groundCoords,
        renderCoords = renderCoords,
        cfg          = cfg,
        holdDist     = holdDist,
        entityCheck  = ped,
        trackDialogue = true,
        dialogueHandler = cfg.dialogue and function()
            openDialogue(spec, ped, cfg.dialogue)
        end or nil,
        onInteract = cfg.onInteract and function()
            cfg.onInteract(i, ped, spec)
        end or nil,
        onExitExtra = function()
            if IsDialogueActive() then closeDialogue() end
        end,
    })
end


local function attachPositionPoint(i, spec)
    if not spec.interact then return end

    local cfg = Interact.resolveInteract(spec.interact, 0.0)
    local canInteractFn = type(spec.interact.canInteract) == "function" and spec.interact.canInteract or nil
    local holdDist = (not canInteractFn and type(cfg.canInteract) == "number" and cfg.canInteract) or Interact.HOLD_RANGE

    local renderZ = spec.pos.z + (cfg.heightOffset or cfg.offsetZ)
    local groundCoords = vec3(spec.pos.x, spec.pos.y, spec.pos.z)
    local renderCoords = vec3(spec.pos.x, spec.pos.y, renderZ)

    Interact.createInteractPoint({
        store        = ACTIVE_POINTS,
        key          = i,
        groundCoords = groundCoords,
        renderCoords = renderCoords,
        cfg          = cfg,
        holdDist     = holdDist,
        canInteractFn = canInteractFn and function(_, dist)
            return canInteractFn(_, dist, spec)
        end or nil,
        onInteract = cfg.onInteract and function()
            cfg.onInteract(i, nil, spec)
        end or nil,
    })
end


local function detachInteractPoint(i)
    local node = SPAWNED[i]
    if not node then
        return
    end
    if node.point then
        if node.point.onExit then
            node.point:onExit()
        end
        if node.point.remove then
            node.point:remove()
        end
        node.point = nil
    end
    node.dui = nil
end

local PED_THREAD_STARTED = false

local function ensurePedThread()
    if PED_THREAD_STARTED then return end
    PED_THREAD_STARTED = true
    CreateThread(function()
        while true do
            local sleep = 1000
            local pPed = PlayerPedId()
            local pPos = GetEntityCoords(pPed)

            for i = 1, REGISTER_COUNT do
                local spec = REGISTER[i]
                if not spec then goto continue end
                local d2 = sqrDist(pPos, spec.pos)

                if d2 <= SPAWN_RANGE2 then
                    if not SPAWNED[i] then
                        local ped = createOne(spec)
                        if ped then
                            SPAWNED[i] = {ped = ped}
                            attachInteractPoint(i, spec, ped)
                            sleep = 0
                        end
                    end
                else
                    if SPAWNED[i] then
                        detachInteractPoint(i)
                        if DoesEntityExist(SPAWNED[i].ped) then
                            DeleteEntity(SPAWNED[i].ped)
                        end
                        SPAWNED[i] = nil
                        sleep = 0
                    end
                end
                ::continue::
            end

            Wait(sleep)
        end
    end)
end

local function positionRegister(cfg)
    if not cfg or not cfg.coords then
        return
    end
    local c = cfg.coords
    if not c.x or not c.y or not c.z then
        return
    end
    if c.w and c.w ~= 0.0 then
        return
    end
    local pos = cfg.coords
    local key = ("@%.2f,%.2f,%.2f"):format(pos.x, pos.y, pos.z)

    if POSITION_INDEX_BY_KEY[key] then
        return POSITION_INDEX_BY_KEY[key]
    end

    local resource = GetInvokingResource() or GetCurrentResourceName()
    local spec = {
        pos     = pos,
        interact = cfg,
        _resource = resource,
    }

    POSITION_COUNT = POSITION_COUNT + 1
    local idx = POSITION_COUNT
    POSITION_REGISTER[idx] = spec
    POSITION_INDEX_BY_KEY[key] = idx

    attachPositionPoint(idx, spec)

    if cfg.blips then
        Interact.createBlip(pos, cfg.blips, resource)
    end

    return idx
end

function pedRegister(cfg)
    if not cfg or not cfg.coords then
        return
    end
    local pos = cfg.coords
    if not pos.w then
        return
    end

    local model   = cfg.model or PED_DEFAULTS.model
    local heading = tonumber(pos.w) or 0.0
    local anim    = cfg.anim or {
        dict  = cfg.animDict  or PED_DEFAULTS.animDict,
        name  = cfg.animName  or PED_DEFAULTS.animName,
        flag  = cfg.animFlag  or PED_DEFAULTS.animFlag,
    }

    local key = (type(model) == "string" and model or tostring(model)) ..
        ("@%.2f,%.2f,%.2f@%.2f"):format(pos.x, pos.y, pos.z, heading)

    if INDEX_BY_KEY[key] then
        return INDEX_BY_KEY[key]
    end

    local resource = GetInvokingResource() or GetCurrentResourceName()
    local spec = {
        model            = model,
        pos              = pos,
        anim             = anim,
        -- Opt-out : a ped rolls its components CLIENT SIDE, so two players see a different
        -- outfit on the same NPC. Fine for a background ped, not for a named vendor.
        -- Default stays true so existing callers are unaffected.
        randomComponents = cfg.randomComponents ~= false,
        interact         = cfg,
        _resource        = resource,
    }

    REGISTER_COUNT = REGISTER_COUNT + 1
    local idx = REGISTER_COUNT
    REGISTER[idx] = spec
    INDEX_BY_KEY[key] = idx

    if cfg.blips then
        Interact.createBlip(pos, cfg.blips, resource)
    end

    ensurePedThread()
    return idx
end

-- Removes a ped registration (symmetric to interactRemove) : despawns the ped if spawned, detaches its
-- interaction point and frees the index/key. Needed for TEMPORARY peds (e.g. an onboarding NPC) —
-- otherwise the registration stays alive until the resource stops (endless distance spawn/despawn).
local function pedRemove(idx)
    local spec = REGISTER[idx]
    if not spec then return end
    detachInteractPoint(idx)
    local node = SPAWNED[idx]
    if node then
        if node.ped and DoesEntityExist(node.ped) then
            DeleteEntity(node.ped)
        end
        SPAWNED[idx] = nil
    end
    for key, i in pairs(INDEX_BY_KEY) do
        if i == idx then
            INDEX_BY_KEY[key] = nil
            break
        end
    end
    -- Only touch blips if THIS ped placed some (removeBlipsForResource purges the whole resource).
    if spec.interact and spec.interact.blips and spec._resource then
        Interact.removeBlipsForResource(spec._resource)
    end
    REGISTER[idx] = nil
end
exports("pedRemove", pedRemove)

-- Cleanup
AddEventHandler(
    "onResourceStop",
    function(res)
        Interact.removeBlipsForResource(res)

        if res == GetCurrentResourceName() then
            -- avenida_interact itself is stopping: clean up everything
            for i, node in pairs(SPAWNED) do
                detachInteractPoint(i)
                if node.ped and DoesEntityExist(node.ped) then
                    DeleteEntity(node.ped)
                end
                SPAWNED[i] = nil
            end
            for i, node in pairs(ACTIVE_POINTS) do
                if node.point then
                    if node.point.onExit then
                        node.point:onExit()
                    end
                    if node.point.remove then
                        node.point:remove()
                    end
                end
                ACTIVE_POINTS[i] = nil
            end
            return
        end

        -- A consumer resource is stopping: clean up its registrations
        for i = REGISTER_COUNT, 1, -1 do
            local spec = REGISTER[i]
            if spec and spec._resource == res then
                detachInteractPoint(i)
                if SPAWNED[i] then
                    if SPAWNED[i].ped and DoesEntityExist(SPAWNED[i].ped) then
                        DeleteEntity(SPAWNED[i].ped)
                    end
                    SPAWNED[i] = nil
                end
                for key, idx in pairs(INDEX_BY_KEY) do
                    if idx == i then
                        INDEX_BY_KEY[key] = nil
                        break
                    end
                end
                REGISTER[i] = nil
            end
        end

        for i = POSITION_COUNT, 1, -1 do
            local spec = POSITION_REGISTER[i]
            if spec and spec._resource == res then
                if ACTIVE_POINTS[i] then
                    local node = ACTIVE_POINTS[i]
                    if node.point then
                        if node.point.onExit then node.point:onExit() end
                        if node.point.remove then node.point:remove() end
                    end
                    ACTIVE_POINTS[i] = nil
                end
                for key, idx in pairs(POSITION_INDEX_BY_KEY) do
                    if idx == i then
                        POSITION_INDEX_BY_KEY[key] = nil
                        break
                    end
                end
                POSITION_REGISTER[i] = nil
            end
        end
    end
)

exports("pedRegister",      pedRegister)
exports("positionRegister", positionRegister)

-- ─────────────────────────────────────────────────────────────────────────────
-- interactCreate / interactRemove
-- Dynamic interaction point (can be created and removed on demand).
-- Same visuals as positionRegister, but without the coordinate cache.
-- ─────────────────────────────────────────────────────────────────────────────

local INTERACT_POINTS = {}
local INTERACT_COUNT  = 0

local function interactCreate(cfg)
    if not cfg or not cfg.coords then return nil end

    local pos      = cfg.coords
    local resource = GetInvokingResource() or GetCurrentResourceName()
    local resolved = Interact.resolveInteract(cfg, 0.0)
    local holdDist = (type(resolved.canInteract) == "number" and resolved.canInteract) or Interact.HOLD_RANGE

    INTERACT_COUNT = INTERACT_COUNT + 1
    local idx  = INTERACT_COUNT
    local node = { _resource = resource }
    INTERACT_POINTS[idx] = node

    local renderCoords = vec3(pos.x, pos.y, pos.z + (resolved.heightOffset or resolved.offsetZ))
    local groundCoords = vec3(pos.x, pos.y, pos.z)

    local point = Interact.createInteractPoint({
        store        = INTERACT_POINTS,
        key          = idx,
        groundCoords = groundCoords,
        renderCoords = renderCoords,
        cfg          = resolved,
        holdDist     = holdDist,
        onInteract = resolved.onInteract and function()
            -- The owning resource may have just stopped/restarted : its onInteract funcref is then
            -- DEAD. Calling it makes the C++ engine log ("Execution of function reference in
            -- script host failed"). Skip it when the resource is no longer 'started' — the point
            -- gets cleaned by onResourceStop right after.
            if GetResourceState(resource) ~= 'started' then return end
            resolved.onInteract(idx, nil, cfg)
        end or nil,
    })

    node.ptId = point.id

    if cfg.blips then
        Interact.createBlip(pos, cfg.blips, resource)
    end

    return idx
end

local function interactRemove(idx)
    local node = INTERACT_POINTS[idx]
    if not node then return end

    if node.point then
        pcall(function()
            if node.point.onExit then node.point:onExit() end
            node.point:remove()
        end)
        node.point = nil
    end
    if node._resource then
        Interact.removeBlipsForResource(node._resource)
    end
    INTERACT_POINTS[idx] = nil
end

exports("interactCreate", interactCreate)
exports("interactRemove", interactRemove)

-- Drop the dynamic points of a resource when it stops
AddEventHandler("onResourceStop", function(res)
    for i, node in pairs(INTERACT_POINTS) do
        if node._resource == res then
            interactRemove(i)
        end
    end
end)

-- Defensive purge when a consumer (re)starts : drops its old ghost points if the stop
-- cleanup missed any, BEFORE it registers again.
-- Avoids having to restart avenida_interact so it "forgets" a resource.
AddEventHandler("onResourceStart", function(res)
    if res == GetCurrentResourceName() then return end
    for i, node in pairs(INTERACT_POINTS) do
        if node._resource == res then
            interactRemove(i)
        end
    end
end)
