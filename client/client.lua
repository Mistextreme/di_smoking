-- ============================================================
-- di_smoking | client/client.lua
-- ============================================================

local QBCore     = exports['qb-core']:GetCoreObject()
local spawnedPeds = {}

-- ============================================================
-- HELPER: NOTIFY
-- ============================================================
local function Notify(msg, type)
    if Config.Notify == "ox" then
        lib.notify({ title = msg, type = type or 'inform' })
    else
        QBCore.Functions.Notify(msg, type or 'primary')
    end
end

-- ============================================================
-- HELPER: PROGRESS BAR
-- Unified callback-style wrapper for both qb and ox progressbars.
-- Must be called from within a coroutine/thread (standard for net events).
-- ============================================================
local function ProgressBar(label, time, cb)
    if Config.Progressbar == "ox" then
        -- lib.progressBar blocks the current coroutine and returns bool
        if lib.progressBar({
            duration      = time,
            label         = label,
            useWhileDead  = false,
            canCancel     = false,
            disable       = {
                move    = true,
                car     = false,
                combat  = true,
                mouse   = false,
            },
        }) then
            cb(true)
        else
            cb(false)
        end
    else
        QBCore.Functions.Progressbar('di_smoking_action', label, time, false, true, {
            disableMovement    = true,
            disableCarMovement = false,
            disableMouse       = false,
            disableCombat      = true,
        }, {}, {}, {}, function()
            cb(true)
        end, function()
            cb(false)
        end)
    end
end

-- ============================================================
-- HELPER: CLIENT-SIDE HAS ITEM CHECK
-- (Server re-validates — this is only used to give early feedback.)
-- ============================================================
local function HasItem(itemName)
    if Config.Inventory == "ox" then
        return exports.ox_inventory:Search('count', itemName) > 0
    else
        local items = QBCore.Functions.GetPlayerData().items
        if not items then return false end
        for _, item in pairs(items) do
            if item and item.name == itemName then
                return true
            end
        end
        return false
    end
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
        local itemLabel = (QBCore.Shared.Items[itemName] and QBCore.Shared.Items[itemName].label) or itemName
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
        local couponLabel = (QBCore.Shared.Items[couponItem] and QBCore.Shared.Items[couponItem].label) or couponItem
        local rewardLabel = (QBCore.Shared.Items[rewardData.item] and QBCore.Shared.Items[rewardData.item].label) or rewardData.item
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

    -- Register menus
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
            local sleep      = 500
            local pedCoords  = GetEntityCoords(PlayerPedId())
            local dist       = #(pedCoords - vector3(coords.x, coords.y, coords.z))

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

            -- Blip at every coord (coords are physically separate locations)
            CreateShopBlip(coords, location.blip, location.label)

            -- Spawn PED at this coord (if enabled)
            if location.ped and location.ped.enabled then
                local ped = SpawnPed(location.ped, coords)
                if ped then
                    spawnedPeds[#spawnedPeds + 1] = ped
                end
            end

            -- Register interaction zone based on Config.Interaction
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
                -- drawtext: key-E proximity loop with native help text
                StartDrawtextLoop(locationIndex, coords, radius, location.label)
            end
        end
    end
end

-- ============================================================
-- EVENT HANDLERS
-- ============================================================

-- qb-target triggers this with { locationIndex = n } as data
RegisterNetEvent('di_smoking:client:openShop')
AddEventHandler('di_smoking:client:openShop', function(data)
    if data and data.locationIndex then
        OpenShopMenu(data.locationIndex)
    end
end)

-- Server triggers openBox after useable item is registered
RegisterNetEvent('di_smoking:client:openBox')
AddEventHandler('di_smoking:client:openBox', function(itemName)
    OpenBox(itemName)
end)

-- Server triggers smokeCig after useable cigarette item is registered
RegisterNetEvent('di_smoking:client:smokeCig')
AddEventHandler('di_smoking:client:smokeCig', function(itemName)
    SmokeCig(itemName)
end)

-- Optional: server can push notifications to client directly
RegisterNetEvent('di_smoking:client:notify')
AddEventHandler('di_smoking:client:notify', function(msg, type)
    Notify(msg, type)
end)

-- ============================================================
-- RESOURCE START
-- ============================================================
AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Wait(1500) -- Allow world and framework to fully initialize
    SetupShopLocations()
    print("^2[di_smoking] ^7Client initialized successfully.")
end)
