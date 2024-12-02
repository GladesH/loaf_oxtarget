local functions = {}
local interactionPoints = {}

-- Générer une clé unique
function functions.GenerateUniqueKey(table)
    local key
    repeat
        key = tostring(math.random(100000, 999999))
    until not table[key]
    return key
end

-- Ajouter un point d'interaction
function functions.AddInteractionPoint(data, onSelect)    
    local pointId = functions.GenerateUniqueKey(interactionPoints)

    -- Configuration par défaut
    data.icon = data.icon or 'fas fa-bars'
    data.label = data.label or 'Interagir'
    data.distance = data.distance or 2.0
    data.size = data.size or vector3(1.5, 1.5, 2.0)
    data.rotation = data.rotation or 0.0
    data.debug = data.debug or false

    -- Configuration de l'option ox_target
    local option = {
        name = 'interaction_' .. pointId,
        icon = data.icon,
        label = data.label,
        onSelect = onSelect,
        distance = data.distance,
        canInteract = data.canInteract -- Fonction optionnelle pour vérifier si l'interaction est possible
    }

    -- Création de la zone d'interaction
    local zone = exports.ox_target:addBoxZone({
        coords = data.coords,
        size = data.size,
        rotation = data.rotation,
        debug = data.debug,
        options = {
            option
        }
    })

    interactionPoints[pointId] = {
        zoneId = zone,
        data = data,
        creator = GetInvokingResource()
    }

    return pointId
end

-- Supprimer un point d'interaction
function functions.RemoveInteractionPoint(pointId)
    if interactionPoints[pointId] then
        exports.ox_target:removeZone(interactionPoints[pointId].zoneId)
        interactionPoints[pointId] = nil
        return true
    end
    return false
end

-- Récupérer les informations d'un point d'interaction
function functions.GetInteractionPoint(pointId)
    return interactionPoints[pointId]
end

-- Récupérer tous les points d'interaction
function functions.GetInteractionPoints()
    return interactionPoints
end

-- Vérifier si un point d'interaction existe
function functions.InteractionExists(pointId)
    return interactionPoints[pointId] ~= nil
end

-- Mettre à jour les données d'un point d'interaction
function functions.UpdateInteractionPoint(pointId, newData)
    if not interactionPoints[pointId] then
        return false
    end

    -- Supprimer l'ancienne zone
    exports.ox_target:removeZone(interactionPoints[pointId].zoneId)

    -- Créer une nouvelle zone avec les données mises à jour
    local updatedData = table.merge(interactionPoints[pointId].data, newData)
    local newZone = exports.ox_target:addBoxZone({
        coords = updatedData.coords,
        size = updatedData.size,
        rotation = updatedData.rotation,
        debug = updatedData.debug,
        options = {
            {
                name = 'interaction_' .. pointId,
                icon = updatedData.icon,
                label = updatedData.label,
                onSelect = updatedData.onSelect,
                distance = updatedData.distance,
                canInteract = updatedData.canInteract
            }
        }
    })

    interactionPoints[pointId].zoneId = newZone
    interactionPoints[pointId].data = updatedData

    return true
end

-- Gestionnaire d'événements pour le nettoyage lors de l'arrêt des ressources
AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        return
    end

    local pointsRemoved = 0
    for pointId, pointData in pairs(interactionPoints) do
        if pointData.creator == resourceName then
            functions.RemoveInteractionPoint(pointId)
            pointsRemoved = pointsRemoved + 1
        end
    end

    if pointsRemoved > 0 then
        print(string.format("Removed %i interaction point%s due to resource %s stopping.", 
            pointsRemoved, 
            pointsRemoved > 1 and "s" or "", 
            resourceName
        ))
    end
end)

-- Fonction utilitaire pour fusionner des tables
function table.merge(t1, t2)
    local result = {}
    for k, v in pairs(t1) do result[k] = v end
    for k, v in pairs(t2) do result[k] = v end
    return result
end