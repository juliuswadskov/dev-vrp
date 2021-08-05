fx_version 'cerulean'
game 'common'

name 'ghmattimysql'
description 'MySQL Middleware for fivem using mysql.js.'
author 'Matthias Mandelartz'
version '1.3.2'
url 'https://github.com/GHMatti/ghmattimysql'

server_scripts {
  'server.js',
  'server.lua',
  'save/server.lua',
}

client_script 'save/client.lua'