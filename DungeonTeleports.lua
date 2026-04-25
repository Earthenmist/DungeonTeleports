local addonName, addon = ...

-- Midnight-safe helpers: "secret value" protection can make numeric compares error.
local function SafeCooldownActive(startTime, duration)
  if startTime == nil or duration == nil then return false end
  local ok, active = pcall(function()
    return startTime > 0 and duration > 0
  end)
  if ok then
    return active
  end
  -- If values are "secret", avoid comparing; try to show and let cooldown frame handle rendering.
  return true
end

local function SafeSetCooldown(cooldownFrame, startTime, duration, modRate)
  if not cooldownFrame then return end
  local ok = pcall(function()
    if cooldownFrame.SetCooldown then
      cooldownFrame:SetCooldown(startTime, duration, modRate)
    elseif CooldownFrame_Set then
      CooldownFrame_Set(cooldownFrame, startTime, duration, modRate)
    end
  end)
  return ok
end

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
-- === Mythic+ suppression guard (Midnight-safe) ===
-- Midnight can return "secret" cooldown values during an active Challenge Mode run.
-- Safest approach: completely suppress the UI + cooldown checks for the duration of the run,
-- then automatically re-enable after the run ends AND you leave the instance/zone.
addon._DT_mplus_suppressed = addon._DT_mplus_suppressed or false
addon._DT_keystone_slotted_at = addon._DT_keystone_slotted_at or nil
addon._DT_mplus_completed = addon._DT_mplus_completed or nil

local function DT_SetMPlusSuppressed(state)
  state = state and true or false
  addon._DT_mplus_suppressed = state

  -- If suppressing, close the window immediately (combat-safe).
  if state and DungeonTeleportsMainFrame and DungeonTeleportsMainFrame.IsShown and DungeonTeleportsMainFrame:IsShown() then
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
  -- Only unsuppress once the run is not active AND you have zone-changed out of the instance.
  if DT_IsChallengeModeActive() then return false end
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
    -- Only suppress after a key has been slotted (someone inserted it) AND the run starts.
    -- If we missed the slotted event for any reason, still suppress for safety.
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
-- === End Mythic+ suppression guard ===


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
if DungeonTeleportsDB.autoInsertKeystone == nil then DungeonTeleportsDB.autoInsertKeystone = false end

-- ================================
-- Mythic+ Keystone helper (Retail + Midnight Beta)
-- - Auto-slot the keystone when the receptacle window opens
-- - Make the keystone window movable and persist its position
-- ================================
local function DT_SetupKeystoneFrame()
  local kf = _G.ChallengesKeystoneFrame
  if not kf then return end

  -- Make movable (only needs to be done once)
  if not kf._DT_movableApplied then
    kf:SetMovable(true)
    kf:EnableMouse(true)
    kf:RegisterForDrag("LeftButton")
    kf:SetClampedToScreen(true)

    kf:HookScript("OnDragStart", function(self)
      if InCombatLockdown and InCombatLockdown() then return end
      self:StartMoving()
    end)

    kf:HookScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      local point, relativeTo, relativePoint, x, y = self:GetPoint()
      DungeonTeleportsDB.keystoneFramePos = DungeonTeleportsDB.keystoneFramePos or {}
      DungeonTeleportsDB.keystoneFramePos.point = point
      DungeonTeleportsDB.keystoneFramePos.relativeTo = (relativeTo and relativeTo.GetName and relativeTo:GetName()) or "UIParent"
      DungeonTeleportsDB.keystoneFramePos.relativePoint = relativePoint
      DungeonTeleportsDB.keystoneFramePos.x = x
      DungeonTeleportsDB.keystoneFramePos.y = y
    end)

    -- Stop auto-insert retries if Blizzard reports the keystone is for a different dungeon.
    -- (Midnight+ can repeatedly fire the same UI error if we keep trying.)
    if not kf._DT_wrongKeyWatcher then
      local watcher = CreateFrame("Frame")
      watcher:RegisterEvent("UI_ERROR_MESSAGE")
      watcher:SetScript("OnEvent", function(_, event, errorType, msg)
        if event ~= "UI_ERROR_MESSAGE" then return end
        -- Midnight+: use errorType (locale-safe). 1012 = "Keystone is for a different dungeon"
        if errorType == 1012 then
          kf._DT_stopAutoInsert = true
          ClearCursor()
          return
        end
        -- Fallback: localized text match (older/odd builds)
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
      if not (DungeonTeleportsDB and DungeonTeleportsDB.autoInsertKeystone == true) then return end
      if InCombatLockdown and InCombatLockdown() then return end
      if kf._DT_stopAutoInsert then return end
      if DT_KeystoneIsSlotted() then return end

      -- Prefer Blizzard API if it works
      if C_ChallengeMode and C_ChallengeMode.SlotKeystone then
        pcall(C_ChallengeMode.SlotKeystone)
        if DT_KeystoneIsSlotted() then return end
      end

      -- Fallback: mimic "Pickup keystone -> click socket" behavior (works on some beta builds)
      local IDs = { [138019]=true, [151086]=true, [158923]=true, [180653]=true }
      local function FindKeystoneInBags()
        if not C_Container or not C_Container.GetContainerNumSlots then return end
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
            pcall(function() btn:Click() end)
            break
          end
        end

        ClearCursor()
      end

      if retries and retries > 0 and not DT_KeystoneIsSlotted() then
        C_Timer.After(0.2, function() DT_TrySlotKeystone(retries - 1) end)
      end
    end

    kf:HookScript("OnShow", function()
      if not (DungeonTeleportsDB and DungeonTeleportsDB.autoInsertKeystone == true) then return end
      kf._DT_stopAutoInsert = false
      -- Delay a tick so the UI + roster state is ready (notably on Midnight Beta)
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
    if event == "ADDON_LOADED" and name ~= "Blizzard_ChallengesUI" then return end
    if event == "PLAYER_ENTERING_WORLD" then
      if IsAddOnLoaded and not IsAddOnLoaded("Blizzard_ChallengesUI") then return end
    end
    DT_SetupKeystoneFrame()
  end)
end


local DungeonTeleports = CreateFrame("Frame")
local createdButtons = {}
local createdTexts = {}
local currentExpansionButtons = {}

local UI = {
  ROW_HEIGHT = 72,
  ROW_GAP = 10,
  COLUMN_GAP = 12,
  DEFAULT_WIDTH = 980,
  DEFAULT_HEIGHT = 680,
  MIN_SCALE = 0.70,
  MAX_SCALE = 1.15,
  DEFAULT_SCALE = 1.0,
}

local COLORS = {
  bg = {0.05, 0.05, 0.07, 0.98},
  bgLight = {0.08, 0.08, 0.10, 1},
  bgCard = {0.06, 0.06, 0.08, 1},
  border = {0.00, 0.74, 0.73, 0.95},
  borderSoft = {0.00, 0.74, 0.73, 0.35},
  accent = {0.00, 0.74, 0.73, 1},
  accentDark = {0.07, 0.41, 0.38, 1},
  hover = {0.10, 0.16, 0.18, 1},
  text = {0.92, 0.92, 0.92, 1},
  textDim = {0.62, 0.62, 0.65, 1},
  success = {0.20, 0.85, 0.40, 1},
  warning = {1.00, 0.82, 0.00, 1},
  danger = {0.95, 0.35, 0.35, 1},
}

local _, playerClass = UnitClass("player")
local classColor = (RAID_CLASS_COLORS and playerClass and RAID_CLASS_COLORS[playerClass]) or NORMAL_FONT_COLOR
if classColor then
  COLORS.accent = {classColor.r or 0.78, classColor.g or 0.61, classColor.b or 0.43, 1}
  COLORS.border = {COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.95}
  COLORS.borderSoft = {COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.35}
  COLORS.accentDark = {
    math.max(0, (classColor.r or 0.78) * 0.45),
    math.max(0, (classColor.g or 0.61) * 0.45),
    math.max(0, (classColor.b or 0.43) * 0.45),
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
  if value < UI.MIN_SCALE then value = UI.MIN_SCALE end
  if value > UI.MAX_SCALE then value = UI.MAX_SCALE end
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

local mainFrame = CreateBackdropFrame("DungeonTeleportsMainFrame", UIParent, 1)
mainFrame:SetSize(UI.DEFAULT_WIDTH, UI.DEFAULT_HEIGHT)
mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
SetPanelStyle(mainFrame, COLORS.bg, {0.02, 0.02, 0.03, 0.85})
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

mainFrame.closeButton = CreateFrame("Button", nil, mainFrame.header, "UIPanelCloseButton")
mainFrame.closeButton:SetSize(24, 24)
mainFrame.closeButton:SetPoint("RIGHT", -4, 0)
mainFrame.closeButton:SetScript("OnClick", function()
  DT_SafeHide(mainFrame)
  DungeonTeleportsDB.isVisible = false
  AnalyticsEvent("ui_visibility", { visible = false })
end)

mainFrame.scaleLabel = mainFrame.header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
mainFrame.scaleLabel:SetText(L["UI_SCALE"] or "Scale")
mainFrame.scaleLabel:SetTextColor(1, 1, 1)

mainFrame.scaleValue = mainFrame.header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
mainFrame.scaleValue:SetText("100%")
mainFrame.scaleValue:SetTextColor(1, 1, 1)

mainFrame.pendingScale = savedScale
mainFrame.scaleSlider = CreateFrame("Slider", "DungeonTeleportsScaleSlider", mainFrame.header, "OptionsSliderTemplate")
mainFrame.scaleSlider:SetSize(90, 12)
mainFrame.scaleSlider:SetMinMaxValues(UI.MIN_SCALE, UI.MAX_SCALE)
mainFrame.scaleSlider:SetValueStep(0.01)
mainFrame.scaleSlider:SetObeyStepOnDrag(true)
_G[mainFrame.scaleSlider:GetName() .. "Low"]:SetText("")
_G[mainFrame.scaleSlider:GetName() .. "High"]:SetText("")
_G[mainFrame.scaleSlider:GetName() .. "Text"]:SetText("")

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

local function StyleScaleAdjustButton(button, glyph)
  button:SetSize(18, 18)
  button:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  button:SetBackdropColor(0.07, 0.07, 0.09, 1)
  button:SetBackdropBorderColor(COLORS.borderSoft[1], COLORS.borderSoft[2], COLORS.borderSoft[3], COLORS.borderSoft[4] or 1)
  button:SetNormalFontObject("GameFontHighlightSmall")
  button:SetHighlightFontObject("GameFontNormalSmall")
  button:SetText(glyph)
  button:GetFontString():SetPoint("CENTER", 0, 0)
  button:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(COLORS.border[1], COLORS.border[2], COLORS.border[3], COLORS.border[4] or 1)
  end)
  button:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(COLORS.borderSoft[1], COLORS.borderSoft[2], COLORS.borderSoft[3], COLORS.borderSoft[4] or 1)
  end)
end

mainFrame.scaleDownButton = CreateFrame("Button", nil, mainFrame.header, "BackdropTemplate")
StyleScaleAdjustButton(mainFrame.scaleDownButton, "−")
mainFrame.scaleDownButton:SetScript("OnClick", function()
  NudgeMainFrameScale(-0.01)
end)

mainFrame.scaleUpButton = CreateFrame("Button", nil, mainFrame.header, "BackdropTemplate")
StyleScaleAdjustButton(mainFrame.scaleUpButton, "+")
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
mainFrame.sidebar:SetWidth(180)
SetPanelStyle(mainFrame.sidebar, {0.05, 0.05, 0.07, 1}, COLORS.borderSoft)

mainFrame.content = CreateBackdropFrame(nil, mainFrame, 1)
mainFrame.content:SetPoint("TOPLEFT", mainFrame.sidebar, "TOPRIGHT", 12, 0)
mainFrame.content:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -14, 14)
SetPanelStyle(mainFrame.content, {0.04, 0.04, 0.06, 1}, COLORS.borderSoft)

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

mainFrame.scrollFrame = CreateFrame("ScrollFrame", "DungeonTeleportsScrollFrame", mainFrame.content, "UIPanelScrollFrameTemplate")
mainFrame.scrollFrame:SetPoint("TOPLEFT", mainFrame.contentHeader, "BOTTOMLEFT", 0, -12)
mainFrame.scrollFrame:SetPoint("BOTTOMRIGHT", mainFrame.content, "BOTTOMRIGHT", -30, 12)

mainFrame.scrollChild = CreateFrame("Frame", nil, mainFrame.scrollFrame)
mainFrame.scrollChild:SetSize(1, 1)
mainFrame.scrollFrame:SetScrollChild(mainFrame.scrollChild)

mainFrame:SetScript("OnShow", function()
  AnalyticsEvent("ui_visibility", { visible = true })
end)
mainFrame:SetScript("OnHide", function()
  AnalyticsEvent("ui_visibility", { visible = false })
end)

_G.DungeonTeleportsMainFrame = mainFrame
addon.mainFrame = mainFrame

local function UpdateExpansionButtonStyles(selectedExpansion)
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

local function EnsureExpansionButtons()
  if mainFrame.expansionButtonsBuilt then return end
  mainFrame.expansionButtonsBuilt = true

  local anchor = nil
  for _, expansion in ipairs(constants.orderedExpansions or {}) do
    local btn = CreateBackdropFrame(nil, mainFrame.sidebar, 1)
    btn:SetSize(144, 32)
    if anchor then
      btn:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
    else
      btn:SetPoint("TOPLEFT", mainFrame.sidebar, "TOPLEFT", 16, -16)
    end
    SetPanelStyle(btn, COLORS.bgLight, COLORS.borderSoft)
    btn:EnableMouse(true)

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetPoint("LEFT", 12, 0)
    btn.text:SetJustifyH("LEFT")
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
      UpdateExpansionButtonStyles(DungeonTeleportsDB.selectedExpansion or DungeonTeleportsDB.defaultExpansion or constants.orderedExpansions[1])
    end)
    btn:SetScript("OnMouseDown", function()
      addon.SelectExpansion(expansion)
    end)

    currentExpansionButtons[expansion] = btn
    anchor = btn
  end
end

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
    constants.mapIDtoSpellID[506] = nil
    constants.mapIDtoSpellID[507] = nil
  end
end

local function GetRowStatus(spellID)
  if C_SpellBook.IsSpellInSpellBook(spellID) or C_SpellBook.IsSpellKnown(spellID) then
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
  EnsureExpansionButtons()

  selectedExpansion = selectedExpansion or DungeonTeleportsDB.defaultExpansion or constants.orderedExpansions[1]
  DungeonTeleportsDB.selectedExpansion = selectedExpansion
  UpdateExpansionButtonStyles(selectedExpansion)

  local mapIDs = constants.mapExpansionToMapID[selectedExpansion]
  if not mapIDs then return end

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
    local spellID = constants.mapIDtoSpellID[mapID]
    local dungeonName = constants.mapIDtoDungeonName[mapID] or "Unknown Dungeon"
    if spellID and spellID > 0 then
      totalCount = totalCount + 1
      local known = C_SpellBook.IsSpellInSpellBook(spellID) or C_SpellBook.IsSpellKnown(spellID)
      if known then knownCount = knownCount + 1 end

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
        local isKnown = C_SpellBook.IsSpellInSpellBook(spellID) or C_SpellBook.IsSpellKnown(spellID) or false
        AnalyticsEvent("teleport_click", { spellID = spellID, expansion = selectedExpansion, known = isKnown })
        if isKnown and DungeonTeleportsDB and DungeonTeleportsDB.closeOnTeleport and mainFrame and mainFrame:IsShown() then
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
      row.iconButton:SetBackdropBorderColor(COLORS.borderSoft[1], COLORS.borderSoft[2], COLORS.borderSoft[3], COLORS.borderSoft[4])

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
      row.nameText:SetTextColor(known and COLORS.warning[1] or COLORS.textDim[1], known and COLORS.warning[2] or COLORS.textDim[2], known and COLORS.warning[3] or COLORS.textDim[3])

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
        if InCombatLockdown() or UnitAffectingCombat("player") or (IsEncounterInProgress and IsEncounterInProgress()) then return end
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
        row.iconButton:SetScript("OnEvent", function() UpdateCooldown() end)
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
        self:SetScript("OnUpdate", function() UpdateTooltip() end)
      end)
      row:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(COLORS.borderSoft[1], COLORS.borderSoft[2], COLORS.borderSoft[3], COLORS.borderSoft[4])
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
  mainFrame.summaryText:SetText(string.format("%d / %d %s", knownCount, totalCount, L["TELEPORTS_LEARNED"] or "learned"))
end

function addon.RefreshTeleportUI(selectedExpansion)
  createTeleportButtons(selectedExpansion or DungeonTeleportsDB.selectedExpansion or DungeonTeleportsDB.defaultExpansion or constants.orderedExpansions[1])
end

function addon.SelectExpansion(expansion)
  DungeonTeleportsDB = DungeonTeleportsDB or {}
  DungeonTeleportsDB.selectedExpansion = expansion
  DungeonTeleportsDB.defaultExpansion = expansion
  AnalyticsEvent("expansion_selected", { expansion = expansion })
  addon.RefreshTeleportUI(expansion)
end

function addon.updateBackground(selectedExpansion)
  -- No-op in v2. Background images have been intentionally retired.
end

SetFactionSpecificSpells()

mainFrame:SetScript("OnShow", function()
  local defaultExpansion = DungeonTeleportsDB.selectedExpansion or DungeonTeleportsDB.defaultExpansion or constants.orderedExpansions[1]
  addon.RefreshTeleportUI(defaultExpansion)
end)

DungeonTeleports:RegisterEvent("PLAYER_LOGIN")
DungeonTeleports:SetScript("OnEvent", function()
  DungeonTeleportsDB = DungeonTeleportsDB or {}
  DungeonTeleportsDB.defaultExpansion = DungeonTeleportsDB.defaultExpansion or L["Current Season"]
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
    DT_SafeHide(DungeonTeleportsMainFrame)
    DungeonTeleportsDB.isVisible = false
    AnalyticsEvent("ui_visibility", { visible = false })
    return
  end

  if addon._DT_mplus_suppressed then
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
      DEFAULT_CHAT_FRAME:AddMessage("|cffff7f00DungeonTeleports: Disabled during Mythic+ run (re-enables after you leave the dungeon).|r")
    end
    return
  end

  local defaultExpansion = DungeonTeleportsDB.selectedExpansion or DungeonTeleportsDB.defaultExpansion or L["Current Season"]
  addon.RefreshTeleportUI(defaultExpansion)
  DT_SafeShow(DungeonTeleportsMainFrame)
  DungeonTeleportsDB.isVisible = true
  AnalyticsEvent("ui_visibility", { visible = true })
end
