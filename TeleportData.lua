local _, addon = ...
local L = addon.L or {}

-- Backgrounds for each expansion
local mapExpansionToBackground = {
    [L["Current Season"]] = "Interface\\AddOns\\DungeonTeleports\\Images\\WarWithinS2.tga",
    [L["Cataclysm"]] = "Interface\\AddOns\\DungeonTeleports\\Images\\Cataclysm.tga",
    [L["Mists of Pandaria"]] = "Interface\\AddOns\\DungeonTeleports\\Images\\MoP.tga",
    [L["Warlords of Draenor"]] = "Interface\\AddOns\\DungeonTeleports\\Images\\WoD.tga",
    [L["Legion"]] = "Interface\\AddOns\\DungeonTeleports\\Images\\Legion.tga",
    [L["Battle for Azeroth"]] = "Interface\\AddOns\\DungeonTeleports\\Images\\BattleForAzeroth.tga",
    [L["Shadowlands"]] = "Interface\\AddOns\\DungeonTeleports\\Images\\Shadowlands.tga",
    [L["Dragonflight"]] = "Interface\\AddOns\\DungeonTeleports\\Images\\Dragonflight.tga",
    [L["The War Within"]] = "Interface\\AddOns\\DungeonTeleports\\Images\\WarWithin.tga",
}

local mapExpansionToMapID = {
    -- Season 1 TWW
    [L["Current Season"]] = {802, 804, 808, 809, 811, 604, 609, 812},
    [L["Cataclysm"]] = {101, 102, 103},
    [L["Mists of Pandaria"]] = {201, 202, 203, 204, 205, 206, 207, 208, 209},
    [L["Warlords of Draenor"]] = {301, 302, 303, 304, 305, 306, 307, 308},
    [L["Legion"]] = {401, 402, 403, 404, 405, 406},
    [L["Battle for Azeroth"]] = {501, 502, 503, 504, 505, 506, 507},
    [L["Shadowlands"]] = {601, 602, 603, 604, 605, 606, 607, 608, 609, 610, 611, 612},
    [L["Dragonflight"]] = {701, 702, 703, 704, 705, 706, 707, 708, 709, 710, 711, 712},
    [L["The War Within"]] = {801, 802, 803, 804, 805, 806, 807, 808, 809, 810},
}


-- Map IDs to Dungeon Names
local mapIDtoDungeonName = {
    [101] = L["DUNGEON_VORTEX_PINNACLE"],
    [102] = L["DUNGEON_THRONE_OF_THE_TIDES"],
    [103] = L["DUNGEON_GRIM_BATOL"],
    [201] = L["DUNGEON_TEMPLE_OF_THE_JADE_SERPENT"],
    [202] = L["DUNGEON_SIEGE_OF_NIUZAO"],
    [203] = L["DUNGEON_SCHOLOMANCE"],
    [204] = L["DUNGEON_SCARLET_MONASTERY"],
    [205] = L["DUNGEON_SCARLET_HALLS"],
    [206] = L["DUNGEON_GATE_OF_THE_SETTING_SUN"],
    [207] = L["DUNGEON_MOGUSHAN_PALACE"],
    [208] = L["DUNGEON_SHADO_PAN_MONASTERY"],
    [209] = L["DUNGEON_STORMSTOUT_BREWERY"],
    [301] = L["DUNGEON_SHADOWMOON_BURIAL_GROUNDS"],
    [302] = L["DUNGEON_EVERBLOOM"],
    [303] = L["DUNGEON_BLOODMAUL_SLAG_MINES"],
    [304] = L["DUNGEON_AUCHINDOUN"],
    [305] = L["DUNGEON_SKYREACH"],
    [306] = L["DUNGEON_UPPER_BLACKROCK_SPIRE"],
    [307] = L["DUNGEON_GRIMRAIL_DEPOT"],
    [308] = L["DUNGEON_IRON_DOCKS"],
    [401] = L["DUNGEON_DARKHEART_THICKET"],
    [402] = L["DUNGEON_BLACK_ROOK_HOLD"],
    [403] = L["DUNGEON_HALLS_OF_VALOR"],
    [404] = L["DUNGEON_NELTHARIONS_LAIR"],
    [405] = L["DUNGEON_COURT_OF_STARS"],
    [406] = L["DUNGEON_KARAZHAN"],
    [501] = L["DUNGEON_ATALDAZAR"],
    [502] = L["DUNGEON_FREEHOLD"],
    [503] = L["DUNGEON_WAYCREST_MANOR"],
    [504] = L["DUNGEON_THE_UNDERROT"],
    [505] = L["DUNGEON_MECHAGON"],
    [506] = L["DUNGEON_SEIGE_OF_BORALUS"],
    [507] = L["DUNGEON_THE_MOTHERLODE"],
    [601] = L["DUNGEON_THE_NECROTIC_WAKE"],
    [602] = L["DUNGEON_PLAGUEFALL"],
    [603] = L["DUNGEON_MISTS_OF_TIRNA_SCITHE"],
    [604] = L["DUNGEON_HALLS_OF_ATONEMENT"],
    [605] = L["DUNGEON_SPIRES_OF_ASCENSION"], 
    [606] = L["DUNGEON_THEATRE_OF_PAIN"],
    [607] = L["DUNGEON_DE_OTHER_SIDE"],
    [608] = L["DUNGEON_SANGUINE_DEPTHS"],
    [609] = L["DUNGEON_TAZAVESH_THE_VEILED_MARKET"],
    [610] = L["RAID_CASTLE_NATHRIA"],
    [611] = L["RAID_SANCTUM_OF_DOMINATION"],
    [612] = L["RAID_SEPULCHER_OF_THE_FIRST_ONES"],
    [701] = L["DUNGEON_RUBY_LIFE_POOLS"],
    [702] = L["DUNGEON_NOKHUD_OFFENSIVE"],
    [703] = L["DUNGEON_AZURE_VAULT"],
    [704] = L["DUNGEON_ALGETHAR_ACADEMY"],
    [705] = L["DUNGEON_ULDAMAN"],
    [706] = L["DUNGEON_NELTHARUS"],
    [707] = L["DUNGEON_BRACKENHIDE_HOLLOW"],
    [708] = L["DUNGEON_HALLS_OF_INFUSION"],
    [709] = L["DUNGEON_DAWN_OF_THE_INFINITE"],
    [710] = L["RAID_VAULT_OF_THE_INCARNATES"],
    [711] = L["RAID_ABBERUS_THE_SHADOWED_CRUCIBLE"],
    [712] = L["RAID_AMIRDRASSIL_THE_DREAMS_HOPE"],
    [801] = L["DUNGEON_CITY_OF_THREADS"],
    [802] = L["DUNGEON_ARA_KARA_CITY_OF_ECHOS"],
    [803] = L["DUNGEON_STONEVAULT"],
    [804] = L["DUNGEON_DAWNBREAKER"],
    [805] = L["DUNGEON_THE_ROOKERY"],
    [806] = L["DUNGEON_DARKFLAME_CLEFT"],
    [807] = L["DUNGEON_CINDERBREW_BREWERY"],
    [808] = L["DUNGEON_PRIORY_OF_THE_SACRED_FLAME"],
    [809] = L["DUNGEON_OPERATION_FLOODGATE"],
    [810] = L["RAID_LIBERATION_UNDERMINE"],
    [811] = L["DUNGEON_ECHO_DOME"],
    [812] = L["RAID_MANAFORGE_OMEGA"],

    -- Add more as needed...
}

-- Mapping Map IDs to Teleport Spells
local mapIDtoSpellID = {
    [101] = 410080, -- The Vortex Pinnacle
    [102] = 424142, -- Throne of the Tide
    [103] = 445424, -- Grim Batol
    [201] = 131204,  -- Jade Serpent
    [202] = 131228, -- Siege of Niuzao
    [203] = 131232, -- Scholomance
    [204] = 131229, -- Scarlet Monastery
    [205] = 131231, -- Scarlet Halls
    [206] = 131225, -- Gate of the Setting Sun
    [207] = 131222, -- Mogu'Shan Palance
    [208] = 131206, -- Shado-Pan Monastery
    [209] = 131205, -- Stormstout Brewery
    [301] = 159899, -- Shadowmoon Burial Grounds
    [302] = 159901, -- Everbloom
    [303] = 159895, -- Bloodmaul Slag Mines
    [304] = 159897, -- Auchindoun
    [305] = 159898, -- Skyreach
    [306] = 159902, -- Upper Blackrock Spire
    [307] = 159900, -- Grimrail Depot
    [308] = 159896, -- Iron Docks
    [401] = 424163, -- Darkheart Thicket
    [402] = 424153, -- Black Rook Hold
    [403] = 393764, -- Halls of Valor
    [404] = 410078, -- Neltharions Lair
    [405] = 393766, -- Court of Starts
    [406] = 373262, -- Karazhan
    [501] = 424187, -- Atal'Dazar
    [502] = 410071, -- Freehold
    [503] = 424167, -- Waycrest
    [504] = 410074, -- Underrot
    [505] = 373274, -- Operation: Mechagon
    [506] = 0,      -- Siege of Boralus (faction-specific, 0 is a placeholder for the real SpellID)
    [507] = 0, -- The Motherlode (Path of the Azerite Refinery)
    [601] = 354462, -- The Necrotic Wake
    [602] = 354463, -- Plaguefall
    [603] = 354464, -- Mists of Tirna Scithe
    [604] = 354465, -- Halls of Attonement
    [605] = 354466, -- Spires of Ascension 
    [606] = 354467, -- Theatre of Pain
    [607] = 354468, -- De Other Side
    [608] = 354469, -- Sanguine Depths
    [609] = 367416, -- Tazavesh, the Veiled Market
    [610] = 373190, -- Castle Nathria
    [611] = 373191, -- Sanctum of Domination
    [612] = 373192, -- Sepulcher of the First Ones
    [701] = 393256, -- Ruby Life Pools
    [702] = 393262, -- Nokhud Offensive
    [703] = 393279, -- Azure Vault
    [704] = 393273, -- Algethar Academy
    [705] = 393222, -- Uldaman
    [706] = 393276, -- Neltharus
    [707] = 393267, -- Brackenhide Hollow
    [708] = 393283, -- Halls of Infusion
    [709] = 424197, -- Dawn of the Infinite
    [710] = 432254, -- Vault of the Incarnates
    [711] = 432257, -- Abberus, the Shadowed Crucible
    [712] = 432258, -- Amirdrassil, the Dream's Hope
    [801] = 445416, -- City of Threads
    [802] = 445417, -- Ara-Kara, City of Echoes
    [803] = 445269, -- Stonevault
    [804] = 445414, -- Dawnbreaker
    [805] = 445443, -- The Rookery
    [806] = 445441, -- Darkflame Cleft
    [807] = 445440, -- Cinderbrew Brewery
    [808] = 445444, -- Priory of the Sacred Flame
    [809] = 1216786, -- Operation: Floodgate (Path of the Circuit Breaker)
    [810] = 1226482, -- Liberation of Undermine
    [811] = 1237124, -- Eco-Dome, Al'dani
    [812] = 1239155, -- Manaforge Omega

    -- Add more as needed...
}

-- Export the constants
addon.constants = {
    mapIDtoDungeonName = mapIDtoDungeonName,
    mapExpansionToMapID = mapExpansionToMapID,
    mapIDtoSpellID = mapIDtoSpellID,
    mapExpansionToBackground = mapExpansionToBackground,
    orderedExpansions = {
    L["Current Season"],
    L["Cataclysm"],
    L["Mists of Pandaria"],
    L["Warlords of Draenor"], 
    L["Legion"],
    L["Battle for Azeroth"],
    L["Shadowlands"],
    L["Dragonflight"],
    L["The War Within"]
}

}
