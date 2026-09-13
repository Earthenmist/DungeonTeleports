local _, addon = ...
local teleportData = addon.teleportData

-- Backgrounds for each expansion
local mapExpansionToBackground = {}

-- NOTE: these keys are stable, locale-independent identifiers (not display text).
-- They are also what gets persisted into DungeonTeleportsDB.selectedExpansion/defaultExpansion,
-- so they must never be run through L[...] here. Anywhere these need to be shown to the
-- player, look them up via L[key] at display time instead (see UpdateExpansionButtonStyles /
-- EnsureExpansionButtons in DungeonTeleports.lua for the existing pattern).
local mapExpansionToMapID = {
    -- Season 1 Midnight
    ["Current Season"] = {901, 902, 903, 904, 704, 001, 407, 305},
    ["Wotlk"] =  {001},
    ["Cataclysm"] = {101, 102, 103},
    ["Mists of Pandaria"] = {201, 202, 203, 204, 205, 206, 207, 208, 209},
    ["Warlords of Draenor"] = {301, 302, 303, 304, 305, 306, 307, 308},
    ["Legion"] = {401, 402, 403, 404, 405, 406},
    ["Battle for Azeroth"] = {501, 502, 503, 504, 505, 506, 507},
    ["Shadowlands"] = {601, 602, 603, 604, 605, 606, 607, 608, 609, 610, 611, 612},
    ["Dragonflight"] = {701, 702, 703, 704, 705, 706, 707, 708, 709, 710, 711, 712},
    ["The War Within"] = {801, 802, 803, 804, 805, 806, 807, 808, 809, 810, 811, 812},
    ["Midnight"] = {901, 902, 903, 904, 905, 906, 907, 908},
}


-- Export the constants
addon.constants_previous = {
    mapIDtoDungeonName = teleportData.mapIDtoDungeonName,
    mapExpansionToMapID = mapExpansionToMapID,
    mapIDtoSpellID = teleportData.mapIDtoSpellID,
    mapExpansionToBackground = mapExpansionToBackground,
    orderedExpansions = {
    "Current Season",
    "Wotlk",
    "Cataclysm",
    "Mists of Pandaria",
    "Warlords of Draenor",
    "Legion",
    "Battle for Azeroth",
    "Shadowlands",
    "Dragonflight",
    "The War Within",
    "Midnight"
}

}

-- =========================================================
-- Data selection: use the current catalog for interface 120100 and newer.
-- =========================================================
do
  local _, _, _, tocVersion = GetBuildInfo()
  if tocVersion and tocVersion >= 120100 and addon.constants_current then
    addon.constants = addon.constants_current
  else
    addon.constants = addon.constants_previous or addon.constants_current
  end
end
