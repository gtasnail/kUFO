
cSystem = { -- very bad :)
    currentRequestId = 0,
    serverCallbacks = {},
    prefix = 'k' 
}

if IsDuplicityVersion() then 
    function cSystem.Register(name, cb)
        cSystem.serverCallbacks[name] = cb
    end

    RegisterNetEvent(cSystem.prefix .. ':triggerServerCallback')
    AddEventHandler(cSystem.prefix .. ':triggerServerCallback', function(name, requestId, ...)
        local source = source
        local callback = cSystem.serverCallbacks[name]
        
        if callback then
            callback(source, function(...)
                TriggerClientEvent(cSystem.prefix .. ':serverCallback', source, requestId, ...)
            end, ...)
        else
            print(('servers callback %s does not exist'):format(name))
        end
    end)
else 
    local cientCallbacks = {}

    RegisterNetEvent(cSystem.prefix .. ':serverCallback')
    AddEventHandler(cSystem.prefix .. ':serverCallback', function(requestId, ...)
        if cientCallbacks[requestId] then
            cientCallbacks[requestId](...)
            cientCallbacks[requestId] = nil
        end
    end)

    function cSystem.Trigger(name, cb, ...)
        cientCallbacks[cSystem.currentRequestId] = cb
        
        TriggerServerEvent(cSystem.prefix .. ':triggerServerCallback', name, cSystem.currentRequestId, ...)
        
        if cSystem.currentRequestId < 65535 then
            cSystem.currentRequestId = cSystem.currentRequestId + 1
        else
            cSystem.currentRequestId = 0
        end
    end
end

