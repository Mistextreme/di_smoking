fx_version 'cerulean'
lua54 'yes'
game 'gta5'

author 'DOTINIT SCRIPTS'
description 'Advanced Cigarette & Smoking System'
version '1.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    'server/server.lua',
    'server/webhook.lua'
}

dependencies {
    'es_extended',
    'ox_lib'
}

escrow_ignore {
    'shared/config.lua',
    'server/webhook.lua'
}
