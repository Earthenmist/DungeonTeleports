local addonName, addon = ...
local L = addon.L
local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

-- Analytics helper (no-op if shim/client isn't present)
local function AnalyticsEvent(name, data)
  local A = _G.DungeonTeleportsAnalytics
  if A and type(A.event) == "function" then
    pcall(A.event, A, name, data)
  end
end

local function ToggleDungeonTeleportsFrame(source)
  if not DungeonTeleportsMainFrame then
    print(L["NOT_INITIALIZED_MAIN"]) 
    return
  end

  if DungeonTeleportsMainFrame:IsShown() then
    DungeonTeleportsMainFrame:Hide()
    DungeonTeleportsDB.isVisible = false
    AnalyticsEvent("ui_visibility", { visible = false, source = source or "minimap" })
  else
    DungeonTeleportsMainFrame:Show()
    DungeonTeleportsDB.isVisible = true
    AnalyticsEvent("ui_visibility", { visible = true, source = source or "minimap" })
  end
end

local function ToggleConfigFrame(source)
  if not DungeonTeleportsConfigFrame then
    print(L["NOT_INITIALIZED_CONFIG"]) 
    return
  end

  if DungeonTeleportsConfigFrame:IsShown() then
    DungeonTeleportsConfigFrame:Hide()
    AnalyticsEvent("config_visibility", { visible = false, source = source or "minimap" })
  else
    DungeonTeleportsConfigFrame:Show()
    AnalyticsEvent("config_visibility", { visible = true, source = source or "minimap" })
  end
end

local minimapButton = LDB:NewDataObject("DungeonTeleports", {
  type = "data source",
  text = L["ADDON_TITLE"],
  icon = "Interface\\ICONS\\inv_spell_arcane_telepotdornogal",
  OnClick = function(_, button)
    AnalyticsEvent("minimap_click", { button = button })
    if button == "LeftButton" then
      ToggleDungeonTeleportsFrame("minimap_left_click")
    elseif button == "RightButton" then
      ToggleConfigFrame("minimap_right_click")
    end
  end,
  OnTooltipShow = function(tooltip)
    tooltip:AddLine(L["ADDON_TITLE"]) 
    tooltip:AddLine(L["Open_Teleports"]) 
    tooltip:AddLine(L["Open_Settings"]) 
  end,
})

-- Register minimap button
local MinimapHandler = CreateFrame("Frame")
MinimapHandler:RegisterEvent("PLAYER_LOGIN")
MinimapHandler:SetScript("OnEvent", function()
  DungeonTeleportsDB = DungeonTeleportsDB or {}
  DungeonTeleportsDB.minimap = DungeonTeleportsDB.minimap or {}

  -- Only register if not already registered
  if not LDBIcon:IsRegistered("DungeonTeleports") then
    LDBIcon:Register("DungeonTeleports", minimapButton, DungeonTeleportsDB.minimap)
    AnalyticsEvent("minimap_registered", {})
  end

  -- Respect saved visibility preference
  if DungeonTeleportsDB.minimap.hidden then
    LDBIcon:Hide("DungeonTeleports")
  end
  AnalyticsEvent("setting_applied", { key = "minimap.hidden", value = not not DungeonTeleportsDB.minimap.hidden })

  -- Restore main frame visibility from last session
  if DungeonTeleportsDB.isVisible and DungeonTeleportsMainFrame then
    DungeonTeleportsMainFrame:Show()
    AnalyticsEvent("ui_visibility", { visible = true, source = "login_restore" })
  elseif DungeonTeleportsMainFrame then
    DungeonTeleportsMainFrame:Hide()
    AnalyticsEvent("ui_visibility", { visible = false, source = "login_restore" })
  end
end)
