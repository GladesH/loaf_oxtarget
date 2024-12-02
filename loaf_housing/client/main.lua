RegisterNetEvent("loaf_housing:set_houses", function(houses)
    while not cache.ownedHouses do
        Wait(0)
    end
    Wait(1000)

    for id, house in pairs(Houses) do
        if house.interaction then
            exports.ox_target:removeZone(house.interaction)
        end

        if house.garageInteraction then
            exports.ox_target:removeZone(house.garageInteraction.store)
            exports.ox_target:removeZone(house.garageInteraction.retrieve)
            house.garageInteraction = nil
        end

        if house.blip then
            lib.RemoveBlip(house.blip)
        end
    end
    Houses = houses
    ReloadBlips(true)
    RefreshHouseDoors()
end)

RegisterNetEvent("loaf_housing:spawn_in_property", function(propertyId, cb)
    propertyId = tonumber(propertyId)
    local propertyData = Houses[propertyId]
    if not propertyData then
        Teleport(vector4(195.17, -933.77, 29.7, 144.5))
        if cb then cb() end
        return
    end

    local stringId = tostring(propertyId)
    if not cache.ownedHouses[stringId] then
        Teleport(propertyData.entrance - vector4(0.0, 0.0, 1.0, 0.0))
    else
        EnterProperty(propertyId, cache.ownedHouses[stringId].id)
    end
    if cb then cb() end
end)

RegisterNetEvent("loaf_housing:update_houses", function(houses)
    local new_ownedHouses = {}
    local new_houses = {}
    for _, house in pairs(houses) do
        local stringId = tostring(house.propertyid)
        if house.owner == cache.identifier then
            new_ownedHouses[stringId] = house
        else
            new_houses[stringId] = house
        end
    end
    cache.ownedHouses = new_ownedHouses
    cache.houses = new_houses
    ReloadBlips()
    RefreshHouseDoors()
end)

function CreateHouseInteraction(house, id)
    local houseOptions = {
        {
            name = 'house_interaction_' .. id,
            icon = 'fas fa-home',
            label = house.type == "house" and Strings["manage_house"]:format(id) or Strings["manage_apart"]:format(id),
            onSelect = function()
                local stringId = tostring(id)
                if cache.busy then return end

                if cache.ownedHouses[stringId] then
                    OwnPropertyMenu(id)
                elseif cache.houses[stringId] and Houses[id].unique then
                    UniqueOwnedMenu(id, cache.houses[stringId].id)
                elseif not Houses[id].unique then
                    EnterPurchaseMenu(id)
                else
                    local amountProperties = 0
                    for _ in pairs(cache.ownedHouses) do
                        amountProperties = amountProperties + 1
                    end
                    if Config.MaxProperties > amountProperties then
                        PurchaseMenu(id)
                    else
                        Notify(Strings["owns_max"])
                    end
                end
            end,
            distance = 2.0
        }
    }

    return exports.ox_target:addBoxZone({
        coords = house.entrance.xyz,
        size = vector3(1.5, 1.5, 2.0),
        rotation = 45.0,
        debug = Config.Debug,
        options = houseOptions
    })
end

function CreateStorageInteraction(location, id, uniqueId, key, owner)
    local storageOptions = {
        {
            name = 'storage_interaction_' .. id .. '_' .. key,
            icon = location.storage and 'fas fa-box' or 'fas fa-tshirt',
            label = location.storage and Strings["access_storage"] or Strings["access_wardrobe"],
            onSelect = function()
                if cache.busy then return end
                StorageMenuHandler({"use", id, uniqueId, key, owner})
            end,
            distance = 2.0
        }
    }

    return exports.ox_target:addBoxZone({
        coords = location.coords,
        size = location.scale or vector3(1.5, 1.5, 2.0),
        rotation = 45.0,
        debug = Config.Debug,
        options = storageOptions
    })
end

function CreateGarageInteraction(house, id)
    if not house.garage then return nil end

    local storeOptions = {
        {
            name = 'garage_store_' .. id,
            icon = 'fas fa-parking',
            label = Strings["store_vehicle"],
            onSelect = function()
                if GetResourceState("loaf_garage") == "started" then
                    exports.loaf_garage:StoreVehicle("property", GetVehiclePedIsUsing(PlayerPedId()))
                elseif GetResourceState("cd_garage") == "started" then
                    TriggerEvent("cd_garage:StoreVehicle_Main", 1, false)
                elseif GetResourceState("jg-advancedgarages") == "started" then
                    TriggerEvent("jg-advancedgarages:client:store-vehicle", "House: "..id, "car")
                end
            end,
            distance = 3.0,
            canInteract = function()
                return IsPedInAnyVehicle(PlayerPedId(), false)
            end
        }
    }

    local retrieveOptions = {
        {
            name = 'garage_retrieve_' .. id,
            icon = 'fas fa-car',
            label = Strings["browse_vehicles"],
            onSelect = function()
                if GetResourceState("loaf_garage") == "started" then
                    exports.loaf_garage:BrowseVehicles("property", house.garage.exit)
                elseif GetResourceState("cd_garage") == "started" then
                    SetEntityCoords(PlayerPedId(), house.garage.exit.xyz - vector3(0.0, 0.0, 1.0))
                    SetEntityHeading(PlayerPedId(), house.garage.exit.w)
                    Wait(50)
                    TriggerEvent("cd_garage:PropertyGarage", "quick")
                elseif GetResourceState("jg-advancedgarages") == "started" then
                    TriggerEvent('jg-advancedgarages:client:open-garage', "House: "..id, "car", vec4(house.garage.exit))
                end
            end,
            distance = 2.0
        }
    }

    return {
        store = exports.ox_target:addBoxZone({
            coords = house.garage.exit.xyz,
            size = vector3(3.0, 3.0, 2.0),
            rotation = house.garage.exit.w,
            debug = Config.Debug,
            options = storeOptions
        }),
        retrieve = exports.ox_target:addBoxZone({
            coords = house.garage.entrance,
            size = vector3(1.5, 1.5, 2.0),
            rotation = 45.0,
            debug = Config.Debug,
            options = retrieveOptions
        })
    }
end

function RefreshGarageInteractions()
    local garageAccess = table.clone(cache.ownedHouses)
    if Config.Garage and Config.AllowGarageKey then
        local keys = exports.loaf_keysystem:GetKeys()
        for _, v in pairs(keys) do
            local _, _, propertyId = v.key_id:find("housing_key_(.*)_")
            if propertyId then
                garageAccess[propertyId] = true
            end
        end
    end

    for id, house in pairs(Houses) do
        if Config.Garage and garageAccess[tostring(id)] then
            if not house.garageInteraction then
                house.garageInteraction = CreateGarageInteraction(house, id)
            end
        else
            if house.garageInteraction then
                if house.garageInteraction.store then
                    exports.ox_target:removeZone(house.garageInteraction.store)
                end
                if house.garageInteraction.retrieve then
                    exports.ox_target:removeZone(house.garageInteraction.retrieve)
                end
                house.garageInteraction = nil
            end
        end
    end
end

function ReloadBlips(reloadInteractions)
    for id, house in pairs(Houses) do
        Wait(0)

        if house.blip then
            lib.RemoveBlip(house.blip)
        end

        -- Gestion des blips...
        if cache.ownedHouses[tostring(id)] then
            if Config.Blip.owned.enabled then
                house.blip = lib.AddBlip({
                    coords = house.entrance.xyz,
                    sprite = Config.Blip.owned.sprite,
                    color = Config.Blip.owned.color,
                    scale = Config.Blip.owned.scale,
                    category = 11,
                    label = house.type == "house" and Strings["own_house"] or Strings["own_apart"]
                })
            end
        elseif cache.houses[tostring(id)] then
            if Config.Blip.ownedOther.enabled then
                house.blip = lib.AddBlip({
                    coords = house.entrance.xyz,
                    sprite = Config.Blip.ownedOther.sprite,
                    color = Config.Blip.ownedOther.color,
                    scale = Config.Blip.ownedOther.scale,
                    category = 10,
                    label = house.type == "house" and Strings["ply_own_house"] or Strings["ply_own_apart"]
                })
            end
        else
            if Config.Blip.forSale.enabled then
                house.blip = lib.AddBlip({
                    coords = house.entrance.xyz,
                    sprite = Config.Blip.forSale.sprite,
                    color = Config.Blip.forSale.color,
                    scale = Config.Blip.forSale.scale,
                    category = 10,
                    label = house.type == "house" and Strings["purchase_house_blip"] or Strings["purchase_apart_blip"]
                })
            end
        end

        -- Gestion des interactions pour les intérieurs MLO
        if house.interiortype == "walkin" and house.locations then
            for key, location in pairs(house.locations) do
                if location.interaction then
                    exports.ox_target:removeZone(location.interaction)
                end

                if cache.ownedHouses[tostring(id)] or cache.houses[tostring(id)] then
                    local owner = (cache.ownedHouses[tostring(id)] and cache.ownedHouses[tostring(id)].owner) or cache.houses[tostring(id)].owner
                    local uniqueId = (cache.ownedHouses[tostring(id)] and cache.ownedHouses[tostring(id)].id) or cache.houses[tostring(id)].id

                    location.interaction = CreateStorageInteraction(location, id, uniqueId, key, owner)
                end
            end
        end

        -- Création/mise à jour des interactions principales
        if reloadInteractions or not house.interaction then
            if house.interaction then
                exports.ox_target:removeZone(house.interaction)
            end
            house.interaction = CreateHouseInteraction(house, id)
        end
    end

    if Config.Garage then
        RefreshGarageInteractions()
    end
end

CreateThread(function()
    if Config.BlipCommand?.Enabled then
        RegisterCommand(Config.BlipCommand.Command, function(_, args)
            if args[1] ~= "0" and args[1] ~= "1" then
                return
            end

            local enabled = args[1] == "1"

            Config.Blip.forSale.enabled = enabled
            Config.Blip.ownedOther = enabled

            ReloadBlips()
        end, false)

        TriggerEvent("chat:addSuggestion", "/" .. Config.BlipCommand.Command, Strings["blip_command"], {
            { name = Strings["blip_command_arg"], help = Strings["blip_command_arg_help"] }
        })
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if Config.BlipCommand?.Enabled then
            TriggerEvent("chat:removeSuggestion", Config.BlipCommand.Command)
        end
    end
end)