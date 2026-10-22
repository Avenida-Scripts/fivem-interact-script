TextUi = {}
TextUi.duiInstances = {}
LocalPlayer.state.TextUiBusy = false

function TextUi:render3DSprite(duiHandler, coords, maxDistance, hintOnly)
    if not duiHandler or not duiHandler.duiObject or not IsDuiAvailable(duiHandler.duiObject) then
        return
    end

    local distance = #(GetEntityCoords(Compat.Ped()) - coords)
    if distance > maxDistance then
        return
    end

    -- Fixed scale : the icon keeps the same size alone (hint) or with the text (hold)
    local scale = 0.40

    -- Aspect correction : the DUI texture is locked to 16:9. Width is un-stretched
    -- against the real screen aspect : 1.0 on 16:9, <1 on ultrawide, >1 on wide < 16:9.
    local sw, sh = GetActiveScreenResolution()
    local widthScale = scale * (16 / 9) / (sw / sh)

    local alpha = 255

    SetDrawOrigin(coords.x, coords.y, coords.z, false)
    DrawInteractiveSprite(duiHandler.dictName, duiHandler.txtName, 0, 0, widthScale, scale, 0.0, 255, 255, 255, alpha)
    ClearDrawOrigin()
end

function TextUi:clearAllDuis()
    for id, duiInstance in pairs(self.duiInstances) do
        if duiInstance.duiHandler and duiInstance.duiHandler.remove then
            duiInstance.duiHandler:remove()
        end
    end
    self.duiInstances = {}
end

function TextUi:close(id)
    local duiData = self.duiInstances[id].duiData
    local duiHandler = self.duiInstances[id].duiHandler

    if not duiHandler then
        return
    end

    duiHandler:sendMessage(
        {
            action = "manageTextUI",
            data = {
                Visible = false,
                Message = duiData.Message,
                Bind = duiData.Bind,
                UseOnlyBind = duiData.UseOnlyBind,
                progress = 100
            }
        }
    )
end

function TextUi:removeDui(id)
    if self.duiInstances[id] and self.duiInstances[id].duiHandler then
        local duiHandler = self.duiInstances[id].duiHandler
        TextUi:close(id)
        SetTimeout(
            1000,
            function()
                duiHandler:remove()
                self.duiInstances[id] = nil
            end
        )
    end
end

AddEventHandler(
    "onResourceStop",
    function(resourceName)
        if resourceName == GetCurrentResourceName() then
            TextUi:clearAllDuis()
        end
    end
)
