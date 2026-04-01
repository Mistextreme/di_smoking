-- ============================================================
-- di_smoking | client/client.lua
-- ESX-Legacy Framework
-- ============================================================

local ESX        = exports['es_extended']:getSharedObject()
local spawnedPeds = {}

-- ============================================================
-- HELPER: NOTIFY
-- ============================================================
local function Notify(msg, type)
    if Config.Notify == "ox" then
        lib.notify({ title = msg, type = type or 'inform' })
    else
        -- ESX native notification
        ESX.ShowNotification(msg)
    end
end

-- ============================================================
-- HELPER: PROGRESS BAR
-- ox_lib is mandatory in this resource (always loaded via fxmanifest).
-- Config.Progressbar "qb" maps to ox_lib on ESX since no QBCore progressbar
-- exists; "ox" uses ox_lib explicitly. Both paths use lib.progressBar.
-- Must be called from within a coroutine/thread (standard for net events).
-- ============================================================
local function ProgressBar(label, time, cb)
    if lib.progressBar({
        duration      = time,
        label         = label,
        useWhileDead  = false,
        canCancel     = false,
        disable       = {
            move   = true,
            car    = false,
            combat = true,
            mouse  = false,
        },
    }) then
        cb(true)
    else
        cb(false)
    end
end

-- ============================================================
-- HELPER: CLIENT-SIDE HAS ITEM CHECK
-- (Server re-validates — used only to give early feedback.)
-- ============================================================
local function HasItem(itemName)
    if Config.Inventory == "ox" then
        return exports.ox_inventory:Search('count', itemName) > 0
    else
        -- ESX inventory is stored as an array in playerData.inventory
        local playerData = ESX.GetPlayerData()
        if not playerData or not playerData.inventory then return false end
        for _, item in ipairs(playerData.inventory) do
            if item.name == itemName and item.count > 0 then
                return true
            end
        end
        return false
    end
end

-- ============================================================
-- HELPER: FORMAT ITEM NAME FOR DISPLAY
-- ESX does not expose a client-side item list, so item names are formatted
-- for readable display in menus (e.g. "silver_ember" → "Silver Ember").
-- ============================================================
local function FormatItemLabel(itemName)
    return itemName:gsub("_", " "):gsub("(%a)([%w]*)", function(a, b)
        return a:upper() .. b:lower()
    end)
end

-- ============================================================
-- HELPER: ATTACH PROP TO PLAYER PED
-- ============================================================
local function AttachProp(modelName, bone, pos, rot)
    local playerPed = PlayerPedId()
    local model     = GetHashKey(modelName)

    RequestModel(model)
    while not HasModelLoaded(model) do Wait(100) end

    local prop = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
    AttachEntityToEntity(
        prop, playerPed,
        GetPedBoneIndex(playerPed, bone),
        pos.x, pos.y, pos.z,
        rot.x, rot.y, rot.z,
        true, true, false, true, 1, true
    )
    SetModelAsNoLongerNeeded(model)
    return prop
end

-- ============================================================
-- HELPER: DESTROY PROP SAFELY
-- ============================================================
local function DestroyProp(prop)
    if prop and DoesEntityExist(prop) then
        DetachEntity(prop, true, true)
        DeleteEntity(prop)
    end
end

-- ============================================================
-- HELPER: PLAY ANIMATION
-- ============================================================
local function PlayAnimation(anim)
    local playerPed = PlayerPedId()
    if anim.type == "scenario" then
        TaskStartScenarioInPlace(playerPed, anim.name, 0, true)
    elseif anim.type == "anim" then
        RequestAnimDict(anim.dict)
        while not HasAnimDictLoaded(anim.dict) do Wait(100) end
        TaskPlayAnim(playerPed, anim.dict, anim.anim, 8.0, -8.0, -1, 49, 0, false, false, false)
    end
end

-- ============================================================
-- BOX OPENING
-- ============================================================
local function OpenBox(itemName)
    local boxData = Config.Boxes[itemName]
    if not boxData then return end

    local playerPed = PlayerPedId()

    -- Attach box prop before animation
    local boxProp = nil
    if boxData.boxProp then
        local attachConfig = boxData.customAttach or Config.PropAttach
        boxProp = AttachProp(boxData.boxProp, attachConfig.bone, attachConfig.pos, attachConfig.rot)
    end

    -- Play opening animation
    PlayAnimation(boxData.openAnimation)

    -- Build progress label (replace {label} placeholder)
    local label = (Config.ProgressTexts.opening or "Opening..."):gsub("{label}", boxData.label or itemName)

    ProgressBar(label, Config.OpenTime, function(success)
        -- Always stop animation and clean up prop
        ClearPedTasks(playerPed)
        DestroyProp(boxProp)

        if success then
            TriggerServerEvent('di_smoking:server:openBox', itemName)
        end
    end)
end

-- ============================================================
-- SMOKE CIGARETTE
-- ============================================================
local function SmokeCig(itemName)
    local boxData = Config.Boxes[itemName]
    if not boxData or not boxData.consume then return end

    local cs        = boxData.consumeSettings
    local playerPed = PlayerPedId()

    -- Early lighter check on client (server re-validates before removal)
    if cs.requiredItem and cs.requiredItem ~= "" then
        if not HasItem(cs.requiredItem) then
            Notify('You need a ' .. cs.requiredItem .. ' to smoke!', 'error')
            return
        end
    end

    -- Load and play smoking animation
    RequestAnimDict(cs.animationOptions.dict)
    while not HasAnimDictLoaded(cs.animationOptions.dict) do Wait(100) end
    TaskPlayAnim(playerPed, cs.animationOptions.dict, cs.animationOptions.anim, 8.0, -8.0, -1, 49, 0, false, false, false)

    -- Attach cigarette prop to mouth bone
    local cigProp = nil
    if cs.prop then
        cigProp = AttachProp(cs.prop, cs.attach.bone, cs.attach.pos, cs.attach.rot)
    end

    ProgressBar('Smoking...', cs.time, function(success)
        -- Always stop animation and remove prop
        ClearPedTasksImmediately(playerPed)
        DestroyProp(cigProp)

        if success then
            TriggerServerEvent('di_smoking:server:smokeCig', itemName)
        end
    end)
end

-- ============================================================
-- SHOP MENU (ox_lib context menu)
-- ============================================================
local function OpenShopMenu(locationIndex)
    local location = Config.SmokingShop.locations[locationIndex]
    if not location then return end

    -- Build buy options
    local buyOptions = {}
    for itemName, price in pairs(Config.SmokingShop.pricing) do
        local itemLabel = FormatItemLabel(itemName)
        buyOptions[#buyOptions + 1] = {
            title       = itemLabel,
            description = 'Price: $' .. price,
            onSelect    = function()
                TriggerServerEvent('di_smoking:server:buyItem', itemName, price)
            end
        }
    end

    -- Build redeem options
    local redeemOptions = {}
    for couponItem, rewardData in pairs(Config.SmokingShop.redemption) do
        local couponLabel = FormatItemLabel(couponItem)
        local rewardLabel = FormatItemLabel(rewardData.item)
        redeemOptions[#redeemOptions + 1] = {
            title       = couponLabel,
            description = 'Exchange for: ' .. rewardLabel,
            onSelect    = function()
                TriggerServerEvent('di_smoking:server:redeemCoupon', couponItem)
            end
        }
    end

    -- Fallback when tables are empty
    if #buyOptions == 0 then
        buyOptions[1] = { title = 'No items available.', disabled = true }
    end
    if #redeemOptions == 0 then
        redeemOptions[1] = { title = 'No coupons available.', disabled = true }
    end

    -- Register and open menus
    lib.registerContext({
        id      = 'di_smoking_shop',
        title   = '🚬 ' .. location.label,
        options = {
            {
                title = '🛒 Buy Items',
                arrow = true,
                menu  = 'di_smoking_shop_buy',
            },
            {
                title = '🎟️ Redeem Coupons',
                arrow = true,
                menu  = 'di_smoking_shop_redeem',
            },
        }
    })

    lib.registerContext({
        id      = 'di_smoking_shop_buy',
        title   = '🛒 Buy Items',
        menu    = 'di_smoking_shop',
        options = buyOptions,
    })

    lib.registerContext({
        id      = 'di_smoking_shop_redeem',
        title   = '🎟️ Redeem Coupons',
        menu    = 'di_smoking_shop',
        options = redeemOptions,
    })

    lib.showContext('di_smoking_shop')
end

-- ============================================================
-- SPAWN PED AT LOCATION COORD
-- ============================================================
local function SpawnPed(pedConfig, coords)
    local model = GetHashKey(pedConfig.model)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(100) end

    local ped = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetModelAsNoLongerNeeded(model)

    if pedConfig.scenario and pedConfig.scenario ~= "" then
        TaskStartScenarioInPlace(ped, pedConfig.scenario, 0, true)
    end

    return ped
end

-- ============================================================
-- CREATE MAP BLIP
-- ============================================================
local function CreateShopBlip(coords, blipConfig, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, blipConfig.sprite)
    SetBlipDisplay(blip, blipConfig.display)
    SetBlipScale(blip, blipConfig.scale)
    SetBlipColour(blip, blipConfig.color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(label)
    EndTextCommandSetBlipName(blip)
    return blip
end

-- ============================================================
-- DRAWTEXT ZONE — per-coord proximity loop
-- Uses native help-text display; no external exports required.
-- ============================================================
local function StartDrawtextLoop(locationIndex, coords, radius, label)
    CreateThread(function()
        local inZone = false
        while true do
            local sleep     = 500
            local pedCoords = GetEntityCoords(PlayerPedId())
            local dist      = #(pedCoords - vector3(coords.x, coords.y, coords.z))

            if dist < radius then
                sleep  = 0
                inZone = true

                -- Display native help text hint
                BeginTextCommandDisplayHelp("STRING")
                AddTextComponentSubstringPlayerName("[E] " .. label)
                EndTextCommandDisplayHelp(0, false, true, -1)

                -- Open shop on E key press
                if IsControlJustPressed(0, 38) then
                    OpenShopMenu(locationIndex)
                end
            else
                inZone = false
            end

            Wait(sleep)
        end
    end)
end

-- ============================================================
-- SETUP ALL SHOP LOCATIONS
-- ============================================================
local function SetupShopLocations()
    if not Config.SmokingShop.enabled then return end

    for locationIndex, location in ipairs(Config.SmokingShop.locations) do
        for coordIndex, coords in ipairs(location.coords) do
            local zoneName = ('di_smoking_shop_%d_%d'):format(locationIndex, coordIndex)
            local radius   = location.radius or 2.0

            -- Blip per coord (each coord is a physically separate location)
            CreateShopBlip(coords, location.blip, location.label)

            -- Spawn PED at this coord (if enabled)
            if location.ped and location.ped.enabled then
                local ped = SpawnPed(location.ped, coords)
                if ped then
                    spawnedPeds[#spawnedPeds + 1] = ped
                end
            end

            -- Setup interaction zone based on Config.Interaction
            if Config.Interaction == "qb" then
                exports['qb-target']:AddCircleZone(zoneName, coords, radius, {
                    name      = zoneName,
                    heading   = coords.w,
                    debugPoly = false,
                    minZ      = coords.z - 1.5,
                    maxZ      = coords.z + 1.5,
                }, {
                    options = {
                        {
                            type          = "client",
                            event         = "di_smoking:client:openShop",
                            icon          = "fas fa-store",
                            label         = location.label,
                            locationIndex = locationIndex,
                        },
                    },
                    distance = radius,
                })

            elseif Config.Interaction == "ox" then
                exports.ox_target:addSphereZone({
                    coords  = vector3(coords.x, coords.y, coords.z),
                    radius  = radius,
                    options = {
                        {
                            name     = zoneName,
                            label    = location.label,
                            icon     = 'fas fa-store',
                            onSelect = function()
                                OpenShopMenu(locationIndex)
                            end,
                        },
                    },
                })

            else
                -- drawtext: proximity loop with native FiveM help text
                StartDrawtextLoop(locationIndex, coords, radius, location.label)
            end
        end
    end
end

-- ============================================================
-- EVENT HANDLERS
-- ============================================================

-- Triggered by qb-target with { locationIndex = n } data table
RegisterNetEvent('di_smoking:client:openShop')
AddEventHandler('di_smoking:client:openShop', function(data)
    if data and data.locationIndex then
        OpenShopMenu(data.locationIndex)
    end
end)

-- Triggered by server after ESX.RegisterUsableItem fires for a box
RegisterNetEvent('di_smoking:client:openBox')
AddEventHandler('di_smoking:client:openBox', function(itemName)
    OpenBox(itemName)
end)

-- Triggered by server after ESX.RegisterUsableItem fires for a cigarette
RegisterNetEvent('di_smoking:client:smokeCig')
AddEventHandler('di_smoking:client:smokeCig', function(itemName)
    SmokeCig(itemName)
end)

-- Optional: server can push a notification directly to client
RegisterNetEvent('di_smoking:client:notify')
AddEventHandler('di_smoking:client:notify', function(msg, type)
    Notify(msg, type)
end)

-- ============================================================
-- PLAYER DATA SYNC (ESX)
-- Keep local playerData fresh for HasItem checks
-- ============================================================
AddEventHandler('esx:playerLoaded', function(playerData)
    ESX.SetPlayerData(playerData)
end)

AddEventHandler('esx:onPlayerLogout', function()
    -- Clean up state on logout
    spawnedPeds = {}
end)

-- ============================================================
-- RESOURCE START
-- ============================================================
AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Wait(1500) -- Allow ESX and world to fully initialize
    SetupShopLocations()
    print("^2[di_smoking] ^7Client initialized successfully (ESX-Legacy).")
end)
