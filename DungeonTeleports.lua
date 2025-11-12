local addonName, addon = ...

-- === DungeonTeleports: Safe hide/show helpers for Midnight combat restrictions ===
local function DT_SafeHide(frame)
  if InCombatLockdown and InCombatLockdown() then
    frame._DT_pendingHide = true
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:HookScript("OnEvent", function(self, event)
      if event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        if self._DT_pendingHide then
          self._DT_pendingHide = nil
          self:Hide()
        end
      end
    end)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
      DEFAULT_CHAT_FRAME:AddMessage("|cffff7f00DungeonTeleports: Window will close after combat.|r")
    end
    return
  end
  frame:Hide()
end

local function DT_SafeShow(frame)
  if InCombatLockdown and InCombatLockdown() then
    frame._DT_pendingShow = true
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:HookScript("OnEvent", function(self, event)
      if event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        if self._DT_pendingShow then
          self._DT_pendingShow = nil
          self:Show()
        end
      end
    end)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
      DEFAULT_CHAT_FRAME:AddMessage("|cffff7f00DungeonTeleports: Window will open after combat.|r")
    end
    return
  end
  frame:Show()
end
-- === End helpers ===

local ok, WA = pcall(LibStub, "WagoAnalytics")
if ok and WA and WA.Register then
  WA = WA:Register("BNBeblGx")
end
local constants = addon.constants
local L = addon.L

addon.version = "Unknown"

-- Analytics helper (no-op if shim/client isn't present)
local function AnalyticsEvent(name, data)
  local A = _G.DungeonTeleportsAnalytics
  if A and type(A.event) == "function" then
    pcall(A.event, A, name, data)
  end
end

-- Event frame to get version + init Wago Analytics
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_ENTERING_WORLD" then
    if _G.GetAddOnMetadata then
      addon.version = _G.GetAddOnMetadata(addonName, "Version") or "Unknown"
    elseif C_AddOns and C_AddOns.GetAddOnMetadata then
      addon.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "Unknown"
    end

    -- Wago Analytics init (no-op if the shim/client isn't present)
    local A = _G.DungeonTeleportsAnalytics
    if A and type(A.init) == "function" then
      pcall(A.init, A, "DungeonTeleports", addon.version)
      AnalyticsEvent("addon_loaded", { version = addon.version })
    end

    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
  end
end)

-- Initialize database if missing
if not DungeonTeleportsDB then
  DungeonTeleportsDB = {}
end

local DungeonTeleports = CreateFrame("Frame")
local createdButtons = {}
local createdTexts = {}

-- Main frame with polished visuals and retained functionality
local mainFrame = CreateFrame("Frame", "DungeonTeleportsMainFrame", UIParent, "BackdropTemplate")
mainFrame:SetSize(295, 600)
mainFrame:SetPoint("CENTER")
mainFrame:SetBackdrop({
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true, tileSize = 32, edgeSize = 32,
  insets = { left = 8, right = 8, top = 8, bottom = 8 },
})
mainFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
mainFrame:SetFrameStrata("DIALOG")
mainFrame:SetToplevel(true)
tinsert(UISpecialFrames, "DungeonTeleportsMainFrame")

-- Soft rounded border and shadow
if not mainFrame.shadow then
  mainFrame.shadow = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
  mainFrame.shadow:SetPoint("TOPLEFT", -5, 5)
  mainFrame.shadow:SetPoint("BOTTOMRIGHT", 5, -5)
  mainFrame.shadow:SetBackdrop({
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
    edgeSize = 16,
  })
  mainFrame.shadow:SetBackdropBorderColor(0, 0, 0, 0.75)
end

-- Title
local title = mainFrame:CreateFontString(nil, "OVERLAY")
title:SetFontObject("GameFontHighlightLarge")
title:SetFont(select(1, title:GetFont()), 18, "OUTLINE") -- Increased size & bold outline
title:SetShadowOffset(1, -1)
title:SetShadowColor(0, 0, 0, 0.75)
title:SetPoint("TOP", mainFrame, "TOP", 0, -35)
title:SetText(L["ADDON_TITLE"])
title:SetTextColor(1, 1, 0)

-- Close button
local closeButton = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
closeButton:SetSize(24, 24)
closeButton:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -10, -10)
closeButton:SetScript("OnClick", function()
  DT_SafeHide(mainFrame)
  DungeonTeleportsDB.isVisible = false
  AnalyticsEvent("ui_visibility", { visible = false })
end)

-- Add black base layer for contrast (kept for compatibility)
local baseBackground = mainFrame:CreateTexture(nil, "BACKGROUND")
baseBackground:SetAllPoints(mainFrame)
baseBackground:SetColorTexture(0, 0, 0, 1)

-- Optional background image/alpha texture
local backgroundTexture = mainFrame:CreateTexture(nil, "ARTWORK")
backgroundTexture:SetAllPoints(mainFrame)
backgroundTexture:SetColorTexture(0, 0, 0, DungeonTeleportsDB.backgroundAlpha or 0.7)
backgroundTexture:SetDrawLayer("ARTWORK", -1)  -- Ensure it draws behind the border
mainFrame.backgroundTexture = backgroundTexture

-- Keep border opaque regardless of alpha slider
mainFrame.SetBackdropColor = function(self, r, g, b, a)
  getmetatable(self).__index.SetBackdropColor(self, r, g, b, 0.95)
end

-- Export frame to addon
_G.DungeonTeleportsMainFrame = mainFrame
addon.mainFrame = mainFrame

-- UI visibility analytics
mainFrame:HookScript("OnShow", function()
  AnalyticsEvent("ui_visibility", { visible = true })
end)

mainFrame:HookScript("OnHide", function()
  AnalyticsEvent("ui_visibility", { visible = false })
end)

-- Background updater method (defined once, not inside loops)
function DungeonTeleportsMainFrame:UpdateBackground()
  if not self.bg then
    self.bg = self:CreateTexture(nil, "BACKGROUND")
    self.bg:SetAllPoints()
    self.bg:SetColorTexture(0, 0, 0, 0.5) -- fallback color
  end

  local expansion = DungeonTeleportsDB.selectedExpansion or constants.orderedExpansions[1]
  local tex = constants.mapExpansionToBackground[expansion]

  if tex then
    self.bg:SetTexture(tex)
  else
    self.bg:SetTexture(nil)
  end

  self.bg:SetShown(not DungeonTeleportsDB.disableBackground)
end

-- Dropdown Menu for Expansions
local dropdown = CreateFrame("Frame", "DungeonTeleportsDropdown", mainFrame, "UIDropDownMenuTemplate")
dropdown:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -75)
UIDropDownMenu_SetWidth(dropdown, 200)
UIDropDownMenu_SetText(dropdown, L["SELECT_EXPANSION"])

-- Function to update the background when switching expansions
function addon.updateBackground(selectedExpansion)
  local background = DungeonTeleportsMainFrame.backgroundTexture
  if not background then return end

  local alpha = DungeonTeleportsDB.backgroundAlpha or 0.7
  local bgPath = addon.constants.mapExpansionToBackground[selectedExpansion]

  if DungeonTeleportsDB.disableBackground then
    background:SetTexture(nil)
    background:SetColorTexture(0, 0, 0, alpha)
    return
  end

  if bgPath then
    background:SetTexture(bgPath)
    background:SetAlpha(alpha)
  else
    background:SetTexture(nil)
    background:SetColorTexture(0, 0, 0, alpha)
  end
end

-- Dropdown selection handler (declared before Initialize so it's in scope)
local function OnExpansionSelected(self, arg1)
  UIDropDownMenu_SetText(dropdown, arg1)
  DungeonTeleportsDB.lastExpansion = arg1 -- Save selection
  AnalyticsEvent("expansion_selected", { expansion = arg1 })

  -- Ensure Background Resets Correctly
  addon.updateBackground(arg1)
  createTeleportButtons(arg1)
end

-- Initialize the dropdown
UIDropDownMenu_Initialize(dropdown, function(self, level, menuList)
  local info = UIDropDownMenu_CreateInfo()
  info.notCheckable = true
  for _, expansion in ipairs(constants.orderedExpansions) do
    info.text = L[expansion] or expansion
    info.arg1 = expansion
    info.func = OnExpansionSelected
    UIDropDownMenu_AddButton(info)
  end
end)

-- Set faction-specific spell IDs (e.g. Siege of Boralus)
local function SetFactionSpecificSpells()
  local faction = UnitFactionGroup("player")
  if faction == "Alliance" then
    constants.mapIDtoSpellID[506] = 445418 -- Alliance spell ID for Siege of Boralus
    constants.mapIDtoSpellID[507] = 467553 -- Alliance spell ID for The Motherlode!!
  elseif faction == "Horde" then
    constants.mapIDtoSpellID[506] = 464256 -- Horde spell ID for Siege of Boralus
    constants.mapIDtoSpellID[507] = 467555 -- Horde spell ID for The Motherlode!!
  else
    constants.mapIDtoSpellID[506] = nil -- No teleport if faction is unknown
    constants.mapIDtoSpellID[507] = nil -- No teleport if faction is unknown
  end
end

-- Function to create teleport buttons
function createTeleportButtons(selectedExpansion)
  local mapIDs = constants.mapExpansionToMapID[selectedExpansion]
  if not mapIDs then return end

  -- Clear existing buttons and texts before creating new ones
  for _, button in pairs(createdButtons) do
    button:Hide()
    button:SetParent(nil)
  end
  wipe(createdButtons)

  for _, text in pairs(createdTexts) do
    text:Hide()
    text:SetParent(nil)
  end
  wipe(createdTexts)

  -- Track buttons globally so the config checkbox can update them live
  DungeonTeleportsMainFrame.buttons = {}

  local index = 0
  local buttonHeight = 50 -- Height per button (including padding)
  local topPadding = 20 -- Padding at the top (dropdown + title space)
  local bottomPadding = 140 -- Padding at the bottom

  for _, mapID in ipairs(mapIDs) do
    local spellID = constants.mapIDtoSpellID[mapID]
    local dungeonName = constants.mapIDtoDungeonName[mapID] or "Unknown Dungeon"

    if spellID then
      local button = CreateFrame("Button", "DungeonTeleportButton" .. mapID, mainFrame, "SecureActionButtonTemplate")
      button:SetSize(40, 40)
      button:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 20, -(index * buttonHeight + topPadding))

      -- Teleport click analytics (fires before the secure action)
      button:SetScript("PreClick", function()
        local known = IsSpellKnown(spellID) or IsPlayerSpell(spellID) or false
        AnalyticsEvent("teleport_click", {
          spellID = spellID,
          expansion = selectedExpansion,
          known = known,
        })
      end)

      -- Button icon
      local texture = button:CreateTexture(nil, "BACKGROUND")
      texture:SetAllPoints(button)
      texture:SetTexture(C_Spell.GetSpellTexture(spellID))

      -- Cooldown overlay (must be a named child of a secure button)
      local cooldown = CreateFrame("Cooldown", "$parentCooldown", button, "CooldownFrameTemplate")
      cooldown:SetAllPoints()
      cooldown:SetFrameLevel(button:GetFrameLevel() + 1)
      cooldown:SetSwipeTexture("Interface\\Cooldown\\ping4") -- optional visual
      cooldown:SetSwipeColor(0, 0, 0, 0.6)
      cooldown:SetDrawBling(false)
      cooldown:SetDrawEdge(true)
      cooldown:SetHideCountdownNumbers(false)
      cooldown:Hide()

      -- Optional disabling of cooldown overlay
      if DungeonTeleportsDB.disableCooldownOverlay then
        cooldown:SetSwipeColor(0, 0, 0, 0)  -- Fully transparent
        cooldown:SetDrawEdge(false)
        cooldown:SetDrawBling(false)
        cooldown:SetHideCountdownNumbers(true)
      end

      -- Dungeon name text
      local nameText = DungeonTeleportsMainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      nameText:SetPoint("LEFT", button, "RIGHT", 10, 0)
      nameText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
      nameText:SetText(dungeonName)
      createdTexts[mapID] = nameText -- Track the text for clearing later

      -- Check if the spell is known
      if IsSpellKnown(spellID) then
        button:SetAttribute("type", "spell")
        button:SetAttribute("spell", spellID)
        button:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
        texture:SetDesaturated(false)
        nameText:SetTextColor(1, 1, 0) -- Yellow for learned teleports

        -- Cooldown update function for known spells
local function UpdateCooldown()
  -- Midnight beta: avoid reading cooldown "secret" fields during combat
  if InCombatLockdown and InCombatLockdown() then
    cooldown:Clear()
    cooldown:Hide()
    return
  end

  local info = C_Spell.GetSpellCooldown(spellID)
  local start = info and info.startTime or nil
  local dur   = info and info.duration  or nil

  if type(start) == "number" and type(dur) == "number" and start > 0 and dur > 0 then
    cooldown:SetCooldown(start, dur)
    cooldown:Show()
  else
    cooldown:Clear()
    cooldown:Hide()
  end
end


        -- Register cooldown update events only if the spell is known
        button:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        button:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
        button:RegisterEvent("PLAYER_ENTERING_WORLD")
        button:RegisterEvent("PLAYER_REGEN_ENABLED")
	button:SetScript("OnEvent", function(_, evt)
  	  UpdateCooldown()
	end)


        -- Force immediate cooldown update on button creation
        UpdateCooldown()
      else
        texture:SetDesaturated(true)
        button:SetEnabled(true)
        button:RegisterForClicks()
        nameText:SetTextColor(0.5, 0.5, 0.5) -- Grey for unlearned teleports
        cooldown:Hide() -- Hide cooldown overlay if teleport not known
      end

      -- Tooltip setup with live updates
      button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetSpellByID(spellID)

        -- Function to update the tooltip in real-time
local function updateTooltip()
  GameTooltip:ClearLines()
  GameTooltip:SetSpellByID(spellID)

  if InCombatLockdown and InCombatLockdown() then
    GameTooltip:AddLine(L["COOLDOWN_UNKNOWN_IN_COMBAT"] or "Cooldown info hidden in combat (beta).", 1, 0, 0)
    GameTooltip:Show()
    return
  end

  if IsSpellKnown(spellID) then
    local info  = C_Spell.GetSpellCooldown(spellID)
    local start = info and info.startTime or nil
    local dur   = info and info.duration  or nil

    if type(start) == "number" and type(dur) == "number" and start > 0 and dur > 0 then
      local remaining = (start + dur) - GetTime()
      GameTooltip:AddLine(L["COOLDOWN_NOT_READY"], 1, 0, 0)
      GameTooltip:AddLine("Cooldown: " .. SecondsToTime(math.max(0, remaining)), 1, 0, 0)
    else
      GameTooltip:AddLine(L["COOLDOWN_READY"], 0, 1, 0)
      GameTooltip:AddLine(L["CLICK_TO_TELEPORT"], 0, 1, 0)
    end
  else
    GameTooltip:AddLine(L["TELEPORT_NOT_KNOWN"], 1, 0, 0)
  end

  GameTooltip:Show()
end


        -- Show tooltip immediately
        updateTooltip()

        -- Start updating tooltip in real-time
        self:SetScript("OnUpdate", function()
          updateTooltip()
        end)
      end)

      -- Stop updating tooltip when mouse leaves
      button:SetScript("OnLeave", function(self)
        self:SetScript("OnUpdate", nil) -- Stop updating tooltip
        GameTooltip:Hide()
      end)

      createdButtons[mapID] = button
      table.insert(DungeonTeleportsMainFrame.buttons, button)
      index = index + 1
    end
  end

  -- Adjust frame height based on the number of buttons
  local totalHeight = topPadding + (index * buttonHeight) + bottomPadding
  local minHeight = 450 -- Minimum frame height
  local maxHeight = 800 -- Maximum frame height to prevent it from being too tall

  -- Apply height, clamped between min and max values
  totalHeight = math.max(minHeight, math.min(totalHeight, maxHeight))
  mainFrame:SetHeight(totalHeight)
end

SetFactionSpecificSpells() -- Set faction-specific spell IDs

-- Now set the OnShow script AFTER dropdown is ready
mainFrame:SetScript("OnShow", function()
  local defaultExpansion = DungeonTeleportsDB.defaultExpansion or L["Current Season"]

  -- Only set text if dropdown exists
  if dropdown then
    UIDropDownMenu_SetText(dropdown, defaultExpansion)
  else
    print("Dropdown not initialized!")
  end

  createTeleportButtons(defaultExpansion)
  C_Timer.After(0.5, function()
    addon.updateBackground(DungeonTeleportsDB.defaultExpansion or L["Current Season"])
  end)
end)

-- Load default expansion on login
DungeonTeleports:RegisterEvent("PLAYER_LOGIN")
DungeonTeleports:SetScript("OnEvent", function()
  DungeonTeleportsDB = DungeonTeleportsDB or {}

  -- Ensure Defaults
  DungeonTeleportsDB.defaultExpansion = DungeonTeleportsDB.defaultExpansion or L["Current Season"]
  DungeonTeleportsDB.backgroundAlpha = DungeonTeleportsDB.backgroundAlpha or 0.7

  -- Reset Background First Before UI Loads
  addon.updateBackground(DungeonTeleportsDB.defaultExpansion)

  -- Now Apply UI Elements
  UIDropDownMenu_SetText(dropdown, DungeonTeleportsDB.defaultExpansion)
  createTeleportButtons(DungeonTeleportsDB.defaultExpansion)

  mainFrame:Hide()
  DungeonTeleportsDB.isVisible = false
end)

-- Track actual teleport outcomes
local castWatcher = CreateFrame("Frame")
castWatcher:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
castWatcher:RegisterEvent("UNIT_SPELLCAST_FAILED")
castWatcher:SetScript("OnEvent", function(_, evt, unit, _, spellID)
  if unit ~= "player" then return end
  if evt == "UNIT_SPELLCAST_SUCCEEDED" then
    AnalyticsEvent("teleport_succeeded", { spellID = spellID })
  elseif evt == "UNIT_SPELLCAST_FAILED" then
    AnalyticsEvent("teleport_failed", { spellID = spellID })
  end
end)

-- Slash command to toggle the frame
SLASH_DUNGEONTELEPORTS1 = "/dungeonteleports"
SLASH_DUNGEONTELEPORTS2 = "/dtp"
SlashCmdList["DUNGEONTELEPORTS"] = function()
  if DungeonTeleportsMainFrame:IsShown() then
    DungeonTeleportsMainFrame:Hide()
    DungeonTeleportsDB.isVisible = false
    AnalyticsEvent("ui_visibility", { visible = false })
  else
    DungeonTeleportsMainFrame:Show()
    DungeonTeleportsDB.isVisible = true
    AnalyticsEvent("ui_visibility", { visible = true })

    -- Use stored default expansion or fallback to "Current Season"
    local defaultExpansion = DungeonTeleportsDB.defaultExpansion or L["Current Season"]

    UIDropDownMenu_SetText(dropdown, defaultExpansion)
    createTeleportButtons(defaultExpansion)
    C_Timer.After(0.5, function()
      addon.updateBackground(DungeonTeleportsDB.defaultExpansion or L["Current Season"])
    end)
  end
end
