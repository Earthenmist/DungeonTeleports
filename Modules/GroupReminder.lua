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
  if C_SpellBook and C_SpellBook.IsSpellKnown then
    return C_SpellBook.IsSpellKnown(spellID)
  end
  if C_SpellBook and C_SpellBook.IsSpellInSpellBook then
    return C_SpellBook.IsSpellInSpellBook(spellID)
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

local DT_GR_pendingPopupData
local DT_GR_popupWaiter
local DT_GR_hidePending

local function PublicMapID(value)
  if issecretvalue and issecretvalue(value) then return nil end
  return type(value) == "number" and value > 0 and value or nil
end

local function IsAtReminderDestination(data)
  local target = data and PublicMapID(data.instanceMapID)
  if not target or not GetInstanceInfo then return false end
  local ok, _, instanceType, _, _, _, _, _, mapID = pcall(GetInstanceInfo)
  if not ok or (issecretvalue and issecretvalue(instanceType)) then return false end
  if instanceType ~= "party" and instanceType ~= "raid" and instanceType ~= "scenario" then return false end
  return PublicMapID(mapID) == target
end

local function WaitForPopupCombatEnd()
  if DT_GR_popupWaiter then return end
  DT_GR_popupWaiter = CreateFrame("Frame")
  DT_GR_popupWaiter:RegisterEvent("PLAYER_REGEN_ENABLED")
  DT_GR_popupWaiter:SetScript("OnEvent", function(self)
    if InCombatLockdown and InCombatLockdown() then return end
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    DT_GR_popupWaiter = nil
    if DT_GR_hidePending and addon._DT_GR_popup then addon._DT_GR_popup:Hide() end
    DT_GR_hidePending = nil
    local pending = DT_GR_pendingPopupData
    DT_GR_pendingPopupData = nil
    if pending then addon:DT_GR_ShowPopup(pending) end
  end)
end

local function HideReminderPopup()
  local popup = addon._DT_GR_popup
  if not popup or not popup:IsShown() then return end
  if InCombatLockdown and InCombatLockdown() then
    DT_GR_hidePending = true
    WaitForPopupCombatEnd()
  else
    DT_GR_hidePending = nil
    popup:Hide()
  end
end

function addon:DT_GR_ClosePopup()
  DT_GR_pendingPopupData = nil
  HideReminderPopup()
end

function addon:DT_GR_CheckDestination()
  if IsAtReminderDestination(DT_GR_pendingPopupData) then DT_GR_pendingPopupData = nil end
  local popup = self._DT_GR_popup
  if popup and IsAtReminderDestination(popup.reminderData) then HideReminderPopup() end
end

local function EnsurePopup()
  if addon._DT_GR_popup then return addon._DT_GR_popup end

  -- Ensure SavedVariables exist before we try to read/write popup position.
  EnsureDefaults()
  local db = DungeonTeleportsDB.groupReminder

  local theme = addon.UITheme
  local colors = theme.colors
  local f = theme.CreatePanel("DungeonTeleports_GroupReminderPopup", UIParent, 1)
  f:SetSize(480, 280)
  theme.StylePanel(f, colors.bg, colors.borderSoft)

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

  -- Deliberately excluded from UISpecialFrames so Escape leaves the reminder open.
  f.Header = theme.CreatePanel(nil, f, 1)
  f.Header:SetPoint("TOPLEFT", 1, -1)
  f.Header:SetPoint("TOPRIGHT", -1, -1)
  f.Header:SetHeight(42)
  theme.StylePanel(f.Header, colors.accentDark, colors.accentDark)

  f.Logo = f.Header:CreateTexture(nil, "ARTWORK")
  f.Logo:SetSize(18, 18)
  f.Logo:SetPoint("LEFT", 12, 0)
  f.Logo:SetTexture("Interface\\AddOns\\DungeonTeleports\\Images\\DungeonTeleportsLogo.tga")

  f.Title = f.Header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.Title:SetPoint("LEFT", f.Logo, "RIGHT", 10, 0)
  f.Title:SetPoint("RIGHT", -44, 0)
  f.Title:SetJustifyH("LEFT")
  f.Title:SetText(L["GROUP_REMINDER_TITLE"])
  f.Title:SetTextColor(1, 1, 1)

  f.InfoPanel = theme.CreatePanel(nil, f, 1)
  f.InfoPanel:SetPoint("TOPLEFT", 14, -56)
  f.InfoPanel:SetPoint("TOPRIGHT", -14, -56)
  f.InfoPanel:SetPoint("BOTTOM", 0, 100)
  theme.StylePanel(f.InfoPanel, colors.bgCard, colors.borderSoft)

  f.RoleIcon = f.InfoPanel:CreateTexture(nil, "OVERLAY")
  f.RoleIcon:SetSize(22, 22)
  f.RoleIcon:SetPoint("TOPRIGHT", f.InfoPanel, "TOPRIGHT", -12, -12)
  f.RoleIcon:Hide()

  f.Content = f.InfoPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.Content:SetPoint("TOPLEFT", f.InfoPanel, "TOPLEFT", 14, -14)
  f.Content:SetWidth(394)
  f.Content:SetWordWrap(true)
  f.Content:SetJustifyH("LEFT")
  f.Content:SetJustifyV("TOP")
  f.Content:SetSpacing(8)

  f.TeleportButton = CreateFrame("Button", nil, f, "SecureActionButtonTemplate,BackdropTemplate")
  theme.StyleButton(f.TeleportButton, "", 48)
  f.TeleportButton:RegisterForClicks("AnyUp", "AnyDown")

  f.TeleportButton.Icon = f.TeleportButton:CreateTexture(nil, "ARTWORK")
  f.TeleportButton.Icon:SetPoint("TOPLEFT", 2, -2)
  f.TeleportButton.Icon:SetPoint("BOTTOMRIGHT", -2, 2)
  f.TeleportButton.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  f.TeleportButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

  -- Cooldown swipe overlay (mirrors main DungeonTeleports buttons)
  f.TeleportButton.Cooldown = CreateFrame("Cooldown", "DungeonTeleports_GroupReminderCooldown", f.TeleportButton, "CooldownFrameTemplate")
  f.TeleportButton.Cooldown:SetAllPoints()
  f.TeleportButton.Cooldown:SetDrawEdge(false)
  f.TeleportButton.Cooldown:SetReverse(true)
  f.TeleportButton.Cooldown:Hide()

  f.TeleportLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.TeleportLabel:SetPoint("LEFT", f.TeleportButton, "RIGHT", 14, 0)
  f.TeleportLabel:SetJustifyH("LEFT")
  f.TeleportLabel:SetText(L["GROUP_REMINDER_TELEPORT"] or "Teleport to dungeon")
  f.TeleportLabel:SetTextColor(colors.accent[1], colors.accent[2], colors.accent[3], 1)

  f.TeleportButton:SetScript("OnEnter", function(self)
    if self.spellID then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetSpellByID(self.spellID)
      GameTooltip:Show()
    end
  end)
  f.TeleportButton:SetScript("OnLeave", GameTooltip_Hide)

  f.TeleportButton:SetScript("PostClick", function(self, _, down)
    -- Wait for release so closing cannot prevent an up-triggered secure cast.
    if down then return end
    if self.spellID and DT_GR_IsSpellKnown(self.spellID) and DungeonTeleportsDB.closeOnTeleport then
      addon:DT_GR_ClosePopup()
    end
  end)

  f.Close = CreateFrame("Button", nil, f.Header, "BackdropTemplate")
  theme.StyleButton(f.Close, "×", 24)
  f.Close:SetPoint("RIGHT", -8, 0)
  f.Close:SetScript("OnClick", function() addon:DT_GR_ClosePopup() end)

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
  if IsAtReminderDestination(data) then
    self:DT_GR_ClosePopup()
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    -- The popup's teleport button is a SecureActionButtonTemplate; creating it
    -- (first show) or changing its spell attribute (every show after that) is
    -- disallowed during combat lockdown. A group-finder application can be
    -- accepted mid-fight, so defer showing the popup until combat ends instead
    -- of erroring.
    DT_GR_pendingPopupData = data
    WaitForPopupCombatEnd()
    return
  end

  local f = EnsurePopup()
  DT_GR_pendingPopupData = nil
  DT_GR_hidePending = nil
  f.reminderData = data

  local lines = {}
  local color = addon.UITheme.colors.accent
  local labelColor = string.format("|cff%02x%02x%02x", math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255))
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
  f:SetHeight(math.max(280, f.Content:GetStringHeight() + 184))

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

  -- Centre the icon and localized label together within the footer.
  f.TeleportLabel:SetWidth(0)
  local labelWidth = math.min(378, f.TeleportLabel:GetStringWidth())
  f.TeleportLabel:SetWidth(labelWidth)
  f.TeleportButton:SetPoint("BOTTOMLEFT", f, "BOTTOM", -(48 + 14 + labelWidth) / 2, 22)

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

  local spellID, dungeonName = self:ResolveDungeonActivity(activity)

  local data = {
    instanceMapID = activity and PublicMapID(activity.mapID),
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

  addon._DT_GR_pendingInvite = addon._DT_GR_pendingInvite or nil
  addon._DT_GR_lastShownAt = addon._DT_GR_lastShownAt or 0
  -- Snapshot of {activityID, srd} per searchResultID, captured the first time
  -- C_LFGList.GetSearchResultInfo() succeeds for it. Blizzard purges search
  -- results from this API once the Premade Groups panel is closed / the list
  -- refreshes, so if the player is accepted *after* that happens, a fresh
  -- lookup at accept-time returns nil even though the application is real.
  -- Falling back to this snapshot keeps the reminder working in that case.
  addon._DT_GR_appCache = addon._DT_GR_appCache or {}

  local function DT_GR_CanShowAgain()
    local now = GetTime and GetTime() or 0
    if (now - (addon._DT_GR_lastShownAt or 0)) < 2 then
      return false
    end
    addon._DT_GR_lastShownAt = now
    return true
  end

  local function DT_GR_ClearPending(searchResultID)
    addon._DT_GR_pendingInvite = nil
    if addon._DT_GR_roleByResult and searchResultID then
      addon._DT_GR_roleByResult[searchResultID] = nil
    end
    if addon._DT_GR_appCache and searchResultID then
      addon._DT_GR_appCache[searchResultID] = nil
    end
  end

  if not self._DT_GR_frame then
    self._DT_GR_frame = CreateFrame("Frame")
    self._DT_GR_frame:SetScript("OnEvent", function(_, event, ...)
      if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        addon:DT_GR_CheckDestination()
        return
      end
      if event == "GROUP_LEFT" then
        addon._DT_GR_lastReminder = nil
        addon._DT_GR_pendingInvite = nil
        addon._DT_GR_appCache = {}
        if DungeonTeleportsDB and DungeonTeleportsDB.groupReminder then
          DungeonTeleportsDB.groupReminder.lastReminder = nil
        end
        return
      end

      if event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
        local searchResultID, newStatus = ...
        if not searchResultID or not newStatus then return end

        local srd = C_LFGList.GetSearchResultInfo and C_LFGList.GetSearchResultInfo(searchResultID)
        local activityID = srd and ((srd.activityIDs and srd.activityIDs[1]) or srd.activityID)

        if srd and activityID then
          -- Live data available - cache it while it's good, in case it's
          -- gone by the time the "accepted" status/GROUP_JOINED arrives.
          addon._DT_GR_appCache[searchResultID] = { srd = srd, activityID = activityID }
        else
          -- Live lookup failed (panel closed, list refreshed, etc). Fall
          -- back to whatever we captured earlier for this application.
          local cached = addon._DT_GR_appCache[searchResultID]
          if cached then
            srd = srd or cached.srd
            activityID = activityID or cached.activityID
          end
        end

        if not srd or not activityID or not IsMythicPlusActivity(activityID) then return end

        local activity = C_LFGList.GetActivityInfoTable and C_LFGList.GetActivityInfoTable(activityID)
        if not activity then return end

        if newStatus == "invited" or newStatus == "inviteaccepted" then
          addon._DT_GR_pendingInvite = {
            searchResultID = searchResultID,
            activity = activity,
            srd = srd,
          }
        else
          return
        end

        if newStatus == "inviteaccepted" then
          if DungeonTeleportsDB.groupReminder.suppressQuickJoinToast and type(LFGListInviteDialog) == "table" and LFGListInviteDialog.Hide then
            if LFGListInviteDialog.IsShown and LFGListInviteDialog:IsShown() then
              LFGListInviteDialog:Hide()
            end
          end

          local pending = addon._DT_GR_pendingInvite
          if not pending or not DT_GR_CanShowAgain() then return end

          C_Timer.After(0.2, function()
            if DungeonTeleportsDB and DungeonTeleportsDB.groupReminder and DungeonTeleportsDB.groupReminder.enabled then
              addon:DT_GR_ShowReminder(pending.searchResultID, pending.activity, pending.srd)
            end
            DT_GR_ClearPending(pending.searchResultID)
          end)
        end

        return
      end

      if event == "GROUP_JOINED" then
        local pending = addon._DT_GR_pendingInvite
        if not pending or not DT_GR_CanShowAgain() then return end

        if DungeonTeleportsDB.groupReminder.suppressQuickJoinToast and type(LFGListInviteDialog) == "table" and LFGListInviteDialog.Hide then
          if LFGListInviteDialog.IsShown and LFGListInviteDialog:IsShown() then
            LFGListInviteDialog:Hide()
          end
        end

        C_Timer.After(0.3, function()
          if DungeonTeleportsDB and DungeonTeleportsDB.groupReminder and DungeonTeleportsDB.groupReminder.enabled then
            addon:DT_GR_ShowReminder(pending.searchResultID, pending.activity, pending.srd)
          end
          DT_GR_ClearPending(pending.searchResultID)
        end)
        return
      end
    end)
  end

  self._DT_GR_frame:UnregisterAllEvents()
  if db.enabled then
    self._DT_GR_frame:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
    self._DT_GR_frame:RegisterEvent("GROUP_JOINED")
    self._DT_GR_frame:RegisterEvent("GROUP_LEFT")
    self._DT_GR_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self._DT_GR_frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
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
    for k in pairs(const.mapIDtoDungeonName) do
      anyName = self:GetDungeonName(k)
      anySpell = self:GetTeleportSpellID(k)
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
