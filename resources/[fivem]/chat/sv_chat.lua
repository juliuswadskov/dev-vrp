RegisterServerEvent('chat:init')
RegisterServerEvent('chat:addTemplate')
RegisterServerEvent('chat:addMessage')
RegisterServerEvent('chat:addSuggestion')
RegisterServerEvent('chat:removeSuggestion')
RegisterServerEvent('_chat:messageEntered')
RegisterServerEvent('chat:clear')
RegisterServerEvent('__cfx_internal:commandFallback')

RAAG = {}

AddEventHandler('_chat:messageEntered', function(author, color, message)
    if not message or not author then
        return
    end

    local source = source
	
	message = Emojit(message)
    TriggerEvent('chatMessage', source, author, message)

	
    if not WasEventCanceled() then
		TriggerEvent("vrp_chat:chatMessage", source, author, message)
    end
	
	CancelEvent()
end)

AddEventHandler('__cfx_internal:commandFallback', function(command)
    if not command then return end
	command = Emojit(command)
    local time = os.date("%H:%M")
    local local_time = "^0[" .. time .. "]"
    local name = GetPlayerName(source)

    TriggerEvent('chatMessage', source, name, '/' .. command)

    if not WasEventCanceled() then
        local args = stringsplit(command, ' ')
		RAAG.sendError(source, "Commanden /" .. string.lower(args[1]) .. " eksitere ikke")
    end
	
	CancelEvent()
end)

AddEventHandler('playerConnecting', function()
    local time = os.date("%H:%M")
    local local_time = "^0[" .. time .. "]"
    TriggerClientEvent('chatMessage', -1, local_time .. " ^4" .. GetPlayerName(source) .. " joinede serveren")
end)

AddEventHandler('playerDropped', function()
    local time = os.date("%H:%M")
    local local_time = "^0[" .. time .. "]"
    TriggerClientEvent('chatMessage', -1, local_time .. " ^4" .. GetPlayerName(source) .. " Leavede serveren")
end)

function Emojit(text)
    for i = 1, #emoji do
        for k = 1, #emoji[i][1] do
            text = string.gsub(text, emoji[i][1][k], emoji[i][2])
        end
    end
    return text
end

function stringsplit(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={} ; i=1
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        t[i] = str
        i = i + 1
    end
    return t
end

RAAG.sendError = function(source, besked)
    local time = os.date("%H:%M")
    local local_time = "^0[" .. time .. "]"
    TriggerClientEvent('chatMessage', source, local_time .. " 🦺 SYSTEM^0: " .. besked)
end