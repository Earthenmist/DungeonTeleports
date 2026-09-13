local _, addon = ...

-- Internal catalog IDs are preserved for saved expansion selections.
-- instanceMapID, journalInstanceID, and challengeMapIDs are distinct Blizzard IDs.
local destinations = {
  [1] = { instanceMapID = 658, journalInstanceID = 278, challengeMapIDs = {556} }, -- Pit of Saron
  [101] = { instanceMapID = 657, journalInstanceID = 68, challengeMapIDs = {438} }, -- The Vortex Pinnacle
  [102] = { instanceMapID = 643, journalInstanceID = 65, challengeMapIDs = {456} }, -- Throne of the Tides
  [103] = { instanceMapID = 670, journalInstanceID = 71, challengeMapIDs = {507} }, -- Grim Batol
  [201] = { instanceMapID = 960, journalInstanceID = 313, challengeMapIDs = {2} }, -- Temple of the Jade Serpent
  [202] = { instanceMapID = 1011, journalInstanceID = 324, challengeMapIDs = {59} }, -- Siege of Niuzao Temple
  [203] = { instanceMapID = 1007, journalInstanceID = 246, challengeMapIDs = {76} }, -- Scholomance
  [204] = { instanceMapID = 1004, journalInstanceID = 316, challengeMapIDs = {78} }, -- Scarlet Monastery
  [205] = { instanceMapID = 1001, journalInstanceID = 311, challengeMapIDs = {77} }, -- Scarlet Halls
  [206] = { instanceMapID = 962, journalInstanceID = 303, challengeMapIDs = {57} }, -- Gate of the Setting Sun
  [207] = { instanceMapID = 994, journalInstanceID = 321, challengeMapIDs = {60} }, -- Mogu'shan Palace
  [208] = { instanceMapID = 959, journalInstanceID = 312, challengeMapIDs = {58} }, -- Shado-Pan Monastery
  [209] = { instanceMapID = 961, journalInstanceID = 302, challengeMapIDs = {56} }, -- Stormstout Brewery
  [301] = { instanceMapID = 1176, journalInstanceID = 537, challengeMapIDs = {165} }, -- Shadowmoon Burial Grounds
  [302] = { instanceMapID = 1279, journalInstanceID = 556, challengeMapIDs = {168} }, -- The Everbloom
  [303] = { instanceMapID = 1175, journalInstanceID = 385, challengeMapIDs = {163} }, -- Bloodmaul Slag Mines
  [304] = { instanceMapID = 1182, journalInstanceID = 547, challengeMapIDs = {164} }, -- Auchindoun
  [305] = { instanceMapID = 1209, journalInstanceID = 476, challengeMapIDs = {161} }, -- Skyreach
  [306] = { instanceMapID = 1358, journalInstanceID = 559, challengeMapIDs = {167} }, -- Upper Blackrock Spire
  [307] = { instanceMapID = 1208, journalInstanceID = 536, challengeMapIDs = {166} }, -- Grimrail Depot
  [308] = { instanceMapID = 1195, journalInstanceID = 558, challengeMapIDs = {169} }, -- Iron Docks
  [401] = { instanceMapID = 1466, journalInstanceID = 762, challengeMapIDs = {198} }, -- Darkheart Thicket
  [402] = { instanceMapID = 1501, journalInstanceID = 740, challengeMapIDs = {199} }, -- Black Rook Hold
  [403] = { instanceMapID = 1477, journalInstanceID = 721, challengeMapIDs = {200} }, -- Halls of Valor
  [404] = { instanceMapID = 1458, journalInstanceID = 767, challengeMapIDs = {206} }, -- Neltharion's Lair
  [405] = { instanceMapID = 1571, journalInstanceID = 800, challengeMapIDs = {210} }, -- Court of Stars
  [406] = { instanceMapID = 1651, journalInstanceID = 860, challengeMapIDs = {227, 234} }, -- Return to Karazhan
  [407] = { instanceMapID = 1753, journalInstanceID = 945, challengeMapIDs = {239, 583} }, -- Seat of the Triumvirate
  [501] = { instanceMapID = 1763, journalInstanceID = 968, challengeMapIDs = {244} }, -- Atal'Dazar
  [502] = { instanceMapID = 1754, journalInstanceID = 1001, challengeMapIDs = {245} }, -- Freehold
  [503] = { instanceMapID = 1862, journalInstanceID = 1021, challengeMapIDs = {248} }, -- Waycrest Manor
  [504] = { instanceMapID = 1841, journalInstanceID = 1022, challengeMapIDs = {251} }, -- The Underrot
  [505] = { instanceMapID = 2097, journalInstanceID = 1178, challengeMapIDs = {369, 370} }, -- Operation: Mechagon
  [506] = { instanceMapID = 1822, journalInstanceID = 1023, challengeMapIDs = {353} }, -- Siege of Boralus
  [507] = { instanceMapID = 1594, journalInstanceID = 1012, challengeMapIDs = {247} }, -- The MOTHERLODE!!
  [508] = { instanceMapID = 1877, journalInstanceID = 1030, challengeMapIDs = {250} }, -- Temple of Sethraliss
  [509] = { instanceMapID = 1762, journalInstanceID = 1041, challengeMapIDs = {249} }, -- Kings' Rest
  [601] = { instanceMapID = 2286, journalInstanceID = 1182, challengeMapIDs = {376} }, -- The Necrotic Wake
  [602] = { instanceMapID = 2289, journalInstanceID = 1183, challengeMapIDs = {379} }, -- Plaguefall
  [603] = { instanceMapID = 2290, journalInstanceID = 1184, challengeMapIDs = {375} }, -- Mists of Tirna Scithe
  [604] = { instanceMapID = 2287, journalInstanceID = 1185, challengeMapIDs = {378} }, -- Halls of Atonement
  [605] = { instanceMapID = 2285, journalInstanceID = 1186, challengeMapIDs = {381} }, -- Spires of Ascension
  [606] = { instanceMapID = 2293, journalInstanceID = 1187, challengeMapIDs = {382} }, -- Theater of Pain
  [607] = { instanceMapID = 2291, journalInstanceID = 1188, challengeMapIDs = {377} }, -- De Other Side
  [608] = { instanceMapID = 2284, journalInstanceID = 1189, challengeMapIDs = {380} }, -- Sanguine Depths
  [609] = { instanceMapID = 2441, journalInstanceID = 1194, challengeMapIDs = {391, 392} }, -- Tazavesh, the Veiled Market
  [610] = { instanceMapID = 2296, journalInstanceID = 1190, challengeMapIDs = {} }, -- Castle Nathria
  [611] = { instanceMapID = 2450, journalInstanceID = 1193, challengeMapIDs = {} }, -- Sanctum of Domination
  [612] = { instanceMapID = 2481, journalInstanceID = 1195, challengeMapIDs = {} }, -- Sepulcher of the First Ones
  [701] = { instanceMapID = 2521, journalInstanceID = 1202, challengeMapIDs = {399} }, -- Ruby Life Pools
  [702] = { instanceMapID = 2516, journalInstanceID = 1198, challengeMapIDs = {400} }, -- The Nokhud Offensive
  [703] = { instanceMapID = 2515, journalInstanceID = 1203, challengeMapIDs = {401} }, -- The Azure Vault
  [704] = { instanceMapID = 2526, journalInstanceID = 1201, challengeMapIDs = {402} }, -- Algeth'ar Academy
  [705] = { instanceMapID = 2451, journalInstanceID = 1197, challengeMapIDs = {403} }, -- Uldaman: Legacy of Tyr
  [706] = { instanceMapID = 2519, journalInstanceID = 1199, challengeMapIDs = {404} }, -- Neltharus
  [707] = { instanceMapID = 2520, journalInstanceID = 1196, challengeMapIDs = {405} }, -- Brackenhide Hollow
  [708] = { instanceMapID = 2527, journalInstanceID = 1204, challengeMapIDs = {406} }, -- Halls of Infusion
  [709] = { instanceMapID = 2579, journalInstanceID = 1209, challengeMapIDs = {463, 464} }, -- Dawn of the Infinite
  [710] = { instanceMapID = 2522, journalInstanceID = 1200, challengeMapIDs = {} }, -- Vault of the Incarnates
  [711] = { instanceMapID = 2569, journalInstanceID = 1208, challengeMapIDs = {} }, -- Aberrus, the Shadowed Crucible
  [712] = { instanceMapID = 2549, journalInstanceID = 1207, challengeMapIDs = {} }, -- Amirdrassil, the Dream's Hope
  [801] = { instanceMapID = 2669, journalInstanceID = 1274, challengeMapIDs = {502} }, -- City of Threads
  [802] = { instanceMapID = 2660, journalInstanceID = 1271, challengeMapIDs = {503} }, -- Ara-Kara, City of Echoes
  [803] = { instanceMapID = 2652, journalInstanceID = 1269, challengeMapIDs = {501} }, -- The Stonevault
  [804] = { instanceMapID = 2662, journalInstanceID = 1270, challengeMapIDs = {505} }, -- The Dawnbreaker
  [805] = { instanceMapID = 2648, journalInstanceID = 1268, challengeMapIDs = {500} }, -- The Rookery
  [806] = { instanceMapID = 2651, journalInstanceID = 1210, challengeMapIDs = {504} }, -- Darkflame Cleft
  [807] = { instanceMapID = 2661, journalInstanceID = 1272, challengeMapIDs = {506} }, -- Cinderbrew Meadery
  [808] = { instanceMapID = 2649, journalInstanceID = 1267, challengeMapIDs = {499} }, -- Priory of the Sacred Flame
  [809] = { instanceMapID = 2773, journalInstanceID = 1298, challengeMapIDs = {525} }, -- Operation: Floodgate
  [810] = { instanceMapID = 2769, journalInstanceID = 1296, challengeMapIDs = {} }, -- Liberation of Undermine
  [811] = { instanceMapID = 2830, journalInstanceID = 1303, challengeMapIDs = {542} }, -- Eco-Dome Al'dani
  [812] = { instanceMapID = 2810, journalInstanceID = 1302, challengeMapIDs = {} }, -- Manaforge Omega
  [901] = { instanceMapID = 2811, journalInstanceID = 1300, challengeMapIDs = {558} }, -- Magisters' Terrace
  [902] = { instanceMapID = 2874, journalInstanceID = 1315, challengeMapIDs = {560} }, -- Maisara Caverns
  [903] = { instanceMapID = 2915, journalInstanceID = 1316, challengeMapIDs = {559} }, -- Nexus-Point Xenas
  [904] = { instanceMapID = 2805, journalInstanceID = 1299, challengeMapIDs = {557} }, -- Windrunner Spire
  [905] = { instanceMapID = 2993, journalInstanceID = 1322, challengeMapIDs = {588} }, -- Altar of Fangs
  [906] = { instanceMapID = 2825, journalInstanceID = 1311, challengeMapIDs = {586} }, -- Den of Nalorakk
  [907] = { instanceMapID = 2859, journalInstanceID = 1309, challengeMapIDs = {584} }, -- The Blinding Vale
  [908] = { instanceMapID = 2923, journalInstanceID = 1313, challengeMapIDs = {585} }, -- Voidscar Arena
  [909] = { instanceMapID = 2813, journalInstanceID = 1304, challengeMapIDs = {587} }, -- Murder Row
}

addon.DungeonDestinations = destinations

local byInstanceMapID, byChallengeMapID = {}, {}
for internalID, destination in pairs(destinations) do
  byInstanceMapID[destination.instanceMapID] = internalID
  for _, challengeMapID in ipairs(destination.challengeMapIDs) do
    byChallengeMapID[challengeMapID] = internalID
  end
end

local factionSpells = {
  [506] = { Alliance = 445418, Horde = 464256 },
  [507] = { Alliance = 467553, Horde = 467555 },
}

local function IsPublic(value)
  return not issecretvalue or not issecretvalue(value)
end

local function IsName(value)
  return IsPublic(value) and type(value) == "string" and value ~= ""
end

local function ReadName(api, id)
  if not api then return nil end
  local ok, name = pcall(api, id)
  return ok and IsName(name) and name or nil
end

function addon:GetTeleportSpellID(internalID)
  local factions = factionSpells[internalID]
  if factions then
    local faction = UnitFactionGroup("player")
    return IsPublic(faction) and factions[faction] or nil
  end
  local constants = self.constants
  local spellID = constants and constants.mapIDtoSpellID[internalID]
  return type(spellID) == "number" and spellID > 0 and spellID or nil
end

function addon:GetDungeonName(internalID)
  local destination = destinations[internalID]
  if destination then
    local name = ReadName(EJ_GetInstanceInfo, destination.journalInstanceID)
    if name then return name end
    -- A split wing's name must not replace the whole destination's label.
    if #destination.challengeMapIDs == 1 and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
      name = ReadName(C_ChallengeMode.GetMapUIInfo, destination.challengeMapIDs[1])
      if name then return name end
    end
  end
  -- Do not cache unavailable API data: retry on the next UI refresh.
  local constants = self.constants
  return constants and constants.mapIDtoDungeonName[internalID] or nil
end

function addon:GetKeystoneDungeonName(challengeMapID)
  if not IsPublic(challengeMapID) or type(challengeMapID) ~= "number" or challengeMapID <= 0 then return nil end
  if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
    local name = ReadName(C_ChallengeMode.GetMapUIInfo, challengeMapID)
    if name then return name end
  end
  local internalID = byChallengeMapID[challengeMapID]
  return internalID and self:GetDungeonName(internalID) or nil
end

function addon:GetKeystoneTeleportSpellID(challengeMapID)
  if not IsPublic(challengeMapID) or type(challengeMapID) ~= "number" then return nil end
  local internalID = byChallengeMapID[challengeMapID]
  return internalID and self:GetTeleportSpellID(internalID) or nil
end

function addon:ResolveDungeonActivity(activity)
  if not IsPublic(activity) or type(activity) ~= "table" then return nil, nil end
  local mapID = activity.mapID
  local internalID
  if IsPublic(mapID) and type(mapID) == "number" then
    internalID = byInstanceMapID[mapID]
  end
  -- LFG owns the display text, including localized split-wing names.
  local name = IsName(activity.fullName) and activity.fullName
    or (IsName(activity.shortName) and activity.shortName)
    or (internalID and self:GetDungeonName(internalID))
  -- Missing or unsupported IDs must never select a teleport by similar text.
  return internalID and self:GetTeleportSpellID(internalID) or nil, name
end
