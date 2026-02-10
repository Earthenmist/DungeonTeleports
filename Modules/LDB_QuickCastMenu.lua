local addonName, addon = ...
local RefreshExpansionList -- forward decl (used by expansion row handlers)
local L = addon.L

-- =========================================================
-- LDB Quick Cast Menu (hover broker text/icon)
--
-- Goals:
--  - Broker hover shows an expansion list + known teleports.
--  - Clicking a teleport casts it immediately (secure buttons).
--  - Minimap icon behavior remains EXACTLY as before (tooltip only).
--  - Midnight-safe gating: no menu in combat, raids, or Mythic+.
-- =========================================================

local function IsMinimapIconFrame(frame)
  if not frame then return false end
  local n = frame.GetName and frame:GetName() or nil
  -- LibDBIcon default button name
  if n and n:find("LibDBIcon10_DungeonTeleports", 1, true) then
    return true
  end
  -- Some displays pass a child region; walk up once.
  local p = frame.GetParent and frame:GetParent() or nil
  if p then
    local pn = p.GetName and p:GetName() or nil
    if pn and pn:find("LibDBIcon10_DungeonTeleports", 1, true) then
      return true
    end
  end
  return false
end

local function IsMenuAllowedHere()
  -- Hard disable in combat for secure safety.
  if InCombatLockdown and InCombatLockdown() then return false end
  if UnitAffectingCombat and UnitAffectingCombat("player") then return false end
  if IsEncounterInProgress and IsEncounterInProgress() then return false end

  -- Respect the addon's own M+ suppression flag if present.
  if addon and addon._DT_mplus_suppressed then return false end

  -- Disable in raids always.
  local inInstance, instanceType = IsInInstance()
  if inInstance and instanceType == "raid" then return false end

  -- Disable in active Mythic+ (Challenge Mode).
  if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive then
    local ok, active = pcall(C_ChallengeMode.IsChallengeModeActive)
    if ok and active then return false end
  end

  return true
end

local function ShowDefaultTooltip(anchor)
  if not GameTooltip then return end
  GameTooltip:SetOwner(anchor, "ANCHOR_BOTTOMRIGHT")
  GameTooltip:ClearLines()
  GameTooltip:AddLine(L["ADDON_TITLE"])
  GameTooltip:AddLine(L["Open_Teleports"])
  GameTooltip:AddLine(L["Open_Settings"])
  GameTooltip:Show()
end

-- -------------------------
-- Menu frame construction
-- -------------------------

local menu
local hideTimer
local selectedExpansion

local expArea, expContent
local tpArea, tpContent

local expButtons = {}
local tpButtons = {}

local function EnsureMenu()
  if menu then return menu end

  menu = CreateFrame("Frame", "DungeonTeleports_LDBQuickCastMenu", UIParent, "BackdropTemplate")
  menu:SetFrameStrata("DIALOG")
  menu:SetFrameLevel(10)
menu:SetClampedToScreen(true)
  menu:EnableMouse(true)
  menu:SetMovable(false)
  menu:SetSize(660, 330)

  menu:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  menu:SetBackdropColor(0, 0, 0, 0.90)

  local title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", 14, -12)
  title:SetText(L["ADDON_TITLE"])

  local hint = menu:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
  hint:SetText("Click a learned teleport to cast.")

  -- Column separators
  local sep = menu:CreateTexture(nil, "BORDER")
  sep:SetColorTexture(1, 1, 1, 0.08)
  sep:SetPoint("TOPLEFT", 214, -54)
  sep:SetPoint("BOTTOMLEFT", 214, 12)
  sep:SetWidth(1)

  local expHeader = menu:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  expHeader:SetPoint("TOPLEFT", 14, -54)
  expHeader:SetText("Expansions")

  local tpHeader = menu:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  tpHeader:SetPoint("TOPLEFT", 226, -54)
  tpHeader:SetText("Teleports")


  -- Column areas (no scrollbars; menu is tall enough to fit lists)
  expArea = CreateFrame("Frame", nil, menu, "BackdropTemplate")
  expArea:SetPoint("TOPLEFT", 10, -72)
  expArea:SetPoint("BOTTOMLEFT", 10, 12)
  expArea:SetWidth(200)
  expArea:SetBackdrop({
    bgFile = "Interface\ChatFrame\ChatFrameBackground",
    edgeFile = "Interface\Tooltips\UI-Tooltip-Border",
    tile = false,
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  expArea:SetBackdropColor(0, 0, 0, 0.25)

  expContent = CreateFrame("Frame", nil, expArea)
  expContent:SetPoint("TOPLEFT", 6, -6)
  expContent:SetPoint("TOPRIGHT", -6, -6)
  expContent:SetHeight(1)

  tpArea = CreateFrame("Frame", nil, menu, "BackdropTemplate")
  tpArea:SetPoint("TOPLEFT", 242, -72)
  tpArea:SetPoint("BOTTOMRIGHT", -10, 12)
  tpArea:SetBackdrop({
    bgFile = "Interface\ChatFrame\ChatFrameBackground",
    edgeFile = "Interface\Tooltips\UI-Tooltip-Border",
    tile = false,
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  tpArea:SetBackdropColor(0, 0, 0, 0.20)

  tpContent = CreateFrame("Frame", nil, tpArea)
  tpContent:SetPoint("TOPLEFT", 8, -8)
  tpContent:SetPoint("TOPRIGHT", -8, -8)
  tpContent:SetHeight(1)


  -- Hover-safe hide
  menu:SetScript("OnEnter", function()
    if hideTimer then
      hideTimer:Cancel()
      hideTimer = nil
    end
  end)
  menu:SetScript("OnLeave", function()
    if hideTimer then hideTimer:Cancel() end
    hideTimer = C_Timer.NewTimer(0.30, function()
      if menu and menu:IsShown() then
        menu:Hide()
      end
    end)
  end)

  menu:Hide()
  return menu
end

local function GetConstants()
  return addon and addon.constants or nil
end

local function ClearTeleportButtons()
  for i = 1, #tpButtons do
    tpButtons[i]:Hide()
  end
end

local function EnsureTeleportButton(i)
  local b = tpButtons[i]
  if b then return b end

  b = CreateFrame("Button", nil, tpContent or menu, "SecureActionButtonTemplate")
  -- Make the whole entry clickable (icon + text)
  b:SetSize(210, 30)
  b:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
  b:EnableMouse(true)

  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(26, 26)
  b.icon:SetPoint("LEFT", b, "LEFT", 6, 0)

  b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.label:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
  b.label:SetJustifyH("LEFT")

  b.rowHL = b:CreateTexture(nil, "HIGHLIGHT")
  b.rowHL:SetPoint("TOPLEFT", -4, 4)
  b.rowHL:SetPoint("BOTTOMRIGHT", b.label, "BOTTOMRIGHT", 4, -4)
  b.rowHL:SetColorTexture(1, 1, 1, 0.06)

  b:SetScript("OnEnter", function(self)
    if hideTimer then hideTimer:Cancel(); hideTimer = nil end
    if not self._spellID then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetFrameStrata("TOOLTIP")
      GameTooltip:SetFrameLevel(100)
    GameTooltip:SetSpellByID(self._spellID)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
    if hideTimer then hideTimer:Cancel() end
    hideTimer = C_Timer.NewTimer(0.30, function()
      if menu and menu:IsShown() then
        menu:Hide()
      end
    end)
  end)

  tpButtons[i] = b
  return b
end

local function RefreshTeleportsForExpansion(expansion)
  local constants = GetConstants()
  if not constants then return end

  ClearTeleportButtons()

  local mapIDs = constants.mapExpansionToMapID and constants.mapExpansionToMapID[expansion] or nil
  if not mapIDs then return end

  local shown = 0
  local startY = 0
  local areaWidth = (tpArea and tpArea:GetWidth() or 480)
  local colWidth = math.floor((areaWidth - 12) / 2)
  local xLabelMax = colWidth

  for _, mapID in ipairs(mapIDs) do
    local spellID = constants.mapIDtoSpellID and constants.mapIDtoSpellID[mapID] or nil
    if spellID then
      local known = IsSpellKnown(spellID) or IsPlayerSpell(spellID)
      if known then
        shown = shown + 1
        local b = EnsureTeleportButton(shown)
        b:ClearAllPoints()
        local idx = shown - 1
        local col = idx % 2
        local row = math.floor(idx / 2)
        local x = col * colWidth
        local y = -row * 40
        b:SetPoint("TOPLEFT", tpContent, "TOPLEFT", x, y)
        b:Show()

        b._spellID = spellID
        -- Secure cast (matches main UI pattern)
        if not InCombatLockdown() then
          b:SetAttribute("type", "spell")
          b:SetAttribute("spell", spellID)
        end

        -- Only set secure attributes out of combat (menu is gated, but keep safe)
        if not (InCombatLockdown and InCombatLockdown()) then
          b:SetAttribute("type", "spell")
          b:SetAttribute("spell", spellID)
        end

        b.icon:SetTexture(C_Spell.GetSpellTexture(spellID))

        local name = (constants.mapIDtoDungeonName and constants.mapIDtoDungeonName[mapID]) or (C_Spell.GetSpellName(spellID)) or ""
        b.label:SetText(name)
          b.label:SetWidth(210 - (6 + 26 + 8 + 6))
        b.label:SetTextColor(1, 1, 0)
      end
    end
  end

  -- Ensure scroll child is tall enough
  if tpContent and tpArea then
    local rows = math.ceil(shown / 2)
    local contentHeight = math.max(1, (rows * 40) + 10)
    tpContent:SetHeight(contentHeight)
  end

  if shown == 0 then
    local msg = menu._noTeleportsMsg
    if not msg then
      msg = menu:CreateFontString(nil, "OVERLAY", "GameFontDisable")
      msg:SetPoint("TOPLEFT", tpContent or menu, "TOPLEFT", 0, -2)
      msg:SetWidth((tpArea and tpArea:GetWidth() or 480) - 12)
      msg:SetJustifyH("LEFT")
      menu._noTeleportsMsg = msg
    end
    msg:SetText("No learned teleports for this expansion.")
    msg:Show()
  elseif menu._noTeleportsMsg then
    menu._noTeleportsMsg:Hide()
  end
end

local function ClearExpansionButtons()
  for i = 1, #expButtons do
    expButtons[i]:Hide()
  end
end

local function EnsureExpansionButton(i)
  local b = expButtons[i]
  if b then return b end

  b = CreateFrame("Button", nil, expContent or menu)
  b:SetSize(188, 20)
  b:RegisterForClicks("LeftButtonUp")

  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.bg:SetColorTexture(1, 0.82, 0, 0.10) -- selected highlight
  b.bg:Hide()

  b.hl = b:CreateTexture(nil, "HIGHLIGHT")
  b.hl:SetAllPoints()
  b.hl:SetColorTexture(1, 1, 1, 0.08)

  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.text:SetPoint("LEFT", 8, 0)
  b.text:SetJustifyH("LEFT")
  b.text:SetWidth(188 - 16)

  b:SetScript("OnEnter", function(self)
    if hideTimer then hideTimer:Cancel(); hideTimer = nil end
    if self._expansion and selectedExpansion ~= self._expansion then
      selectedExpansion = self._expansion
      RefreshTeleportsForExpansion(selectedExpansion)
      RefreshExpansionList()
    end
  end)

  b:SetScript("OnLeave", function()
    if hideTimer then hideTimer:Cancel() end
    hideTimer = C_Timer.NewTimer(0.30, function()
      if menu and menu:IsShown() then
        menu:Hide()
      end
    end)
  end)
  expButtons[i] = b
  return b
end

RefreshExpansionList = function()
  local constants = GetConstants()
  if not constants then return end

  ClearExpansionButtons()

  local ordered = constants.orderedExpansions or {}
  if not selectedExpansion then
    selectedExpansion = ordered[1]
  end
  local y = -2

  for i = 1, #ordered do
    local exp = ordered[i]
    local b = EnsureExpansionButton(i)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", expContent, "TOPLEFT", 0, y)
    b.text:SetText(exp)
    b._expansion = exp
    if selectedExpansion == exp then b.bg:Show() else b.bg:Hide() end
    b:Show()
    y = y - 22
  end

  -- Ensure scroll child is tall enough
  if expContent and expArea then
    local contentHeight = math.max(1, (#ordered * 26) + 6)
    expContent:SetHeight(contentHeight)
  end

  if not selectedExpansion then
    selectedExpansion = ordered[1]
  end
  if selectedExpansion then
    RefreshTeleportsForExpansion(selectedExpansion)
  end
end

local function AnchorMenuTo(frame)
  menu:ClearAllPoints()

  if frame and frame.GetCenter and frame:GetCenter() then
    menu:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -6)
    return
  end

  -- Fallback: anchor near cursor
  local x, y = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  x, y = x / scale, y / scale
  menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x + 12, y - 12)
end

local function ShowMenu(anchorFrame)
  EnsureMenu()
  RefreshExpansionList()
  AnchorMenuTo(anchorFrame)
  menu:Show()
end

-- -------------------------
-- Hook LDB object
-- -------------------------

local HookFrame = CreateFrame("Frame")
HookFrame:RegisterEvent("PLAYER_LOGIN")
HookFrame:SetScript("OnEvent", function()
  local obj = addon and addon.LDBObject
  if not obj then return end

  -- Preserve existing click behavior.
  local existingOnClick = obj.OnClick
  local existingOnTooltipShow = obj.OnTooltipShow

  obj.OnClick = function(...)
    return existingOnClick and existingOnClick(...) or nil
  end

  -- Keep tooltip behavior as a fallback for displays that only use OnTooltipShow.
  obj.OnTooltipShow = function(tooltip)
    if existingOnTooltipShow then
      return existingOnTooltipShow(tooltip)
    end
  end

  obj.OnEnter = function(frame)
    -- Minimap icon: behave exactly as before (tooltip only)
    if IsMinimapIconFrame(frame) then
      ShowDefaultTooltip(frame)
      return
    end

    -- Broker frames: show hover-cast menu when allowed.
    if not IsMenuAllowedHere() then
      ShowDefaultTooltip(frame)
      return
    end

    -- Do not show tooltip when menu is active (avoid overlap)
    if GameTooltip then GameTooltip:Hide() end
    ShowMenu(frame)
  end

  obj.OnLeave = function(frame)
    if IsMinimapIconFrame(frame) then
      if GameTooltip then GameTooltip:Hide() end
      return
    end

    if hideTimer then hideTimer:Cancel() end
    hideTimer = C_Timer.NewTimer(0.30, function()
      if menu and menu:IsShown() then
        menu:Hide()
      end
    end)
  end
end)