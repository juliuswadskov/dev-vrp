local Proxy = module("lib/Proxy")
local Tunnel = module("lib/Tunnel")
local Luang = module("lib/Luang")
local config = module("cfg/base")
Debug = module("lib/Debug")
db = exports.ghmattimysql

vRP = {}
tvRP = {}

Proxy.addInterface("vRP", vRP)
Tunnel.bindInterface("vRP", tvRP)
vRPclient = Tunnel.getInterface("vRP", "vRP")

vRP.users = {} -- will store logged users (id) by first identifier
vRP.rusers = {} -- store the opposite of users
vRP.user_tables = {} -- user data tables (logger storage, saved to database)
vRP.user_tmp_tables = {} -- user tmp data tables (logger storage, not saved)
vRP.user_sources = {} -- user sources

local Lang = Luang()
Lang:loadLocale(config.lang, module("cfg/lang/"..config.lang) or {})
vRP.lang = Lang.lang[config.lang]

-- return user id or nil in case of error (if not found, will create it)
vRP.getUserIdByIdentifiers = function(ids)
    if ids and #ids then
        for i = 1, #ids do
            if not config.ignore_ip_identifier or (string.find(ids[i], "ip:") == nil) then
                local rows = db:executeSync("SELECT user_id FROM vrp_user_ids WHERE identifier = @identifier", {identifier = ids[i]})
                
                if #rows > 0 then -- found
                    return rows[1].user_id
                end
            end
        end
        
        -- no ids found, create user
        local rows, affected = db:executeSync("INSERT INTO vrp_users(whitelisted,banned) VALUES(false,false); SELECT LAST_INSERT_ID() AS id", {})
        
        if #rows > 0 then
            local user_id = rows[1].id
            
            for l,w in pairs(ids) do
                if not config.ignore_ip_identifier or (string.find(w, "ip:") == nil) then
                    db:execute("INSERT INTO vrp_user_ids(identifier,user_id) VALUES(@identifier,@user_id)", {user_id = user_id, identifier = w})
                end
            end
            
            return user_id
        end
    end
end

vRP.getPlayerEndpoint = function(player)
    return GetPlayerEP(player) or "0.0.0.0"
end

vRP.getPlayerName = function(player)
    return GetPlayerName(player) or "unknown"
end

vRP.isBanned = function(user_id, cbr)
    local rows = db:executeSync("SELECT banned FROM vrp_users WHERE id = @user_id", {user_id = user_id})

    if #rows > 0 then
        return rows[1].banned
    else
        return false
    end
end

vRP.setBanned = function(user_id, banned)
    db:execute("UPDATE vrp_users SET banned = @banned WHERE id = @user_id", {user_id = user_id, banned = banned})
end

vRP.isWhitelisted = function(user_id, cbr)
    local rows = db:executeSync("SELECT whitelisted FROM vrp_users WHERE id = @user_id", {user_id = user_id})

    if #rows > 0 then
        return rows[1].whitelisted
    else
        return false
    end
end

vRP.setWhitelisted = function(user_id, whitelisted)
    db:execute("UPDATE vrp_users SET whitelisted = @whitelisted WHERE id = @user_id", {user_id = user_id, whitelisted = whitelisted})
end

vRP.getLastLogin = function(user_id, cbr)
    local rows = db:executeSync("SELECT last_login FROM vrp_users WHERE id = @user_id", {user_id = user_id})

    if #rows > 0 then
        return rows[1].last_login
    else
        return ""
    end
end

vRP.setUData = function(user_id, key, value)
    db:execute("REPLACE INTO vrp_user_data(user_id,dkey,dvalue) VALUES(@user_id,@key,@value)", {user_id = user_id, key = key, value = value})
end

vRP.getUData = function(user_id, key, cbr)
    local rows = db:executeSync("SELECT dvalue FROM vrp_user_data WHERE user_id = @user_id AND dkey = @key", {user_id = user_id, key = key})

    if #rows > 0 then
        return rows[1].dvalue
    else
        return ""
    end
end

vRP.setSData = function(key, value)
    db:execute("REPLACE INTO vrp_srv_data(dkey,dvalue) VALUES(@key,@value)", {key = key, value = value})
end

vRP.getSData = function(key, cbr)
    local rows = db:executeSync("SELECT dvalue FROM vrp_srv_data WHERE dkey = @key", {key = key})

    if #rows > 0 then
        return rows[1].dvalue
    else
        return ""
    end
end

vRP.getUserDataTable = function(user_id)
    return vRP.user_tables[user_id]
end

vRP.getUserTmpTable = function(user_id)
    return vRP.user_tmp_tables[user_id]
end

-- return the player spawn count (0 = not spawned, 1 = first spawn, ...)
vRP.getSpawns = function(user_id)
    local tmp = vRP.getUserTmpTable(user_id)

    if tmp then
        return tmp.spawns or 0
    end

    return 0
end

vRP.getUserId = function(source)
    if source ~= nil then
        local ids = GetPlayerIdentifiers(source)

        if ids ~= nil and #ids > 0 then
            return vRP.users[ids[1]]
        end
    end

    return nil
end

-- return map of user_id -> player source
vRP.getUsers = function()
    local users = {}

    for k,v in pairs(vRP.user_sources) do
        users[k] = v
    end

    return users
end

-- return source or nil
vRP.getUserSource = function(user_id)
    return vRP.user_sources[user_id]
end

vRP.ban = function(source, reason)
    local user_id = vRP.getUserId(source)

    if user_id then
        vRP.setBanned(user_id, true)
        vRP.kick(source,"[Banned] "..reason)
    end
end

vRP.kick = function(source, reason)
    DropPlayer(source, reason)
end

-- drop vRP player/user (internal usage)
vRP.dropPlayer = function(source)
    local user_id = vRP.getUserId(source)
    local endpoint = vRP.getPlayerEndpoint(source)

    -- remove player from connected clients
    vRPclient.removePlayer(-1, {source})

    if user_id then
        TriggerEvent("vRP:playerLeave", user_id, source)

        -- save user data table
        vRP.setUData(user_id,"vRP:datatable",json.encode(vRP.getUserDataTable(user_id)))

        print("[vRP] "..endpoint.." disconnected (user_id = "..user_id..")")
        vRP.users[vRP.rusers[user_id]] = nil
        vRP.rusers[user_id] = nil
        vRP.user_tables[user_id] = nil
        vRP.user_tmp_tables[user_id] = nil
        vRP.user_sources[user_id] = nil
    end
end

-- tasks

task_save_datatables = function()
    SetTimeout(config.save_interval * 1000, task_save_datatables)
    TriggerEvent("vRP:save")

    Debug.log("save datatables")
    
    for k,v in pairs(vRP.user_tables) do
        vRP.setUData(k, "vRP:datatable", json.encode(v))
    end
end

Citizen.CreateThread(function()
    task_save_datatables()
end)

-- ping timeout
task_timeout = function()
    local users = vRP.getUsers()

    for k,v in pairs(users) do
        if GetPlayerPing(v) <= 0 then
            vRP.kick(v, "[vRP] Ping timeout.")
            vRP.dropPlayer(v)
        end
    end

    SetTimeout(30000, task_timeout)
end
task_timeout()

AddEventHandler("playerConnecting",function(name, setMessage, deferrals)
    deferrals.defer()

    local source = source
    Debug.log("playerConnecting "..name)
    local ids = GetPlayerIdentifiers(source)

    if ids ~= nil and #ids > 0 then
        deferrals.update("[vRP] Checking identifiers...")
        local user_id = vRP.getUserIdByIdentifiers(ids)

        if user_id then -- check user validity 
            deferrals.update("[vRP] Checking banned...")

            if not vRP.isBanned(user_id) then
                deferrals.update("[vRP] Checking whitelisted...")

                if not config.whitelist or vRP.isWhitelisted(user_id) then
                    if vRP.rusers[user_id] == nil then -- not present on the server, init
                        -- load user data table
                        deferrals.update("[vRP] Loading datatable...")
                        local sdata = vRP.getUData(user_id, "vRP:datatable")

                        -- init entries
                        vRP.users[ids[1]] = user_id
                        vRP.rusers[user_id] = ids[1]
                        vRP.user_tables[user_id] = {}
                        vRP.user_tmp_tables[user_id] = {}
                        vRP.user_sources[user_id] = source

                        local data = json.decode(sdata)

                        if type(data) == "table" then
                            vRP.user_tables[user_id] = data
                        end

                        -- init user tmp table
                        local tmpdata = vRP.getUserTmpTable(user_id)

                        deferrals.update("[vRP] Getting last login...")
                        local last_login = vRP.getLastLogin(user_id)
                        tmpdata.last_login = last_login or ""
                        tmpdata.spawns = 0

                        -- set last login
                        local ep = vRP.getPlayerEndpoint(source)
                        local last_login_stamp = os.date("%H:%M:%S %d/%m/%Y")
                        db:execute("UPDATE vrp_users SET last_login = @last_login WHERE id = @user_id", {user_id = user_id, last_login = last_login_stamp})

                        -- trigger join
                        print("[vRP] "..name.." ("..vRP.getPlayerEndpoint(source)..") joined (user_id = "..user_id..")")
                        TriggerEvent("vRP:playerJoin", user_id, source, name, tmpdata.last_login)
                        -- exports.vrp_loadingscreen:startLoadingscreen(user_id, source, deferrals)
                        deferrals.done()
                    else -- already connected
                        print("[vRP] "..name.." ("..vRP.getPlayerEndpoint(source)..") re-joined (user_id = "..user_id..")")
                        -- reset first spawn
                        local tmpdata = vRP.getUserTmpTable(user_id)
                        tmpdata.spawns = 0
                        
                        TriggerEvent("vRP:playerRejoin", user_id, source, name)
                        deferrals.done()
                        -- exports.vrp_loadingscreen:startLoadingscreen(user_id, source, deferrals)
                    end
                else
                    print("[vRP] "..name.." ("..vRP.getPlayerEndpoint(source)..") rejected: not whitelisted (user_id = "..user_id..")")
                    Citizen.Wait(1000)
                    deferrals.done("[vRP] Not whitelisted (user_id = "..user_id..").")
                end
            else
                print("[vRP] "..name.." ("..vRP.getPlayerEndpoint(source)..") rejected: banned (user_id = "..user_id..")")
                Citizen.Wait(1000)
                deferrals.done("[vRP] Banned (user_id = "..user_id..").")
            end
        else
            print("[vRP] "..name.." ("..vRP.getPlayerEndpoint(source)..") rejected: identification error")
            Citizen.Wait(1000)
            deferrals.done("[vRP] Identification error.")
        end
    else
        print("[vRP] "..name.." ("..vRP.getPlayerEndpoint(source)..") rejected: missing identifiers")
        Citizen.Wait(1000)
        deferrals.done("[vRP] Missing identifiers.")
    end
end)

-- Credit til LazeSmash#0516 for at sige hvordan man skal gør xD
AddEventHandler('onResourceStart', function()
    for k,v in ipairs(GetPlayers()) do
        local name = GetPlayerName(v)
        local ids = GetPlayerIdentifiers(v)
        local user_id = vRP.getUserIdByIdentifiers(ids)

        if user_id then 
            local sdata = vRP.getUData(user_id, "vRP:datatable")

            vRP.users[ids[1]] = user_id
            vRP.rusers[user_id] = ids[1]
            vRP.user_tables[user_id] = {}
            vRP.user_tmp_tables[user_id] = {}
            vRP.user_sources[user_id] = v

            local data = json.decode(sdata)

            if type(data) == "table" then
                vRP.user_tables[user_id] = data
            end

            local tmpdata = vRP.getUserTmpTable(user_id)
            local last_login = vRP.getLastLogin(user_id)
            tmpdata.last_login = last_login or ""
            tmpdata.spawns = 0

            print("[vRP] "..name.." ("..vRP.getPlayerEndpoint(v)..") blev loadet ind (user_id = "..user_id..")")
            TriggerEvent("vRP:playerJoin", user_id, v, name, tmpdata.last_login)
        end
    end
end)

AddEventHandler("playerDropped",function(reason)
    local source = source
    Debug.log("playerDropped "..source)

    vRP.dropPlayer(source)
end)

RegisterServerEvent("vRPcli:playerSpawned")
AddEventHandler("vRPcli:playerSpawned", function()
    Debug.log("playerSpawned "..source)
    -- register user sources and then set first spawn to false
    local user_id = vRP.getUserId(source)
    local player = source

    if user_id then
        vRP.user_sources[user_id] = source
        local tmp = vRP.getUserTmpTable(user_id)
        tmp.spawns = tmp.spawns+1
        local first_spawn = (tmp.spawns == 1)

        if first_spawn then
            -- first spawn, reference player
            -- send players to new player
            for k,v in pairs(vRP.user_sources) do
                vRPclient.addPlayer(source,{v})
            end
            -- send new player to all players
            vRPclient.addPlayer(-1, {source})

            -- set client tunnel delay at first spawn
            Tunnel.setDestDelay(player, config.load_delay)

            -- show loading
            vRPclient.setProgressBar(player, {"vRP:loading", "botright", "Loading...", 0,0,0, 100})

            SetTimeout(2000, function()
                SetTimeout(config.load_duration*1000, function() -- set client delay to normal delay
                    Tunnel.setDestDelay(player, config.global_delay)
                    vRPclient.removeProgressBar(player,{"vRP:loading"})
                end)
            end)
        end

        SetTimeout(2000, function() -- trigger spawn event
            TriggerEvent("vRP:playerSpawn", user_id, player, first_spawn)
        end)
    end
end)

RegisterServerEvent("vRP:playerDied")