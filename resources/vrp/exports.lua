--[[ 
    exporter alle funktioner, så du kan bruge dem som fx.
    
    local vRP = exports.vrp
    local user_id = vRP:getUserId(source)
]]

for k,v in pairs(vRP and tvRP) do
    if type(v) == "function" then
        exports(k,v)
    end
end