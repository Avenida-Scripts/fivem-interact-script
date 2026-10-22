fx_version "cerulean"
game "gta5"

lua54 "yes"

name        "avenida_interact"
author      "Avenida Scripts"
description "Avenida — Interact | 3D interaction points, peds, entities & dialogues | Multi-framework (ESX/QBCore/Standalone) | Tebex"
version     "1.1.0"

shared_scripts {
  -- Uncomment the line below only if you set Config.UseOxLib = true.
  -- ox_lib is NOT required: bridges/compat.lua provides a native implementation.
  -- "@ox_lib/init.lua",
  "config/config.lua",
}

client_scripts {
  "bridges/compat.lua",
  "bridges/hud.lua",
  "client/nui.lua",
  "client/hold.lua",
  "client/exports.lua",
  "client/utils.lua",
  "client/dialogue.lua",
  "client/ped.lua",
  "client/entity.lua",
  "config/entities/*.lua",
  "config/positions/*.lua",
  "config/peds/*.lua",
}

files {
  "web/build/index.html",
  "web/build/**/*"
}

ui_page "web/build/index.html"

-- Cfx escrow exemptions — these files stay readable/editable for buyers
escrow_ignore {
  "config/*.lua",
  "config/**/*.lua",
  "bridges/*.lua",
  "README.md",
  "CHANGELOG.md",
}
