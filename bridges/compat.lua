-- bridges/compat.lua
-- Keeps avenida_interact dependency free. Everything ox_lib used to provide (DUI objects,
-- proximity points, wait helpers) has a native implementation here.
--
-- Set Config.UseOxLib = true if you prefer ox_lib to do the work. In that case you also need
-- to uncomment the '@ox_lib/init.lua' line in fxmanifest.lua, otherwise 'lib' does not exist.

Compat = {}

local USE_OX = Config.UseOxLib and lib ~= nil

---Current player ped. cache.ped can be 0 right after a spawn, so it is never trusted alone.
---@return number
function Compat.Ped()
    if USE_OX and cache and cache.ped and cache.ped > 0 then return cache.ped end
    return PlayerPedId()
end

---@return string
function Compat.Resource()
    return GetCurrentResourceName()
end

---Waits for cb() to return true. Returns false on timeout instead of throwing.
---@param cb fun(): boolean
---@param _err string  unused in native mode, kept for ox_lib signature parity
---@param timeout number  milliseconds
---@return boolean
function Compat.WaitFor(cb, _err, timeout)
    if USE_OX then
        local ok, res = pcall(lib.waitFor, cb, _err, timeout)
        return ok and res ~= nil
    end

    local deadline = GetGameTimer() + (timeout or 5000)
    while GetGameTimer() < deadline do
        if cb() then return true end
        Wait(0)
    end
    return false
end

--------------------------------------------------------------------------------
-- DUI
--------------------------------------------------------------------------------

local duiCount = 0

---Creates a DUI and its runtime texture.
---Returned object exposes: duiObject, dictName, txtName, :sendMessage(data), :remove()
---@param url string
---@param width number
---@param height number
---@return table
function Compat.Dui(url, width, height)
    if USE_OX then
        return lib.dui:new({ url = url, width = width, height = height, debug = false })
    end

    duiCount = duiCount + 1
    local name = ("avenida_interact_dui_%d"):format(duiCount)

    local duiObject = CreateDui(url, width, height)
    local handle    = GetDuiHandle(duiObject)
    local txd       = CreateRuntimeTxd(name)
    CreateRuntimeTextureFromDuiHandle(txd, name, handle)

    return {
        duiObject = duiObject,
        dictName  = name,
        txtName   = name,
        url       = url,

        sendMessage = function(self, data)
            if not self.duiObject then return end
            SendDuiMessage(self.duiObject, json.encode(data))
        end,

        remove = function(self)
            if not self.duiObject then return end
            DestroyDui(self.duiObject)
            self.duiObject = nil
        end,
    }
end

--------------------------------------------------------------------------------
-- Proximity points
--------------------------------------------------------------------------------

local POINTS     = {}
local NEARBY     = {}
local nearbyLen  = 0
local pointCount = 0
local managerUp  = false

-- How often the full point list is re-scanned. ox_lib uses the same 300ms.
local SCAN_INTERVAL = 300

local function startManager()
    if managerUp then return end
    managerUp = true

    -- Scan pass: decides which points are in range, fires onEnter / onExit and rebuilds
    -- the nearby list so the render pass never walks the full registry.
    CreateThread(function()
        while managerUp do
            local ped = Compat.Ped()
            if ped and ped > 0 then
                local pos  = GetEntityCoords(ped)
                local list = {}
                local len  = 0

                for _, point in pairs(POINTS) do
                    local dist = #(pos - point.coords)

                    if dist <= point.distance then
                        point.currentDistance = dist
                        if not point.isInside then
                            point.isInside = true
                            if point.onEnter then point:onEnter() end
                        end
                        -- onEnter may have removed the point
                        if POINTS[point.id] then
                            len = len + 1
                            list[len] = point
                        end
                    elseif point.isInside then
                        point.isInside = false
                        point.currentDistance = nil
                        if point.onExit then point:onExit() end
                    end
                end

                NEARBY, nearbyLen = list, len
            end
            Wait(SCAN_INTERVAL)
        end
    end)

    -- Render pass: per frame only while something is in range, idle otherwise.
    CreateThread(function()
        while managerUp do
            if nearbyLen > 0 then
                for i = 1, nearbyLen do
                    local point = NEARBY[i]
                    if point and point.isInside and point.nearby then
                        point:nearby()
                    end
                end
                Wait(0)
            else
                Wait(SCAN_INTERVAL)
            end
        end
    end)
end

---Creates a proximity point.
---Assign :onEnter(), :onExit() and :nearby() on the returned object.
---@param opts table  { coords = vector3, distance = number }
---@return table point  exposes .id, .coords, .distance, :remove()
function Compat.Point(opts)
    if USE_OX then
        return lib.points.new(opts)
    end

    pointCount = pointCount + 1

    local point = {
        id       = pointCount,
        coords   = opts.coords,
        distance = opts.distance,
        isInside = false,
    }

    function point:remove()
        POINTS[self.id] = nil
        self.isInside   = false
        -- Drop it from the current render list too: the next scan is up to 300ms away and
        -- the render pass would keep ticking a removed point until then.
        for i = 1, nearbyLen do
            if NEARBY[i] == self then
                table.remove(NEARBY, i)
                nearbyLen = nearbyLen - 1
                break
            end
        end
    end

    POINTS[point.id] = point
    startManager()

    return point
end

AddEventHandler("onResourceStop", function(res)
    if res ~= GetCurrentResourceName() then return end
    managerUp = false
    POINTS, NEARBY, nearbyLen = {}, {}, 0
end)
