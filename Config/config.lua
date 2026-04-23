local addonName, addon = ...
local L = addon.L
local LDBIcon = LibStub("LibDBIcon-1.0")

if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then
  return
end

local function AnalyticsEvent(name, data)
  local A = _G.DungeonTeleportsAnalytics
  if A and type(A.event) == "function" then
    pcall(A.event, A, name, data)
  end
end

function addon.ForceRefreshUI()
  if DungeonTeleportsMainFrame and DungeonTeleportsMainFrame:IsShown() and addon.RefreshTeleportUI then
    local selectedExpansion = DungeonTeleportsDB.selectedExpansion or DungeonTeleportsDB.defaultExpansion or addon.constants.orderedExpansions[1]
    addon.RefreshTeleportUI(selectedExpansion)
  end
end

local widgets = {}
local categoryID
local groupReminderWidgets = {}
local groupReminderCategory
local ldbMenuWidgets = {}
local ldbMenuCategory
local qolWidgets = {}
local qolCategory

local function BuildConfigUI(parent)
  local frame = CreateFrame("Frame", "DungeonTeleportsOptionsPanel", parent)
  frame:SetAllPoints(true)
  frame:Hide()

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

  local cooldownCheckbox = CreateFrame("CheckButton", "DungeonTeleports_CooldownCheckbox", frame, "ChatConfigCheckButtonTemplate")
  cooldownCheckbox:SetPoint("TOPLEFT", minimapCheckbox, "BOTTOMLEFT", 0, -12)
  cooldownCheckbox.Text:SetText(L["DISABLE_COOLDOWN_OVERLAY"])
  cooldownCheckbox:SetScript("OnClick", function(self)
    local v = self:GetChecked()
    DungeonTeleportsDB.disableCooldownOverlay = v
    AnalyticsEvent("setting_changed", { key = "disableCooldownOverlay", value = not not v })
    addon.ForceRefreshUI()
  end)

  local autoKeyCheckbox = CreateFrame("CheckButton", "DungeonTeleports_AutoInsertKeystoneCheckbox", frame, "ChatConfigCheckButtonTemplate")
  autoKeyCheckbox:SetPoint("TOPLEFT", cooldownCheckbox, "BOTTOMLEFT", 0, -12)
  autoKeyCheckbox.Text:SetText(L["AUTO_INSERT_KEYSTONE"])
  autoKeyCheckbox:SetScript("OnClick", function(self)
    local v = self:GetChecked()
    DungeonTeleportsDB.autoInsertKeystone = v
    AnalyticsEvent("setting_changed", { key = "autoInsertKeystone", value = not not v })
  end)

  local expansionLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  expansionLabel:SetPoint("TOPLEFT", autoKeyCheckbox, "BOTTOMLEFT", 0, -18)
  expansionLabel:SetText(L["DEFAULT_EXPANSION"])

  local expansionDropdown = CreateFrame("Frame", "DungeonTeleportsExpansionDropdown", frame, "UIDropDownMenuTemplate")
  expansionDropdown:SetPoint("LEFT", expansionLabel, "RIGHT", -10, -5)
  UIDropDownMenu_SetWidth(expansionDropdown, 170)
  UIDropDownMenu_Initialize(expansionDropdown, function()
    local info = UIDropDownMenu_CreateInfo()
    info.notCheckable = true
    for _, exp in ipairs(addon.constants.orderedExpansions) do
      info.text = L[exp] or exp
      info.arg1 = exp
      info.func = function(_, arg1)
        DungeonTeleportsDB.defaultExpansion = arg1
        DungeonTeleportsDB.selectedExpansion = arg1
        UIDropDownMenu_SetText(expansionDropdown, L[arg1] or arg1)
        AnalyticsEvent("setting_changed", { key = "defaultExpansion", value = arg1 })
        addon.ForceRefreshUI()
      end
      UIDropDownMenu_AddButton(info)
    end
  end)

  local scaleLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  scaleLabel:SetPoint("TOPLEFT", expansionLabel, "BOTTOMLEFT", 0, -32)
  scaleLabel:SetText(L["UI_SCALE"] or "Window Scale")

  local scaleSlider = CreateFrame("Slider", "DungeonTeleportsUIScaleSlider", frame, "OptionsSliderTemplate")
  scaleSlider:SetPoint("TOPLEFT", scaleLabel, "BOTTOMLEFT", 8, -16)
  scaleSlider:SetMinMaxValues(0.70, 1.15)
  scaleSlider:SetValueStep(0.01)
  scaleSlider:SetObeyStepOnDrag(true)
  scaleSlider:SetWidth(220)
  _G[scaleSlider:GetName() .. "Low"]:SetText("70%")
  _G[scaleSlider:GetName() .. "High"]:SetText("115%")
  _G[scaleSlider:GetName() .. "Text"]:SetText(L["UI_SCALE"] or "Window Scale")
  scaleSlider:SetScript("OnValueChanged", function(self, value)
    DungeonTeleportsDB.uiScale = value
    AnalyticsEvent("setting_changed", { key = "uiScale", value = value })
    if DungeonTeleportsMainFrame then
      DungeonTeleportsMainFrame:SetScale(value)
      if DungeonTeleportsMainFrame.scaleSlider and math.abs((DungeonTeleportsMainFrame.scaleSlider:GetValue() or value) - value) > 0.0001 then
        DungeonTeleportsMainFrame.scaleSlider:SetValue(value)
      end
    end
  end)

  local reset = CreateFrame("Button", "DungeonTeleportsResetButton", frame, "UIPanelButtonTemplate")
  reset:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", -8, -40)
  reset:SetText(L["RESET_SETTINGS"])
  reset:SetWidth(reset:GetTextWidth() + 20)
  reset:SetHeight(24)
  reset:SetScript("OnClick", function()
    AnalyticsEvent("settings_reset", {})
    DungeonTeleportsDB = {}
    DungeonTeleportsDB.autoInsertKeystone = false
    DungeonTeleportsDB.uiScale = 1.0
    ReloadUI()
  end)

  widgets.minimapCheckbox = minimapCheckbox
  widgets.cooldownCheckbox = cooldownCheckbox
  widgets.autoKeyCheckbox = autoKeyCheckbox
  widgets.expansionDropdown = expansionDropdown
  widgets.scaleSlider = scaleSlider

  return frame
end

local function RegisterSettingsCategory()
  local panel = BuildConfigUI(UIParent)

  panel.OnCommit = function() end

  panel.OnDefault = function()
    DungeonTeleportsDB = DungeonTeleportsDB or {}
    DungeonTeleportsDB.minimap = { hidden = false }
    DungeonTeleportsDB.disableCooldownOverlay = false
    DungeonTeleportsDB.autoInsertKeystone = false
    DungeonTeleportsDB.defaultExpansion = nil
    DungeonTeleportsDB.selectedExpansion = nil
    DungeonTeleportsDB.uiScale = 1.0
    DungeonTeleportsDB.qol = {
      autoInviteOnWhisper = false,
      autoInviteKeyword = "inv, invite, 123",
      autoInviteRestriction = "anyone",
    }

    if widgets.minimapCheckbox then widgets.minimapCheckbox:SetChecked(true) end
    if widgets.cooldownCheckbox then widgets.cooldownCheckbox:SetChecked(false) end
    if widgets.autoKeyCheckbox then widgets.autoKeyCheckbox:SetChecked(false) end
    if widgets.scaleSlider then widgets.scaleSlider:SetValue(1.0) end
    if widgets.expansionDropdown then UIDropDownMenu_SetText(widgets.expansionDropdown, L["Current Season"]) end

    addon.ForceRefreshUI()
  end

  panel.OnRefresh = function()
    local db = DungeonTeleportsDB or {}
    if widgets.minimapCheckbox then widgets.minimapCheckbox:SetChecked(not (db.minimap and db.minimap.hidden)) end
    if widgets.cooldownCheckbox then widgets.cooldownCheckbox:SetChecked(db.disableCooldownOverlay or false) end
    if widgets.autoKeyCheckbox then widgets.autoKeyCheckbox:SetChecked(db.autoInsertKeystone == true) end
    if widgets.scaleSlider then widgets.scaleSlider:SetValue(db.uiScale or 1.0) end
    if widgets.expansionDropdown then UIDropDownMenu_SetText(widgets.expansionDropdown, L[db.defaultExpansion or L["Current Season"]] or db.defaultExpansion or L["Current Season"]) end
    AnalyticsEvent("config_visibility", { visible = true, source = "blizzard_settings" })
  end

  panel:SetScript("OnHide", function()
    AnalyticsEvent("config_visibility", { visible = false, source = "blizzard_settings" })
  end)

  local title = L["CONFIG_TITLE"] or "Dungeon Teleports"
  local category = Settings.RegisterCanvasLayoutCategory(panel, title)
  Settings.RegisterAddOnCategory(category)
  addon._settingsCategory = category
  local _, _, _, tocVersion = GetBuildInfo()
  addon._retailCategoryKey = "DungeonTeleportsCategory"
  if tocVersion and tocVersion < 120000 then
    category.ID = "DungeonTeleportsCategory"
    categoryID = "DungeonTeleportsCategory"
  else
    categoryID = (category.GetID and category:GetID()) or category.ID
  end

  if not groupReminderCategory and addon and addon.DT_GR_UpdateRegistration then
    local grPanel = (addon.DT_GR_BuildConfigPanel and addon:DT_GR_BuildConfigPanel(nil, groupReminderWidgets))
    if grPanel then
      local grTitle = L["GROUP_REMINDER_TITLE"] or "Group Reminder"
      groupReminderCategory = Settings.RegisterCanvasLayoutSubcategory(category, grPanel, grTitle)
    end
  end

  if not ldbMenuCategory and addon and addon.DT_LDB_UpdateRegistration then
    local ldbPanel = (addon.DT_LDB_BuildConfigPanel and addon:DT_LDB_BuildConfigPanel(nil, ldbMenuWidgets))
    if ldbPanel then
      local ldbTitle = L["LDB_MENU_TITLE"] or "DataText Menu"
      ldbMenuCategory = Settings.RegisterCanvasLayoutSubcategory(category, ldbPanel, ldbTitle)
    end
  end

  if not qolCategory and addon and addon.DT_QOL_UpdateRegistration then
    local qolPanel = (addon.DT_QOL_BuildConfigPanel and addon:DT_QOL_BuildConfigPanel(nil, qolWidgets))
    if qolPanel then
      local qolTitle = L["QOL_TITLE"] or "QoL"
      qolCategory = Settings.RegisterCanvasLayoutSubcategory(category, qolPanel, qolTitle)
    end
  end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == addonName then
    DungeonTeleportsDB = DungeonTeleportsDB or {}
    if not categoryID then RegisterSettingsCategory() end
  elseif event == "PLAYER_LOGIN" then
    if not categoryID then RegisterSettingsCategory() end
  end
end)

local function DT_ResolveSettingsCategoryID()
  if addon._settingsCategory and addon._settingsCategory.GetID then
    local id = addon._settingsCategory:GetID()
    if type(id) == "number" then return id end
  end

  if Settings and Settings.GetCategoryList then
    local list = Settings.GetCategoryList()
    if type(list) == "table" then
      for _, cat in ipairs(list) do
        if cat and cat.GetName and cat:GetName() == (L["CONFIG_TITLE"] or "Dungeon Teleports") then
          if cat.GetID then
            local id = cat:GetID()
            if type(id) == "number" then
              addon._settingsCategory = cat
              return id
            end
          end
        end
      end
    end
  end

  return nil
end

local function OpenSettingsCategory()
  if not categoryID then
    RegisterSettingsCategory()
  end

  local _, _, _, tocVersion = GetBuildInfo()

  if tocVersion and tocVersion >= 120000 and C_SettingsUtil and C_SettingsUtil.OpenSettingsPanel then
    local id = DT_ResolveSettingsCategoryID()
    if type(id) == "number" then
      C_SettingsUtil.OpenSettingsPanel(id)
      return
    end
  end

  if tocVersion and tocVersion < 120000 and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory("DungeonTeleportsCategory")
    return
  end

  if Settings and Settings.OpenToCategory then
    if addon._settingsCategory then
      Settings.OpenToCategory(addon._settingsCategory)
      return
    end
    if type(categoryID) == "number" then
      Settings.OpenToCategory(categoryID)
      return
    end
  end

  print("DungeonTeleports: Unable to open settings category.")
end

function ToggleConfig()
  OpenSettingsCategory()
end
addon.OpenConfig = OpenSettingsCategory

SLASH_DUNGEONTELEPORTSCONFIG1 = "/dtpconfig"
SlashCmdList["DUNGEONTELEPORTSCONFIG"] = function()
  OpenSettingsCategory()
end
