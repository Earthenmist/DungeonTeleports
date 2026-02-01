local addonName, addon = ...
local L = addon.L

-- =========================================================
-- Group Reminder module (DungeonTeleports)
-- =========================================================
-- Fires when an LFG application transitions to "inviteaccepted" (joined),
-- filters to Mythic+ only, and shows a popup with a teleport button.

local function EnsureDefaults()
  DungeonTeleportsDB = DungeonTeleportsDB or {}
  DungeonTeleportsDB.groupReminder = DungeonTeleportsDB.groupReminder or {}
  local db = DungeonTeleportsDB.groupReminder

  if db.enabled == nil then db.enabled = true end
  if db.showPopup == nil then db.showPopup = true end
  if db.showChat == nil then db.showChat = true end
  if db.showDungeonName == nil then db.showDungeonName = true end
  if db.showGroupName == nil then db.showGroupName = true end
  if db.showGroupDescription == nil then db.showGroupDescription = false end
  if db.showAppliedRole == nil then db.showAppliedRole = true end
  if db.suppressQuickJoinToast == nil then db.suppressQuickJoinToast = false end
end

local function DT_GR_GetSpellNameIcon(spellID)
  if not spellID or spellID == 0 then
    return nil, nil
  end


  -- Retail/modern API
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(spellID)
    if info then
      return info.name, info.iconID
    end
  end

  -- Fallback (older clients)
  if GetSpellInfo then
    local name, _, icon = GetSpellInfo(spellID)
    return name, icon
  end

  return nil, nil
end


local function DT_GR_IsSpellKnown(spellID)
  if not spellID or spellID == 0 then return false end
  if C_Spell and C_Spell.IsSpellKnown then
    return C_Spell.IsSpellKnown(spellID)
  end
  if IsPlayerSpell then
    return IsPlayerSpell(spellID)
  end
  if IsSpellKnown then
    return IsSpellKnown(spellID)
  end
  return false
end

local function DT_GR_GetSpellCooldown(spellID)
  if not spellID or spellID == 0 then return 0, 0, 0, 1 end

  -- Modern API
  if C_Spell and C_Spell.GetSpellCooldown then
    local cd = C_Spell.GetSpellCooldown(spellID)
    if cd then
      return cd.startTime or 0, cd.duration or 0, (cd.isEnabled and 1 or 0), cd.modRate or 1
    end
  end

  -- Legacy API
  if GetSpellCooldown then
    local start, duration, enable, modRate = GetSpellCooldown(spellID)
    return start or 0, duration or 0, enable or 0, modRate or 1
  end

  return 0, 0, 0, 1
end

local function DT_GR_SetCooldown(cooldownFrame, spellID)
  if not cooldownFrame then return end
  cooldownFrame:Hide()

  if not spellID or spellID == 0 then return end
  local start, duration, enable, modRate = DT_GR_GetSpellCooldown(spellID)

  if enable == 1 and duration and duration > 1.5 and start and start > 0 then
    if CooldownFrame_Set then
      CooldownFrame_Set(cooldownFrame, start, duration, enable, nil, modRate)
    else
      cooldownFrame:SetCooldown(start, duration, modRate)
    end
    cooldownFrame:Show()
  end
end



-- Track role chosen at application time
addon._DT_GR_roleByResult = addon._DT_GR_roleByResult or {}

if C_LFGList and C_LFGList.ApplyToGroup and not addon._DT_GR_applyHooked then
  addon._DT_GR_applyHooked = true
  hooksecurefunc(C_LFGList, "ApplyToGroup", function(searchResultID, tank, heal, dps)
    if tank then addon._DT_GR_roleByResult[searchResultID] = "TANK"
    elseif heal then addon._DT_GR_roleByResult[searchResultID] = "HEALER"
    elseif dps then addon._DT_GR_roleByResult[searchResultID] = "DAMAGER"
    end
  end)
end

local function GetAppliedRoleText(searchResultID)
  -- Prefer the role we captured at application time (more reliable than group assignment on join)
  local roleKey = addon._DT_GR_roleByResult and addon._DT_GR_roleByResult[searchResultID]
  if roleKey == "TANK" then return (TANK or "Tank") end
  if roleKey == "HEALER" then return (HEALER or "Healer") end
  if roleKey == "DAMAGER" then return (DAMAGER or "Damage") end

  -- Fallback: if already in group, try assigned role
  if type(UnitGroupRolesAssigned) == "function" then
    local assigned = UnitGroupRolesAssigned("player")
    if assigned == "TANK" then return (TANK or "Tank") end
    if assigned == "HEALER" then return (HEALER or "Healer") end
    if assigned == "DAMAGER" then return (DAMAGER or "Damage") end
  end

  -- Fallback: current LFG role selection (if UI is open)
  local tank, heal, dps = GetLFGRoles()
  if tank then return (TANK or "Tank") end
  if heal then return (HEALER or "Healer") end
  if dps then return (DAMAGER or "Damage") end
  return "-"
end


-- Name matching helpers
local function TrimQualifiersAndWhitespace(s)
  if type(s) ~= "string" then return "" end
  -- Strip bracketed qualifiers like "(Mythic Keystone)" and trim
  s = s:gsub("%s*%b()", "")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  return s
end

local function Norm(s)
  s = TrimQualifiersAndWhitespace(s)
  if s == "" then return "" end
  s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  s = s:lower():gsub("[^%w%s]", " ")
  s = s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return s
end

local function NormWithoutLeadingThe(s)
  s = TrimQualifiersAndWhitespace(s)
  if s == "" then return "" end
  s = s:gsub("^The%s+", "")
  return Norm(s)
end

local function BuildNameLookup()
  local const = addon.constants
  local t = {}
  if not const or type(const.mapIDtoDungeonName) ~= "table" or type(const.mapIDtoSpellID) ~= "table" then
    return t
  end
  for internalID, dungeonName in pairs(const.mapIDtoDungeonName) do
    local spellID = const.mapIDtoSpellID[internalID]
    if type(dungeonName) == "string" and type(spellID) == "number" and spellID ~= 0 then
      t[Norm(dungeonName)] = { spellID = spellID, displayName = dungeonName }
    end
  end
  return t
end

addon._DT_GR_nameToTeleport = addon._DT_GR_nameToTeleport or nil

local function ResolveTeleportSpell(fullName, shortName)
  if not addon._DT_GR_nameToTeleport then
    addon._DT_GR_nameToTeleport = BuildNameLookup()
  end

  -- Aliases for dungeon name variants returned by LFG/Queue UI
  -- (e.g. split megadungeons using the same teleport)
  local ALIASES = {
    ["tazavesh streets"] = "tazavesh the veiled market",
    ["tazavesh gambit"]  = "tazavesh the veiled market",
  }

  local function Lookup(normKey)
    if normKey == "" then return nil end
    local aliased = ALIASES[normKey]
    if aliased then normKey = aliased end
    local v = addon._DT_GR_nameToTeleport[normKey]
    if v then
      return v.spellID, v.displayName
    end
    return nil
  end

  -- Exact normalized match (full name)
  local k = Norm(fullName)
  local spellID, displayName = Lookup(k)
  if spellID then return spellID, displayName end

  -- Fallback: some sources may prepend/remove leading "The "
  local kNoThe = NormWithoutLeadingThe(fullName)
  spellID, displayName = Lookup(kNoThe)
  if spellID then return spellID, displayName end

  -- Exact normalized match (short name)
  k = Norm(shortName)
  spellID, displayName = Lookup(k)
  if spellID then return spellID, displayName end

  kNoThe = NormWithoutLeadingThe(shortName)
  spellID, displayName = Lookup(kNoThe)
  if spellID then return spellID, displayName end

  -- contains-match fallback (also respects aliases via Lookup())
  local hay = k
  if hay == "" then hay = kNoThe end
  if hay ~= "" then
    for nk, v in pairs(addon._DT_GR_nameToTeleport) do
      if hay:find(nk, 1, true) or nk:find(hay, 1, true) then
        return v.spellID, v.displayName
      end
    end
  end

  return nil, nil
end


local function HeaderLabel()
  local addonTitle = (L["CONFIG_TITLE"] or "Mythic Dungeon Teleports")
  local headerText = (L["GROUP_REMINDER_TITLE"] or "Group Reminder")
  return "|cffffd100" .. addonTitle .. "|r - |cffffd700" .. headerText .. "|r"
end

local function GuessRoleKey(roleText)
  if roleText == TANK then return "TANK" end
  if roleText == HEALER then return "HEALER" end
  if roleText == DAMAGER then return "DAMAGER" end
end

local function EnsurePopup()
  if addon._DT_GR_popup then return addon._DT_GR_popup end

  -- Ensure SavedVariables exist before we try to read/write popup position.
  EnsureDefaults()
  local db = DungeonTeleportsDB.groupReminder

  local f = CreateFrame("Frame", "DungeonTeleports_GroupReminderPopup", UIParent, "BackdropTemplate")
  f:SetSize(420, 220)

  -- Restore the last position (if moved) instead of always centering.
  if db.popupPos and db.popupPos.point and db.popupPos.relPoint and db.popupPos.x and db.popupPos.y then
    f:SetPoint(db.popupPos.point, UIParent, db.popupPos.relPoint, db.popupPos.x, db.popupPos.y)
  else
    f:SetPoint("CENTER")
  end

  f:Hide()
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()

    -- Persist the frame position in SavedVariables (account-wide).
    -- We store relative to UIParent so it survives UI scale changes reasonably well.
    local point, _, relPoint, xOfs, yOfs = self:GetPoint(1)
    if point and relPoint and xOfs and yOfs and DungeonTeleportsDB and DungeonTeleportsDB.groupReminder then
      DungeonTeleportsDB.groupReminder.popupPos = {
        point = point,
        relPoint = relPoint,
        x = xOfs,
        y = yOfs,
      }
    end

    -- Also mark it as user-placed so the client can remember it in layout cache
    -- on some setups (harmless if it doesn't apply).
    if self.SetUserPlaced then
      self:SetUserPlaced(true)
    end
  end)

  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile = true, tileSize = 32, edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
  })
  f:SetBackdropBorderColor(0, 0, 0, 1)

  table.insert(UISpecialFrames, "DungeonTeleports_GroupReminderPopup")

  f.Title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  -- Give the title its own horizontal space so it never collides with the close button.
  f.Title:SetPoint("TOPLEFT", 14, -14)
  f.Title:SetPoint("TOPRIGHT", -34, -14)
  f.Title:SetJustifyH("CENTER")
  f.Title:SetText(HeaderLabel())

  f.RoleIcon = f:CreateTexture(nil, "OVERLAY")
  f.RoleIcon:SetSize(22, 22)
  f.RoleIcon:SetPoint("TOP", f.Title, "BOTTOM", 0, -6)
  f.RoleIcon:Hide()

  f.Content = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.Content:SetPoint("TOP", f.RoleIcon, "BOTTOM", 0, -10)
  f.Content:SetPoint("LEFT", 20, 0)
  f.Content:SetPoint("RIGHT", -20, 0)
  f.Content:SetJustifyH("CENTER")
  f.Content:SetJustifyV("TOP")
  f.Content:SetSpacing(4)

  f.TeleportButton = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
  f.TeleportButton:SetPoint("BOTTOM", 0, 20)
  f.TeleportButton:SetSize(40, 40)
  f.TeleportButton:RegisterForClicks("AnyUp", "AnyDown")

  f.TeleportButton.Icon = f.TeleportButton:CreateTexture(nil, "ARTWORK")
  f.TeleportButton.Icon:SetAllPoints()
  f.TeleportButton.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  f.TeleportButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

  -- Cooldown swipe overlay (mirrors main DungeonTeleports buttons)
  f.TeleportButton.Cooldown = CreateFrame("Cooldown", "DungeonTeleports_GroupReminderCooldown", f.TeleportButton, "CooldownFrameTemplate")
  f.TeleportButton.Cooldown:SetAllPoints()
  f.TeleportButton.Cooldown:SetDrawEdge(false)
  f.TeleportButton.Cooldown:SetReverse(true)
  f.TeleportButton.Cooldown:Hide()

  f.TeleportLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  -- Anchor the label to the button so they can never overlap.
  f.TeleportLabel:SetPoint("BOTTOM", f.TeleportButton, "TOP", 0, 10)
  f.TeleportLabel:SetText(L["GROUP_REMINDER_TELEPORT"] or "Teleport to dungeon")
  f.TeleportLabel:SetTextColor(1, 0.82, 0, 1)

  f.TeleportButton:SetScript("OnEnter", function(self)
    if self.spellID then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetSpellByID(self.spellID)
      GameTooltip:Show()
    end
  end)
  f.TeleportButton:SetScript("OnLeave", GameTooltip_Hide)

  f.Close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  f.Close:SetPoint("TOPRIGHT", -5, -5)

  f:Hide()
  addon._DT_GR_popup = f
  return f
end

function addon:DT_GR_ShowPopup(data)
  if not data then return end
  EnsureDefaults()
  _G.DungeonTeleports_GroupReminder = addon
  local db = DungeonTeleportsDB.groupReminder
  if not db.enabled or not db.showPopup then return end

  local f = EnsurePopup()
  f.Title:SetText(HeaderLabel())

  local lines = {}
  local labelColor = "|cffffd100"
  local valueColor = "|cffffffff"

  if db.showDungeonName then
    table.insert(lines, labelColor .. (L["GROUP_REMINDER_DUNGEON"] or "Dungeon:") .. "|r " .. valueColor .. (data.dungeonName or "-") .. "|r")
  end
  if db.showGroupName then
    table.insert(lines, labelColor .. (L["GROUP_REMINDER_GROUP"] or "Group:") .. "|r " .. valueColor .. (data.groupName or "-") .. "|r")
  end
  if db.showGroupDescription then
    table.insert(lines, labelColor .. (L["GROUP_REMINDER_DESCRIPTION"] or "Description:") .. "|r " .. valueColor .. (data.comment or "-") .. "|r")
  end
  if db.showAppliedRole then
    table.insert(lines, labelColor .. (L["GROUP_REMINDER_ROLE"] or "Role:") .. "|r " .. valueColor .. (data.roleText or "-") .. "|r")
  end

  f.Content:SetText(table.concat(lines, "\n"))

  local roleKey = GuessRoleKey(data.roleText)
  if db.showAppliedRole and roleKey and f.RoleIcon.SetAtlas then
    local atlas = (roleKey == "TANK" and "roleicon-tank") or (roleKey == "HEALER" and "roleicon-healer") or "roleicon-dps"
    f.RoleIcon:SetAtlas(atlas, true)
    f.RoleIcon:Show()
  else
    f.RoleIcon:Hide()
  end

  f.TeleportButton.spellID = nil
  f.TeleportButton:SetAttribute("type", nil)
  f.TeleportButton:SetAttribute("spell", nil)

  if data.teleportSpellID and DT_GR_IsSpellKnown(data.teleportSpellID) then
    f.TeleportButton.spellID = data.teleportSpellID
    f.TeleportButton:SetAttribute("type", "spell")
    f.TeleportButton:SetAttribute("spell", data.teleportSpellID)

    local _, icon = DT_GR_GetSpellNameIcon(data.teleportSpellID)
    f.TeleportButton.Icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    f.TeleportButton.Icon:SetDesaturated(false)
    f.TeleportButton:SetAlpha(1)
    f.TeleportLabel:SetText(L["GROUP_REMINDER_TELEPORT"] or "Teleport to dungeon")
      DT_GR_SetCooldown(f.TeleportButton.Cooldown, data.teleportSpellID)
  else
    f.TeleportButton.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    f.TeleportButton.Icon:SetDesaturated(true)
    f.TeleportButton:SetAlpha(0.7)
    f.TeleportLabel:SetText(L["GROUP_REMINDER_TELEPORT_UNKNOWN"] or "Teleport not known")
    DT_GR_SetCooldown(f.TeleportButton.Cooldown, nil)
  end

  f:Show()
end

function addon:DT_GR_ShowLastReminder()
  local last = self._DT_GR_lastReminder or (DungeonTeleportsDB and DungeonTeleportsDB.groupReminder and DungeonTeleportsDB.groupReminder.lastReminder)
  if last then
    self:DT_GR_ShowPopup(last)
  end
end

-- Clickable chat link: opens the popup again
if not addon._DT_GR_chatLinkHooked then
  addon._DT_GR_chatLinkHooked = true

  -- Some addons replace SetItemRef or SetItemRef can be overridden after we load.
  -- Preferred approach: hook chat frame hyperlink clicks directly; keep SetItemRef as fallback.
  local function DT_GR_HandleLink(link)
    if type(link) ~= "string" then return end
    local linkType = strsplit(":", link, 2)
    if linkType ~= "dtpreminder" then return end
    if addon and addon.DT_GR_ShowLastReminder then
      addon:DT_GR_ShowLastReminder()
    end
  end

  -- Hook OnHyperlinkClick on available chat frames (most reliable across UI mods)
  local num = _G.NUM_CHAT_WINDOWS or 10
  for i = 1, num do
    local cf = _G["ChatFrame"..i]
    if cf and cf.HookScript then
      cf:HookScript("OnHyperlinkClick", function(_, link)
        DT_GR_HandleLink(link)
      end)
    end
  end

  -- Some clients expose a global ChatFrame_OnHyperlinkShow; only hook if it exists.
  if type(_G.ChatFrame_OnHyperlinkShow) == "function" then
    hooksecurefunc("ChatFrame_OnHyperlinkShow", function(_, link)
      DT_GR_HandleLink(link)
    end)
  end

  -- Fallback: also hook SetItemRef (works on many clients)
  hooksecurefunc("SetItemRef", function(link)
    DT_GR_HandleLink(link)
  end)
end


local function IsMythicPlusActivity(activityID)
  local t = C_LFGList.GetActivityInfoTable and C_LFGList.GetActivityInfoTable(activityID)
  if t and t.isMythicPlusActivity ~= nil then
    return not not t.isMythicPlusActivity
  end
  return false
end

local function BuildChatLine(db, data)
  local vcol = "|cffff6a00"
  local parts = {}
  if db.showDungeonName then table.insert(parts, vcol .. (data.dungeonName or "-") .. "|r") end
  if db.showGroupName then table.insert(parts, vcol .. (data.groupName or "-") .. "|r") end
  local msg = (L["GROUP_REMINDER_INVITED"] or "You joined") .. " " .. table.concat(parts, ", ")
  if db.showAppliedRole and data.roleText then
    msg = msg .. " " .. string.format((L["GROUP_REMINDER_AS_ROLE"] or "as %s"), vcol .. data.roleText .. "|r")
  end
  local linkText = "|cffffd100[" .. (L["GROUP_REMINDER_OPEN"] or "Open reminder") .. "]|r"
  local link = string.format("|Hdtpreminder:1|h%s|h", linkText)
  return HeaderLabel() .. " " .. msg .. " " .. link
end

function addon:DT_GR_ShowReminder(searchResultID, activity, searchResultInfo)
  EnsureDefaults()
  _G.DungeonTeleports_GroupReminder = addon
  local db = DungeonTeleportsDB.groupReminder
  if not db.enabled then return end

  local roleText = GetAppliedRoleText(searchResultID)
  local groupName = (searchResultInfo and searchResultInfo.name) or ""
  local comment = (searchResultInfo and searchResultInfo.comment) or ""

  local spellID, resolvedName = ResolveTeleportSpell(activity and activity.fullName, activity and activity.shortName)
  local rawDungeonName = (activity and (activity.fullName or activity.shortName)) or ""
  local dungeonName
  do
    local rawLower = rawDungeonName:lower()
    if rawLower:find("tazavesh streets", 1, true) or rawLower:find("tazavesh gambit", 1, true) then
      -- Keep the split-wing name for display, but still use the unified teleport spell.
      dungeonName = rawDungeonName
    else
      dungeonName = resolvedName or rawDungeonName
    end
  end

  local data = {
    groupName = groupName,
    comment = comment,
    dungeonName = dungeonName,
    roleText = roleText,
    teleportSpellID = spellID,
  }

  self._DT_GR_lastReminder = data
  DungeonTeleportsDB.groupReminder.lastReminder = data

  if db.showPopup then
    self:DT_GR_ShowPopup(data)
  end
  if db.showChat then
    print(BuildChatLine(db, data))
  end
end

function addon:DT_GR_UpdateRegistration()
  EnsureDefaults()
  _G.DungeonTeleports_GroupReminder = addon
  local db = DungeonTeleportsDB.groupReminder

  if not self._DT_GR_frame then
    self._DT_GR_frame = CreateFrame("Frame")
    self._DT_GR_frame:SetScript("OnEvent", function(_, event, ...)
      if event == "GROUP_LEFT" then
        addon._DT_GR_lastReminder = nil
        if DungeonTeleportsDB and DungeonTeleportsDB.groupReminder then
          DungeonTeleportsDB.groupReminder.lastReminder = nil
        end
        return
      end

      if event ~= "LFG_LIST_APPLICATION_STATUS_UPDATED" then return end
      local searchResultID, newStatus = ...
      if not searchResultID or not newStatus then return end
      if newStatus ~= "inviteaccepted" then return end

      local srd = C_LFGList.GetSearchResultInfo and C_LFGList.GetSearchResultInfo(searchResultID)
      if not srd then return end

      local activityID = (srd.activityIDs and srd.activityIDs[1]) or srd.activityID
      if not activityID then return end
      if not IsMythicPlusActivity(activityID) then return end

      local activity = C_LFGList.GetActivityInfoTable and C_LFGList.GetActivityInfoTable(activityID)
      if not activity then return end

      if DungeonTeleportsDB.groupReminder.suppressQuickJoinToast and type(LFGListInviteDialog) == "table" and LFGListInviteDialog.Hide then
        if LFGListInviteDialog.IsShown and LFGListInviteDialog:IsShown() then
          LFGListInviteDialog:Hide()
        end
      end

      C_Timer.After(0.2, function()
        if DungeonTeleportsDB and DungeonTeleportsDB.groupReminder and DungeonTeleportsDB.groupReminder.enabled then
          addon:DT_GR_ShowReminder(searchResultID, activity, srd)
        end

        -- Clear cached role after we've built the reminder
        if addon._DT_GR_roleByResult then
          addon._DT_GR_roleByResult[searchResultID] = nil
        end
      end)

    end)
  end

  self._DT_GR_frame:UnregisterAllEvents()
  if db.enabled then
    self._DT_GR_frame:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
    self._DT_GR_frame:RegisterEvent("GROUP_LEFT")
  end
end

function addon:DT_GR_Test()
  EnsureDefaults()
  _G.DungeonTeleports_GroupReminder = addon
  if not DungeonTeleportsDB.groupReminder.enabled then
    print("|cffff7f00DungeonTeleports: Group Reminder is disabled in settings.|r")
    return
  end

  local const = addon.constants
  local anyName
  local anySpell
  if const and type(const.mapIDtoDungeonName) == "table" then
    for k, v in pairs(const.mapIDtoDungeonName) do
      anyName = v
      anySpell = const.mapIDtoSpellID and const.mapIDtoSpellID[k] or nil
      if anyName then break end
    end
  end

  local data = {
    groupName = "+10 weekly chill",
    comment = "Test reminder from DungeonTeleports.",
    dungeonName = anyName or "Unknown Dungeon",
    roleText = (UnitGroupRolesAssigned("player") == "HEALER" and HEALER) or (UnitGroupRolesAssigned("player") == "TANK" and TANK) or DAMAGER,
    teleportSpellID = anySpell,
  }

  addon._DT_GR_lastReminder = data
  DungeonTeleportsDB.groupReminder.lastReminder = data

  self:DT_GR_ShowPopup(data)
  if DungeonTeleportsDB.groupReminder.showChat then
    print(BuildChatLine(DungeonTeleportsDB.groupReminder, data))
  end
end

-- =========================================================
-- Settings UI (sub-page under Blizzard Settings)
-- =========================================================
function addon:DT_GR_BuildConfigPanel(parent, outWidgets)
  local widgets = outWidgets or {}

  local frame = CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(true)
  frame:Hide() -- prevent showing in-world before Settings parents it

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText(L["GROUP_REMINDER_TITLE"] or "Group Reminder")

  local desc = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  desc:SetPoint("RIGHT", -16, 0)
  desc:SetJustifyH("LEFT")
  desc:SetText(L["GROUP_REMINDER_DESC"] or "Shows a reminder when you accept a Mythic+ invite, with a teleport button if you know the spell.")

  local enable = CreateFrame("CheckButton", nil, frame, "ChatConfigCheckButtonTemplate")
  enable:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
  enable.Text:SetText(L["GROUP_REMINDER_ENABLED"] or "Enable Group Reminder")
  enable:SetScript("OnClick", function(self)
    EnsureDefaults()
  _G.DungeonTeleports_GroupReminder = addon
    DungeonTeleportsDB.groupReminder.enabled = not not self:GetChecked()
    if addon.DT_GR_UpdateRegistration then addon:DT_GR_UpdateRegistration() end
  end)

  local showPopup = CreateFrame("CheckButton", nil, frame, "ChatConfigCheckButtonTemplate")
  showPopup:SetPoint("TOPLEFT", enable, "BOTTOMLEFT", 0, -10)
  showPopup.Text:SetText(L["GROUP_REMINDER_SHOW_POPUP"] or "Show popup")
  showPopup:SetScript("OnClick", function(self)
    EnsureDefaults()
  _G.DungeonTeleports_GroupReminder = addon
    DungeonTeleportsDB.groupReminder.showPopup = not not self:GetChecked()
  end)

  local showChat = CreateFrame("CheckButton", nil, frame, "ChatConfigCheckButtonTemplate")
  showChat:SetPoint("TOPLEFT", showPopup, "BOTTOMLEFT", 0, -10)
  showChat.Text:SetText(L["GROUP_REMINDER_SHOW_CHAT"] or "Also print to chat")
  showChat:SetScript("OnClick", function(self)
    EnsureDefaults()
  _G.DungeonTeleports_GroupReminder = addon
    DungeonTeleportsDB.groupReminder.showChat = not not self:GetChecked()
  end)

  local suppressToast = CreateFrame("CheckButton", nil, frame, "ChatConfigCheckButtonTemplate")
  suppressToast:SetPoint("TOPLEFT", showChat, "BOTTOMLEFT", 0, -10)
  suppressToast.Text:SetText(L["GROUP_REMINDER_SUPPRESS_TOAST"] or "Hide Blizzard invite dialog after accepting")
  suppressToast:SetScript("OnClick", function(self)
    EnsureDefaults()
  _G.DungeonTeleports_GroupReminder = addon
    DungeonTeleportsDB.groupReminder.suppressQuickJoinToast = not not self:GetChecked()
  end)

  local section = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  section:SetPoint("TOPLEFT", suppressToast, "BOTTOMLEFT", 0, -16)
  section:SetText(L["GROUP_REMINDER_FIELDS"] or "Popup fields")

  local function MakeFieldCheckbox(labelKey, dbKey, anchor)
    local cb = CreateFrame("CheckButton", nil, frame, "ChatConfigCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
    cb.Text:SetText(labelKey)
    cb:SetScript("OnClick", function(self)
      EnsureDefaults()
  _G.DungeonTeleports_GroupReminder = addon
      DungeonTeleportsDB.groupReminder[dbKey] = not not self:GetChecked()
    end)
    return cb
  end

  local cbDungeon = MakeFieldCheckbox(L["GROUP_REMINDER_DUNGEON"] or "Dungeon name", "showDungeonName", section)
  local cbGroup   = MakeFieldCheckbox(L["GROUP_REMINDER_GROUP"] or "Group name", "showGroupName", cbDungeon)
  local cbDesc    = MakeFieldCheckbox(L["GROUP_REMINDER_DESCRIPTION"] or "Description", "showGroupDescription", cbGroup)
  local cbRole    = MakeFieldCheckbox(L["GROUP_REMINDER_ROLE"] or "Applied role", "showAppliedRole", cbDesc)

  local test = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  test:SetPoint("TOPLEFT", cbRole, "BOTTOMLEFT", 0, -18)
  test:SetText(L["GROUP_REMINDER_TEST"] or "Test")
  test:SetWidth(test:GetTextWidth() + 20)
  test:SetHeight(24)
  test:SetScript("OnClick", function()
    if addon.DT_GR_Test then addon:DT_GR_Test() end
  end)

  frame.OnRefresh = function()
    EnsureDefaults()
  _G.DungeonTeleports_GroupReminder = addon
    local db = DungeonTeleportsDB.groupReminder
    enable:SetChecked(db.enabled)
    showPopup:SetChecked(db.showPopup)
    showChat:SetChecked(db.showChat)
    suppressToast:SetChecked(db.suppressQuickJoinToast)
    cbDungeon:SetChecked(db.showDungeonName)
    cbGroup:SetChecked(db.showGroupName)
    cbDesc:SetChecked(db.showGroupDescription)
    cbRole:SetChecked(db.showAppliedRole)
  end

  widgets.enable = enable
  widgets.showPopup = showPopup
  widgets.showChat = showChat
  widgets.suppressToast = suppressToast
  widgets.cbDungeon = cbDungeon
  widgets.cbGroup = cbGroup
  widgets.cbDesc = cbDesc
  widgets.cbRole = cbRole
  widgets.test = test

  return frame
end

-- Bootstrap on load
local init = CreateFrame("Frame")
init:RegisterEvent("ADDON_LOADED")
init:SetScript("OnEvent", function(self, _, arg1)
  if arg1 ~= addonName then return end
  EnsureDefaults()
  _G.DungeonTeleports_GroupReminder = addon
  if addon and addon.DT_GR_UpdateRegistration then
    addon:DT_GR_UpdateRegistration()
  end
  self:UnregisterEvent("ADDON_LOADED")
end)
