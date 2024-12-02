local activeTargets = {}

if Config.FurnishCommand.Enabled then
    RegisterCommand(Config.FurnishCommand.Command, function()
        local instance = cache.currentInstance

        if not instance then
            return
        end

        local allowedFurnish = Config.Furnish == "all" or cache.identifier == instance.owner
        if not allowedFurnish and Config.Furnish == "key" then
            allowedFurnish = exports.loaf_keysystem:HasKey(GetKeyName(instance.property, instance.id))
        end

        if allowedFurnish then
            SelectFurnitureMenu()
        end
    end)
end

function InstanceInteraction()
    if not cache.busy then 
        OpenInstanceMenu()
    end
end

function Teleport(coords)
    for i = 1, 25 do
        SetEntityCoords(PlayerPedId(), coords.xyz)
        Wait(50)
    end
    while IsEntityWaitingForWorldCollision(PlayerPedId()) do
        SetEntityCoords(PlayerPedId(), coords.xyz)
        Wait(50)
    end
    if type(coords) == "vector4" then
        SetEntityHeading(PlayerPedId(), coords.w)
    end
end

function StorageMenuHandler(data)
    local propertyId, uniqueId, furnitureId, owner = table.unpack(data)

    if Config.Inventory == "ox" then
        if Config.RequireKeyStorage then
            if not exports.loaf_keysystem:HasKey(GetKeyName(propertyId, uniqueId)) then
                return
            end
        end
        exports.ox_inventory:setStashTarget(propertyId .. "_" .. uniqueId .. "_" .. furnitureId, owner)
    end

    ChooseStorageMenu(propertyId, uniqueId, furnitureId, owner)
end

function ClearAllTargetZones()
    for _, targetId in ipairs(activeTargets) do
        if targetId then
            exports.ox_target:removeZone(targetId)
        end
    end
    activeTargets = {}
end
function LoadFurniture()
    RemoveInteractableFurniture("REMOVE_ALL")
    DeleteFurniture()
    cache.spawnedFurniture = {}
    for k, v in pairs(cache.currentInstance.furniture) do
        local coords = vector3(v.offset.x, v.offset.y, v.offset.z)
        if cache.shell then
            coords = GetOffsetFromEntityInWorldCoords(cache.shell, coords)
        end

        local toInsert = {
            coords = coords,
            id = k,
            data = v
        }

        if v.items or v.item == "NOT_AN_ITEM" then
            local propertyId = cache.currentInstance.property
            local uniqueId = cache.currentInstance.id
            local furnitureId = k
            local owner = cache.currentInstance.owner

            local targetId = exports.ox_target:addBoxZone({
                coords = coords,
                size = vector3(2.0, 2.0, 2.0),
                rotation = 0.0,
                debug = Config.Debug,
                options = {
                    {
                        name = 'storage_' .. k,
                        icon = v.items and 'fas fa-box' or 'fas fa-tshirt',
                        label = v.items and Strings["access_storage"] or Strings["access_wardrobe"],
                        distance = 2.0,
                        onSelect = function()
                            StorageMenuHandler({propertyId, uniqueId, furnitureId, owner})
                        end
                    }
                }
            })
            
            table.insert(activeTargets, targetId)
            toInsert.targetId = targetId
        end

        if v.item ~= "NOT_AN_ITEM" then
            local object = SpawnFurniture(v.item, coords)
            if object ~= nil then
                FreezeEntityPosition(object, true)
                SetEntityCoordsNoOffset(object, coords)
                SetEntityHeading(object, v.offset.h)
                if v.offset.tilt then
                    SetEntityRotation(object, v.offset.tilt, 0.0, v.offset.h, 2, true)
                end

                toInsert.object = object
                LoadInteractableFurniture(object, v.item, k)

                local _, _, furnitureData = FindFurniture(v.item)
                if furnitureData then
                    if furnitureData.attached then
                        toInsert.attached = {}
                        for k, v in pairs(furnitureData.attached) do
                            local attached = SpawnFurniture(v.object, coords)
                            if DoesEntityExist(attached) then
                                FreezeEntityPosition(attached, true)
                                AttachEntityToEntity(attached, object, 0, v.offset.xyz, vector3(0.0, 0.0, v.offset.w), false, false, false, false, 2, true)
                                table.insert(toInsert.attached, attached)
                            end
                        end
                    end
                end
            end
        end

        table.insert(cache.spawnedFurniture, toInsert)
    end
end

function DeleteFurniture()
    if not cache.spawnedFurniture then return end
    
    ClearAllTargetZones()
    
    for k, v in pairs(cache.spawnedFurniture) do
        if v.object then DeleteEntity(v.object) end
        if v.attached then
            for _, attached in pairs(v.attached) do
                DeleteEntity(attached)
            end
        end
    end
    cache.spawnedFurniture = {}
end
local weatherSyncScripts = {
    "qb-weathersync",
    "cd_easytime"
}

RegisterNetEvent("loaf_housing:weather_sync", function()
    if not cache.shell then
        return
    end

    local previousWind = GetWindSpeed()

    TriggerEvent("ToggleWeatherSync", false)
    TriggerEvent("qb-weathersync:client:DisableSync")
    TriggerEvent("cd_easytime:PauseSync", true)

    local hasWeathersync = false
    for _, script in pairs(weatherSyncScripts) do
        if GetResourceState(script) == "started" then
            hasWeathersync = true
        end
    end

    while cache.inInstance do
        if hasWeathersync then
            Wait(500)
        else
            Wait(0)
            SetWeather()
        end
    end

    Wait(1000)
    SetWindSpeed(previousWind)

    TriggerEvent("ToggleWeatherSync", true)
    TriggerEvent("qb-weathersync:client:EnableSync")
    TriggerEvent("cd_easytime:PauseSync", false)
end)

RegisterNetEvent("loaf_housing:refresh_furniture", function(newFurniture)
    if not cache.currentInstance then return end
    cache.currentInstance.furniture = newFurniture
    LoadFurniture()
end)

function ExitInstance()
    DeleteFurniture()

    if cache.shell then
        local shell = cache.shell
        SetTimeout(750, function()
            DeleteEntity(shell)
        end)
    end

    TriggerServerEvent("loaf_housing:exit_property", cache.currentInstance.instanceid)
    for _, targetId in pairs(activeTargets) do
        exports.ox_target:removeZone(targetId)
    end
    activeTargets = {}

    cache.inInstance = false
    cache.shell = nil
    cache.spawnedFurniture = nil
    cache.currentInstance = nil
    cache.busy = false
end

function RefreshConceal()
    local currentInstance = LocalPlayer.state.loaf_housing_instance
    for _, player in pairs(GetActivePlayers()) do
        local instance = Player(GetPlayerServerId(player)).state.loaf_housing_instance
        local shouldConceal = (instance and instance ~= currentInstance and player ~= PlayerId()) or false
        NetworkConcealPlayer(player, shouldConceal)
    end
end

AddStateBagChangeHandler("loaf_housing_instance", nil, function(bagName, key, value)
    if bagName:sub(1, #"player:") ~= "player:" then
        return
    end

    local source = tonumber(bagName:sub(#"player:" + 1, #bagName))
    if source == GetPlayerServerId(PlayerId()) then
        return
    end

    local playerId = GetPlayerFromServerId(source)
    local timer = GetGameTimer() + 10000
    while not playerId and timer > GetGameTimer() do
        Wait(250)
        playerId = GetPlayerFromServerId(source)
    end
    Wait(1000)

    local instance = value
    local currentInstance = LocalPlayer.state.loaf_housing_instance
    local shouldConceal = (instance and instance ~= currentInstance) or false

    NetworkConcealPlayer(playerId, shouldConceal)
end)
RegisterNetEvent("loaf_housing:enter_instance", function(data)
    CloseMenu()

    cache.inInstance = true
    cache.currentInstance = data
    cache.busy = true

    local doorHeading, doorPosition = -1.0
    local housedata = Houses[data.property]

    if data.shell then
        local shell = Shells[data.shell]
        if not shell then
            ExitInstance()
            return print("^1SHELL "..data.shell.." DOES NOT EXIST")
        end
        local shell_model = lib.LoadModel(shell.object)
        if not shell_model.success then
            ExitInstance()
            Notify(Strings["couldnt_load"]:format(data.shell))
            return
        end

        cache.shell = CreateObject(shell_model.model, data.coords.xyz, false, false, false)
        SetEntityHeading(cache.shell, 0.0)
        FreezeEntityPosition(cache.shell, true)

        doorPosition = GetOffsetFromEntityInWorldCoords(cache.shell, shell.doorOffset)
        if shell.doorHeading then
            doorHeading = shell.doorHeading
        end
    elseif data.interior then
        if data.interior.ipl then
            RequestIpl(data.interior.ipl)
            while not IsIplActive(data.interior.ipl) do
                Wait(250)
            end
        end

        doorPosition = data.interior.coords
        if data.interior.heading then
            doorHeading = data.interior.heading
        end
    end

    -- Ajout de l'interaction ox_target pour la porte
    local exitTarget = exports.ox_target:addBoxZone({
        coords = vector3(doorPosition.x, doorPosition.y - 0.5, doorPosition.z + 1.5), -- Position beaucoup plus haute
        size = vector3(2.0, 2.0, 3.0), -- Zone très haute pour être sûr
        rotation = doorHeading,
        options = {
            {
                name = 'exit_interaction',
                icon = 'fas fa-sign-out-alt',
                label = housedata.type == "house" and Strings["manage_house"]:format(data.property) or Strings["manage_apart"]:format(data.property),
                onSelect = InstanceInteraction,
                distance = 2.0
            }
        }
    })
    table.insert(activeTargets, doorTarget)

    TriggerEvent("qb-anticheat:client:ToggleDecorate", true)
    SetEntityVisible(PlayerPedId(), false, 0)
    SetEntityInvincible(PlayerPedId(), true)

    DoScreenFadeOut(750)
    while not IsScreenFadedOut() do Wait(0) end

    RefreshConceal()
    TriggerEvent("loaf_housing:weather_sync")
    TriggerEvent("loaf_housing:entered_property", data.property, Houses[data.property], data)

    Teleport(doorPosition)
    SetEntityHeading(PlayerPedId(), doorHeading)

    SetFocusPosAndVel(Config.FurnitureStore.Interior, 0.0, 0.0, 0.0)
    Wait(2500)
    ClearFocus()

    TriggerEvent("loaf_housing:refresh_furniture", cache.currentInstance.furniture)

    DoScreenFadeIn(500)

    TriggerEvent("qb-anticheat:client:ToggleDecorate", false)
    SetEntityVisible(PlayerPedId(), true, 0)
    SetTimeout(500, function()
        SetEntityInvincible(PlayerPedId(), false)
    end)

    while cache.inInstance do
        if #(GetEntityCoords(PlayerPedId()) - doorPosition) > 100.0 then
            SetEntityCoords(PlayerPedId(), doorPosition)
        end
        Wait(500)
    end

    TriggerEvent("qb-anticheat:client:ToggleDecorate", true)
    SetEntityVisible(PlayerPedId(), false, 0)
    SetEntityInvincible(PlayerPedId(), true)

    ExitInstance()

    CloseMenu()

    DoScreenFadeOut(750)
    while not IsScreenFadedOut() do Wait(0) end

    Teleport(housedata.entrance - vector4(0.0, 0.0, 1.0, 0.0))
    DoScreenFadeIn(500)

    TriggerEvent("qb-anticheat:client:ToggleDecorate", false)
    SetEntityVisible(PlayerPedId(), true, 0)
    SetTimeout(500, function()
        SetEntityInvincible(PlayerPedId(), false)
    end)
end)

RegisterNetEvent("loaf_housing:exit_instance", function()
    cache.inInstance = false
    ClearAllTargetZones()
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    DeleteFurniture()
    ClearAllTargetZones()
    if cache.shell then
        DeleteEntity(cache.shell)
        Teleport(Houses[cache.currentInstance.property].entrance - vec4(0.0, 0.0, 1.0, 0.0))
    end
end)