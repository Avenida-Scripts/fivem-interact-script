-- Interactions on existing entities (props, vehicles, objects)
-- Interact.* is exposed by utils.lua (loaded before this file)

local ENTITY_REGISTER = {}
local ENTITY_COUNT    = 0
local ACTIVE_ENTITIES = {}

local function attachEntityPoint(i, spec)
    if not spec.interact then return end

    local entity = spec.entity
    local boneIdx = spec.boneIdx
    local cfg    = Interact.resolveInteract(spec.interact, 0.0)
    local canInteractFn = type(spec.interact.canInteract) == "function" and spec.interact.canInteract or nil
    local holdDist      = (not canInteractFn and type(cfg.canInteract) == "number" and cfg.canInteract) or Interact.HOLD_RANGE

    local baseCoords = spec.pos
    local offsetZ    = cfg.heightOffset or cfg.offsetZ or 1.0

    Interact.createInteractPoint({
        store        = ACTIVE_ENTITIES,
        key          = i,
        groundCoords = vec3(baseCoords.x, baseCoords.y, baseCoords.z),
        renderCoords = function()
            if DoesEntityExist(entity) then
                local c = boneIdx and GetWorldPositionOfEntityBone(entity, boneIdx) or GetEntityCoords(entity)
                return vec3(c.x, c.y, c.z + offsetZ)
            end
            return vec3(baseCoords.x, baseCoords.y, baseCoords.z + offsetZ)
        end,
        cfg          = cfg,
        holdDist     = holdDist,
        entityCheck  = entity,
        canInteractFn = canInteractFn and function(_, dist)
            return canInteractFn(_, dist, spec)
        end or nil,
        onInteract = cfg.onInteract and function()
            cfg.onInteract(i, entity, spec)
        end or nil,
    })
end

local function entityRegister(cfg)
    if not cfg or not cfg.entity then
        return
    end
    if not DoesEntityExist(cfg.entity) then
        return
    end

    local resource = GetInvokingResource() or GetCurrentResourceName()
    local boneIdx  = cfg.bone and GetEntityBoneIndexByName(cfg.entity, cfg.bone) or nil
    if boneIdx == -1 then boneIdx = nil end
    local pos      = boneIdx and GetWorldPositionOfEntityBone(cfg.entity, boneIdx) or GetEntityCoords(cfg.entity)
    local spec = {
        entity    = cfg.entity,
        boneIdx   = boneIdx,
        pos       = pos,
        interact  = cfg,
        _resource = resource,
    }

    ENTITY_COUNT = ENTITY_COUNT + 1
    local idx = ENTITY_COUNT
    ENTITY_REGISTER[idx] = spec

    attachEntityPoint(idx, spec)

    if cfg.blips then
        Interact.createBlip(pos, cfg.blips, resource)
    end

    return idx
end

-- Cleanup
AddEventHandler(
    "onResourceStop",
    function(res)
        if res == GetCurrentResourceName() then
            for i, node in pairs(ACTIVE_ENTITIES) do
                if node.point then
                    if node.point.onExit then node.point:onExit() end
                    if node.point.remove then node.point:remove() end
                end
                ACTIVE_ENTITIES[i] = nil
            end
            return
        end

        for i = ENTITY_COUNT, 1, -1 do
            local spec = ENTITY_REGISTER[i]
            if spec and spec._resource == res then
                if ACTIVE_ENTITIES[i] then
                    local node = ACTIVE_ENTITIES[i]
                    if node.point then
                        if node.point.onExit then node.point:onExit() end
                        if node.point.remove then node.point:remove() end
                    end
                    ACTIVE_ENTITIES[i] = nil
                end
                ENTITY_REGISTER[i] = nil
            end
        end
    end
)

exports("entityRegister", entityRegister)

local function entityRemove(idx)
    local node = ACTIVE_ENTITIES[idx]
    if not node then return end
    if node.point then
        pcall(function()
            if node.point.onExit then node.point:onExit() end
            node.point:remove()
        end)
    end
    ACTIVE_ENTITIES[idx] = nil
    ENTITY_REGISTER[idx] = nil
end

exports("entityRemove", entityRemove)

-- Per-hash watchers : a single GetGamePool call covers them all
local HASH_WATCHERS   = {}  -- { hash -> { cfg, resource } }
local HASH_REGISTERED = {}  -- { entity_handle -> true }

local WATCHER_THREAD_STARTED = false

local function ensureWatcherThread()
    if WATCHER_THREAD_STARTED then return end
    WATCHER_THREAD_STARTED = true
    CreateThread(function()
        while true do
            if next(HASH_WATCHERS) then
                local pool = GetGamePool("CObject")

                -- Register props that just spawned in the pool
                for _, obj in ipairs(pool) do
                    if not HASH_REGISTERED[obj] then
                        local model    = GetEntityModel(obj)
                        local watchers = HASH_WATCHERS[model]
                        if watchers then
                            HASH_REGISTERED[obj] = true
                            for _, w in ipairs(watchers) do
                                local cfg = {}
                                for k, v in pairs(w.cfg) do cfg[k] = v end
                                cfg.entity = obj
                                entityRegister(cfg)
                            end
                        end
                    end
                end

                -- Clean up despawned entities
                for obj in pairs(HASH_REGISTERED) do
                    if not DoesEntityExist(obj) then
                        HASH_REGISTERED[obj] = nil
                    end
                end
            end

            Wait(5000)
        end
    end)
end

local function entityRegisterByHash(hash, cfg)
    if not hash or not cfg then
        return
    end
    local resource = GetInvokingResource() or GetCurrentResourceName()
    if not HASH_WATCHERS[hash] then
        HASH_WATCHERS[hash] = {}
    end
    HASH_WATCHERS[hash][#HASH_WATCHERS[hash] + 1] = { cfg = cfg, resource = resource }
    ensureWatcherThread()
end

exports("entityRegisterByHash", entityRegisterByHash)
