local addonName, addon = ...
local L = addon.L
local LDBIcon = LibStub("LibDBIcon-1.0")

-- Analytics helper (no-op if shim/client isn't present)
local function AnalyticsEvent(name, data)
  local A = _G.DungeonTeleportsAnalytics
  if A and type(A.event) == "function" then
    pcall(A.event, A, name, data)
  end
end

-- Helper to force UI refresh
function addon.ForceRefreshUI()
  if DungeonTeleportsMainFrame and DungeonTeleportsMainFrame:IsShown() then
    local selectedExpansion = DungeonTeleportsDB.defaultExpansion or addon.constants.orderedExpansions[1]
    UIDropDownMenu_SetText(DungeonTeleportsDropdown, selectedExpansion)
    addon.updateBackground(selectedExpansion)
    createTeleportButtons(selectedExpansion)
  end
end

-- Create the polished settings frame
local ConfigFrame = CreateFrame("Frame", "DungeonTeleportsConfigFrame", UIParent, "BackdropTemplate")
ConfigFrame:SetSize(375, 370)
ConfigFrame:SetPoint("CENTER")
ConfigFrame:SetBackdrop({
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true, tileSize = 32, edgeSize = 32,
  insets = { left = 8, right = 8, top = 8, bottom = 8 },
})
ConfigFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
ConfigFrame:SetFrameStrata("DIALOG")
ConfigFrame:SetFrameLevel(100)
ConfigFrame:SetToplevel(true)

-- Soft rounded border and shadow
if not ConfigFrame.shadow then
  ConfigFrame.shadow = CreateFrame("Frame", nil, ConfigFrame, "BackdropTemplate")
  ConfigFrame.shadow:SetPoint("TOPLEFT", -5, 5)
  ConfigFrame.shadow:SetPoint("BOTTOMRIGHT", 5, -5)
  ConfigFrame.shadow:SetBackdrop({
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
    edgeSize = 16,
  })
  ConfigFrame.shadow:SetBackdropBorderColor(0, 0, 0, 0.75)
end

ConfigFrame:SetMovable(true)
ConfigFrame:EnableMouse(true)
ConfigFrame:RegisterForDrag("LeftButton")
ConfigFrame:SetScript("OnDragStart", ConfigFrame.StartMoving)
ConfigFrame:SetScript("OnDragStop", ConfigFrame.StopMovingOrSizing)
ConfigFrame:EnableKeyboard(true)
ConfigFrame:SetPropagateKeyboardInput(false)
ConfigFrame:SetScript("OnKeyDown", function(self, key)
  if key == "ESCAPE" then
    self:Hide()
    self:SetPropagateKeyboardInput(false)
  end
end)

ConfigFrame:Hide()

-- Title
local title = ConfigFrame:CreateFontString(nil, "OVERLAY")
title:SetFontObject("GameFontHighlightLarge")
title:SetFont(select(1, title:GetFont()), 18, "OUTLINE") -- Increased size & bold outline
title:SetShadowOffset(1, -1)
title:SetShadowColor(0, 0, 0, 0.75)
title:SetPoint("TOP", ConfigFrame, "TOP", 0, -35)
title:SetText(L["CONFIG_TITLE"])
title:SetTextColor(1, 1, 0)

local versionText = ConfigFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
versionText:SetPoint("BOTTOMLEFT", ConfigFrame, "BOTTOMLEFT", 15, 10)
versionText:SetText("vLoading...")

local function UpdateVersionText()
  if addon.version and addon.version ~= "Unknown" then
    versionText:SetText("v" .. addon.version)
  else
    C_Timer.After(1, UpdateVersionText)
  end
end
UpdateVersionText()

-- Add black base layer for contrast (kept for compatibility)
local baseBackground = ConfigFrame:CreateTexture(nil, "BACKGROUND")
baseBackground:SetAllPoints(ConfigFrame)
baseBackground:SetColorTexture(0, 0, 0, 1)

-- Optional background image/alpha texture
local backgroundTexture = ConfigFrame:CreateTexture(nil, "ARTWORK")
backgroundTexture:SetAllPoints(ConfigFrame)
backgroundTexture:SetColorTexture(0, 0, 0, DungeonTeleportsDB.backgroundAlpha or 0.7)
backgroundTexture:SetDrawLayer("ARTWORK", -1)  -- Ensure it draws behind the border
ConfigFrame.backgroundTexture = backgroundTexture

local closeButton = CreateFrame("Button", nil, ConfigFrame, "UIPanelCloseButton")
closeButton:SetSize(24, 24)
closeButton:SetPoint("TOPRIGHT", ConfigFrame, "TOPRIGHT", -10, -10)
closeButton:SetScript("OnClick", function() ConfigFrame:Hide() end)

local minimapCheckbox = CreateFrame("CheckButton", nil, ConfigFrame, "ChatConfigCheckButtonTemplate")
minimapCheckbox:SetPoint("TOPLEFT", ConfigFrame, "TOPLEFT", 20, -80)
minimapCheckbox.Text:SetText(L["SHOW_MINIMAP"])
minimapCheckbox:SetScript("OnClick", function(self)
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

local backgroundCheckbox = CreateFrame("CheckButton", nil, ConfigFrame, "ChatConfigCheckButtonTemplate")
backgroundCheckbox:SetPoint("TOPLEFT", minimapCheckbox, "BOTTOMLEFT", 0, -20)
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

local cooldownCheckbox = CreateFrame("CheckButton", nil, ConfigFrame, "ChatConfigCheckButtonTemplate")
cooldownCheckbox:SetPoint("TOPLEFT", backgroundCheckbox, "BOTTOMLEFT", 0, -20)
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

local expansionLabel = ConfigFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
expansionLabel:SetPoint("TOPLEFT", cooldownCheckbox, "BOTTOMLEFT", 0, -20)
expansionLabel:SetText(L["DEFAULT_EXPANSION"])

local expansionDropdown = CreateFrame("Frame", "DungeonTeleportsExpansionDropdown", ConfigFrame, "UIDropDownMenuTemplate")
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

local slider = CreateFrame("Slider", "DungeonTeleportsOpacitySlider", ConfigFrame, "OptionsSliderTemplate")
slider:SetPoint("TOPLEFT", expansionLabel, "BOTTOMLEFT", 0, -30)
slider:SetMinMaxValues(0, 1)
slider:SetValueStep(0.05)
slider:SetObeyStepOnDrag(true)
slider:SetWidth(200)
slider.tooltipText = L["OPACITY_TOOLTIP"]
slider:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(L["OPACITY_TOOLTIP"], 1, 1, 1)
  GameTooltip:AddLine(L["OPACITY_WARNING"], 1, 0, 0, true)
  GameTooltip:Show()
end)
slider:SetScript("OnLeave", GameTooltip_Hide)
slider.Text = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
slider.Text:SetPoint("TOP", slider, "BOTTOM", 0, -5)
slider.Text:SetText(L["OPACITY_SLIDER"])
slider:SetScript("OnValueChanged", function(self, value)
  DungeonTeleportsDB.backgroundAlpha = value
  AnalyticsEvent("setting_changed", { key = "backgroundAlpha", value = value })
  addon.ForceRefreshUI()
end)

local reset = CreateFrame("Button", nil, ConfigFrame, "UIPanelButtonTemplate")
reset:SetPoint("BOTTOM", ConfigFrame, "BOTTOM", 0, 35)
reset:SetText(L["RESET_SETTINGS"])
reset:SetWidth(reset:GetTextWidth() + 20)
reset:SetHeight(25)
reset:SetScript("OnClick", function()
  AnalyticsEvent("settings_reset", {})
  DungeonTeleportsDB = {}
  ReloadUI()
end)
reset:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(L["RESET_SETTINGS"], 1, 1, 0)
  GameTooltip:AddLine(L["RESET_TOOLTIP"], 1, 1, 1, true)
  GameTooltip:Show()
end)
reset:SetScript("OnLeave", GameTooltip_Hide)

ConfigFrame:SetScript("OnShow", function()
  minimapCheckbox:SetChecked(not (DungeonTeleportsDB.minimap and DungeonTeleportsDB.minimap.hidden))
  backgroundCheckbox:SetChecked(DungeonTeleportsDB.disableBackground or false)
  cooldownCheckbox:SetChecked(DungeonTeleportsDB.disableCooldownOverlay or false)
  slider:SetValue(DungeonTeleportsDB.backgroundAlpha or 0.7)
  UIDropDownMenu_SetText(expansionDropdown, DungeonTeleportsDB.defaultExpansion or L["Current Season"])
  AnalyticsEvent("config_visibility", { visible = true, source = "config_ui" })
end)

ConfigFrame:HookScript("OnHide", function()
  AnalyticsEvent("config_visibility", { visible = false, source = "config_ui" })
end)

function ToggleConfig()
  if ConfigFrame:IsShown() then ConfigFrame:Hide() else ConfigFrame:Show() end
end

SLASH_DUNGEONTELEPORTSCONFIG1 = "/dtpconfig"
SlashCmdList["DUNGEONTELEPORTSCONFIG"] = ToggleConfig
