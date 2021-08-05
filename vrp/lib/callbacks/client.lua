cCallback = {}

exports("TriggerServerCallback", function(name, args, cb)
    TriggerServerEvent("vrp-callback:TriggerServerCallback", name, args)
    while not cCallback[name] do
        Wait(1)
    end
    cb(cCallback[name])
end

RegisterNetEvent("vrp-callback:RecieveServerCallback")
AddEventHandler("vrp-callback:RecieveServerCallback", function(name, data)
    cCallback[name] = data
end)