
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'lnd'


shared_script {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    '@oxmysql/lib/MySQL.lua',
}

server_script 'server/main.lua'