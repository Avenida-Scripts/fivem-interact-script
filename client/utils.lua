-- Shared helpers between ped.lua and entity.lua
Interact = {}

Interact.BLIPS        = {}
Interact.HOLD_RANGE   = Config.HoldRange
Interact.UNLOCK_FNS   = {}   -- { [pointId] = unlockFn }
Interact.lastLockedId = nil

-- DUI texture locked to 16:9 : consistent HTML layout, un-stretching handled at draw time (render3DSprite)
local DUI_W, DUI_H = 1920, 1080

Interact.DEFAULTS = Config.Defaults
Interact.COLORS   = Config.Colors
Interact.KEYS     = Config.Keys

function Interact.resolveKey(bind)
    if not bind then return nil end
    return Interact.KEYS[string.upper(bind)] or nil
end

function Interact.resolveColor(color)
    if not color then return nil end
    return Interact.COLORS[color] or color
end

function Interact.resolveInteract(cfg, defaultOffsetZ)
    if not cfg then cfg = {} end
    local dlg        = cfg.dialogue
    local defaultMsg = (dlg and dlg.name) and Interact.DEFAULTS.dialogueMsg:format(dlg.name) or Interact.DEFAULTS.message
    return {
        message         = cfg.message     or defaultMsg,
        key             = cfg.key         or Interact.DEFAULTS.key,
        showIcon        = cfg.showIcon    or Interact.DEFAULTS.showIcon,
        canInteract     = cfg.canInteract or Interact.DEFAULTS.canInteract,
        hintIcon        = cfg.hintIcon    or Interact.DEFAULTS.hintIcon,
        hintColor       = Interact.resolveColor(cfg.hintColor) or Interact.DEFAULTS.hintColor,
        offsetZ         = cfg.offsetZ     or (defaultOffsetZ ~= nil and defaultOffsetZ or Interact.DEFAULTS.offsetZ),
        heightOffset    = cfg.heightOffset,
        onInteract      = cfg.onInteract,
        resetOnInteract = cfg.resetOnInteract ~= false,
        dialogue        = dlg,
        choices         = cfg.choices,
    }
end

function Interact.createBlip(pos, cfg, resource)
    if not cfg then return end
    local blip = AddBlipForCoord(pos.x, pos.y, pos.z)
    SetBlipSprite(blip, cfg.sprite or 1)
    SetBlipColour(blip, cfg.color or 0)
    SetBlipScale(blip, cfg.scale or 0.8)
    SetBlipDisplay(blip, cfg.display or 2)
    SetBlipAlpha(blip, cfg.alpha or 255)
    if cfg.road then SetBlipRoute(blip, true) end
    if cfg.text then
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(cfg.text)
        EndTextCommandSetBlipName(blip)
    end
    Interact.BLIPS[#Interact.BLIPS + 1] = { blip = blip, resource = resource }
end

function Interact.removeBlipsForResource(res)
    for i = #Interact.BLIPS, 1, -1 do
        local entry = Interact.BLIPS[i]
        if entry.resource == res then
            if DoesBlipExist(entry.blip) then
                RemoveBlip(entry.blip)
            end
            table.remove(Interact.BLIPS, i)
        end
    end
end

---

--- Creates an interaction point with its DUI, hint/hold handling and lock/unlock.
--- Shared by ped.lua, entity.lua and interactCreate.
---@param opts table
---@return table point
function Interact.createInteractPoint(opts)
    local store          = opts.store
    local key            = opts.key
    local groundCoords   = opts.groundCoords
    local renderCoords   = opts.renderCoords
    local cfg            = opts.cfg
    local holdDist       = opts.holdDist
    local canInteractFn  = opts.canInteractFn
    local entityHandle   = opts.entityCheck
    local onInteractCb   = opts.onInteract
    local dialogueHandler = opts.dialogueHandler
    local onExitExtra    = opts.onExitExtra
    local trackDialogue  = opts.trackDialogue or false
    local onDespawn      = opts.onDespawn

    local node = store[key] or {}
    store[key] = node

    local point = Compat.Point({
        coords   = groundCoords,
        distance = cfg.showIcon,
    })

    local zoneState      = "none"
    local interacted     = false
    local wasInDialogue  = false

    local function getRender()
        if type(renderCoords) == "function" then return renderCoords() end
        return renderCoords
    end

    local function armHold(hintOnly)
        local id = point.id

        -- Build multi-choice UI + control lists when cfg.choices is set
        local choicesUI   = nil
        local choicesCtrl = nil
        if cfg.choices and #cfg.choices > 0 then
            choicesUI   = {}
            choicesCtrl = {}
            for _, c in ipairs(cfg.choices) do
                if not c.condition or c.condition() then
                    local resolvedKey = c.key or Interact.resolveKey(c.bind)
                    local resolvedColor = Interact.resolveColor(c.hintColor) or cfg.hintColor
                    choicesUI[#choicesUI + 1] = { bind = c.bind, message = c.message, hintColor = resolvedColor }
                local choiceInteract = c.onInteract
                choicesCtrl[#choicesCtrl + 1] = {
                    bindControl = resolvedKey,
                    onCallback  = function(_)
                        if cfg.resetOnInteract then
                            interacted = true
                            zoneState  = "hint"
                            armHold(true)
                            Interact.lastLockedId = point.id
                            Interact.UNLOCK_FNS[point.id] = function()
                                interacted = false
                                local refCoords = (entityHandle and DoesEntityExist(entityHandle))
                                    and GetEntityCoords(entityHandle) or point.coords
                                local dist = #(GetEntityCoords(Compat.Ped()) - refCoords)
                                if dist <= holdDist then
                                    zoneState = "hold"
                                    armHold(false)
                                end
                            end
                        end
                        if choiceInteract then choiceInteract(entityHandle) end
                    end,
                }
                end -- condition
            end
        end

        local params = {
            Visible      = true,
            HintOnly     = hintOnly or false,
            HintIcon     = cfg.hintIcon,
            HintColor    = cfg.hintColor,
            Message      = cfg.message,
            Bind         = "E",
            UseOnlyBind  = false,
            BindToHold   = cfg.key,
            DistanceHold = holdDist,
            Coords       = point.coords,
            ChoicesUI    = choicesUI,
            ChoicesCtrl  = choicesCtrl,
            canInteract  = function(_, dist)
                if interacted then return false end
                if entityHandle and not DoesEntityExist(entityHandle) then return false end
                if canInteractFn then
                    local decision = canInteractFn(_, dist)
                    if decision ~= nil then return decision end
                end
                return dist <= holdDist
            end,
            onCallback = function(_)
                if cfg.dialogue and dialogueHandler then
                    interacted = true
                    zoneState  = "hint"
                    armHold(true)
                    dialogueHandler()
                    return
                end
                if cfg.resetOnInteract then
                    interacted = true
                    zoneState  = "hint"
                    armHold(true)
                    Interact.lastLockedId = point.id
                    Interact.UNLOCK_FNS[point.id] = function()
                        interacted = false
                        local refCoords = (entityHandle and DoesEntityExist(entityHandle))
                            and GetEntityCoords(entityHandle) or point.coords
                        local dist = #(GetEntityCoords(Compat.Ped()) - refCoords)
                        if dist <= holdDist then
                            zoneState = "hold"
                            armHold(false)
                        end
                    end
                end
                if onInteractCb then
                    onInteractCb()
                end
            end,
        }

        local isNewDui = not (store[key] and store[key].dui)
        local handler  = exports["avenida_interact"]:HandleHoldTextUI(id, params)
        if store[key] then
            store[key].dui = handler
            if isNewDui then
                store[key].duiReady = false
                SetTimeout(700, function()
                    if store[key] then store[key].duiReady = true end
                end)
            end
        end
    end

    function point:onEnter()
        if entityHandle and not DoesEntityExist(entityHandle) then return end
        zoneState = "hint"
        armHold(true)
    end

    function point:onExit()
        exports["avenida_interact"]:RemoveHoldTextUI(self.id)
        if store[key] then
            store[key].dui      = nil
            store[key].duiReady = nil
        end
        zoneState = "none"
        if Interact.lastLockedId == self.id then
            Interact.lastLockedId = nil
        end
        Interact.UNLOCK_FNS[self.id] = nil
        if onExitExtra then onExitExtra() end
    end

    function point:nearby()
        -- Stale ox_lib tick : after point:remove(), the point stays ≤300ms in nearbyPoints
        -- (rebuilt every 300ms) while the per-frame tick still calls nearby(). If the node was
        -- removed from the store (interactRemove / purge / despawn) or replaced, NEVER re-arm
        -- — otherwise armHold() revives an orphan Hold instance with the old onInteract
        -- (dead funcref after the consumer restarted) plus a leaked lib.dui.
        local liveNode = store[key]
        if not liveNode or liveNode.point ~= self then return end

        if entityHandle and not DoesEntityExist(entityHandle) then
            self:onExit()
            self:remove()
            store[key] = nil
            if onDespawn then onDespawn() end
            return
        end

        if not (store[key] and store[key].dui) then
            zoneState = "hint"
            armHold(true)
            return
        end

        if store[key].duiReady == false then return end

        if trackDialogue then
            local inDialogue = IsDialogueActive()
            if wasInDialogue and not inDialogue then
                interacted    = false
                wasInDialogue = false
            elseif inDialogue and interacted then
                wasInDialogue = true
            end
        end

        local dist = #(GetEntityCoords(Compat.Ped()) - self.coords)
        if dist <= holdDist then
            if interacted then
                if zoneState ~= "hint" then
                    zoneState = "hint"
                    armHold(true)
                end
            else
                if zoneState ~= "hold" then
                    zoneState = "hold"
                    armHold(false)
                end
            end
        else
            if interacted then interacted = false end
            if zoneState ~= "hint" then
                zoneState = "hint"
                armHold(true)
            end
        end

        local handler = store[key] and store[key].dui
        if not handler then return end

        exports["avenida_interact"]:Draw3DSprite({
            duiHandler  = handler,
            coords      = getRender(),
            maxDistance  = self.distance,
            hintOnly    = zoneState == "hint",
        })
    end

    node.point = point
    return point
end

---

function TextUi:initializeDui(id, data)
    if not id then
        return
    end
    if not self.duiInstances[id] then
        self.duiInstances[id] = {
            duiHandler = Compat.Dui(("nui://%s/web/build/index.html"):format(Compat.Resource()), DUI_W, DUI_H)
        }
    end

    local duiHandler = self.duiInstances[id].duiHandler
    LocalPlayer.state.TextUiBusy = data.Visible

    Compat.WaitFor(
        function()
            return duiHandler and IsDuiAvailable(duiHandler.duiObject)
        end,
        "DUI not available for id: " .. tostring(id),
        5000
    )

    self.duiInstances[id].duiData = data

    duiHandler:sendMessage(
        {
            action = "manageTextUI",
            data = {
                Visible = data.Visible,
                Message = data.Message,
                Bind = data.Bind or "E",
                UseOnlyBind = data.UseOnlyBind or false,
                progress = 100
            }
        }
    )

    return duiHandler
end
