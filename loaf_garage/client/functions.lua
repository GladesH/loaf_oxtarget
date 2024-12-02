-- passive mode (no collision)
local passive = false

RegisterNetEvent("loaf_garage:passive", function(vehicle)
    if not Config.Passive then
        return
    end

    if not passive then 
        ResetEntityAlpha(vehicle)
        for _, veh in pairs(GetGamePool("CVehicle")) do
            if veh ~= vehicle then
                ResetEntityAlpha(veh)
                SetEntityNoCollisionEntity(vehicle, veh, true)
                SetEntityNoCollisionEntity(veh, vehicle, true)
            end
        end
        return 
    end

    while passive do
        for _, veh in pairs(GetGamePool("CVehicle")) do
            if veh ~= vehicle and veh ~= GetVehiclePedIsUsing(PlayerPedId()) then
                SetEntityAlpha(veh, 153, false)
                SetEntityNoCollisionEntity(vehicle, veh, false)
                SetEntityNoCollisionEntity(veh, vehicle, false)
            end
        end
        Wait(0)
    end
end)

function TogglePassive(toggle, vehicle)
    passive = toggle == true
    TriggerEvent("loaf_garage:passive", vehicle)
end

function HasAccessGarage(garage)
    local garageData = Config.Garages[garage]
    if not garageData then return false end

    if garageData.jobs == "civ" or garageData.jobs == "all" or not garageData.jobs then
        return true
    elseif type(garageData.jobs) == "table" and IsInTable(garageData.jobs, GetJob()) then
        return true
    end

    return false
end

_G.ReloadGarages = function()
    for garage, data in pairs(Config.Garages) do
        if not HasAccessGarage(garage) then
            if data.blip then
                RemoveBlip(data.blip)
                data.blip = nil
            end
            if data.zoneStore then
                exports.ox_target:removeZone(data.zoneStore)
                data.zoneStore = nil
            end
            if data.zoneRetrieve then
                exports.ox_target:removeZone(data.zoneRetrieve)
                data.zoneRetrieve = nil
            end
            goto continue
        end

        -- Ajout du blip
        if not data.blip and not data.disableBlip then
            data.blip = AddBlipForCoord(data.retrieve.x, data.retrieve.y, data.retrieve.z)
            SetBlipSprite(data.blip, Config.Blip.garage.sprite)
            SetBlipColour(data.blip, Config.Blip.garage.color)
            SetBlipScale(data.blip, Config.Blip.garage.scale)
            SetBlipAsShortRange(data.blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(Strings["garage_blip"])
            EndTextCommandSetBlipName(data.blip)
        end

        -- Zones ox_target pour les garages style "garage" ou bateaux
        if Config.GarageStyle == "garage" or IsInTable(data.vehicleTypes, "boat") then
            if not data.zoneRetrieve then
                data.zoneRetrieve = exports.ox_target:addBoxZone({
                    coords = data.retrieve,
                    size = vector3(3.0, 3.0, 2.0),
                    rotation = 0.0,
                    debug = true, -- Mettre à true temporairement pour voir la zone
                    options = {
                        {
                            name = 'retrieve_vehicle_' .. garage,
                            icon = 'fas fa-car',
                            label = Strings["browse_vehicles"],
                            distance = 3.0, -- Augmenter la distance d'interaction
                            onSelect = function()
                                print("Tentative d'ouverture du menu garage") -- Debug
                                BrowseVehicles(garage)
                            end
                        }
                    }
                })
            end

            if not data.zoneStore then
                data.zoneStore = exports.ox_target:addBoxZone({
                    coords = data.store,
                    size = vector3(5.0, 5.0, 3.0),
                    rotation = 0.0,
                    debug = true, -- Mettre à true temporairement pour voir la zone
                    options = {
                        {
                            name = 'store_vehicle_' .. garage,
                            icon = 'fas fa-parking',
                            label = Strings["store_vehicle"],
                            distance = 3.0, -- Augmenter la distance d'interaction
                            onSelect = function()
                                print("Tentative de stockage du véhicule") -- Debug
                                StoreVehicle(garage)
                            end,
                            canInteract = function()
                                return IsPedInAnyVehicle(PlayerPedId(), false)
                            end
                        }
                    }
                })
            end
        elseif Config.GarageStyle == "parking" then
            for location, coords in pairs(data.parkingLots) do
                local name = garage .. "_" .. location
                exports.ox_target:addBoxZone({
                    coords = coords.xyz,
                    size = vector3(5.9, 3.2, 2.0),
                    rotation = coords.w,
                    debug = Config.Debug,
                    options = {
                        {
                            name = 'store_' .. name,
                            icon = 'fas fa-parking',
                            label = Strings["store_vehicle"],
                            onSelect = function()
                                local vehicle = IsPedInAnyVehicle(PlayerPedId()) and GetVehiclePedIsIn(PlayerPedId())
                                StoreVehicle(garage, vehicle)
                            end,
                            canInteract = function()
                                return IsPedInAnyVehicle(PlayerPedId())
                            end
                        },
                        {
                            name = 'retrieve_' .. name,
                            icon = 'fas fa-car',
                            label = Strings["browse_vehicles"],
                            onSelect = function()
                                BrowseVehicles(garage, coords)
                            end,
                            canInteract = function()
                                return not IsPedInAnyVehicle(PlayerPedId())
                            end
                        }
                    }
                })
            end
        end

        ::continue::
    end

    -- Fourrière
    if Config.Impound.enabled then
        for impound, data in pairs(Config.Impounds) do
            if not data.blip and not data.disableBlip then
                data.blip = AddBlipForCoord(data.retrieve.x, data.retrieve.y, data.retrieve.z)
                SetBlipSprite(data.blip, Config.Blip.impound.sprite)
                SetBlipColour(data.blip, Config.Blip.impound.color)
                SetBlipScale(data.blip, Config.Blip.impound.scale)
                SetBlipAsShortRange(data.blip, true)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(Strings["impound_blip"])
                EndTextCommandSetBlipName(data.blip)
            end

            if not data.zoneRetrieve then
                data.zoneRetrieve = exports.ox_target:addBoxZone({
                    coords = data.retrieve,
                    size = vector3(3.0, 3.0, 2.0),
                    rotation = 0.0,
                    debug = Config.Debug,
                    options = {
                        {
                            name = 'impound_' .. impound,
                            icon = 'fas fa-car',
                            label = Strings["browse_impound"],
                            onSelect = function()
                                BrowseVehicles(impound, data.spawn, true)
                            end
                        }
                    }
                })
            end
        end
    end
end

-- Fourrière
if Config.Impound.enabled then
    for impound, data in pairs(Config.Impounds) do
        if not data.blip and not data.disableBlip then
            data.blip = AddBlipForCoord(data.retrieve.x, data.retrieve.y, data.retrieve.z)
            SetBlipSprite(data.blip, Config.Blip.impound.sprite)
            SetBlipColour(data.blip, Config.Blip.impound.color)
            SetBlipScale(data.blip, Config.Blip.impound.scale)
            SetBlipAsShortRange(data.blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(Strings["impound_blip"])
            EndTextCommandSetBlipName(data.blip)
        end

        if not data.zoneRetrieve then
            data.zoneRetrieve = exports.ox_target:addBoxZone({
                coords = data.retrieve,
                size = vector3(3.0, 3.0, 2.0),
                rotation = 0.0,
                debug = Config.Debug,
                options = {
                    {
                        name = 'impound_' .. impound,
                        icon = 'fas fa-car',
                        label = Strings["browse_impound"],
                        onSelect = function()
                            BrowseVehicles(impound, data.spawn, true)
                        end
                    }
                }
            })
        end
    end
end


-- Damages functions
function SetDamages(vehicle, damages)
if not Config.SaveDamages or not DoesEntityExist(vehicle) then 
    return 
end

if damages.bodyHealth then
    SetVehicleBodyHealth(vehicle, damages.bodyHealth)
end
if damages.engineHealth then
    SetVehicleEngineHealth(vehicle, damages.engineHealth)
end
if damages.dirtLevel then
    SetVehicleDirtLevel(vehicle, damages.dirtLevel)
end
if damages.deformation and GetResourceState("VehicleDeformation") == "started" then
    exports.VehicleDeformation:SetVehicleDeformation(vehicle, damages.deformation)
end
if damages.burstTires then
    for _, v in pairs(damages.burstTires) do
        SetVehicleTyreBurst(vehicle, v, true, 1000.0)
    end
end
if damages.damagedWindows then
    for _, v in pairs(damages.damagedWindows) do
        if v == 0 then
            PopOutVehicleWindscreen(vehicle)
        end
        SmashVehicleWindow(vehicle, v)
    end
end
if damages.brokenDoors then
    for _, v in pairs(damages.brokenDoors) do
        SetVehicleDoorBroken(vehicle, v, true)
    end
end
end
function GetDamages(vehicle)
    if not Config.SaveDamages then 
        return nil 
    end

    local burstTires = {}
    for _, v in pairs({0, 1, 2, 3, 4, 5, 45, 47}) do
        if IsVehicleTyreBurst(vehicle, v, false) then
            table.insert(burstTires, v)
        end
    end

    local damagedWindows = {}
    for i = 0, 7 do
        if not IsVehicleWindowIntact(vehicle, i) then
            table.insert(damagedWindows, i)
        end
    end

    local brokenDoors = {}
    for i = 0, 5 do
        if IsVehicleDoorDamaged(vehicle, i) then
            table.insert(brokenDoors, i)
        end
    end

    local deformation
    if GetResourceState("VehicleDeformation") == "started" then
        deformation = exports.VehicleDeformation:GetVehicleDeformation(vehicle)
    end

    return {
        engineHealth = GetVehicleEngineHealth(vehicle),
        bodyHealth = GetVehicleBodyHealth(vehicle),
        dirtLevel = GetVehicleDirtLevel(vehicle),
        deformation = deformation,
        burstTires = burstTires,
        damagedWindows = damagedWindows,
        brokenDoors = brokenDoors
    }
end

-- Misc functions
function IsInTable(t, v)
    for _, value in pairs(t) do
        if value == v then
            return true
        end
    end
    return false
end

function LoadModel(model)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end
    return model
end

function FadeOut(ms)
    DoScreenFadeOut(ms or 500)
    while IsScreenFadingOut() do
        Wait(0)
    end
end

function FadeIn(ms)
    DoScreenFadeIn(ms or 500)
    while IsScreenFadingIn() do
        Wait(0)
    end
end

function CreateLocalVehicle(data, spawnLocation)
    local vehicleProperties = data.vehicle
    local model = LoadModel(vehicleProperties.model)

    local vehicle = CreateVehicle(model, spawnLocation.xyz, spawnLocation.w, false, false)
    if ESX then
        ESX.Game.SetVehicleProperties(vehicle, vehicleProperties)
    elseif QBCore then
        QBCore.Functions.SetVehicleProperties(vehicle, json.decode(data.mods))
    end
    SetVehicleOnGroundProperly(vehicle)
    if data.damages then 
        local damages = json.decode(data.damages)
        SetTimeout(250, function()
            SetVehicleFixed(vehicle)
            Wait(50)
            SetDamages(vehicle, damages)
        end)
    end

    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetVehRadioStation(vehicle, "OFF")
    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
    SetVehicleEngineOn(vehicle, true, true, true)
    SetVehicleHandbrake(vehicle, true)
    FreezeEntityPosition(vehicle, true)

    return vehicle
end

CreateThread(function()
    while not loaded do 
        Wait(500)
    end

    Config.Garages["property"] = {
        retrieve = vector3(8000.0, 8000.0, 8000.0),
        spawn = vector4(8000.0, 8000.0, 8000.0, 0.0),
        store = vector3(8000.0, 8000.0, 8000.0),

        jobs = "civ",
        vehicleTypes = {"car"},
        parkingLots = {},
        disableBlip = true
    }

    ReloadGarages()

    RegisterNetEvent("loaf_garage:ping_out", function(coords, plate)
        if not Config.PingAlreadyOut then
            return
        end
    
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, 225)
        SetBlipColour(blip, 3)
        SetBlipScale(blip, 0.8)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(plate)
        EndTextCommandSetBlipName(blip)
        SetBlipRoute(blip, true)
        Notify(Strings["ping"])

        Wait(30000)
        
        RemoveBlip(blip)
    end)
end)
