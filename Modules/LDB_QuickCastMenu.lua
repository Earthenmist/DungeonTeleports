local addonName, addon = ...
local RefreshExpansionList -- forward decl (used by expansion row handlers)
local L = addon.L

-- Saved setting: LDB menu style ("full" | "minimal")
local function GetLDBStyle()
  DungeonTeleportsDB = DungeonTeleportsDB or {}
  local v = DungeonTeleportsDB.ldbMenuStyle
  if v ~= "minimal" and v ~= "full" then v = "full" end
  return v
end

local function SetLDBStyle(v)
  DungeonTeleportsDB = DungeonTeleportsDB or {}
  if v ~= "minimal" and v ~= "full" then v = "full" end
  DungeonTeleportsDB.ldbMenuStyle = v
end

local function GetLDBShowHearthButtons()
  DungeonTeleportsDB = DungeonTeleportsDB or {}
  if DungeonTeleportsDB.ldbShowHearthButtons == nil then
    DungeonTeleportsDB.ldbShowHearthButtons = true
  end
  return DungeonTeleportsDB.ldbShowHearthButtons
end

local function SetLDBShowHearthButtons(v)
  DungeonTeleportsDB = DungeonTeleportsDB or {}
  DungeonTeleportsDB.ldbShowHearthButtons = (v and true) or false
end

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

local function IsMouseOverQuickCastMenu()
  if menu and menu:IsShown() and menu:IsMouseOver() then return true end
  if expArea and expArea:IsShown() and expArea:IsMouseOver() then return true end
  if tpArea and tpArea:IsShown() and tpArea:IsMouseOver() then return true end
  if hearthBtn and hearthBtn:IsShown() and hearthBtn:IsMouseOver() then return true end
  if dalaranBtn and dalaranBtn:IsShown() and dalaranBtn:IsMouseOver() then return true end
  return false
end

local function CancelMenuHide()
  if hideTimer then
    hideTimer:Cancel()
    hideTimer = nil
  end
end

local function ScheduleMenuHide()
  if hideTimer then hideTimer:Cancel() end
  hideTimer = C_Timer.NewTimer(0.30, function()
    if menu and menu:IsShown() and (not IsMouseOverQuickCastMenu()) then
      menu:Hide()
    end
  end)
end

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
    --bgFile = "Interface\ChatFrame\ChatFrameBackground",
    --edgeFile = "Interface\Tooltips\UI-Tooltip-Border",
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
    --bgFile = "Interface\ChatFrame\ChatFrameBackground",
    --edgeFile = "Interface\Tooltips\UI-Tooltip-Border",
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
    ScheduleMenuHide()
  end)

  menu:Hide()
  return menu
end



local hearthBtn, dalaranBtn

local function SetupUtilityButton(btn, itemID, fallbackIcon)
  -- Secure item usage (reliable click-to-use)
  btn:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
  -- Mirror teleport buttons: use primary attributes
  btn:SetAttribute("type", "item")
  btn:SetAttribute("item", "item:" .. itemID)
  -- Also set button-specific attributes for safety
  btn:SetAttribute("type1", "item")
  btn:SetAttribute("item1", "item:" .. itemID)
local icon = fallbackIcon
  if C_Item and C_Item.GetItemIconByID then
    icon = C_Item.GetItemIconByID(itemID) or icon
  end
  if btn.icon then
    btn.icon:SetTexture(icon)
  end

  btn:SetScript("OnEnter", function(self)
    CancelMenuHide()
    if GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetItemByID(itemID)
      GameTooltip:Show()
    end
  end)
  btn:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
    ScheduleMenuHide()
  end)
end

local function EnsureUtilityButtons()
  if not menu then return end
  -- (fixed) no recursion here
  local show = GetLDBShowHearthButtons()

  if not hearthBtn then
    hearthBtn = CreateFrame("Button", nil, menu, "SecureActionButtonTemplate")
    hearthBtn:SetSize(26, 26)
    hearthBtn:SetHitRectInsets(-6, -6, -6, -6)
    hearthBtn.icon = hearthBtn:CreateTexture(nil, "ARTWORK")
    hearthBtn.icon:SetPoint("TOPLEFT", 2, -2)
    hearthBtn.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    hearthBtn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    hearthBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    SetupUtilityButton(hearthBtn, 6948, 134414)
  end

  if not dalaranBtn then
    dalaranBtn = CreateFrame("Button", nil, menu, "SecureActionButtonTemplate")
    dalaranBtn:SetSize(26, 26)
    dalaranBtn:SetHitRectInsets(-6, -6, -6, -6)
    dalaranBtn.icon = dalaranBtn:CreateTexture(nil, "ARTWORK")
    dalaranBtn.icon:SetPoint("TOPLEFT", 2, -2)
    dalaranBtn.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    dalaranBtn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    dalaranBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    SetupUtilityButton(dalaranBtn, 140192, 134414)
  end

  hearthBtn:SetShown(show)
  dalaranBtn:SetShown(show)

  -- Position (top-right of menu, within header area)
  dalaranBtn:ClearAllPoints()
  dalaranBtn:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -10, -10)

  hearthBtn:ClearAllPoints()
  hearthBtn:SetPoint("RIGHT", dalaranBtn, "LEFT", -6, 0)
end

local function ApplyMenuStyle()
  if not menu then return end
  EnsureUtilityButtons()
  local style = GetLDBStyle()
  -- Hide any previously-created teleport buttons (even if they are not tracked in tpButtons)
  if tpContent and tpContent.GetChildren then
    local kids = { tpContent:GetChildren() }
    for _, child in ipairs(kids) do
      if child and child.Hide and (child._DT_QC_TP or child:GetAttribute("type") or child:GetAttribute("type1")) then
        child:Hide()
      end
    end
  end
  for _, btn in ipairs(tpButtons) do
    btn:Hide()
  end

  if style == "minimal" then
    -- Minimal: single column, ~12 teleports visible
    menu:SetWidth(430)
    menu:SetHeight(360)

    if expArea then expArea:SetWidth(210) end
    if tpArea then
      tpArea:ClearAllPoints()
      tpArea:SetPoint("TOPLEFT", menu, "TOPLEFT", 232, -72)
      tpArea:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -10, 14)
    end
  else
    -- Full: 2 columns, ~6 rows visible
    menu:SetWidth(720)
    menu:SetHeight(340)

    if expArea then expArea:SetWidth(210) end
    if tpArea then
      tpArea:ClearAllPoints()
      tpArea:SetPoint("TOPLEFT", menu, "TOPLEFT", 232, -72)
      tpArea:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -10, 14)
    end
  end

  if divider then
    divider:ClearAllPoints()
    divider:SetPoint("TOPLEFT", menu, "TOPLEFT", 204, -66)
    divider:SetPoint("BOTTOMLEFT", menu, "BOTTOMLEFT", 204, 14)
  end
end

local function GetConstants()
  return addon and addon.constants or nil
end

local function ClearTeleportButtons()
  for i = 1, #tpButtons do
    tpButtons[i]:Hide()
  end
end

local function ApplyTeleportButtonStyle(b, style, colWidth)
  if style == "minimal" then
    b:SetHeight(20)
    b:SetWidth(colWidth)
    b.icon:Hide()
    b.label:ClearAllPoints()
    b.label:SetPoint("LEFT", b, "LEFT", 8, 0)
    b.label:SetWidth(colWidth - 16)
    b.label:SetFontObject("GameFontHighlightSmall")
    b.label:SetTextColor(1, 1, 1)
    b.rowHL:SetAllPoints()
  else
    -- Full (icons) style
    b:SetHeight(30)
    b:SetWidth(210)
    b.icon:Show()
    b.icon:SetSize(26, 26)
    b.icon:ClearAllPoints()
    b.icon:SetPoint("LEFT", b, "LEFT", 6, 0)
    b.label:ClearAllPoints()
    b.label:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
    b.label:SetWidth(210 - (6 + 26 + 8 + 6))
    b.label:SetFontObject("GameFontHighlight")
    b.label:SetTextColor(1, 1, 0)
    b.rowHL:SetAllPoints()
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
    ScheduleMenuHide()
  end)

  tpButtons[i] = b
    b._DT_QC_TP = true
  return b
end

local function RefreshTeleportsForExpansion(expansion)
  local constants = GetConstants()
  if not constants then return end

  ClearTeleportButtons()

  local mapIDs = constants.mapExpansionToMapID and constants.mapExpansionToMapID[expansion] or nil
  if not mapIDs then return end

  local style = GetLDBStyle()
  local shown = 0
  local areaWidth = (tpArea and tpArea:GetWidth() or 0)
  if areaWidth <= 1 and menu then
    areaWidth = (menu:GetWidth() or 480) - 250
  end
  if areaWidth <= 1 then areaWidth = 480 end
  local columns = (style == "minimal") and 1 or 2
  local colWidth = (columns == 1) and (areaWidth - 12) or math.floor((areaWidth - 12) / 2)
  local rowStep = (style == "minimal") and 22 or 40

  for _, mapID in ipairs(mapIDs) do
    local spellID = constants.mapIDtoSpellID and constants.mapIDtoSpellID[mapID] or nil
    if spellID then
      local known = IsSpellKnown(spellID) or IsPlayerSpell(spellID)
      if known then
        shown = shown + 1
        local b = EnsureTeleportButton(shown)
        ApplyTeleportButtonStyle(b, style, colWidth)
        b:ClearAllPoints()
        local idx = shown - 1
        local col = idx % columns
        local row = math.floor(idx / columns)
        local x = col * (colWidth + (colGap or 0))
        local y = -row * rowStep
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

        if style ~= "minimal" then
          b.icon:SetTexture(C_Spell.GetSpellTexture(spellID))
        end

        local name = (constants.mapIDtoDungeonName and constants.mapIDtoDungeonName[mapID]) or (C_Spell.GetSpellName(spellID)) or ""
        b.label:SetText(name)
        if style == "minimal" then
          b.label:SetWidth(colWidth - 16)
          b.label:SetTextColor(1, 1, 1)
        else
          b.label:SetWidth(210 - (6 + 26 + 8 + 6))
          end
      end
    end
  end

  -- Ensure scroll child is tall enough
  if tpContent and tpArea then
    local rows = math.ceil(shown / columns)
    local contentHeight = math.max(1, (rows * rowStep) + 10)
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
    ScheduleMenuHide()
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
  EnsureUtilityButtons()
  ApplyMenuStyle()
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
    ScheduleMenuHide()
  end
end)

-- =========================================================
-- Settings Subcategory: DataText Menu
-- =========================================================
function addon:DT_LDB_BuildConfigPanel(parent, outWidgets)
  local widgets = outWidgets or {}

  local panel = CreateFrame("Frame", nil, parent)
  panel:SetAllPoints(true)
  panel:Hide() -- prevent showing in-world before Settings parents it

  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText(L["LDB_MENU_TITLE"] or "DataText Menu")

  local sub = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  sub:SetText(L["LDB_MENU_DESC"] or "Choose how the broker hover menu is displayed.")

  -- Radio: Full
  local full = CreateFrame("CheckButton", nil, panel, "UIRadioButtonTemplate")
  full:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -14)
  full.text:SetText(L["LDB_STYLE_FULL"] or "Full (Icons)")
  full.value = "full"

  local fullPreview = panel:CreateTexture(nil, "ARTWORK")
  fullPreview:SetSize(350, 174)
  fullPreview:SetPoint("TOPLEFT", full, "BOTTOMLEFT", 28, -6)
  -- Placeholder preview texture (swap later)
  fullPreview:SetTexture("Interface\\AddOns\\DungeonTeleports\\Images\\LDBMenuPreview_Full.tga")
  fullPreview:SetTexCoord(0, 1, 0, 1)
  fullPreview:SetAlpha(0.75)

  -- Radio: Minimal
  local minimal = CreateFrame("CheckButton", nil, panel, "UIRadioButtonTemplate")
  minimal:SetPoint("TOPLEFT", fullPreview, "BOTTOMLEFT", -28, -14)
  minimal.text:SetText(L["LDB_STYLE_MINIMAL"] or "Minimal (Text only)")
  minimal.value = "minimal"

  local minimalPreview = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  minimalPreview:SetPoint("TOPLEFT", minimal, "BOTTOMLEFT", 28, -8)
  minimalPreview:SetText("• Teleport 1\n• Teleport 2\n• Teleport 3")
  minimalPreview:SetTextColor(1, 1, 1)
  minimalPreview:SetAlpha(0.75)

  local hs = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
  hs:SetPoint("TOPLEFT", minimalPreview, "BOTTOMLEFT", -28, -18)
  hs.Text:SetText(L["LDB_SHOW_HEARTH"] or "Show Hearthstone buttons (Normal & Dalaran)")
  hs.tooltipText = L["LDB_SHOW_HEARTH_DESC"] or "Adds Hearthstone and Dalaran Hearthstone icons to the top-right of the hover menu."


  local function SetSelected(v)
    full:SetChecked(v == "full")
    minimal:SetChecked(v == "minimal")
  end

  local function Apply(v)
    SetLDBStyle(v)
    SetSelected(v)
    -- If menu is open, refresh contents/layout
    if menu and menu:IsShown() then
      ApplyMenuStyle()
      if selectedExpansion then RefreshTeleportsForExpansion(selectedExpansion) end
    end
  end

  full:SetScript("OnClick", function() Apply("full") end)
  minimal:SetScript("OnClick", function() Apply("minimal") end)

  panel:SetScript("OnShow", function()
    SetSelected(GetLDBStyle())
    hs:SetChecked(GetLDBShowHearthButtons())
  end)

  hs:SetScript("OnClick", function(self)
    SetLDBShowHearthButtons(self:GetChecked())
    if menu and menu:IsShown() then
      EnsureUtilityButtons()
    end
  end)

  return panel
end

-- Shim for config.lua to detect this module
function addon.DT_LDB_UpdateRegistration() end
