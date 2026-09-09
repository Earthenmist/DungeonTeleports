local addonName, addon = ...
local L = addon.L

local qolWidgets = {}
local inviteThrottle = {}

local RESTRICT_ANYONE = "anyone"
local RESTRICT_FRIENDS = "friends"
local RESTRICT_GUILD = "guild"
local RESTRICT_FRIENDS_OR_GUILD = "friends_or_guild"

local function GetDB()
  DungeonTeleportsDB = DungeonTeleportsDB or {}
  DungeonTeleportsDB.qol = DungeonTeleportsDB.qol or {}

  if DungeonTeleportsDB.qol.autoInviteOnWhisper == nil then
    DungeonTeleportsDB.qol.autoInviteOnWhisper = false
  end

  if type(DungeonTeleportsDB.qol.autoInviteKeyword) ~= "string" or DungeonTeleportsDB.qol.autoInviteKeyword == "" then
    DungeonTeleportsDB.qol.autoInviteKeyword = "inv, invite, 123"
  end

  local restriction = DungeonTeleportsDB.qol.autoInviteRestriction
  if restriction ~= RESTRICT_ANYONE
    and restriction ~= RESTRICT_FRIENDS
    and restriction ~= RESTRICT_GUILD
    and restriction ~= RESTRICT_FRIENDS_OR_GUILD then
    DungeonTeleportsDB.qol.autoInviteRestriction = RESTRICT_ANYONE
  end

  return DungeonTeleportsDB.qol
end

local function NormaliseKeyword(text)
  if type(text) ~= "string" then return "" end

  local okTrim, trimmed = pcall(string.match, text, "^%s*(.-)%s*$")
  if not okTrim or type(trimmed) ~= "string" then
    return ""
  end

  local okLower, lowered = pcall(string.lower, trimmed)
  if not okLower or type(lowered) ~= "string" then
    return ""
  end

  return lowered
end

local function IsAutoInviteAllowedHere()
  -- Match the addon's existing safety gating for risky behaviour.
  if InCombatLockdown and InCombatLockdown() then return false end
  if UnitAffectingCombat and UnitAffectingCombat("player") then return false end
  if IsEncounterInProgress and IsEncounterInProgress() then return false end

  -- Respect the addon's own Mythic+ suppression flag if present.
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

local function GetInviteKeywords()
  local db = GetDB()
  local raw = db.autoInviteKeyword or ""

  local keywords = {}
  for entry in string.gmatch(raw, "([^,]+)") do
    local word = NormaliseKeyword(entry)
    if word ~= "" then
      keywords[word] = true
    end
  end

  return keywords
end

local function GetRestrictionLabel(value)
  if value == RESTRICT_FRIENDS then
    return L["AUTO_INVITE_RESTRICT_FRIENDS"] or "Friends only"
  elseif value == RESTRICT_GUILD then
    return L["AUTO_INVITE_RESTRICT_GUILD"] or "Guild members only"
  elseif value == RESTRICT_FRIENDS_OR_GUILD then
    return L["AUTO_INVITE_RESTRICT_FRIENDS_OR_GUILD"] or "Friends or guild members"
  end

  return L["AUTO_INVITE_RESTRICT_ANYONE"] or "Anyone"
end

local function IsNameInFriendsList(sender)
  if not sender or sender == "" then return false end

  local shortName = Ambiguate and Ambiguate(sender, "short") or sender

  if C_FriendList and C_FriendList.GetFriendInfo then
    local info = C_FriendList.GetFriendInfo(sender)
    if info then return true end
    if shortName ~= sender and C_FriendList.GetFriendInfo(shortName) then
      return true
    end
  end

  if C_FriendList and C_FriendList.IsFriend then
    if C_FriendList.IsFriend(sender) or (shortName ~= sender and C_FriendList.IsFriend(shortName)) then
      return true
    end
  end

  if GetNumFriends and GetFriendInfo then
    for i = 1, (GetNumFriends() or 0) do
      local name = GetFriendInfo(i)
      if name and (name == sender or name == shortName) then
        return true
      end
    end
  end

  return false
end

local function IsGuildMemberName(sender)
  if not sender or sender == "" or not IsInGuild or not IsInGuild() then
    return false
  end

  local shortName = Ambiguate and Ambiguate(sender, "short") or sender

  if IsGuildMember then
    if IsGuildMember(sender) or (shortName ~= sender and IsGuildMember(shortName)) then
      return true
    end
  end

  return false
end

local function SenderMatchesRestriction(sender)
  local db = GetDB()
  local restriction = db.autoInviteRestriction or RESTRICT_ANYONE

  if restriction == RESTRICT_ANYONE then
    return true
  elseif restriction == RESTRICT_FRIENDS then
    return IsNameInFriendsList(sender)
  elseif restriction == RESTRICT_GUILD then
    return IsGuildMemberName(sender)
  elseif restriction == RESTRICT_FRIENDS_OR_GUILD then
    return IsNameInFriendsList(sender) or IsGuildMemberName(sender)
  end

  return true
end

local function BNSenderMatchesRestriction()
  local db = GetDB()
  local restriction = db.autoInviteRestriction or RESTRICT_ANYONE

  if restriction == RESTRICT_ANYONE then
    return true
  elseif restriction == RESTRICT_FRIENDS then
    return true
  elseif restriction == RESTRICT_GUILD then
    return false
  elseif restriction == RESTRICT_FRIENDS_OR_GUILD then
    return true
  end

  return true
end

local function InviteSender(sender)
  if not sender or sender == "" then return end

  if C_PartyInfo and C_PartyInfo.InviteUnit then
    C_PartyInfo.InviteUnit(sender)
  elseif InviteUnit then
    InviteUnit(sender)
  end
end

local function GetBNGameAccountIDFromSenderID(bnSenderID)
  if not bnSenderID then return nil end

  local numFriends = BNGetNumFriends and BNGetNumFriends() or 0

  for i = 1, numFriends do
    -- Legacy API fallback is often the most reliable for matching the bnSenderID
    -- from CHAT_MSG_BN_WHISPER to a friend entry.
    local presenceID, accountName, battleTag, isBattleTagPresence, toonName, toonID, client, isOnline = nil, nil, nil, nil, nil, nil, nil, nil
    if BNGetFriendInfo then
      presenceID, accountName, battleTag, isBattleTagPresence, toonName, toonID, client, isOnline = BNGetFriendInfo(i)
    end

    if presenceID == bnSenderID then

      if BNGetNumFriendGameAccounts and BNGetFriendGameAccountInfo then
        local numGameAccounts = BNGetNumFriendGameAccounts(i) or 0
        for j = 1, numGameAccounts do
          local hasFocus, characterName, clientProgram, realmName, realmID, faction, race, class, zoneName, level, gameText, broadcastText, broadcastTime, canSoR, toonID2, gameAccountID, isGameAFK, isGameBusy, isGuidDataAvailable, customMessage, customMessageTime, wowProjectID = BNGetFriendGameAccountInfo(i, j)
          if gameAccountID and (clientProgram == BNET_CLIENT_WOW or clientProgram == "WoW") then
            return gameAccountID
          end
        end
      end

      -- C_BattleNet fallback in case the legacy game-account API is unavailable.
      local accountInfo = C_BattleNet and C_BattleNet.GetFriendAccountInfo and C_BattleNet.GetFriendAccountInfo(i)
      if accountInfo then
        local game = accountInfo.gameAccountInfo
        if game and game.gameAccountID and (game.clientProgram == BNET_CLIENT_WOW or game.clientProgram == "WoW") and game.isOnline then
          return game.gameAccountID
        end
      end

      return nil
    end

    -- Extra fallback: some clients expose the account id on C_BattleNet only.
    local accountInfo = C_BattleNet and C_BattleNet.GetFriendAccountInfo and C_BattleNet.GetFriendAccountInfo(i)
    local accountID = accountInfo and (accountInfo.bnetAccountID or accountInfo.accountID)
    if accountID == bnSenderID then
      local game = accountInfo.gameAccountInfo
      if game and game.gameAccountID and (game.clientProgram == BNET_CLIENT_WOW or game.clientProgram == "WoW") and game.isOnline then
        return game.gameAccountID
      end
    end
  end

  return nil
end

local function InviteBNSender(bnSenderID)
  if not bnSenderID then return false end

  local gameAccountID = GetBNGameAccountIDFromSenderID(bnSenderID)
  if not gameAccountID then
    return false
  end

  if BNInviteFriend then
    BNInviteFriend(gameAccountID)
    return true
  end

  return false
end

local function MessageMatchesKeyword(message)
  local keywords = GetInviteKeywords()
  local messageText = NormaliseKeyword(message)

  if messageText == "" then return false end
  if not next(keywords) then return false end

  return keywords[messageText] == true
end

local function IsThrottled(key)
  local now = GetTime and GetTime() or 0
  local lastInvite = inviteThrottle[key]
  if lastInvite and (now - lastInvite) < 5 then
    return true
  end
  inviteThrottle[key] = now
  return false
end

local function ExtractBNPresenceID(...)
  local bnSenderID = select(13, ...)
  if type(bnSenderID) == "number" and bnSenderID > 0 then
    return bnSenderID
  end
  return nil
end

local whisperFrame = CreateFrame("Frame")
whisperFrame:RegisterEvent("CHAT_MSG_WHISPER")
whisperFrame:RegisterEvent("CHAT_MSG_BN_WHISPER")
whisperFrame:SetScript("OnEvent", function(_, event, ...)
  local db = GetDB()
  if not db.autoInviteOnWhisper then return end
  if not IsAutoInviteAllowedHere() then return end

  if event == "CHAT_MSG_WHISPER" then
    local message, sender = ...
    if not MessageMatchesKeyword(message) then return end
    if not sender or sender == "" then return end
    if not SenderMatchesRestriction(sender) then return end
    if IsThrottled("WHISPER:" .. sender) then return end
    InviteSender(sender)
    return
  end

  if event == "CHAT_MSG_BN_WHISPER" then
    local message = ...
    local arg13 = select(13, ...)
    local presenceID = arg13
    local arg14 = select(14, ...)
    local arg15 = select(15, ...)

    if not MessageMatchesKeyword(message) then
      return
    end

    if not presenceID then
      return
    end

    if not BNSenderMatchesRestriction() then
      return
    end

    if IsThrottled("BN:" .. tostring(presenceID)) then
      return
    end

    if not InviteBNSender(presenceID) then
    end
    return
  end
end)

function addon:DT_QOL_BuildConfigPanel(parent, outWidgets)
  local widgets = outWidgets or qolWidgets

  local panel = CreateFrame("Frame", nil, parent)
  panel:SetAllPoints(true)
  panel:Hide()

  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText(L["QOL_TITLE"] or "QoL")

  local sub = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  sub:SetText(L["QOL_DESC"] or "Quality of life options.")

  local autoInvite = CreateFrame("CheckButton", nil, panel, "ChatConfigCheckButtonTemplate")
  autoInvite:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -14)
  autoInvite.Text:SetText(L["AUTO_INVITE_ON_WHISPER"] or "Auto-invite to party on whisper")

  local keywordLabel, keywordBox, hint
  local restrictionLabel, restrictionDropdown, restrictionHint

  local function SetSubControlsEnabled(enabled)
    local alpha = enabled and 1 or 0.45

    keywordLabel:SetAlpha(alpha)
    keywordBox:SetEnabled(enabled)
    keywordBox:EnableMouse(enabled)
    keywordBox:SetAlpha(alpha)
    if enabled then
      keywordBox:SetTextColor(1, 1, 1)
    else
      keywordBox:SetTextColor(0.55, 0.55, 0.55)
      keywordBox:ClearFocus()
    end

    hint:SetAlpha(alpha)
    restrictionLabel:SetAlpha(alpha)
    restrictionDropdown:SetAlpha(alpha)
    if enabled then
      UIDropDownMenu_EnableDropDown(restrictionDropdown)
    else
      UIDropDownMenu_DisableDropDown(restrictionDropdown)
    end
    restrictionHint:SetAlpha(alpha)
  end

  autoInvite:SetScript("OnClick", function(self)
    local db = GetDB()
    local enabled = self:GetChecked() and true or false
    db.autoInviteOnWhisper = enabled
    SetSubControlsEnabled(enabled)
  end)
  autoInvite:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["AUTO_INVITE_ON_WHISPER"] or "Auto-invite to party on whisper", 1, 1, 0)
    GameTooltip:AddLine(L["AUTO_INVITE_ON_WHISPER_DESC"] or "Automatically invites players who whisper your chosen keyword.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  autoInvite:SetScript("OnLeave", GameTooltip_Hide)

  keywordLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  keywordLabel:SetPoint("TOPLEFT", autoInvite, "BOTTOMLEFT", 30, -10)
  keywordLabel:SetText(L["AUTO_INVITE_KEYWORD"] or "Whisper keyword")

  keywordBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
  keywordBox:SetSize(160, 30)
  keywordBox:SetAutoFocus(false)
  keywordBox:SetPoint("TOPLEFT", keywordLabel, "BOTTOMLEFT", 0, 0)
  keywordBox:SetMaxLetters(50)
  keywordBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
  end)
  keywordBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)
  keywordBox:SetScript("OnEditFocusLost", function(self)
    local db = GetDB()
    local value = self:GetText() or ""
    value = value:match("^%s*(.-)%s*$") or ""
    if value == "" then
      value = "inv, invite, 123"
    end
    db.autoInviteKeyword = value
    self:SetText(value)
  end)
  keywordBox:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["AUTO_INVITE_KEYWORD"] or "Whisper keyword", 1, 1, 0)
    GameTooltip:AddLine(L["AUTO_INVITE_KEYWORD_DESC"] or "Players must whisper one of the configured words. Separate multiple entries with commas.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  keywordBox:SetScript("OnLeave", GameTooltip_Hide)

  hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  hint:SetPoint("TOPLEFT", keywordBox, "BOTTOMLEFT", 0, 0)
  hint:SetText(L["AUTO_INVITE_KEYWORD_HINT"] or "Example: inv, invite, 123")

  restrictionLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  restrictionLabel:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -18)
  restrictionLabel:SetText(L["AUTO_INVITE_RESTRICTION"] or "Invite restriction")

  restrictionDropdown = CreateFrame("Frame", nil, panel, "UIDropDownMenuTemplate")
  restrictionDropdown:SetPoint("TOPLEFT", restrictionLabel, "BOTTOMLEFT", -18, -4)
  UIDropDownMenu_SetWidth(restrictionDropdown, 180)
  UIDropDownMenu_Initialize(restrictionDropdown, function()
    local info = UIDropDownMenu_CreateInfo()
    info.notCheckable = true

    local function AddChoice(value)
      info.text = GetRestrictionLabel(value)
      info.arg1 = value
      info.func = function(_, arg1)
        local db = GetDB()
        db.autoInviteRestriction = arg1
        UIDropDownMenu_SetText(restrictionDropdown, GetRestrictionLabel(arg1))
      end
      UIDropDownMenu_AddButton(info)
    end

    AddChoice(RESTRICT_ANYONE)
    AddChoice(RESTRICT_FRIENDS)
    AddChoice(RESTRICT_GUILD)
    AddChoice(RESTRICT_FRIENDS_OR_GUILD)
  end)
  restrictionDropdown:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["AUTO_INVITE_RESTRICTION"] or "Invite restriction", 1, 1, 0)
    GameTooltip:AddLine(L["AUTO_INVITE_RESTRICTION_DESC"] or "Choose who can trigger auto-invite with the whisper keyword. Battle.net whispers count as friends, except for Guild-only mode.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  restrictionDropdown:SetScript("OnLeave", GameTooltip_Hide)

  restrictionHint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  restrictionHint:SetPoint("TOPLEFT", restrictionDropdown, "BOTTOMLEFT", 16, 0)
  restrictionHint:SetText(L["AUTO_INVITE_RESTRICTION_HINT"] or "Set to Anyone, Friends only, Guild members only, or Friends & Guild. Battle.net whispers count as friends.")

  panel:SetScript("OnShow", function()
    local db = GetDB()
    local enabled = db.autoInviteOnWhisper == true
    autoInvite:SetChecked(enabled)
    keywordBox:SetText(db.autoInviteKeyword or "inv, invite, 123")
    UIDropDownMenu_SetText(restrictionDropdown, GetRestrictionLabel(db.autoInviteRestriction or RESTRICT_ANYONE))
    SetSubControlsEnabled(enabled)
  end)

  widgets.autoInviteCheckbox = autoInvite
  widgets.keywordBox = keywordBox
  widgets.restrictionDropdown = restrictionDropdown

  return panel
end

function addon.DT_QOL_UpdateRegistration() end
