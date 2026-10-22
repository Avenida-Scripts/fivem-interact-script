Hold = {}
Hold.instances = {}

local PRESS_DEBOUNCE_MS = 500
-- DUI texture locked to 16:9 : consistent HTML layout, un-stretching handled at draw time (render3DSprite)
local DUI_W, DUI_H = 1920, 1080

function Hold:isWithinDistance(id)
    local inst = self.instances[id]
    if not inst then
        return false
    end
    local dist = #(GetEntityCoords(Compat.Ped()) - inst.coords)
    return dist <= inst.distanceHold
end

function Hold:init(id, data)
    if not id then
        return
    end

    local isNew = not self.instances[id]

    if isNew then
        self.instances[id] = {
            dui = Compat.Dui(("nui://%s/web/build/index.html"):format(Compat.Resource()), DUI_W, DUI_H),
            bindKey      = data.Bind or "E",
            bindHold     = data.BindToHold or 38,
            onCallback   = data.onCallback,
            choices      = data.ChoicesCtrl or nil,
            coords       = data.Coords or {x = 0, y = 0, z = 0},
            distanceHold = data.DistanceHold or 3,
            canInteract = (type(data.canInteract) == "function") and data.canInteract or function()
                    return data.canInteract ~= false
                end,
            lastFireAt = 0,
            id = id
        }

        Hold:ensureManager()

        Compat.WaitFor(
            function()
                local inst = self.instances[id]
                return inst and inst.dui and IsDuiAvailable(inst.dui.duiObject)
            end,
            "ok",
            5000
        )
    else
        local inst = self.instances[id]
        if data.onCallback ~= nil then
            inst.onCallback = data.onCallback
        end
        if type(data.canInteract) == "function" then
            inst.canInteract = data.canInteract
        end
        if data.DistanceHold  then inst.distanceHold = data.DistanceHold   end
        if data.BindToHold    then inst.bindHold     = data.BindToHold     end
        if data.Coords        then inst.coords       = data.Coords         end
        if data.ChoicesCtrl ~= nil then inst.choices = data.ChoicesCtrl   end
    end

    self.instances[id].intData = data

    local inst = self.instances[id]
    local dui  = inst.dui

    local function sendMsg()
        if not self.instances[id] or not dui then
            return
        end
        pcall(
            function()
                dui:sendMessage(
                    {
                        action = "manageTextUI",
                        data = {
                            Visible     = data.Visible,
                            HintOnly    = data.HintOnly  or false,
                            HintIcon    = data.HintIcon,
                            HintColor   = data.HintColor,
                            Message     = data.Message,
                            Bind        = inst.bindKey or "E",
                            UseOnlyBind = data.UseOnlyBind or false,
                            Intent      = data.Intent or "success",
                            Icon        = data.Icon,
                            Choices     = data.ChoicesUI or nil
                        }
                    }
                )
            end
        )
    end

    if isNew then
        SetTimeout(600, sendMsg)
    else
        sendMsg()
    end

    self:setVisible(id, data.Visible == true and not (data.HintOnly == true))
    return dui
end

function Hold:ensureManager()
    if self._managerActive then return end
    self._managerActive = true
    CreateThread(function()
        while next(self.instances) do
            local ids = {}
            for id in pairs(self.instances) do
                ids[#ids + 1] = id
            end
            for _, id in ipairs(ids) do
                if self.instances[id] then
                    if self:isWithinDistance(id) then
                        self:check(id)
                    end
                end
            end
            Wait(50)
        end
        self._managerActive = false
    end)
end

function Hold:check(id)
    local inst = self.instances[id]
    if not inst then
        return
    end
    if not self:isWithinDistance(id) then
        return
    end

    if type(inst.canInteract) == "function" then
        local dist = #(GetEntityCoords(Compat.Ped()) - inst.coords)
        if inst.canInteract(id, dist) ~= true then
            return
        end
    end

    if inst.choices then
        for _, c in ipairs(inst.choices) do
            if IsControlPressed(0, c.bindControl) or IsDisabledControlPressed(0, c.bindControl) then
                local now = GetGameTimer()
                if now - inst.lastFireAt > PRESS_DEBOUNCE_MS then
                    inst.lastFireAt = now
                    if inst.dui and IsDuiAvailable(inst.dui.duiObject) then
                        pcall(function()
                            inst.dui:sendMessage({ action = "interactFlash", data = {} })
                        end)
                    end
                    if c.onCallback then
                        local ok, err = pcall(c.onCallback, id)
                        if not ok and err ~= nil and Config.Debug then
                            print(('[avenida_interact] choice onCallback error (id %s): %s'):format(tostring(id), tostring(err)))
                        end
                    end
                end
                break
            end
        end
    elseif IsControlPressed(0, inst.bindHold) or IsDisabledControlPressed(0, inst.bindHold) then
        local now = GetGameTimer()
        if now - inst.lastFireAt > PRESS_DEBOUNCE_MS then
            inst.lastFireAt = now
            if inst.dui and IsDuiAvailable(inst.dui.duiObject) then
                pcall(function()
                    inst.dui:sendMessage({ action = "interactFlash", data = {} })
                end)
            end
            if inst.onCallback then
                local ok, err = pcall(inst.onCallback, id)
                if not ok and err ~= nil and Config.Debug then
                    print(('[avenida_interact] onCallback error (id %s): %s'):format(tostring(id), tostring(err)))
                end
            end
        end
    end
end

function Hold:stopThread(id)
    if self.instances[id] and self.instances[id].thread then
        self.instances[id].thread = nil
    end
end

function Hold:hasActive()
    return next(self.instances) ~= nil
end

function Hold:setVisible(id, visible)
    local inst = self.instances[id]
    if not inst then
        return
    end
    inst._visible = visible and true or false

    local anyVisible = false
    for _, it in pairs(self.instances) do
        if it._visible then
            anyVisible = true
            break
        end
    end
    LocalPlayer.state.TextUiBusy = anyVisible
end

function Hold:closeDui(id)
    local inst = self.instances[id]
    if not inst then
        return
    end
    local dui  = inst.dui
    local data = inst.intData or {}

    if dui then
        pcall(
            function()
                dui:sendMessage(
                    {
                        action = "manageTextUI",
                        data = {
                            Visible     = false,
                            Message     = data.Message,
                            Bind        = inst.bindKey or "E",
                            UseOnlyBind = data.UseOnlyBind or false,
                            Intent      = data.Intent,
                            Icon        = data.Icon
                        }
                    }
                )
            end
        )
    end

    self:setVisible(id, false)
end

function Hold:remove(id)
    local inst = self.instances[id]
    if not inst then
        return
    end

    Hold:closeDui(id)

    self.instances[id] = nil

    SetTimeout(
        1000,
        function()
            if inst.dui then
                pcall(
                    function()
                        inst.dui:remove()
                    end
                )
            end
        end
    )
end

AddEventHandler(
    "onResourceStop",
    function(resourceName)
        if resourceName == GetCurrentResourceName() then
            for id, _ in pairs(Hold.instances) do
                Hold:remove(id)
            end
        end
    end
)
