local sCallback = {}

exports("RegisterServerCallback", function(name, func)
    sCallback[name] = func
end

RegisterServerEvent("vrp-callback:TriggerServerCallback")
AddEventHandler("vrp-callback:TriggerServerCallback", function(name, args)
    local source = source
    TriggerClientEvent("vrp-callback:RecieveServerCallback", source, name, sCallback[name](table.unpack(args)))
end)