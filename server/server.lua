-- ============================================================
-- di_smoking | server/server.lua
-- ============================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================================
-- HELPER: SEND WEBHOOK
-- ============================================================
local function SendWebhook(playerName, action, details)
    if not Config.Webhook or Config.Webhook == "" then return end
    local data = {
        ["username"] = "di_smoking",
        ["embeds"] = {{
            ["title"]       = "di_smoking | " .. action,
            ["description"] = "**Player:** " .. playerName .. "\n**Details:** " .. details,
            ["color"]       = 3066993,
            ["footer"]      = { ["text"] = os.date("%Y-%m-%d %H:%M:%S") }
        }}
    }
    PerformHttpRequest(Config.Webhook, function() end, "POST",
        json.encode(data),
        { ["Content-Type"] = "application/json" }
    )
end

-- ============================================================
-- HELPER: NOTIFY PLAYER
-- ============================================================
local function NotifyPlayer(source, msg, type)
    if Config.Notify == "ox" then
        TriggerClientEvent('ox_lib:notify', source, { title = msg, type = type or 'inform' })
    else
        TriggerClientEvent('QBCore:Notify', source, msg, type or 'primary')
    end
end

-- ============================================================
-- HELPER: INVENTORY — HAS ITEM
-- ============================================================
local function HasItem(source, item, amount)
    amount = amount or 1
    if Config.Inventory == "ox" then
        return exports.ox_inventory:Search(source, 'count', item) >= amount
    else
        local xPlayer = QBCore.Functions.GetPlayer(source)
        if not xPlayer then return false end
        local playerItem = xPlayer.Functions.GetItemByName(item)
        return playerItem ~= nil and playerItem.amount >= amount
    end
end

-- ============================================================
-- HELPER: INVENTORY — GIVE ITEM
-- ============================================================
local function GiveItem(source, item, amount)
    if Config.Inventory == "ox" then
        exports.ox_inventory:AddItem(source, item, amount)
    else
        local xPlayer = QBCore.Functions.GetPlayer(source)
        if not xPlayer then return end
        xPlayer.Functions.AddItem(item, amount)
        TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[item], 'add')
    end
end

-- ============================================================
-- HELPER: INVENTORY — REMOVE ITEM
-- ============================================================
local function RemoveItem(source, item, amount)
    if Config.Inventory == "ox" then
        return exports.ox_inventory:RemoveItem(source, item, amount)
    else
        local xPlayer = QBCore.Functions.GetPlayer(source)
        if not xPlayer then return false end
        local removed = xPlayer.Functions.RemoveItem(item, amount)
        if removed then
            TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[item], 'remove')
        end
        return removed
    end
end

-- ============================================================
-- HELPER: MONEY — GET CASH
-- ============================================================
local function GetPlayerMoney(source)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if not xPlayer then return 0 end
    return xPlayer.Functions.GetMoney('cash')
end

-- ============================================================
-- HELPER: MONEY — REMOVE CASH
-- ============================================================
local function RemovePlayerMoney(source, amount)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if not xPlayer then return false end
    return xPlayer.Functions.RemoveMoney('cash', amount)
end

-- ============================================================
-- HELPER: GET ITEM LABEL (safe fallback)
-- ============================================================
local function GetItemLabel(itemName)
    return (QBCore.Shared.Items[itemName] and QBCore.Shared.Items[itemName].label) or itemName
end

-- ============================================================
-- REGISTER USEABLE ITEMS
-- ============================================================
local function RegisterUseableItems()
    if Config.Inventory == "ox" then
        -- ox_inventory: register a single hook that handles all di_smoking items
        exports.ox_inventory:registerHook('useItem', function(payload)
            local source   = payload.source
            local itemName = payload.item.name

            -- Check if it's a box item
            if Config.Boxes[itemName] then
                TriggerClientEvent('di_smoking:client:openBox', source, itemName)
                return false -- prevent automatic item removal (handled server-side)
            end

            -- Check if it's a cigarette item
            for boxKey, boxData in pairs(Config.Boxes) do
                if boxData.consume and boxData.giveItem == itemName then
                    TriggerClientEvent('di_smoking:client:smokeCig', source, boxKey)
                    return false -- prevent automatic item removal (handled server-side)
                end
            end
        end)

    else
        -- QBCore inventory: register each box and cigarette as a useable item
        for itemName, boxData in pairs(Config.Boxes) do
            -- Box item
            QBCore.Functions.CreateUseableItem(itemName, function(source, item)
                local xPlayer = QBCore.Functions.GetPlayer(source)
                if not xPlayer then return end
                TriggerClientEvent('di_smoking:client:openBox', source, itemName)
            end)

            -- Cigarette item
            if boxData.consume and boxData.giveItem then
                local cigItem = boxData.giveItem
                local boxKey  = itemName -- capture for closure
                QBCore.Functions.CreateUseableItem(cigItem, function(source, item)
                    local xPlayer = QBCore.Functions.GetPlayer(source)
                    if not xPlayer then return end
                    TriggerClientEvent('di_smoking:client:smokeCig', source, boxKey)
                end)
            end
        end
    end
end

-- ============================================================
-- NET EVENT: OPEN BOX
-- ============================================================
RegisterNetEvent('di_smoking:server:openBox', function(itemName)
    local source  = source
    local boxData = Config.Boxes[itemName]
    if not boxData then return end

    local xPlayer = QBCore.Functions.GetPlayer(source)
    if not xPlayer then return end

    -- Validate player actually has the box
    if not HasItem(source, itemName, 1) then
        NotifyPlayer(source, 'You do not have this item!', 'error')
        return
    end

    -- Remove the box from inventory
    if not RemoveItem(source, itemName, 1) then
        NotifyPlayer(source, 'Could not remove item!', 'error')
        return
    end

    -- Give the cigarettes inside the box
    GiveItem(source, boxData.giveItem, boxData.cigAmount)
    NotifyPlayer(source, 'You received ' .. boxData.cigAmount .. 'x ' .. boxData.label .. '!', 'success')

    -- Roll for each bonus item
    if boxData.bonus then
        for _, bonusData in ipairs(boxData.bonus) do
            local roll = math.random(1, 100)
            if roll <= bonusData.chance then
                GiveItem(source, bonusData.item, bonusData.amount)
                NotifyPlayer(source, 'Bonus! You received a ' .. GetItemLabel(bonusData.item) .. '!', 'success')
            end
        end
    end

    -- Webhook log
    SendWebhook(
        GetPlayerName(source),
        "Box Opened",
        "Box: " .. (boxData.label or itemName) .. " | Cigarettes received: " .. boxData.cigAmount
    )
end)

-- ============================================================
-- NET EVENT: SMOKE CIGARETTE
-- ============================================================
RegisterNetEvent('di_smoking:server:smokeCig', function(itemName)
    local source  = source
    local boxData = Config.Boxes[itemName]
    if not boxData or not boxData.consume then return end

    local cs      = boxData.consumeSettings
    local cigItem = boxData.giveItem

    -- Validate cigarette exists
    if not HasItem(source, cigItem, 1) then
        NotifyPlayer(source, 'You do not have any cigarettes!', 'error')
        return
    end

    -- Validate lighter (required item)
    if cs.requiredItem and cs.requiredItem ~= "" then
        if not HasItem(source, cs.requiredItem, 1) then
            NotifyPlayer(source, 'You need a ' .. GetItemLabel(cs.requiredItem) .. ' to smoke!', 'error')
            return
        end
    end

    -- Remove the consumed cigarette
    if not RemoveItem(source, cigItem, 1) then
        NotifyPlayer(source, 'Could not remove cigarette!', 'error')
        return
    end

    -- Calculate and apply stress reduction
    local stressRemove = math.random(cs.stressRemove.min, cs.stressRemove.max)
    TriggerClientEvent(Config.StressEvent, source, -stressRemove)
    NotifyPlayer(source, 'You feel more relaxed after smoking.', 'success')

    -- Webhook log
    SendWebhook(
        GetPlayerName(source),
        "Cigarette Smoked",
        "Type: " .. (boxData.label or itemName) .. " | Stress removed: " .. stressRemove
    )
end)

-- ============================================================
-- NET EVENT: BUY ITEM FROM SHOP
-- ============================================================
RegisterNetEvent('di_smoking:server:buyItem', function(itemName, clientPrice)
    local source = source
    if not Config.SmokingShop.enabled then return end

    -- Validate item exists in pricing table
    local price = Config.SmokingShop.pricing[itemName]
    if not price then
        NotifyPlayer(source, 'Item not available in shop!', 'error')
        return
    end

    -- Anti-tamper: verify price matches server-side config
    if price ~= clientPrice then
        NotifyPlayer(source, 'Invalid purchase request!', 'error')
        return
    end

    -- Check player has enough cash
    if GetPlayerMoney(source) < price then
        NotifyPlayer(source, 'You do not have enough cash!', 'error')
        return
    end

    -- Remove money and give item
    if not RemovePlayerMoney(source, price) then
        NotifyPlayer(source, 'Could not process payment!', 'error')
        return
    end

    GiveItem(source, itemName, 1)
    NotifyPlayer(source, 'You purchased ' .. GetItemLabel(itemName) .. ' for $' .. price .. '!', 'success')

    -- Webhook log
    SendWebhook(
        GetPlayerName(source),
        "Shop Purchase",
        "Bought: " .. GetItemLabel(itemName) .. " | Price: $" .. price
    )
end)

-- ============================================================
-- NET EVENT: REDEEM COUPON
-- ============================================================
RegisterNetEvent('di_smoking:server:redeemCoupon', function(couponItem)
    local source = source
    if not Config.SmokingShop.enabled then return end

    -- Validate coupon exists in redemption table
    local rewardData = Config.SmokingShop.redemption[couponItem]
    if not rewardData then
        NotifyPlayer(source, 'Invalid coupon!', 'error')
        return
    end

    -- Check player has the coupon
    if not HasItem(source, couponItem, 1) then
        NotifyPlayer(source, 'You do not have this coupon!', 'error')
        return
    end

    -- Remove coupon and give reward box
    if not RemoveItem(source, couponItem, 1) then
        NotifyPlayer(source, 'Could not redeem coupon!', 'error')
        return
    end

    GiveItem(source, rewardData.item, rewardData.amount)
    NotifyPlayer(source, 'Coupon redeemed for ' .. GetItemLabel(rewardData.item) .. '!', 'success')

    -- Webhook log
    SendWebhook(
        GetPlayerName(source),
        "Coupon Redeemed",
        "Coupon: " .. GetItemLabel(couponItem) .. " | Reward: " .. GetItemLabel(rewardData.item)
    )
end)

-- ============================================================
-- INIT
-- ============================================================
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    math.randomseed(os.time())
    RegisterUseableItems()
    print("^2[di_smoking] ^7Server initialized successfully.")
end)
