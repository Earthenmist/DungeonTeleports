local addonName, addon = ...

-- Cooldown rendering and combat-safe visibility
local function SafeCooldownActive(startTime, duration)
  if startTime == nil or duration == nil then
    return false
  end
  local ok, active = pcall(function()
    return startTime > 0 and duration > 0
  end)
  if ok then
    return active
  end
  -- If comparison fails, leave rendering to the cooldown frame.
  return true
end

local function SafeSetCooldown(cooldownFrame, startTime, duration, modRate)
  if not cooldownFrame then
    return
  end
  local ok = pcall(function()
    if cooldownFrame.SetCooldown then
      cooldownFrame:SetCooldown(startTime, duration, modRate)
    elseif CooldownFrame_Set then
      CooldownFrame_Set(cooldownFrame, startTime, duration, modRate)
    end
  end)
  return ok
end

-- Defer hiding protected frames until combat ends.
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

-- Mythic+ suppression
-- Suppress the window during a run; resume after leaving the party/scenario instance.
addon._DT_mplus_suppressed = addon._DT_mplus_suppressed or false
addon._DT_keystone_slotted_at = addon._DT_keystone_slotted_at or nil
addon._DT_mplus_completed = addon._DT_mplus_completed or nil

local function DT_SetMPlusSuppressed(state)
  state = state and true or false
  addon._DT_mplus_suppressed = state

  -- If suppressing, close the window immediately (combat-safe).
  if
    state
    and DungeonTeleportsMainFrame
    and DungeonTeleportsMainFrame.IsShown
    and DungeonTeleportsMainFrame:IsShown()
  then
    DT_SafeHide(DungeonTeleportsMainFrame)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
      DEFAULT_CHAT_FRAME:AddMessage("|cffff7f00DungeonTeleports: Suppressed during Mythic+ run (Midnight safety).|r")
    end
  end
end

local function DT_IsChallengeModeActive()
  local ok, active = pcall(function()
    return C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive()
  end)
  return ok and active or false
end

local function DT_ShouldUnsuppress()
  -- Wait until the run has ended and the player is outside a party/scenario instance.
  if DT_IsChallengeModeActive() then
    return false
  end
  local inInstance, instanceType = IsInInstance()
  if inInstance and (instanceType == "party" or instanceType == "scenario") then
    return false
  end
  return true
end

local mplusGuardFrame = CreateFrame("Frame")
mplusGuardFrame:RegisterEvent("CHALLENGE_MODE_KEYSTONE_SLOTTED")
mplusGuardFrame:RegisterEvent("CHALLENGE_MODE_START")
mplusGuardFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
mplusGuardFrame:RegisterEvent("CHALLENGE_MODE_RESET")
mplusGuardFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
mplusGuardFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
mplusGuardFrame:SetScript("OnEvent", function(_, event)
  if event == "CHALLENGE_MODE_KEYSTONE_SLOTTED" then
    addon._DT_keystone_slotted_at = GetTime()
    addon._DT_mplus_completed = nil
    return
  end

  if event == "CHALLENGE_MODE_START" then
    -- Suppress at run start even if the keystone-slotted event was missed.
    if addon._DT_keystone_slotted_at then
      DT_SetMPlusSuppressed(true)
    else
      DT_SetMPlusSuppressed(true)
    end
    return
  end

  if event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" then
    -- Keep suppressed until the player leaves the instance / zone changes.
    addon._DT_mplus_completed = true
    return
  end

  -- World/zone transitions: enforce suppression while active; otherwise re-enable once out.
  if DT_IsChallengeModeActive() then
    DT_SetMPlusSuppressed(true)
    return
  end

  if addon._DT_mplus_suppressed and DT_ShouldUnsuppress() then
    addon._DT_keystone_slotted_at = nil
    addon._DT_mplus_completed = nil
    DT_SetMPlusSuppressed(false)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
      DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DungeonTeleports: Re-enabled after Mythic+ run.|r")
    end
  end
end)
-- Addon metadata and analytics

local ok, WA = pcall(LibStub, "WagoAnalytics")
if ok and WA and WA.Register then
  WA = WA:Register("BNBeblGx")
end
local constants = addon.constants
local L = addon.L

addon.version = "Unknown"

-- Missing spellbook APIs are treated as an unknown spell.
local function DT_IsSpellKnown(spellID)
  if not C_SpellBook then
    return false
  end
  if C_SpellBook.IsSpellInSpellBook and C_SpellBook.IsSpellInSpellBook(spellID) then
    return true
  end
  if C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spellID) then
    return true
  end
  return false
end

-- Analytics failures must not interrupt addon behavior.
local function AnalyticsEvent(name, data)
  local A = _G.DungeonTeleportsAnalytics
  if A and type(A.event) == "function" then
    pcall(A.event, A, name, data)
  end
end

-- Initialize metadata and analytics once the player enters the world.
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

-- Saved settings and legacy expansion-key migration
if not DungeonTeleportsDB then
  DungeonTeleportsDB = {}
end
if DungeonTeleportsDB.autoInsertKeystone == nil then
  DungeonTeleportsDB.autoInsertKeystone = false
end
if DungeonTeleportsDB.keystoneModuleEnabled == nil then
  DungeonTeleportsDB.keystoneModuleEnabled = true
end

-- Before 2.1.10, saved selections could contain translated expansion names.
-- Convert them to stable keys before reading the selected/default expansion.
local function DT_MigrateExpansionKey(value)
  if value == nil or value == "__KEYSTONES__" then
    return value
  end
  if constants and constants.mapExpansionToMapID and constants.mapExpansionToMapID[value] then
    return value -- already a valid stable key
  end
  if constants and constants.orderedExpansions and L then
    -- Search all loaded locales because the saved value may come from another client language.
    for _, localeTable in pairs(L) do
      if type(localeTable) == "table" then
        for _, key in ipairs(constants.orderedExpansions) do
          if localeTable[key] == value then
            return key
          end
        end
      end
    end
  end
  return nil -- unrecognized; caller falls back to the default expansion
end

DungeonTeleportsDB.selectedExpansion = DT_MigrateExpansionKey(DungeonTeleportsDB.selectedExpansion)
DungeonTeleportsDB.defaultExpansion = DT_MigrateExpansionKey(DungeonTeleportsDB.defaultExpansion)

-- Keystone receptacle: optional auto-insertion and saved window position
local DT_keystoneFrameSetupWaiter

local function DT_SetupKeystoneFrame()
  local kf = _G.ChallengesKeystoneFrame
  if not kf then
    return
  end

  -- Setup and position restore modify a protected frame. World-entry and addon-load
  -- events can occur in combat, so defer the entire operation.
  if InCombatLockdown and InCombatLockdown() then
    if not DT_keystoneFrameSetupWaiter then
      DT_keystoneFrameSetupWaiter = CreateFrame("Frame")
      DT_keystoneFrameSetupWaiter:RegisterEvent("PLAYER_REGEN_ENABLED")
      DT_keystoneFrameSetupWaiter:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        DT_keystoneFrameSetupWaiter = nil
        DT_SetupKeystoneFrame()
      end)
    end
    return
  end

  -- Make movable (only needs to be done once)
  if not kf._DT_movableApplied then
    kf:SetMovable(true)
    kf:EnableMouse(true)
    kf:RegisterForDrag("LeftButton")
    kf:SetClampedToScreen(true)

    kf:HookScript("OnDragStart", function(self)
      if InCombatLockdown and InCombatLockdown() then
        return
      end
      self:StartMoving()
    end)

    kf:HookScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      local point, relativeTo, relativePoint, x, y = self:GetPoint()
      DungeonTeleportsDB.keystoneFramePos = DungeonTeleportsDB.keystoneFramePos or {}
      DungeonTeleportsDB.keystoneFramePos.point = point
      DungeonTeleportsDB.keystoneFramePos.relativeTo = (relativeTo and relativeTo.GetName and relativeTo:GetName())
        or "UIParent"
      DungeonTeleportsDB.keystoneFramePos.relativePoint = relativePoint
      DungeonTeleportsDB.keystoneFramePos.x = x
      DungeonTeleportsDB.keystoneFramePos.y = y
    end)

    -- Stop retries when the keystone belongs to a different dungeon.
    if not kf._DT_wrongKeyWatcher then
      local watcher = CreateFrame("Frame")
      watcher:RegisterEvent("UI_ERROR_MESSAGE")
      watcher:SetScript("OnEvent", function(_, event, errorType, msg)
        if event ~= "UI_ERROR_MESSAGE" then
          return
        end
        -- Error 1012 identifies a wrong-dungeon keystone independently of locale.
        if errorType == 1012 then
          kf._DT_stopAutoInsert = true
          ClearCursor()
          return
        end
        -- Legacy fallback for builds that provide the English error text.
        if type(msg) == "string" and msg:lower():find("different dungeon", 1, true) then
          kf._DT_stopAutoInsert = true
          ClearCursor()
        end
      end)
      kf._DT_wrongKeyWatcher = watcher
    end

    -- Auto-slot keystone when the receptacle window opens
    local function DT_KeystoneIsSlotted()
      if C_ChallengeMode and C_ChallengeMode.GetSlottedKeystoneInfo then
        local mapID = C_ChallengeMode.GetSlottedKeystoneInfo()
        return mapID ~= nil
      end
      if C_ChallengeMode and C_ChallengeMode.HasSlottedKeystone then
        return C_ChallengeMode.HasSlottedKeystone()
      end
      return false
    end

    local function DT_TrySlotKeystone(retries)
      if not (DungeonTeleportsDB and DungeonTeleportsDB.autoInsertKeystone == true) then
        return
      end
      if InCombatLockdown and InCombatLockdown() then
        return
      end
      if kf._DT_stopAutoInsert then
        return
      end
      if DT_KeystoneIsSlotted() then
        return
      end

      -- Prefer Blizzard API if it works
      if C_ChallengeMode and C_ChallengeMode.SlotKeystone then
        pcall(C_ChallengeMode.SlotKeystone)
        if DT_KeystoneIsSlotted() then
          return
        end
      end

      -- Fall back to picking up the keystone and clicking an available socket button.
      local IDs = { [138019] = true, [151086] = true, [158923] = true, [180653] = true }
      local function FindKeystoneInBags()
        if not C_Container or not C_Container.GetContainerNumSlots then
          return
        end
        for bag = 0, (NUM_BAG_FRAMES or 4) do
          local slots = C_Container.GetContainerNumSlots(bag)
          for slot = 1, slots do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID and IDs[itemID] then
              return bag, slot
            end
          end
        end
      end

      local bag, slot = FindKeystoneInBags()
      if bag and slot and C_Container and C_Container.PickupContainerItem then
        ClearCursor()
        C_Container.PickupContainerItem(bag, slot)

        local clickTargets = {
          kf.KeystoneSlot,
          kf.KeystoneButton,
          kf.InsertButton,
          kf.SocketButton,
          kf.KeystoneFrame and kf.KeystoneFrame.KeystoneSlot,
        }

        for _, btn in ipairs(clickTargets) do
          if btn and btn.Click then
            pcall(function()
              btn:Click()
            end)
            break
          end
        end

        ClearCursor()
      end

      if retries and retries > 0 and not DT_KeystoneIsSlotted() then
        C_Timer.After(0.2, function()
          DT_TrySlotKeystone(retries - 1)
        end)
      end
    end

    kf:HookScript("OnShow", function()
      if not (DungeonTeleportsDB and DungeonTeleportsDB.autoInsertKeystone == true) then
        return
      end
      kf._DT_stopAutoInsert = false
      -- Allow the receptacle to initialize before the first insertion attempt.
      C_Timer.After(0.1, function()
        DT_TrySlotKeystone(10) -- retry for ~2 seconds total
      end)
    end)
    kf._DT_movableApplied = true
  end

  -- Restore saved position (safe if target frame no longer exists)
  local pos = DungeonTeleportsDB.keystoneFramePos
  if pos and pos.point and pos.relativePoint and pos.x and pos.y then
    kf:ClearAllPoints()
    local rel = _G[pos.relativeTo] or UIParent
    kf:SetPoint(pos.point, rel, pos.relativePoint, pos.x, pos.y)
  end
end

-- Keystone frame may not exist until Blizzard_ChallengesUI loads
do
  local kfLoader = CreateFrame("Frame")
  kfLoader:RegisterEvent("ADDON_LOADED")
  kfLoader:RegisterEvent("PLAYER_ENTERING_WORLD")
  kfLoader:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name ~= "Blizzard_ChallengesUI" then
      return
    end
    if event == "PLAYER_ENTERING_WORLD" then
      if IsAddOnLoaded and not IsAddOnLoaded("Blizzard_ChallengesUI") then
        return
      end
    end
    DT_SetupKeystoneFrame()
  end)
end

-- Main window and shared widget styling
local DungeonTeleports = CreateFrame("Frame")
local createdButtons = {}
local createdTexts = {}
local currentExpansionButtons = {}

local UI = {
  ROW_HEIGHT = 72,
  ROW_GAP = 10,
  COLUMN_GAP = 12,
  DEFAULT_WIDTH = 1010,
  DEFAULT_HEIGHT = 680,
  MIN_SCALE = 0.70,
  MAX_SCALE = 1.15,
  DEFAULT_SCALE = 1.0,
}

local COLORS = {
  bg = { 0.05, 0.05, 0.07, 0.98 },
  bgLight = { 0.08, 0.08, 0.10, 1 },
  bgCard = { 0.06, 0.06, 0.08, 1 },
  border = { 0.00, 0.74, 0.73, 0.95 },
  borderSoft = { 0.00, 0.74, 0.73, 0.35 },
  accent = { 0.00, 0.74, 0.73, 1 },
  accentDark = { 0.07, 0.41, 0.38, 1 },
  hover = { 0.10, 0.16, 0.18, 1 },
  text = { 0.92, 0.92, 0.92, 1 },
  textDim = { 0.62, 0.62, 0.65, 1 },
  success = { 0.20, 0.85, 0.40, 1 },
  warning = { 1.00, 0.82, 0.00, 1 },
  danger = { 0.95, 0.35, 0.35, 1 },
}

local _, playerClass = UnitClass("player")
local classColor = (RAID_CLASS_COLORS and playerClass and RAID_CLASS_COLORS[playerClass]) or NORMAL_FONT_COLOR
if classColor then
  COLORS.accent = { classColor.r or 0.78, classColor.g or 0.61, classColor.b or 0.43, 1 }
  COLORS.border = { COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.95 }
  COLORS.borderSoft = { COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.35 }
  COLORS.accentDark = {
    math.max(0, (classColor.r or 0.78) * 0.70),
    math.max(0, (classColor.g or 0.61) * 0.70),
    math.max(0, (classColor.b or 0.43) * 0.70),
    1,
  }
  COLORS.hover = {
    math.min(1, (classColor.r or 0.78) * 0.20 + 0.08),
    math.min(1, (classColor.g or 0.61) * 0.20 + 0.08),
    math.min(1, (classColor.b or 0.43) * 0.20 + 0.08),
    1,
  }
end

local function ClampScale(scale)
  local value = tonumber(scale) or UI.DEFAULT_SCALE
  if value < UI.MIN_SCALE then
    value = UI.MIN_SCALE
  end
  if value > UI.MAX_SCALE then
    value = UI.MAX_SCALE
  end
  return value
end

local function SafeHideTooltip(button)
  if button and button.SetScript then
    button:SetScript("OnUpdate", nil)
  end
  GameTooltip:Hide()
end

local function CreateBackdropFrame(name, parent, inset)
  local frame = CreateFrame("Frame", name, parent, "BackdropTemplate")
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false,
    edgeSize = 1,
    insets = { left = inset or 1, right = inset or 1, top = inset or 1, bottom = inset or 1 },
  })
  return frame
end

local function SetPanelStyle(frame, bg, border)
  bg = bg or COLORS.bgCard
  border = border or COLORS.borderSoft
  frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
  frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
end

local function StyleHeaderButton(button, glyph, size)
  button:SetSize(size, size)
  button:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  SetPanelStyle(button, COLORS.bgCard, COLORS.borderSoft)
  button:SetNormalFontObject("GameFontHighlightLarge")
  button:SetText(glyph)
  local label = button:GetFontString()
  if label then
    label:SetPoint("CENTER", 0, 0)
    label:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
  end
  button:SetScript("OnEnter", function(self)
    SetPanelStyle(self, COLORS.hover, COLORS.border)
    local text = self:GetFontString()
    if text then
      text:SetTextColor(1, 1, 1)
    end
  end)
  button:SetScript("OnLeave", function(self)
    SetPanelStyle(self, COLORS.bgCard, COLORS.borderSoft)
    local text = self:GetFontString()
    if text then
      text:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    end
  end)
  button:SetScript("OnMouseDown", function(self)
    SetPanelStyle(self, COLORS.accentDark, COLORS.border)
  end)
  button:SetScript("OnMouseUp", function(self)
    SetPanelStyle(
      self,
      self:IsMouseOver() and COLORS.hover or COLORS.bgCard,
      self:IsMouseOver() and COLORS.border or COLORS.borderSoft
    )
  end)
end

-- Reuse the same class-colored widgets in auxiliary windows.
addon.UITheme = {
  colors = COLORS,
  CreatePanel = CreateBackdropFrame,
  StylePanel = SetPanelStyle,
  StyleButton = StyleHeaderButton,
}

local mainFrame = CreateBackdropFrame("DungeonTeleportsMainFrame", UIParent, 1)
mainFrame:SetSize(UI.DEFAULT_WIDTH, UI.DEFAULT_HEIGHT)
mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
SetPanelStyle(mainFrame, COLORS.bg, { 0.02, 0.02, 0.03, 0.85 })
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  DungeonTeleportsDB = DungeonTeleportsDB or {}
  local point, _, relativePoint, x, y = self:GetPoint()
  DungeonTeleportsDB.windowPosition = {
    point = point,
    relativePoint = relativePoint,
    x = x,
    y = y,
  }
end)
mainFrame:SetFrameStrata("DIALOG")
mainFrame:SetToplevel(true)
mainFrame:SetClampedToScreen(true)
tinsert(UISpecialFrames, "DungeonTeleportsMainFrame")

local savedScale = ClampScale(DungeonTeleportsDB and DungeonTeleportsDB.uiScale)
mainFrame:SetScale(savedScale)

mainFrame.header = CreateBackdropFrame(nil, mainFrame, 1)
mainFrame.header:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 1, -1)
mainFrame.header:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -1, -1)
mainFrame.header:SetHeight(42)
SetPanelStyle(mainFrame.header, COLORS.accentDark, COLORS.accentDark)

mainFrame.logo = mainFrame.header:CreateTexture(nil, "ARTWORK")
mainFrame.logo:SetSize(18, 18)
mainFrame.logo:SetPoint("LEFT", 8, 0)
mainFrame.logo:SetTexture("Interface\\AddOns\\DungeonTeleports\\Images\\DungeonTeleportsLogo.tga")

mainFrame.title = mainFrame.header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
mainFrame.title:SetPoint("LEFT", mainFrame.logo, "RIGHT", 8, 0)
mainFrame.title:SetText(L["ADDON_TITLE"])
mainFrame.title:SetTextColor(1, 1, 1)

mainFrame.closeButton = CreateFrame("Button", nil, mainFrame.header, "BackdropTemplate")
StyleHeaderButton(mainFrame.closeButton, "×", 24)
mainFrame.closeButton:SetPoint("RIGHT", -8, 0)
mainFrame.closeButton:SetScript("OnClick", function()
  DT_SafeHide(mainFrame)
  DungeonTeleportsDB.isVisible = false
  AnalyticsEvent("ui_visibility", { visible = false })
end)

mainFrame.scaleLabel = mainFrame.header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
mainFrame.scaleLabel:SetText(L["UI_SCALE"] or "Scale")
mainFrame.scaleLabel:SetTextColor(1, 1, 1)

mainFrame.scaleValue = mainFrame.header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
mainFrame.scaleValue:SetWidth(36)
mainFrame.scaleValue:SetJustifyH("RIGHT")
mainFrame.scaleValue:SetText("100%")
mainFrame.scaleValue:SetTextColor(1, 1, 1)

mainFrame.pendingScale = savedScale
mainFrame.scaleSlider = CreateFrame("Slider", "DungeonTeleportsScaleSlider", mainFrame.header)
mainFrame.scaleSlider:SetSize(96, 22)
mainFrame.scaleSlider:SetOrientation("HORIZONTAL")
mainFrame.scaleSlider:EnableMouse(true)
mainFrame.scaleSlider:SetMinMaxValues(UI.MIN_SCALE, UI.MAX_SCALE)
mainFrame.scaleSlider:SetValueStep(0.01)
mainFrame.scaleSlider:SetObeyStepOnDrag(true)

mainFrame.scaleSlider.track = mainFrame.scaleSlider:CreateTexture(nil, "BACKGROUND")
mainFrame.scaleSlider.track:SetPoint("LEFT", 0, 0)
mainFrame.scaleSlider.track:SetPoint("RIGHT", 0, 0)
mainFrame.scaleSlider.track:SetHeight(6)
mainFrame.scaleSlider.track:SetColorTexture(COLORS.borderSoft[1], COLORS.borderSoft[2], COLORS.borderSoft[3], 1)

mainFrame.scaleSlider.trackBackground = mainFrame.scaleSlider:CreateTexture(nil, "BORDER")
mainFrame.scaleSlider.trackBackground:SetPoint("TOPLEFT", mainFrame.scaleSlider.track, "TOPLEFT", 1, -1)
mainFrame.scaleSlider.trackBackground:SetPoint("BOTTOMRIGHT", mainFrame.scaleSlider.track, "BOTTOMRIGHT", -1, 1)
mainFrame.scaleSlider.trackBackground:SetColorTexture(COLORS.bgCard[1], COLORS.bgCard[2], COLORS.bgCard[3], 1)

mainFrame.scaleSlider.fill = mainFrame.scaleSlider:CreateTexture(nil, "ARTWORK")
mainFrame.scaleSlider.fill:SetPoint("LEFT", 1, 0)
mainFrame.scaleSlider.fill:SetHeight(4)
mainFrame.scaleSlider.fill:SetColorTexture(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)

mainFrame.scaleSlider:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
mainFrame.scaleSlider.thumb = mainFrame.scaleSlider:GetThumbTexture()
mainFrame.scaleSlider.thumb:SetSize(8, 16)
mainFrame.scaleSlider.thumb:SetDrawLayer("OVERLAY")
mainFrame.scaleSlider.thumb:SetVertexColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
mainFrame.scaleSlider:SetScript("OnEnter", function(self)
  self.track:SetColorTexture(COLORS.border[1], COLORS.border[2], COLORS.border[3], 1)
  self.thumb:SetVertexColor(1, 1, 1, 1)
end)
mainFrame.scaleSlider:SetScript("OnLeave", function(self)
  self.track:SetColorTexture(COLORS.borderSoft[1], COLORS.borderSoft[2], COLORS.borderSoft[3], 1)
  self.thumb:SetVertexColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
end)

local function ApplyMainFrameScale(value)
  value = ClampScale(value)
  mainFrame.pendingScale = value
  mainFrame:SetScale(value)
  DungeonTeleportsDB = DungeonTeleportsDB or {}
  DungeonTeleportsDB.uiScale = value
  if mainFrame.scaleValue then
    mainFrame.scaleValue:SetText(string.format("%d%%", math.floor(value * 100 + 0.5)))
  end
end

local function NudgeMainFrameScale(delta)
  local current = mainFrame.pendingScale or mainFrame.scaleSlider:GetValue() or savedScale
  local newValue = ClampScale(current + delta)
  mainFrame.scaleSlider:SetValue(newValue)
  ApplyMainFrameScale(newValue)
end

mainFrame.scaleDownButton = CreateFrame("Button", nil, mainFrame.header, "BackdropTemplate")
StyleHeaderButton(mainFrame.scaleDownButton, "−", 22)
mainFrame.scaleDownButton:SetScript("OnClick", function()
  NudgeMainFrameScale(-0.01)
end)

mainFrame.scaleUpButton = CreateFrame("Button", nil, mainFrame.header, "BackdropTemplate")
StyleHeaderButton(mainFrame.scaleUpButton, "+", 22)
mainFrame.scaleUpButton:SetScript("OnClick", function()
  NudgeMainFrameScale(0.01)
end)

mainFrame.scaleValue:SetPoint("RIGHT", mainFrame.closeButton, "LEFT", -10, 0)
mainFrame.scaleUpButton:SetPoint("RIGHT", mainFrame.scaleValue, "LEFT", -8, 0)
mainFrame.scaleSlider:SetPoint("RIGHT", mainFrame.scaleUpButton, "LEFT", -8, 0)
mainFrame.scaleDownButton:SetPoint("RIGHT", mainFrame.scaleSlider, "LEFT", -8, 0)
mainFrame.scaleLabel:SetPoint("RIGHT", mainFrame.scaleDownButton, "LEFT", -8, 0)

mainFrame.scaleSlider:SetScript("OnValueChanged", function(self, value)
  value = ClampScale(value)
  local fraction = (value - UI.MIN_SCALE) / (UI.MAX_SCALE - UI.MIN_SCALE)
  self.fill:SetWidth(math.max(0.01, (self:GetWidth() - 2) * fraction))
  self.fill:SetShown(fraction > 0)
  mainFrame.pendingScale = value
  if mainFrame.scaleValue then
    mainFrame.scaleValue:SetText(string.format("%d%%", math.floor(value * 100 + 0.5)))
  end
end)
mainFrame.scaleSlider:SetScript("OnMouseUp", function(self)
  ApplyMainFrameScale(self:GetValue())
end)
mainFrame.scaleSlider:SetScript("OnHide", function(self)
  ApplyMainFrameScale(self:GetValue())
end)
mainFrame.scaleSlider:SetValue(savedScale)
ApplyMainFrameScale(savedScale)

mainFrame.sidebar = CreateBackdropFrame(nil, mainFrame, 1)
mainFrame.sidebar:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 14, -50)
mainFrame.sidebar:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 14, 14)
mainFrame.sidebar:SetWidth(210)
SetPanelStyle(mainFrame.sidebar, { 0.05, 0.05, 0.07, 1 }, COLORS.borderSoft)

mainFrame.content = CreateBackdropFrame(nil, mainFrame, 1)
mainFrame.content:SetPoint("TOPLEFT", mainFrame.sidebar, "TOPRIGHT", 12, 0)
mainFrame.content:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -14, 14)
SetPanelStyle(mainFrame.content, { 0.04, 0.04, 0.06, 1 }, COLORS.borderSoft)

mainFrame.contentHeader = CreateBackdropFrame(nil, mainFrame.content, 1)
mainFrame.contentHeader:SetPoint("TOPLEFT", 12, -12)
mainFrame.contentHeader:SetPoint("TOPRIGHT", -12, -12)
mainFrame.contentHeader:SetHeight(58)
SetPanelStyle(mainFrame.contentHeader, COLORS.bgCard, COLORS.border)

mainFrame.contentIcon = mainFrame.contentHeader:CreateTexture(nil, "ARTWORK")
mainFrame.contentIcon:SetSize(30, 30)
mainFrame.contentIcon:SetPoint("LEFT", 12, 0)
mainFrame.contentIcon:SetTexture("Interface\\Icons\\inv_relics_hourglass")

mainFrame.contentTitle = mainFrame.contentHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
mainFrame.contentTitle:SetPoint("TOPLEFT", mainFrame.contentIcon, "TOPRIGHT", 10, -2)
mainFrame.contentTitle:SetJustifyH("LEFT")
mainFrame.contentTitle:SetTextColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3])

mainFrame.contentSubtitle = mainFrame.contentHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
mainFrame.contentSubtitle:SetPoint("TOPLEFT", mainFrame.contentTitle, "BOTTOMLEFT", 0, -4)
mainFrame.contentSubtitle:SetJustifyH("LEFT")
mainFrame.contentSubtitle:SetTextColor(COLORS.textDim[1], COLORS.textDim[2], COLORS.textDim[3])
mainFrame.contentSubtitle:SetText(L["TELEPORTS_BY_EXPANSION_DESC"] or "Teleport spells by expansion or current season")

mainFrame.summaryText = mainFrame.contentHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
mainFrame.summaryText:SetPoint("RIGHT", -12, 0)
mainFrame.summaryText:SetTextColor(COLORS.textDim[1], COLORS.textDim[2], COLORS.textDim[3])

mainFrame.scrollFrame =
  CreateFrame("ScrollFrame", "DungeonTeleportsScrollFrame", mainFrame.content, "UIPanelScrollFrameTemplate")
mainFrame.scrollFrame:SetPoint("TOPLEFT", mainFrame.contentHeader, "BOTTOMLEFT", 0, -12)
mainFrame.scrollFrame:SetPoint("BOTTOMRIGHT", mainFrame.content, "BOTTOMRIGHT", -30, 12)

mainFrame.scrollChild = CreateFrame("Frame", nil, mainFrame.scrollFrame)
mainFrame.scrollChild:SetSize(1, 1)
mainFrame.scrollFrame:SetScrollChild(mainFrame.scrollChild)

-- Keystone cache, sharing, and list view
local KEYSTONE_PREFIX = "DTKEYSTONE"
local KEYSTONE_CACHE_TTL_SECONDS = 8 * 24 * 60 * 60
local keystoneBrowser
local lastKeystoneBroadcast = 0
local keystoneRefreshTicker = nil
local libKeystone = nil
local libKeystoneRegistered = false
local libKeystoneHandler = {}
local lastLibKeystoneRequest = 0
local KEYSTONE_VIEW_ID = "__KEYSTONES__"

local function KeystoneShouldPauseSync()
  -- Pause sync during runs to avoid processing busy addon traffic while the UI is suppressed.
  return (addon and addon._DT_mplus_suppressed) or DT_IsChallengeModeActive()
end

local function IsKeystoneModuleEnabled()
  return not (DungeonTeleportsDB and DungeonTeleportsDB.keystoneModuleEnabled == false)
end

local function GetKeystoneSort()
  DungeonTeleportsDB = DungeonTeleportsDB or {}
  DungeonTeleportsDB.keystonesSortKey = DungeonTeleportsDB.keystonesSortKey or "level"
  DungeonTeleportsDB.keystonesSortAscending = DungeonTeleportsDB.keystonesSortAscending or false
  return DungeonTeleportsDB.keystonesSortKey, DungeonTeleportsDB.keystonesSortAscending
end

local function SetKeystoneSort(key)
  DungeonTeleportsDB = DungeonTeleportsDB or {}
  if DungeonTeleportsDB.keystonesSortKey == key then
    DungeonTeleportsDB.keystonesSortAscending = not DungeonTeleportsDB.keystonesSortAscending
  else
    DungeonTeleportsDB.keystonesSortKey = key
    DungeonTeleportsDB.keystonesSortAscending = (key == "name" or key == "dungeon")
  end
end

local function ClearTeleportRows()
  for _, button in pairs(createdButtons) do
    SafeHideTooltip(button)
    button:Hide()
    button:SetParent(nil)
  end
  wipe(createdButtons)

  for _, textObj in pairs(createdTexts) do
    if textObj and textObj.Hide then
      textObj:Hide()
      textObj:SetParent(nil)
    end
  end
  wipe(createdTexts)
end

local function ClearKeystoneRows()
  if keystoneBrowser then
    keystoneBrowser:Hide()
  end
end

local function GetFullPlayerName(unit)
  unit = unit or "player"
  local name, realm = UnitFullName(unit)
  if not name or name == "" then
    return nil
  end
  realm = realm and realm ~= "" and realm or GetRealmName()
  return name, realm, name .. "-" .. (realm or "")
end

local function GetMythicPlusRating(unit)
  if C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
    local ok, summary = pcall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, unit or "player")
    if ok and summary and summary.currentSeasonScore then
      return tonumber(summary.currentSeasonScore) or 0
    end
  end
  return 0
end

local function GetKeystoneDungeonName(challengeMapID)
  challengeMapID = tonumber(challengeMapID)
  if not challengeMapID or challengeMapID == 0 then
    return "-"
  end

  return addon:GetKeystoneDungeonName(challengeMapID) or ("Map " .. tostring(challengeMapID))
end

local function EnsureKeystoneDB()
  DungeonTeleportsDB = DungeonTeleportsDB or {}
  DungeonTeleportsDB.keystones = DungeonTeleportsDB.keystones or {}
  DungeonTeleportsDB.keystones.characters = DungeonTeleportsDB.keystones.characters or {}
  DungeonTeleportsDB.keystones.party = DungeonTeleportsDB.keystones.party or {}
  DungeonTeleportsDB.keystones.guild = DungeonTeleportsDB.keystones.guild or {}
  return DungeonTeleportsDB.keystones
end

local function PruneStaleKeystoneCache()
  local db = EnsureKeystoneDB()
  local cutoff = time() - KEYSTONE_CACHE_TTL_SECONDS

  local function pruneScope(scope)
    for fullName, record in pairs(scope or {}) do
      local updated = type(record) == "table" and tonumber(record.updated) or nil
      if updated == 0 then
        updated = tonumber(record.receivedAt)
      end
      if not updated or updated < cutoff then
        scope[fullName] = nil
      end
    end
  end

  pruneScope(db.characters)
  pruneScope(db.party)
  pruneScope(db.guild)
end

local function GetGroupFullNames()
  local group = {}
  local function addUnit(unit)
    if UnitExists and UnitExists(unit) then
      local name, realm = UnitFullName(unit)
      if name and name ~= "" then
        realm = realm and realm ~= "" and realm or GetRealmName()
        group[name .. "-" .. realm] = true
      end
    end
  end

  addUnit("player")
  if IsInRaid and IsInRaid() then
    for i = 1, 40 do
      addUnit("raid" .. i)
    end
  elseif IsInGroup and IsInGroup() then
    for i = 1, 4 do
      addUnit("party" .. i)
    end
  end
  return group
end

local function PrunePartyKeystoneCache()
  local db = EnsureKeystoneDB()
  local group = GetGroupFullNames()
  for fullName in pairs(db.party or {}) do
    if not group[fullName] then
      db.party[fullName] = nil
    end
  end
end

local function UpdateOwnKeystoneCache()
  local db = EnsureKeystoneDB()
  local name, realm, fullName = GetFullPlayerName("player")
  if not fullName then
    return nil
  end

  if not C_MythicPlus or not C_MythicPlus.GetOwnedKeystoneChallengeMapID or not C_MythicPlus.GetOwnedKeystoneLevel then
    return db.characters[fullName]
  end
  local mapOK, mapID = pcall(C_MythicPlus.GetOwnedKeystoneChallengeMapID)
  local levelOK, level = pcall(C_MythicPlus.GetOwnedKeystoneLevel)
  if not mapOK or not levelOK or (issecretvalue and (issecretvalue(mapID) or issecretvalue(level))) then
    return db.characters[fullName]
  end
  mapID, level = tonumber(mapID) or 0, tonumber(level) or 0

  local record = {
    name = name,
    realm = realm,
    fullName = fullName,
    level = level or 0,
    mapID = mapID or 0,
    dungeon = GetKeystoneDungeonName(mapID),
    rating = GetMythicPlusRating("player"),
    updated = time(),
    source = "DungeonTeleports",
  }
  db.characters[fullName] = record
  db.party[fullName] = record
  if IsInGuild and IsInGuild() then
    db.guild[fullName] = record
  end
  return record
end

local function StoreRemoteKeystone(scope, name, realm, level, mapID, rating, updated, source)
  if not name or name == "" then
    return
  end
  local db = EnsureKeystoneDB()
  local fullName = name .. "-" .. ((realm and realm ~= "") and realm or GetRealmName())
  local record = {
    name = name,
    realm = realm,
    fullName = fullName,
    level = tonumber(level),
    mapID = tonumber(mapID),
    dungeon = GetKeystoneDungeonName(mapID),
    rating = tonumber(rating) or 0,
    updated = math.min(tonumber(updated) or time(), time()),
    receivedAt = time(),
    source = source or "DungeonTeleports",
  }
  local records = scope == "GUILD" and db.guild or db.party
  local previous = records[fullName]
  if previous and (tonumber(previous.updated) or 0) > record.updated then
    return
  end
  if
    previous
    and record.updated == 0
    and previous.updated == 0
    and previous.level == record.level
    and previous.mapID == record.mapID
    and previous.rating == record.rating
  then
    return
  end
  records[fullName] = record
end

local function SplitFullName(fullName)
  if not fullName or fullName == "" then
    return nil
  end
  local name, realm = strsplit("-", fullName)
  if not name or name == "" then
    return nil
  end
  realm = realm and realm ~= "" and realm or GetRealmName()
  return name, realm
end

local function StoreExternalKeystone(scope, fullName, level, mapID, rating, updated, source)
  local name, realm = SplitFullName(fullName)
  if not name then
    return
  end
  StoreRemoteKeystone(scope or "GUILD", name, realm, level, mapID, rating, updated, source)
end

-- Keystone sharing integrations
local function GetLibKeystone()
  if libKeystone then
    return libKeystone
  end
  if LibStub then
    local ok, lib = pcall(LibStub, "LibKeystone", true)
    if ok and lib then
      libKeystone = lib
      return libKeystone
    end
  end
  return nil
end

local function RegisterLibKeystone()
  local lib = GetLibKeystone()
  if not lib or libKeystoneRegistered or not lib.Register then
    return false
  end

  local ok = pcall(lib.Register, libKeystoneHandler, function(keyLevel, mapID, playerRating, sender, channel)
    if KeystoneShouldPauseSync() then
      return
    end
    if not sender or sender == "" then
      return
    end
    local scope = (channel == "GUILD") and "GUILD" or "PARTY"
    StoreExternalKeystone(scope, sender, keyLevel, mapID, playerRating, time(), "LibKeystone")

    if
      DungeonTeleportsDB
      and DungeonTeleportsDB.selectedExpansion == "__KEYSTONES__"
      and mainFrame
      and mainFrame:IsShown()
    then
      addon.ShowKeystoneView(true)
    end
  end)

  if ok then
    libKeystoneRegistered = true
    return true
  end
  return false
end

local function RequestLibKeystones(force)
  if not IsKeystoneModuleEnabled() or KeystoneShouldPauseSync() then
    return false
  end
  local lib = GetLibKeystone()
  if not lib or not lib.Request then
    return false
  end
  RegisterLibKeystone()

  local now = GetTime and GetTime() or 0
  if not force and (now - lastLibKeystoneRequest) < 10 then
    return true
  end
  lastLibKeystoneRequest = now

  if IsInGroup and IsInGroup() then
    pcall(lib.Request, (IsInRaid and IsInRaid()) and "RAID" or "PARTY")
  end
  if IsInGuild and IsInGuild() then
    pcall(lib.Request, "GUILD")
  end
  return true
end

local function ImportAstralKeysCache()
  local astral = _G.AstralKeys
  if type(astral) ~= "table" then
    return 0
  end

  local imported = 0
  for _, entry in pairs(astral) do
    if type(entry) == "table" and entry.unit and entry.dungeon_id and entry.key_level then
      local level = tonumber(entry.key_level) or 0
      local mapID = tonumber(entry.dungeon_id) or 0
      if level > 0 and mapID > 0 then
        local rating = tonumber(entry.mplus_score) or 0
        local updated = tonumber(entry.time_stamp) or 0
        StoreExternalKeystone("GUILD", entry.unit, level, mapID, rating, updated, "AstralKeys")
        imported = imported + 1
      end
    end
  end
  return imported
end

local function HandleAstralKeysMessage(msg, channel, sender)
  if type(msg) ~= "string" then
    return false
  end

  -- AstralKeys current sync format is: updateV8 Name-Realm:CLASS:mapID:keyLevel:weeklyBest:week:score:faction
  local payload = msg:match("^updateV%d+%s+(.+)$")
  if not payload then
    return false
  end

  local unit, class, mapID, keyLevel, weeklyBest, week, score = strsplit(":", payload)
  if not unit or not mapID or not keyLevel then
    return false
  end

  local scope = (channel == "PARTY" or channel == "RAID") and "PARTY" or "GUILD"
  StoreExternalKeystone(scope, unit, keyLevel, mapID, score, time(), "AstralKeys")
  return true
end

local function HandleAddonKeystoneLink(text, sender, channel, source)
  if type(text) ~= "string" then
    return false
  end

  local itemID, mapID, level = string.match(text, "Hkeystone:(%d+):(%d+):(%d+):")
  if not mapID or not level then
    return false
  end

  local scope = (channel == "PARTY" or channel == "RAID" or channel == "INSTANCE_CHAT") and "PARTY" or "GUILD"
  StoreExternalKeystone(scope, sender, level, mapID, 0, time(), source or "Addon Link")
  return true
end

local function BroadcastOwnKeystone(force)
  if not IsKeystoneModuleEnabled() or KeystoneShouldPauseSync() then
    return
  end
  local now = GetTime()
  if not force and (now - lastKeystoneBroadcast) < 10 then
    return
  end
  lastKeystoneBroadcast = now

  local record = UpdateOwnKeystoneCache()
  if not record or not C_ChatInfo or not C_ChatInfo.SendAddonMessage then
    return
  end

  local msg = table.concat({
    record.name or "",
    record.realm or "",
    tostring(record.level or 0),
    tostring(record.mapID or 0),
    tostring(record.rating or 0),
    tostring(record.updated or time()),
  }, "|")

  if IsInGroup and IsInGroup() then
    local channel = (IsInRaid and IsInRaid()) and "RAID" or "PARTY"
    pcall(C_ChatInfo.SendAddonMessage, KEYSTONE_PREFIX, msg, channel)
  end
  if IsInGuild and IsInGuild() then
    pcall(C_ChatInfo.SendAddonMessage, KEYSTONE_PREFIX, msg, "GUILD")
  end
end

local UpdateExpansionButtonStyles
local EnsureExpansionButtons

-- Keystone navigation and list widgets
local function CreateKeystoneButton()
  if mainFrame.keystoneButton then
    if IsKeystoneModuleEnabled() then
      mainFrame.keystoneButton:Show()
    else
      mainFrame.keystoneButton:Hide()
    end
    return
  end
  if not IsKeystoneModuleEnabled() then
    return
  end

  local btn = CreateBackdropFrame(nil, mainFrame.sidebar, 1)
  btn:SetSize(178, 32)
  btn:SetPoint("BOTTOMLEFT", mainFrame.sidebar, "BOTTOMLEFT", 16, 16)
  SetPanelStyle(btn, COLORS.bgLight, COLORS.borderSoft)
  btn:EnableMouse(true)

  btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  btn.text:SetPoint("LEFT", 12, 0)
  btn.text:SetPoint("RIGHT", -10, 0)
  btn.text:SetJustifyH("LEFT")
  btn.text:SetText(L["KEYSTONE_KEYSTONES"])
  btn.text:SetTextColor(COLORS.textDim[1], COLORS.textDim[2], COLORS.textDim[3])

  btn.activeBar = btn:CreateTexture(nil, "ARTWORK")
  btn.activeBar:SetPoint("TOPLEFT", 0, 0)
  btn.activeBar:SetPoint("BOTTOMLEFT", 0, 0)
  btn.activeBar:SetWidth(4)
  btn.activeBar:SetColorTexture(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
  btn.activeBar:Hide()

  btn:SetScript("OnEnter", function(self)
    if DungeonTeleportsDB.selectedExpansion ~= "__KEYSTONES__" then
      self:SetBackdropColor(COLORS.hover[1], COLORS.hover[2], COLORS.hover[3], 1)
    end
  end)
  btn:SetScript("OnLeave", function(self)
    UpdateExpansionButtonStyles(
      DungeonTeleportsDB.selectedExpansion or DungeonTeleportsDB.defaultExpansion or constants.orderedExpansions[1]
    )
  end)
  btn:SetScript("OnMouseDown", function()
    if addon.ShowKeystoneView then
      addon.ShowKeystoneView()
    end
  end)

  mainFrame.keystoneButton = btn
end

local function SetKeystoneButtonActive(active)
  if not mainFrame.keystoneButton then
    return
  end
  if active then
    mainFrame.keystoneButton:SetBackdropColor(COLORS.accentDark[1], COLORS.accentDark[2], COLORS.accentDark[3], 1)
    mainFrame.keystoneButton:SetBackdropBorderColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
    mainFrame.keystoneButton.text:SetTextColor(1, 1, 1)
    mainFrame.keystoneButton.activeBar:Show()
  else
    mainFrame.keystoneButton:SetBackdropColor(COLORS.bgLight[1], COLORS.bgLight[2], COLORS.bgLight[3], 1)
    mainFrame.keystoneButton:SetBackdropBorderColor(
      COLORS.borderSoft[1],
      COLORS.borderSoft[2],
      COLORS.borderSoft[3],
      COLORS.borderSoft[4]
    )
    mainFrame.keystoneButton.text:SetTextColor(COLORS.textDim[1], COLORS.textDim[2], COLORS.textDim[3])
    mainFrame.keystoneButton.activeBar:Hide()
  end
end

local function CreateKeystoneRefreshButton()
  if mainFrame.keystoneRefreshButton then
    return mainFrame.keystoneRefreshButton
  end

  local btn = CreateBackdropFrame(nil, mainFrame.contentHeader, 1)
  btn:SetSize(84, 24)
  btn:SetPoint("RIGHT", -10, 0)
  SetPanelStyle(btn, COLORS.bgLight, COLORS.borderSoft)
  btn:EnableMouse(true)
  btn:Hide()

  btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  btn.text:SetPoint("CENTER", 0, 0)
  btn.text:SetText(L["KEYSTONE_REFRESH"])
  btn.text:SetTextColor(COLORS.warning[1], COLORS.warning[2], COLORS.warning[3])

  btn:SetScript("OnEnter", function(self)
    self:SetBackdropColor(COLORS.hover[1], COLORS.hover[2], COLORS.hover[3], 1)
  end)
  btn:SetScript("OnLeave", function(self)
    SetPanelStyle(self, COLORS.bgLight, COLORS.borderSoft)
  end)
  btn:SetScript("OnMouseDown", function()
    UpdateOwnKeystoneCache()
    ImportAstralKeysCache()
    RequestLibKeystones(true)
    PruneStaleKeystoneCache()
    PrunePartyKeystoneCache()
    BroadcastOwnKeystone(true)
    if addon.ShowKeystoneView then
      addon.ShowKeystoneView(true)
    end
  end)

  mainFrame.keystoneRefreshButton = btn
  return btn
end

local function SetKeystoneRefreshVisible(visible)
  local btn = CreateKeystoneRefreshButton()
  if visible then
    btn:Show()
  else
    btn:Hide()
  end
end

local function StartKeystoneAutoRefresh()
  if keystoneRefreshTicker or not C_Timer or not C_Timer.NewTicker then
    return
  end
  keystoneRefreshTicker = C_Timer.NewTicker(30, function()
    if
      not (
        DungeonTeleportsDB
        and DungeonTeleportsDB.selectedExpansion == "__KEYSTONES__"
        and mainFrame
        and mainFrame:IsShown()
      )
    then
      if keystoneRefreshTicker and keystoneRefreshTicker.Cancel then
        keystoneRefreshTicker:Cancel()
      end
      keystoneRefreshTicker = nil
      return
    end
    if KeystoneShouldPauseSync() then
      return
    end
    UpdateOwnKeystoneCache()
    ImportAstralKeysCache()
    RequestLibKeystones(false)
    PruneStaleKeystoneCache()
    PrunePartyKeystoneCache()
    BroadcastOwnKeystone(false)
    if addon.ShowKeystoneView then
      addon.ShowKeystoneView(true)
    end
  end)
end

-- Keystone sorting and view assembly
local function SortedRecords(t)
  local rows = {}
  local index = 0

  local function safeText(value)
    return string.lower(tostring(value or ""))
  end
  local function safeNumber(value)
    return tonumber(value) or 0
  end

  -- Snapshot sort fields so cache updates cannot change values during comparison.
  for _, record in pairs(t or {}) do
    if type(record) == "table" then
      index = index + 1
      local dungeonName = GetKeystoneDungeonName(record.mapID)
      table.insert(rows, {
        name = record.name,
        fullName = record.fullName,
        realm = record.realm,
        level = record.level,
        dungeon = dungeonName,
        mapID = record.mapID,
        rating = record.rating,
        source = record.source,
        updated = record.updated,
        _sortIndex = index,
        _sortName = safeText(record.name or record.fullName),
        _sortFullName = safeText(record.fullName or record.name),
        _sortDungeon = safeText(dungeonName),
        _sortLevel = safeNumber(record.level),
        _sortRating = safeNumber(record.rating),
      })
    end
  end

  local sortKey, ascending = GetKeystoneSort()

  local function comparePrimary(a, b)
    local av, bv
    if sortKey == "name" then
      av, bv = a._sortName, b._sortName
    elseif sortKey == "dungeon" then
      av, bv = a._sortDungeon, b._sortDungeon
    elseif sortKey == "rating" then
      av, bv = a._sortRating, b._sortRating
    else
      av, bv = a._sortLevel, b._sortLevel
    end

    if av ~= bv then
      if ascending then
        return av < bv
      end
      return av > bv
    end
    return nil
  end

  table.sort(rows, function(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
      return false
    end

    local primary = comparePrimary(a, b)
    if primary ~= nil then
      return primary
    end

    -- Keep tie-breakers fixed across sort directions to maintain a strict ordering.
    if a._sortLevel ~= b._sortLevel then
      return a._sortLevel > b._sortLevel
    end
    if a._sortRating ~= b._sortRating then
      return a._sortRating > b._sortRating
    end
    if a._sortDungeon ~= b._sortDungeon then
      return a._sortDungeon < b._sortDungeon
    end
    if a._sortName ~= b._sortName then
      return a._sortName < b._sortName
    end
    if a._sortFullName ~= b._sortFullName then
      return a._sortFullName < b._sortFullName
    end
    return (a._sortIndex or 0) < (b._sortIndex or 0)
  end)
  return rows
end

local DT_pendingRefreshExpansion
local DT_refreshWaiter

local function DeferViewRefresh(destination, background)
  if not InCombatLockdown() then
    return false
  end
  if background and DT_pendingRefreshExpansion then
    return true
  end
  DT_pendingRefreshExpansion = destination
  if not DT_refreshWaiter then
    DT_refreshWaiter = CreateFrame("Frame")
    DT_refreshWaiter:RegisterEvent("PLAYER_REGEN_ENABLED")
    DT_refreshWaiter:SetScript("OnEvent", function(self)
      self:UnregisterEvent("PLAYER_REGEN_ENABLED")
      DT_refreshWaiter = nil
      local pending = DT_pendingRefreshExpansion
      DT_pendingRefreshExpansion = nil
      if pending == KEYSTONE_VIEW_ID then
        addon.ShowKeystoneView()
      else
        createTeleportButtons(pending)
      end
    end)
  end
  return true
end

function addon.ShowKeystoneView(skipSync)
  if DeferViewRefresh(KEYSTONE_VIEW_ID, skipSync) then
    return
  end
  if not IsKeystoneModuleEnabled() then
    local fallback = DungeonTeleportsDB.defaultExpansion or constants.orderedExpansions[1]
    DungeonTeleportsDB.selectedExpansion = fallback
    addon.RefreshTeleportUI(fallback)
    return
  end
  EnsureExpansionButtons()
  CreateKeystoneButton()
  ClearTeleportRows()

  RegisterLibKeystone()
  if not skipSync and not KeystoneShouldPauseSync() then
    UpdateOwnKeystoneCache()
    ImportAstralKeysCache()
    RequestLibKeystones(false)
    PruneStaleKeystoneCache()
    PrunePartyKeystoneCache()
    BroadcastOwnKeystone(false)
  end

  DungeonTeleportsDB.selectedExpansion = "__KEYSTONES__"
  UpdateExpansionButtonStyles("__KEYSTONES__")
  SetKeystoneButtonActive(true)
  SetKeystoneRefreshVisible(true)
  StartKeystoneAutoRefresh()

  mainFrame.contentIcon:SetTexture("Interface\\Icons\\inv_relics_hourglass")
  mainFrame.contentTitle:SetText(L["KEYSTONE_KEYSTONES"])
  mainFrame.contentSubtitle:SetText(L["KEYSTONE_PARTY_GUILD_CHARACTER_KEYSTONES"])
  mainFrame.summaryText:SetText("")

  local db = EnsureKeystoneDB()
  local party = {}
  if IsInGroup() then
    for fullName in pairs(GetGroupFullNames()) do
      party[fullName] = db.party[fullName] or { fullName = fullName, name = fullName:match("^[^-]+") }
    end
  end
  if not keystoneBrowser then
    keystoneBrowser = addon.KeystoneBrowser.Create(mainFrame, addon.UITheme, {
      refresh = function()
        addon.ShowKeystoneView(true)
      end,
      sort = SetKeystoneSort,
      getSort = GetKeystoneSort,
      known = DT_IsSpellKnown,
    })
  end
  keystoneBrowser:Render({
    party = SortedRecords(party),
    guild = SortedRecords(IsInGuild() and db.guild or {}),
    characters = SortedRecords(db.characters),
  })
end

function addon.SetKeystoneModuleEnabled(enabled)
  DungeonTeleportsDB = DungeonTeleportsDB or {}
  DungeonTeleportsDB.keystoneModuleEnabled = enabled ~= false
  if mainFrame.keystoneButton then
    if DungeonTeleportsDB.keystoneModuleEnabled then
      mainFrame.keystoneButton:Show()
    else
      mainFrame.keystoneButton:Hide()
    end
  elseif DungeonTeleportsDB.keystoneModuleEnabled then
    CreateKeystoneButton()
  end
  if not DungeonTeleportsDB.keystoneModuleEnabled and DungeonTeleportsDB.selectedExpansion == "__KEYSTONES__" then
    local fallback = DungeonTeleportsDB.defaultExpansion or constants.orderedExpansions[1]
    DungeonTeleportsDB.selectedExpansion = fallback
    addon.RefreshTeleportUI(fallback)
  end
  UpdateExpansionButtonStyles(
    DungeonTeleportsDB.selectedExpansion or DungeonTeleportsDB.defaultExpansion or constants.orderedExpansions[1]
  )
end

CreateKeystoneButton()

mainFrame:SetScript("OnHide", function()
  AnalyticsEvent("ui_visibility", { visible = false })
  if keystoneRefreshTicker and keystoneRefreshTicker.Cancel then
    keystoneRefreshTicker:Cancel()
  end
  keystoneRefreshTicker = nil
end)

_G.DungeonTeleportsMainFrame = mainFrame
addon.mainFrame = mainFrame

-- Expansion navigation
UpdateExpansionButtonStyles = function(selectedExpansion)
  SetKeystoneButtonActive(selectedExpansion == "__KEYSTONES__")
  for expansion, btn in pairs(currentExpansionButtons) do
    local active = expansion == selectedExpansion
    if active then
      btn:SetBackdropColor(COLORS.accentDark[1], COLORS.accentDark[2], COLORS.accentDark[3], 1)
      btn:SetBackdropBorderColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
      btn.text:SetTextColor(1, 1, 1)
      btn.activeBar:Show()
    else
      btn:SetBackdropColor(COLORS.bgLight[1], COLORS.bgLight[2], COLORS.bgLight[3], 1)
      btn:SetBackdropBorderColor(COLORS.borderSoft[1], COLORS.borderSoft[2], COLORS.borderSoft[3], COLORS.borderSoft[4])
      btn.text:SetTextColor(COLORS.textDim[1], COLORS.textDim[2], COLORS.textDim[3])
      btn.activeBar:Hide()
    end
  end
end

EnsureExpansionButtons = function()
  if mainFrame.expansionButtonsBuilt then
    return
  end
  mainFrame.expansionButtonsBuilt = true

  local anchor = nil
  for _, expansion in ipairs(constants.orderedExpansions or {}) do
    local btn = CreateBackdropFrame(nil, mainFrame.sidebar, 1)
    btn:SetSize(178, 32)
    if anchor then
      btn:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
    else
      btn:SetPoint("TOPLEFT", mainFrame.sidebar, "TOPLEFT", 16, -16)
    end
    SetPanelStyle(btn, COLORS.bgLight, COLORS.borderSoft)
    btn:EnableMouse(true)

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetPoint("LEFT", 12, 0)
    btn.text:SetPoint("RIGHT", -10, 0)
    btn.text:SetJustifyH("LEFT")
    btn.text:SetWordWrap(false)
    btn.text:SetText(L[expansion] or expansion)

    btn.activeBar = btn:CreateTexture(nil, "ARTWORK")
    btn.activeBar:SetPoint("TOPLEFT", 0, 0)
    btn.activeBar:SetPoint("BOTTOMLEFT", 0, 0)
    btn.activeBar:SetWidth(4)
    btn.activeBar:SetColorTexture(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
    btn.activeBar:Hide()

    btn:SetScript("OnEnter", function(self)
      if DungeonTeleportsDB.selectedExpansion ~= expansion then
        self:SetBackdropColor(COLORS.hover[1], COLORS.hover[2], COLORS.hover[3], 1)
      end
    end)
    btn:SetScript("OnLeave", function(self)
      UpdateExpansionButtonStyles(
        DungeonTeleportsDB.selectedExpansion or DungeonTeleportsDB.defaultExpansion or constants.orderedExpansions[1]
      )
    end)
    btn:SetScript("OnMouseDown", function()
      addon.SelectExpansion(expansion)
    end)

    currentExpansionButtons[expansion] = btn
    anchor = btn
  end
end

-- Teleport grid and cooldown display
local function GetRowStatus(spellID)
  if DT_IsSpellKnown(spellID) then
    local info = C_Spell.GetSpellCooldown(spellID)
    local start = info and info.startTime or nil
    local dur = info and info.duration or nil
    if type(start) == "number" and type(dur) == "number" and start > 0 and dur > 0 then
      local remaining = math.max(0, (start + dur) - GetTime())
      return L["COOLDOWN_NOT_READY"] or "Not ready yet!", SecondsToTime(remaining), COLORS.warning
    end
    return L["COOLDOWN_READY"] or "Ready to use!", L["CLICK_TO_TELEPORT"] or "Click to teleport!", COLORS.success
  end
  return L["TELEPORT_NOT_KNOWN"] or "Teleport not known!", nil, COLORS.textDim
end

function createTeleportButtons(selectedExpansion)
  if DeferViewRefresh(selectedExpansion or DungeonTeleportsDB.defaultExpansion or constants.orderedExpansions[1]) then
    return
  end

  EnsureExpansionButtons()

  selectedExpansion = selectedExpansion or DungeonTeleportsDB.defaultExpansion or constants.orderedExpansions[1]
  DungeonTeleportsDB.selectedExpansion = selectedExpansion
  UpdateExpansionButtonStyles(selectedExpansion)
  SetKeystoneRefreshVisible(false)
  ClearKeystoneRows()

  local mapIDs = constants.mapExpansionToMapID[selectedExpansion]
  if not mapIDs then
    return
  end

  for _, button in pairs(createdButtons) do
    SafeHideTooltip(button)
    button:Hide()
    button:SetParent(nil)
  end
  wipe(createdButtons)

  for _, textObj in pairs(createdTexts) do
    if textObj and textObj.Hide then
      textObj:Hide()
      textObj:SetParent(nil)
    end
  end
  wipe(createdTexts)

  DungeonTeleportsMainFrame.buttons = {}

  local knownCount, totalCount = 0, 0
  local availableWidth = math.max(640, (mainFrame.scrollFrame:GetWidth() or 700) - 8)
  local columnWidth = math.floor((availableWidth - UI.COLUMN_GAP) / 2)
  local index = 0

  for _, mapID in ipairs(mapIDs) do
    local spellID = addon:GetTeleportSpellID(mapID)
    local dungeonName = addon:GetDungeonName(mapID) or "Unknown Dungeon"
    if spellID and spellID > 0 then
      totalCount = totalCount + 1
      local known = DT_IsSpellKnown(spellID)
      if known then
        knownCount = knownCount + 1
      end

      local rowIndex = math.floor(index / 2)
      local colIndex = index % 2
      local xOffset = colIndex * (columnWidth + UI.COLUMN_GAP)
      local yOffset = -(rowIndex * (UI.ROW_HEIGHT + UI.ROW_GAP))

      local row = CreateBackdropFrame(nil, mainFrame.scrollChild, 1)
      row:SetSize(columnWidth, UI.ROW_HEIGHT)
      row:SetPoint("TOPLEFT", mainFrame.scrollChild, "TOPLEFT", xOffset, yOffset)
      SetPanelStyle(row, COLORS.bgCard, COLORS.borderSoft)
      row:EnableMouse(true)

      row.clickButton = CreateFrame("Button", nil, row, "SecureActionButtonTemplate")
      row.clickButton:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
      row.clickButton:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
      row.clickButton:SetFrameLevel(row:GetFrameLevel() + 1)
      if known then
        row.clickButton:SetAttribute("type", "spell")
        row.clickButton:SetAttribute("spell", spellID)
        row.clickButton:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
      else
        row.clickButton:RegisterForClicks()
      end
      row.clickButton:SetScript("PreClick", function()
        local isKnown = DT_IsSpellKnown(spellID)
        AnalyticsEvent("teleport_click", { spellID = spellID, expansion = selectedExpansion, known = isKnown })
        if
          isKnown
          and DungeonTeleportsDB
          and DungeonTeleportsDB.closeOnTeleport
          and mainFrame
          and mainFrame:IsShown()
        then
          mainFrame:Hide()
          DungeonTeleportsDB.isVisible = false
        end
      end)
      row.clickButton:SetScript("OnEnter", function()
        row:GetScript("OnEnter")(row)
      end)
      row.clickButton:SetScript("OnLeave", function()
        row:GetScript("OnLeave")(row)
      end)

      row.iconButton = CreateFrame("Frame", nil, row, "BackdropTemplate")
      row.iconButton:SetSize(46, 46)
      row.iconButton:SetPoint("LEFT", 12, 0)
      row.iconButton:SetFrameLevel(row.clickButton:GetFrameLevel() + 1)
      row.iconButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
      })
      row.iconButton:SetBackdropColor(0, 0, 0, 0.35)
      row.iconButton:SetBackdropBorderColor(
        COLORS.borderSoft[1],
        COLORS.borderSoft[2],
        COLORS.borderSoft[3],
        COLORS.borderSoft[4]
      )

      local texture = row.iconButton:CreateTexture(nil, "ARTWORK")
      texture:SetAllPoints(row.iconButton)
      texture:SetTexture(C_Spell.GetSpellTexture(spellID))
      texture:SetDesaturated(not known)

      local cooldown = CreateFrame("Cooldown", "$parentCooldown", row.iconButton, "CooldownFrameTemplate")
      cooldown:SetAllPoints()
      cooldown:SetFrameLevel(row.iconButton:GetFrameLevel() + 1)
      cooldown:SetSwipeTexture("Interface\\Cooldown\\ping4")
      cooldown:SetSwipeColor(0, 0, 0, 0.6)
      cooldown:SetDrawBling(false)
      cooldown:SetDrawEdge(true)
      cooldown:SetHideCountdownNumbers(false)
      cooldown:Hide()

      if DungeonTeleportsDB.disableCooldownOverlay then
        cooldown:SetSwipeColor(0, 0, 0, 0)
        cooldown:SetDrawEdge(false)
        cooldown:SetDrawBling(false)
        cooldown:SetHideCountdownNumbers(true)
      end

      row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
      row.nameText:SetDrawLayer("OVERLAY", 7)
      row.nameText:SetPoint("TOPLEFT", row.iconButton, "TOPRIGHT", 12, 0)
      row.nameText:SetPoint("RIGHT", row, "RIGHT", -16, 0)
      row.nameText:SetJustifyH("LEFT")
      row.nameText:SetText(dungeonName)
      row.nameText:SetTextColor(
        known and COLORS.warning[1] or COLORS.textDim[1],
        known and COLORS.warning[2] or COLORS.textDim[2],
        known and COLORS.warning[3] or COLORS.textDim[3]
      )

      row.statusText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      row.statusText:SetDrawLayer("OVERLAY", 7)
      row.statusText:SetPoint("TOPLEFT", row.nameText, "BOTTOMLEFT", 0, -3)
      row.statusText:SetPoint("RIGHT", row, "RIGHT", -16, 0)
      row.statusText:SetJustifyH("LEFT")

      row.detailText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      row.detailText:SetDrawLayer("OVERLAY", 7)
      row.detailText:SetPoint("TOPLEFT", row.statusText, "BOTTOMLEFT", 0, -2)
      row.detailText:SetPoint("RIGHT", row, "RIGHT", -16, 0)
      row.detailText:SetJustifyH("LEFT")

      local function UpdateCooldown()
        if
          InCombatLockdown()
          or UnitAffectingCombat("player")
          or (IsEncounterInProgress and IsEncounterInProgress())
        then
          return
        end
        if addon._DT_mplus_suppressed then
          cooldown:Clear()
          cooldown:Hide()
          return
        end
        if InCombatLockdown and InCombatLockdown() then
          cooldown:Clear()
          cooldown:Hide()
          return
        end
        local info = C_Spell.GetSpellCooldown(spellID)
        local start = info and info.startTime or nil
        local dur = info and info.duration or nil
        local okS, s = pcall(tonumber, start)
        local okD, d = pcall(tonumber, dur)
        local okM, m = pcall(tonumber, info and info.modRate)
        if okS and okD and type(s) == "number" and type(d) == "number" and s > 0 and d > 0 then
          SafeSetCooldown(cooldown, s, d, (okM and m) or nil)
          cooldown:Show()
        else
          cooldown:Clear()
          cooldown:Hide()
        end

        local status, detail, color = GetRowStatus(spellID)
        row.statusText:SetText(status or "")
        row.statusText:SetTextColor(color[1], color[2], color[3], color[4] or 1)
        row.detailText:SetText(detail or "")
        row.detailText:SetTextColor(COLORS.textDim[1], COLORS.textDim[2], COLORS.textDim[3], 1)
      end

      if known then
        row.iconButton:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        row.iconButton:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
        row.iconButton:RegisterEvent("PLAYER_ENTERING_WORLD")
        row.iconButton:RegisterEvent("PLAYER_REGEN_ENABLED")
        row.iconButton:SetScript("OnEvent", function()
          UpdateCooldown()
        end)
        UpdateCooldown()
      else
        local status, detail, color = GetRowStatus(spellID)
        row.statusText:SetText(status or "")
        row.statusText:SetTextColor(color[1], color[2], color[3], color[4] or 1)
        row.detailText:SetText(detail or "")
        row.detailText:SetTextColor(COLORS.textDim[1], COLORS.textDim[2], COLORS.textDim[3], 1)
      end

      local function UpdateTooltip()
        GameTooltip:ClearLines()
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:SetSpellByID(spellID)
        if InCombatLockdown and InCombatLockdown() then
          GameTooltip:AddLine(L["COOLDOWN_UNKNOWN_IN_COMBAT"] or "Cooldown info hidden in combat (beta).", 1, 0, 0)
          GameTooltip:Show()
          return
        end
        if known then
          local info = C_Spell.GetSpellCooldown(spellID)
          local start = info and info.startTime or nil
          local dur = info and info.duration or nil
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

      row:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.8)
        UpdateTooltip()
        self:SetScript("OnUpdate", function()
          UpdateTooltip()
        end)
      end)
      row:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(
          COLORS.borderSoft[1],
          COLORS.borderSoft[2],
          COLORS.borderSoft[3],
          COLORS.borderSoft[4]
        )
        SafeHideTooltip(self)
      end)
      row:SetScript("OnMouseDown", function()
        if known and row.clickButton and row.clickButton.Click then
          row.clickButton:Click()
        end
      end)

      createdButtons[mapID] = row
      table.insert(DungeonTeleportsMainFrame.buttons, row.clickButton)
      index = index + 1
    end
  end

  local numRows = math.max(1, math.ceil(totalCount / 2))
  local totalHeight = math.max(1, numRows * UI.ROW_HEIGHT + math.max(0, numRows - 1) * UI.ROW_GAP)
  mainFrame.scrollChild:SetSize(availableWidth, totalHeight)
  mainFrame.contentTitle:SetText(L[selectedExpansion] or selectedExpansion)
  mainFrame.summaryText:SetText(
    string.format("%d / %d %s", knownCount, totalCount, L["TELEPORTS_LEARNED"] or "learned")
  )
end

-- Public teleport UI entry points
function addon.RefreshTeleportUI(selectedExpansion)
  createTeleportButtons(
    selectedExpansion
      or DungeonTeleportsDB.selectedExpansion
      or DungeonTeleportsDB.defaultExpansion
      or constants.orderedExpansions[1]
  )
end

function addon.SelectExpansion(expansion)
  DungeonTeleportsDB = DungeonTeleportsDB or {}
  DungeonTeleportsDB.selectedExpansion = expansion
  DungeonTeleportsDB.defaultExpansion = expansion
  AnalyticsEvent("expansion_selected", { expansion = expansion })
  addon.RefreshTeleportUI(expansion)
end

function addon.updateBackground(selectedExpansion)
  -- Compatibility entry point; expansion backgrounds are no longer rendered.
end

-- Refresh on show, including login visibility restoration. The refresh path guards
-- secure button updates; callers own visibility analytics to avoid duplicate events.
mainFrame:SetScript("OnShow", function()
  local defaultExpansion = DungeonTeleportsDB.selectedExpansion
    or DungeonTeleportsDB.defaultExpansion
    or constants.orderedExpansions[1]
  if defaultExpansion == "__KEYSTONES__" and IsKeystoneModuleEnabled() then
    addon.ShowKeystoneView()
  else
    addon.RefreshTeleportUI(
      (defaultExpansion == "__KEYSTONES__" and (DungeonTeleportsDB.defaultExpansion or constants.orderedExpansions[1]))
        or defaultExpansion
    )
  end
end)

-- Addon lifecycle and keystone events
DungeonTeleports:RegisterEvent("PLAYER_LOGIN")
DungeonTeleports:RegisterEvent("PLAYER_ENTERING_WORLD")
DungeonTeleports:RegisterEvent("ADDON_LOADED")
DungeonTeleports:RegisterEvent("CHAT_MSG_ADDON")
-- Only process supported addon messages. Normal chat can contain secret strings
-- that cannot be safely parsed for keystone links.
DungeonTeleports:RegisterEvent("BAG_UPDATE_DELAYED")
DungeonTeleports:RegisterEvent("GROUP_ROSTER_UPDATE")
DungeonTeleports:SetScript("OnEvent", function(_, event, prefix, msg, channel, sender)
  if event == "CHAT_MSG_ADDON" or event == "BAG_UPDATE_DELAYED" or event == "GROUP_ROSTER_UPDATE" then
    if not IsKeystoneModuleEnabled() or KeystoneShouldPauseSync() then
      return
    end
  end

  if event == "CHAT_MSG_ADDON" and type(msg) == "string" then
    local updated = false
    if prefix == KEYSTONE_PREFIX then
      local name, realm, level, mapID, rating, stamp = strsplit("|", msg)
      StoreRemoteKeystone(
        channel == "GUILD" and "GUILD" or "PARTY",
        name,
        realm,
        level,
        mapID,
        rating,
        stamp,
        "DungeonTeleports"
      )
      updated = true
    elseif prefix == "AstralKeys" then
      updated = HandleAstralKeysMessage(msg, channel, sender)
    else
      -- Ignore unrelated traffic to avoid unnecessary parsing in busy groups.
      return
    end
    if
      updated
      and DungeonTeleportsDB
      and DungeonTeleportsDB.selectedExpansion == "__KEYSTONES__"
      and mainFrame:IsShown()
    then
      addon.ShowKeystoneView(true)
    end
    return
  elseif event == "BAG_UPDATE_DELAYED" or event == "GROUP_ROSTER_UPDATE" then
    UpdateOwnKeystoneCache()
    PruneStaleKeystoneCache()
    if event == "GROUP_ROSTER_UPDATE" then
      PrunePartyKeystoneCache()
      RequestLibKeystones(true)
      BroadcastOwnKeystone(false)
    end
    if DungeonTeleportsDB and DungeonTeleportsDB.selectedExpansion == "__KEYSTONES__" and mainFrame:IsShown() then
      addon.ShowKeystoneView(true)
    end
    return
  elseif event == "ADDON_LOADED" or event == "PLAYER_ENTERING_WORLD" then
    RegisterLibKeystone()
    if not KeystoneShouldPauseSync() then
      RequestLibKeystones(false)
    end
    return
  elseif event ~= "PLAYER_LOGIN" then
    return
  end
  DungeonTeleportsDB = DungeonTeleportsDB or {}
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    pcall(C_ChatInfo.RegisterAddonMessagePrefix, KEYSTONE_PREFIX)
    pcall(C_ChatInfo.RegisterAddonMessagePrefix, "AstralKeys")
  end
  RegisterLibKeystone()
  UpdateOwnKeystoneCache()
  ImportAstralKeysCache()
  RequestLibKeystones(true)
  PruneStaleKeystoneCache()
  DungeonTeleportsDB.defaultExpansion = DungeonTeleportsDB.defaultExpansion or "Current Season"
  DungeonTeleportsDB.selectedExpansion = DungeonTeleportsDB.selectedExpansion or DungeonTeleportsDB.defaultExpansion
  DungeonTeleportsDB.uiScale = ClampScale(DungeonTeleportsDB.uiScale)
  if DungeonTeleportsDB.closeOnTeleport == nil then
    DungeonTeleportsDB.closeOnTeleport = false
  end

  if DungeonTeleportsDB.windowPosition then
    local pos = DungeonTeleportsDB.windowPosition
    mainFrame:ClearAllPoints()
    mainFrame:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 40)
  end

  mainFrame.scaleSlider:SetValue(DungeonTeleportsDB.uiScale)
  mainFrame:Hide()
  DungeonTeleportsDB.isVisible = false
  addon.RefreshTeleportUI(DungeonTeleportsDB.defaultExpansion)
end)

-- Player spellcast outcome analytics
local castWatcher = CreateFrame("Frame")
castWatcher:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
castWatcher:RegisterEvent("UNIT_SPELLCAST_FAILED")
castWatcher:SetScript("OnEvent", function(_, evt, unit, _, spellID)
  if unit ~= "player" then
    return
  end
  if evt == "UNIT_SPELLCAST_SUCCEEDED" then
    AnalyticsEvent("teleport_succeeded", { spellID = spellID })
  elseif evt == "UNIT_SPELLCAST_FAILED" then
    AnalyticsEvent("teleport_failed", { spellID = spellID })
  end
end)

-- Shared window controls for slash commands, minimap, and addon compartment
-- Opening can rebuild secure buttons, so defer the entire action during combat.
local function DT_OpenTeleportWindowNow(source)
  -- The OnShow handler owns content refresh when the window becomes visible.
  DungeonTeleportsMainFrame:Show()
  DungeonTeleportsDB.isVisible = true
  AnalyticsEvent("ui_visibility", { visible = true, source = source })
end

local DT_openWaiter
local DT_pendingOpenSource

function addon.OpenTeleportWindow(source)
  if addon._DT_mplus_suppressed then
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
      DEFAULT_CHAT_FRAME:AddMessage(
        "|cffff7f00DungeonTeleports: Disabled during Mythic+ run (re-enables after you leave the dungeon).|r"
      )
    end
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
      DEFAULT_CHAT_FRAME:AddMessage("|cffff7f00DungeonTeleports: Window will open after combat.|r")
    end
    -- Coalesce repeated requests and re-check suppression when combat ends.
    DT_pendingOpenSource = source or DT_pendingOpenSource
    if not DT_openWaiter then
      DT_openWaiter = CreateFrame("Frame")
      DT_openWaiter:RegisterEvent("PLAYER_REGEN_ENABLED")
      DT_openWaiter:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        DT_openWaiter = nil
        local pendingSource = DT_pendingOpenSource
        DT_pendingOpenSource = nil
        addon.OpenTeleportWindow(pendingSource)
      end)
    end
    return
  end

  DT_OpenTeleportWindowNow(source)
end

function addon.CloseTeleportWindow(source)
  DT_SafeHide(DungeonTeleportsMainFrame)
  DungeonTeleportsDB.isVisible = false
  AnalyticsEvent("ui_visibility", { visible = false, source = source })
end

-- Slash commands
SLASH_DUNGEONTELEPORTS1 = "/dungeonteleports"
SLASH_DUNGEONTELEPORTS2 = "/dtp"
SlashCmdList["DUNGEONTELEPORTS"] = function()
  if DungeonTeleportsMainFrame:IsShown() then
    addon.CloseTeleportWindow("slash_command")
  else
    addon.OpenTeleportWindow("slash_command")
  end
end
