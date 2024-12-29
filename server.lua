local config = {
    ufoModel = `p_spinning_anus_s`,
    locations = {
        ['ufo1'] = {
            coords = vec4(1587.5613, 3898.0386, 77.9171, 243.8755)
        },
        ['ufo2'] = {
            coords = vec4(539.8740, 5549.1743, 828.4636, 19.9721)
        }
    }
}
local activeUFOs = {}

local function CreateStationaryUFO(ufoId)
    if not config.locations[ufoId] then
        return nil
    end

    local coords = config.locations[ufoId].coords
    local ufo = CreateObjectNoOffset(config.ufoModel, coords.x, coords.y, coords.z, true, true, false)

    activeUFOs[ufoId] = {
        entity = ufo,
        netId = NetworkGetNetworkIdFromEntity(ufo),
        startPos = vector3(coords.x, coords.y, coords.z),
        isReturning = false,
        currentPos = vector3(coords.x, coords.y, coords.z),
        chasing = false
    }
    GlobalState[ufoId] = {
        netId = activeUFOs[ufoId].netId,
        chasing = false
    }

    return ufo
end

local function DeleteAllUFOs()
    for k, v in pairs(activeUFOs) do
        if DoesEntityExist(v.entity) then
            DeleteEntity(v.entity)
        end
    end
    activeUFOs = {}
end

cSystem.Register('ufo:getActiveUFOs', function(source, cb)
    local safeUFOs = {}
    for k, v in pairs(activeUFOs) do
        safeUFOs[k] = {
            netId = v.netId,
            startPos = v.startPos,
            isReturning = v.isReturning,
            currentPos = v.currentPos
        }
    end
    cb(safeUFOs)
end)

CreateThread(function()
    for k, v in pairs(config.locations) do
        CreateStationaryUFO(k)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    DeleteAllUFOs()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    DeleteAllUFOs()
end)
RegisterNetEvent('ufo:stateChange')
AddEventHandler('ufo:stateChange', function(ufoId, state, status, playerServerId)
    if activeUFOs[ufoId] then
        if state == "chasing" and status then
            if activeUFOs[ufoId].chasingPlayer and activeUFOs[ufoId].chasingPlayer ~= playerServerId then
                return
            end
            activeUFOs[ufoId].chasingPlayer = playerServerId
            activeUFOs[ufoId].chasing = true

            CreateThread(function()
                while activeUFOs[ufoId].chasing do
                    local playerPed = GetPlayerPed(playerServerId)
                    if playerPed then
                        local playerPos = GetEntityCoords(playerPed) + vector3(0, 0, 50)
                        activeUFOs[ufoId].currentPos = playerPos

                        GlobalState[ufoId] = {
                            netId = activeUFOs[ufoId].netId,
                            chasing = true,
                            chasingPlayer = playerServerId,
                            currentPos = playerPos
                        }
                    end
                    Wait(5000)
                end
            end)

        elseif state == "chasing" and status == false then

            activeUFOs[ufoId].chasingPlayer = nil
            activeUFOs[ufoId].chasing = false
            GlobalState[ufoId] = {
                netId = activeUFOs[ufoId].netId,
                chasing = false,
                chasingPlayer = nil,
                currentPos = activeUFOs[ufoId].currentPos
            }
        end
    end
end)
