local activeUFOs = {}
local nearbyUFOs = {}

function IsUFOInNearbyTable(ufoId)
    return nearbyUFOs[ufoId] ~= nil
end

function RemoveUFOFromNearby(ufoId)
    if nearbyUFOs[ufoId] then
        nearbyUFOs[ufoId] = nil
    end
end

function HasLineOfSightToPlayer(ufoPos, playerPos)
    local retval, hit = GetShapeTestResult(StartShapeTestRay(ufoPos.x, ufoPos.y, ufoPos.z, playerPos.x, playerPos.y,
        playerPos.z, 1, 0, 0))
    return hit == 0
end

function FindNearbyUFOs()
    while true do
        if activeUFOs then
            for ufoId, ufo in pairs(activeUFOs) do
                if NetworkDoesNetworkIdExist(ufo.netId) and not IsUFOInNearbyTable(ufoId) then
                    local nearbyUFO = {
                        netId = ufo.netId,
                        entity = NetworkGetEntityFromNetworkId(ufo.netId),
                        startPos = ufo.startPos,
                        currentPos = ufo.currentPos,
                        isReturning = ufo.isReturning,
                        active = true,
                        lastSightTime = GetGameTimer(),
                        hasLineOfSight = true
                    }
                    nearbyUFOs[ufoId] = nearbyUFO
                    InitNearbyUFO(nearbyUFO, ufoId)
                end
            end
            Wait(500)
        else
            Wait(500)
        end
    end
end

local function CalculateUFOOffsets(dt)
    local time = GetGameTimer() / 1000 + timeOffset
    local wobble = math.sin(time * config.wobbleSpeed) * config.wobbleAmount
    return vector3(0, 0, wobble)
end

local function GetGroundZ(x, y, z)
    local startPos = vector3(x, y, z)
    local endPos = vector3(x, y, z - 1000.0)

    local ray = StartExpensiveSynchronousShapeTestLosProbe(startPos.x, startPos.y, startPos.z, endPos.x, endPos.y,
        endPos.z, 1, 0, 4)

    local retval, hit, endCoords = GetShapeTestResult(ray)
    return hit == 1 and endCoords.z or z - 1000.0
end

function InitNearbyUFO(ufoData, ufoId)
    CreateThread(function()
        local entity = NetworkGetEntityFromNetworkId(ufoData.netId)
        if not entity or not DoesEntityExist(entity) then
            RemoveUFOFromNearby(ufoId)
            return
        end

        SetEntityCollision(entity, false, false)
        FreezeEntityPosition(entity, true)

        local rotation = 0.0
        local previousPos = ufoData.currentPos
        local lerpSpeed = 0.015
        local beamRadius = 8.0

        local function ApplyBeamEffect(beamOrigin)
            local vehicles = GetGamePool('CVehicle')
            for _, vehicle in ipairs(vehicles) do
                local vehPos = GetEntityCoords(vehicle)
                local distance = #(vector3(beamOrigin.x, beamOrigin.y, beamOrigin.z - 50.0) - vehPos)
                if distance < beamRadius then
                    local force = 10.0
                    -- SetEntityVelocity(vehicle, 0.0, 0.0, force)
                    ApplyForceToEntity(vehicle, 1, 0, 0, force * 100, 0, 0, 0, 0, 0, 0, 0, 0, 0)

                else
                    SetVehicleGravity(vehicle, true)
                end
            end
            local peds = GetGamePool('CPed')
            for _, ped in ipairs(peds) do
                if not IsPedAPlayer(ped) then
                    local pedPos = GetEntityCoords(ped)
                    local distance = #(vector3(beamOrigin.x, beamOrigin.y, beamOrigin.z) - pedPos)

                    if distance < beamRadius then

                        SetPedToRagdoll(ped, 1000, 1000, 0, true, true, false)
                        local force = 2.0 * (1.0 - distance / beamRadius)
                        SetEntityVelocity(ped, 0.0, 0.0, force)
                    end
                end
            end
        end

        while DoesEntityExist(entity) and NetworkDoesNetworkIdExist(ufoData.netId) do
            if not nearbyUFOs[ufoId] then
                break
            end

            -- DrawWireframeBox(entity)
            local currentUFO = nearbyUFOs[ufoId]

            if currentUFO.chasing and currentUFO.chasingPlayer then
                local playerPed = GetPlayerPed(GetPlayerFromServerId(currentUFO.chasingPlayer))

                if DoesEntityExist(playerPed) then
                    local playerPos = GetEntityCoords(playerPed)
                    local ufoPos = GetEntityCoords(entity)
                    local hasLineOfSight = HasLineOfSightToPlayer(ufoPos, playerPos)

                    if hasLineOfSight then
                        currentUFO.lastSightTime = GetGameTimer()
                        currentUFO.hasLineOfSight = true
                    else
                        local timeSinceLastSight = GetGameTimer() - currentUFO.lastSightTime
                        if timeSinceLastSight > 1000 then
                            currentUFO.chasing = false
                            currentUFO.chasingPlayer = nil
                            TriggerServerEvent('ufo:stateChange', ufoId, 'chasing', false, currentUFO.chasingPlayer)
                            currentUFO.hasLineOfSight = false
                        end
                    end

                    if currentUFO.hasLineOfSight then
                        local targetPos = playerPos + vector3(0, 0, 50)

                        if previousPos and targetPos then
                            previousPos = vector3(Lerp(previousPos.x, targetPos.x, lerpSpeed),
                                Lerp(previousPos.y, targetPos.y, lerpSpeed), Lerp(previousPos.z, targetPos.z, lerpSpeed))

                            if DoesEntityExist(entity) then
                                SetEntityCoordsNoOffset(entity, previousPos.x, previousPos.y, previousPos.z, true, true,
                                    true)
                                local groundZ = GetGroundZ(previousPos.x, previousPos.y, previousPos.z)

                                if NetworkDoesNetworkIdExist(ufoData.netId) then
                                    DrawMarker(1, previousPos, vec3(0, 0, 0), vec3(0, 180.0, 0), beamRadius * 2,
                                        beamRadius * 2, 55.0, 0, 255, 200, 100, false, false, 0, false, 0, 0, 0)
                                    DrawLightWithRange(previousPos.x, previousPos.y, previousPos.z - 5.0, 0, 255, 200,
                                        10.0, 20.0)
                                    DrawLightWithRange(previousPos.x, previousPos.y, groundZ + 0.5, 0, 255, 200, 10.0,
                                        20.0)

                                    ApplyBeamEffect(previousPos)
                                end
                            end
                        end
                    end
                end
            else
                if DoesEntityExist(entity) and previousPos then
                    SetEntityCoordsNoOffset(entity, previousPos.x, previousPos.y, previousPos.z, true, true, true)
                end
            end

            local playerPed = PlayerPedId()
            if DoesEntityExist(playerPed) and DoesEntityExist(entity) then
                local playerPos = GetEntityCoords(playerPed)
                local ufoPos = GetEntityCoords(entity)
                local distance = #(ufoPos - playerPos)
                local playerServerId = GetPlayerServerId(PlayerId())

                if distance < 200.0 and not currentUFO.chasing then
                    if (not activeUFOs[ufoId].chasingPlayer or activeUFOs[ufoId].chasingPlayer == playerServerId) and
                        HasLineOfSightToPlayer(ufoPos, playerPos) then
                        currentUFO.chasing = true
                        currentUFO.chasingPlayer = playerServerId
                        currentUFO.lastSightTime = GetGameTimer()
                        currentUFO.hasLineOfSight = true
                        TriggerServerEvent('ufo:stateChange', ufoId, 'chasing', true, playerServerId)
                    end
                elseif distance >= 200.0 and currentUFO.chasing and currentUFO.chasingPlayer == playerServerId then
                    currentUFO.chasing = false
                    currentUFO.chasingPlayer = nil
                    currentUFO.hasLineOfSight = false
                    TriggerServerEvent('ufo:stateChange', ufoId, 'chasing', false, playerServerId)
                end
            end

            if not NetworkDoesNetworkIdExist(currentUFO.netId) then
                break
            end

            if DoesEntityExist(entity) then
                rotation = (rotation + 0.2) % 360.0
                SetEntityRotation(entity, 0.0, 0.0, rotation, 2, true)
            end

            Wait(0)
        end

        RemoveUFOFromNearby(ufoId)
    end)
end

function Lerp(a, b, t)
    return a + (b - a) * t
end

CreateThread(function()
    cSystem.Trigger('ufo:getActiveUFOs', function(ufos)
        activeUFOs = ufos
    end)
    while next(activeUFOs) == nil do
        Wait(10)
    end

    --[[    while true do
        for k,v in pairs(activeUFOs) do
            if NetworkDoesNetworkIdExist(v.netId) then
                print(DoesEntityExist(NetToObj(v.netId)))
            end
        end
        Wait(0)
    end]]
    FindNearbyUFOs()
end)

AddStateBagChangeHandler(nil, 'global', function(bagName, key, value)
    local ufoId = key
    if activeUFOs[ufoId] then
        activeUFOs[ufoId].chasing = value.chasing
        activeUFOs[ufoId].currentPos = value.currentPos
        activeUFOs[ufoId].chasingPlayer = value.chasingPlayer

        if nearbyUFOs[ufoId] then
            nearbyUFOs[ufoId].chasing = value.chasing
            nearbyUFOs[ufoId].currentPos = value.currentPos
            nearbyUFOs[ufoId].chasingPlayer = value.chasingPlayer
        end
    end
end)
