local addonName, addon = ...
local L = addon.L
local LDBIcon = LibStub("LibDBIcon-1.0")

-- =========================================================
-- Retail-only guard
-- =========================================================
if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then
  return
end

-- =========================================================
-- Analytics helper (no-op if shim/client isn't present)
-- =========================================================
local function AnalyticsEvent(name, data)
  local A = _G.DungeonTeleportsAnalytics
  if A and type(A.event) == "function" then
    pcall(A.event, A, name, data)
  end
end

-- =========================================================
-- Helper to force UI refresh (unchanged)
-- =========================================================
function addon.ForceRefreshUI()
  if DungeonTeleportsMainFrame and DungeonTeleportsMainFrame:IsShown() then
    local selectedExpansion = DungeonTeleportsDB.defaultExpansion or addon.constants.orderedExpansions[1]
    UIDropDownMenu_SetText(DungeonTeleportsDropdown, selectedExpansion)
    addon.updateBackground(selectedExpansion)
    createTeleportButtons(selectedExpansion)
  end
end

-- =========================================================
-- Settings Panel: Canvas category with your controls
-- =========================================================
local widgets = {}
local categoryID

local function BuildConfigUI(parent)
  local frame = CreateFrame("Frame", "DungeonTeleportsOptionsPanel", parent)
  frame:SetAllPoints(true)
  frame:Hide()
--  frame:SetIgnoreParentScale(true)
--  frame:SetIgnoreParentAlpha(true)

  -- Title/header
  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText(L["CONFIG_TITLE"] or "Dungeon Teleports")

  local versionText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  versionText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  versionText:SetText("vLoading...")

  local function UpdateVersionText()
    if addon.version and addon.version ~= "Unknown" then
      versionText:SetText("v" .. addon.version)
    else
      C_Timer.After(1, UpdateVersionText)
    end
  end
  UpdateVersionText()

  -- Row: Show minimap icon
  local minimapCheckbox = CreateFrame("CheckButton", "DungeonTeleports_MinimapCheckbox", frame, "ChatConfigCheckButtonTemplate")
  minimapCheckbox:SetPoint("TOPLEFT", versionText, "BOTTOMLEFT", 0, -16)
  minimapCheckbox.Text:SetText(L["SHOW_MINIMAP"])
  minimapCheckbox:SetScript("OnClick", function(self)
    DungeonTeleportsDB.minimap = DungeonTeleportsDB.minimap or {}
    local isHidden = not self:GetChecked()
    DungeonTeleportsDB.minimap.hidden = isHidden
    if isHidden then LDBIcon:Hide("DungeonTeleports") else LDBIcon:Show("DungeonTeleports") end
    AnalyticsEvent("setting_changed", { key = "minimap.hidden", value = isHidden })
  end)
  minimapCheckbox:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["SHOW_MINIMAP"], 1, 1, 0)
    GameTooltip:AddLine(L["TOGGLE_MINIMAP"], 1, 1, 1, true)
    GameTooltip:Show()
  end)
  minimapCheckbox:SetScript("OnLeave", GameTooltip_Hide)

  -- Row: Disable background
  local backgroundCheckbox = CreateFrame("CheckButton", "DungeonTeleports_BackgroundCheckbox", frame, "ChatConfigCheckButtonTemplate")
  backgroundCheckbox:SetPoint("TOPLEFT", minimapCheckbox, "BOTTOMLEFT", 0, -12)
  backgroundCheckbox.Text:SetText(L["DISABLE_BACKGROUND"])
  backgroundCheckbox.tooltipText = L["DISABLE_BACKGROUND_TOOLTIP"]
  backgroundCheckbox:SetScript("OnClick", function(self)
    local v = self:GetChecked()
    DungeonTeleportsDB.disableBackground = v
    AnalyticsEvent("setting_changed", { key = "disableBackground", value = not not v })
    addon.ForceRefreshUI()
  end)
  backgroundCheckbox:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["DISABLE_BACKGROUND"], 1, 1, 0)
    GameTooltip:AddLine(L["DISABLE_BACKGROUND_TOOLTIP"], 1, 1, 1, true)
    GameTooltip:Show()
  end)
  backgroundCheckbox:SetScript("OnLeave", GameTooltip_Hide)

  -- Row: Disable cooldown overlay
  local cooldownCheckbox = CreateFrame("CheckButton", "DungeonTeleports_CooldownCheckbox", frame, "ChatConfigCheckButtonTemplate")
  cooldownCheckbox:SetPoint("TOPLEFT", backgroundCheckbox, "BOTTOMLEFT", 0, -12)
  cooldownCheckbox.Text:SetText(L["DISABLE_COOLDOWN_OVERLAY"])
  cooldownCheckbox:SetScript("OnClick", function(self)
    local v = self:GetChecked()
    DungeonTeleportsDB.disableCooldownOverlay = v
    AnalyticsEvent("setting_changed", { key = "disableCooldownOverlay", value = not not v })
    addon.ForceRefreshUI()
  end)
  cooldownCheckbox:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["DISABLE_COOLDOWN_OVERLAY"], 1, 1, 0)
    GameTooltip:AddLine(L["DISABLE_COOLDOWN_OVERLAY_TOOLTIP"], 1, 1, 1, true)
    GameTooltip:AddLine(L["COOLDOWN_OVERLAY_WARNING"], 1, 0, 0, true)
    GameTooltip:Show()
  end)
  cooldownCheckbox:SetScript("OnLeave", GameTooltip_Hide)


  -- Row: Auto-insert Mythic Keystone
  local autoKeyCheckbox = CreateFrame("CheckButton", "DungeonTeleports_AutoKeyCheckbox", frame, "ChatConfigCheckButtonTemplate")
  autoKeyCheckbox:SetPoint("TOPLEFT", cooldownCheckbox, "BOTTOMLEFT", 0, -12)
  autoKeyCheckbox.Text:SetText(L["AUTO_INSERT_KEYSTONE"] or "Auto-insert Mythic Keystone")
  autoKeyCheckbox:SetScript("OnClick", function(self)
    local v = self:GetChecked()
    DungeonTeleportsDB.autoInsertKeystone = v
    AnalyticsEvent("setting_changed", { key = "autoInsertKeystone", value = v })
  end)
  autoKeyCheckbox:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["AUTO_INSERT_KEYSTONE"] or "Auto-insert Mythic Keystone", 1, 1, 0)
    GameTooltip:AddLine(L["AUTO_INSERT_KEYSTONE_TOOLTIP"] or "Automatically inserts your Mythic Keystone when the keystone window opens.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  autoKeyCheckbox:SetScript("OnLeave", GameTooltip_Hide)

  -- Row: Default expansion label + dropdown
  local expansionLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  expansionLabel:SetPoint("TOPLEFT", autoKeyCheckbox, "BOTTOMLEFT", 0, -18)
  expansionLabel:SetText(L["DEFAULT_EXPANSION"])

  local expansionDropdown = CreateFrame("Frame", "DungeonTeleportsExpansionDropdown", frame, "UIDropDownMenuTemplate")
  expansionDropdown:SetPoint("LEFT", expansionLabel, "RIGHT", -10, -5)
  UIDropDownMenu_SetWidth(expansionDropdown, 150)
  UIDropDownMenu_Initialize(expansionDropdown, function()
    local info = UIDropDownMenu_CreateInfo()
    info.notCheckable = true
    for _, exp in ipairs(addon.constants.orderedExpansions) do
      info.text = exp
      info.arg1 = exp
      info.func = function(_, arg1)
        DungeonTeleportsDB.defaultExpansion = arg1
        UIDropDownMenu_SetText(expansionDropdown, arg1)
        AnalyticsEvent("setting_changed", { key = "defaultExpansion", value = arg1 })
        addon.ForceRefreshUI()
      end
      UIDropDownMenu_AddButton(info)
    end
  end)
  expansionDropdown:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["DEFAULT_EXPANSION"], 1, 1, 0)
    GameTooltip:AddLine(L["DEFAULT_EXPANSION_TOOLTIP"], 1, 1, 1, true)
    GameTooltip:Show()
  end)
  expansionDropdown:SetScript("OnLeave", GameTooltip_Hide)

  -- Row: Opacity slider
  local slider = CreateFrame("Slider", "DungeonTeleportsOpacitySlider", frame, "OptionsSliderTemplate")
  slider:SetPoint("TOPLEFT", expansionLabel, "BOTTOMLEFT", 0, -26)
  slider:SetMinMaxValues(0, 1)
  slider:SetValueStep(0.05)
  slider:SetObeyStepOnDrag(true)
  slider:SetWidth(220)
  slider.tooltipText = L["OPACITY_TOOLTIP"]
  slider:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["OPACITY_TOOLTIP"], 1, 1, 1)
    GameTooltip:AddLine(L["OPACITY_WARNING"], 1, 0, 0, true)
    GameTooltip:Show()
  end)
  slider:SetScript("OnLeave", GameTooltip_Hide)
  slider.Text = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  slider.Text:SetPoint("TOP", slider, "BOTTOM", 0, -6)
  slider.Text:SetText(L["OPACITY_SLIDER"])
  slider:SetScript("OnValueChanged", function(self, value)
    DungeonTeleportsDB.backgroundAlpha = value
    AnalyticsEvent("setting_changed", { key = "backgroundAlpha", value = value })
    addon.ForceRefreshUI()
  end)

  -- Footer: Reset button (hard reset + reload)
  local reset = CreateFrame("Button", "DungeonTeleportsResetButton", frame, "UIPanelButtonTemplate")
  reset:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -40)
  reset:SetText(L["RESET_SETTINGS"])
  reset:SetWidth(reset:GetTextWidth() + 20)
  reset:SetHeight(24)
  reset:SetScript("OnClick", function()
    AnalyticsEvent("settings_reset", {})
    DungeonTeleportsDB = {}
    DungeonTeleportsDB.autoInsertKeystone = false
    ReloadUI()
  end)
  reset:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["RESET_SETTINGS"], 1, 1, 0)
    GameTooltip:AddLine(L["RESET_TOOLTIP"], 1, 1, 1, true)
    GameTooltip:Show()
  end)
  reset:SetScript("OnLeave", GameTooltip_Hide)

  -- Stash widget refs
  widgets.minimapCheckbox    = minimapCheckbox
  widgets.backgroundCheckbox = backgroundCheckbox
  widgets.cooldownCheckbox   = cooldownCheckbox
  widgets.autoKeyCheckbox     = autoKeyCheckbox
  widgets.slider             = slider
  widgets.expansionDropdown  = expansionDropdown

  return frame
end

local function RegisterSettingsCategory()
  local panel = BuildConfigUI(UIParent)  -- Settings will parent/manage it

  -- Canvas lifecycle callbacks live on the panel
  panel.OnCommit = function(self)
    -- currently saving immediately on change; keep for validation if needed
  end

  panel.OnDefault = function(self)
    -- Soft defaults (no reload)
    DungeonTeleportsDB = DungeonTeleportsDB or {}
    DungeonTeleportsDB.minimap = { hidden = false }
    DungeonTeleportsDB.disableBackground = false
    DungeonTeleportsDB.disableCooldownOverlay = false
    DungeonTeleportsDB.backgroundAlpha = 0.7
    DungeonTeleportsDB.autoInsertKeystone = false
    DungeonTeleportsDB.defaultExpansion = nil

    if widgets.minimapCheckbox then widgets.minimapCheckbox:SetChecked(true) end
    if widgets.backgroundCheckbox then widgets.backgroundCheckbox:SetChecked(false) end
    if widgets.cooldownCheckbox then widgets.cooldownCheckbox:SetChecked(false) end
    if widgets.autoKeyCheckbox then widgets.autoKeyCheckbox:SetChecked(false) end
    if widgets.slider then widgets.slider:SetValue(0.7) end
    if widgets.expansionDropdown then UIDropDownMenu_SetText(widgets.expansionDropdown, L["Current Season"]) end

    addon.ForceRefreshUI()
  end

  panel.OnRefresh = function(self)
    local db = DungeonTeleportsDB or {}
    if widgets.minimapCheckbox then widgets.minimapCheckbox:SetChecked(not (db.minimap and db.minimap.hidden)) end
    if widgets.backgroundCheckbox then widgets.backgroundCheckbox:SetChecked(db.disableBackground or false) end
    if widgets.cooldownCheckbox then widgets.cooldownCheckbox:SetChecked(db.disableCooldownOverlay or false) end
    if widgets.autoKeyCheckbox then widgets.autoKeyCheckbox:SetChecked(db.autoInsertKeystone == true) end
    if widgets.slider then widgets.slider:SetValue(db.backgroundAlpha or 0.7) end
    if widgets.expansionDropdown then UIDropDownMenu_SetText(widgets.expansionDropdown, db.defaultExpansion or L["Current Season"]) end
    AnalyticsEvent("config_visibility", { visible = true, source = "blizzard_settings" })
  end

  panel:SetScript("OnHide", function()
    AnalyticsEvent("config_visibility", { visible = false, source = "blizzard_settings" })
  end)

  -- Register the category under AddOns
  local title = L["CONFIG_TITLE"] or "Dungeon Teleports"
  local category = Settings.RegisterCanvasLayoutCategory(panel, title)
  category.ID = "DungeonTeleportsCategory"
  categoryID = category.ID
  Settings.RegisterAddOnCategory(category)
end

-- =========================================================
-- Init category once vars are ready + provide openers/shims
-- =========================================================
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == addonName then
    DungeonTeleportsDB = DungeonTeleportsDB or {}
    if not categoryID then RegisterSettingsCategory() end
  elseif event == "PLAYER_LOGIN" then
    -- safety: ensure registration even if ADDON_LOADED path missed
    if not categoryID then RegisterSettingsCategory() end
  end
end)

-- --- Openers / legacy shims ---
local function OpenSettingsCategory()
  if not categoryID then
    RegisterSettingsCategory()
  end
  if Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(categoryID)
  else
    -- Retail-only file, but add a guard just in case
    print("DungeonTeleports: Blizzard Settings API unavailable.")
  end
end

-- Global shim for any old callers (minimap, keybinds, etc.)
function ToggleConfig()
  OpenSettingsCategory()
end
addon.OpenConfig = OpenSettingsCategory

-- Slash command: open Blizzard Settings to our category
SLASH_DUNGEONTELEPORTSCONFIG1 = "/dtpconfig"
SlashCmdList["DUNGEONTELEPORTSCONFIG"] = function()
  OpenSettingsCategory()
end
