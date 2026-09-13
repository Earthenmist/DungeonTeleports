local _, addon = ...
local L = addon.L
local Browser = {}
addon.KeystoneBrowser = Browser

local function Public(value)
  return not issecretvalue or not issecretvalue(value)
end

function Browser.State(record)
  if (record.level or 0) > 0 and (record.mapID or 0) > 0 then
    return "key"
  end
  if record.level == 0 and record.mapID == 0 then
    return "none"
  end
  return "unknown"
end

function Browser.Filter(records, options, query)
  local result = {}
  query = string.lower((query or ""):match("^%s*(.-)%s*$"))
  local minimum, maximum = tonumber(options.minLevel), tonumber(options.maxLevel)
  for _, record in ipairs(records) do
    local state = Browser.State(record)
    local name = string.lower(record.fullName or record.name or "")
    local dungeon = string.lower(record.dungeon or "")
    if
      (query == "" or name:find(query, 1, true) or dungeon:find(query, 1, true))
      and (not options.hideNoKey or state == "key")
      and (not minimum or (state == "key" and record.level >= minimum))
      and (not maximum or (state == "key" and record.level <= maximum))
    then
      result[#result + 1] = record
    end
  end
  return result
end

function Browser.Freshness(updated, now)
  if not updated or updated <= 0 then
    return L["KEYSTONE_AGE_UNKNOWN"], true
  end
  local age = math.max(0, now - updated)
  local text
  if age < 60 then
    text = L["KEYSTONE_JUST_UPDATED"]
  elseif age < 3600 then
    text = string.format(L["KEYSTONE_MINUTES_AGO"], math.floor(age / 60))
  elseif age < 86400 then
    text = string.format(L["KEYSTONE_HOURS_AGO"], math.floor(age / 3600))
  else
    text = string.format(L["KEYSTONE_DAYS_AGO"], math.floor(age / 86400))
  end
  return age >= 86400 and string.format(L["KEYSTONE_STALE"], text) or text, age >= 86400
end

local function Text(parent, font)
  local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
  text:SetJustifyH("LEFT")
  return text
end

local function DungeonIcon(mapID)
  if mapID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
    local ok, _, _, _, texture = pcall(C_ChallengeMode.GetMapUIInfo, mapID)
    if ok and Public(texture) and type(texture) == "number" then
      return texture
    end
  end
  return "Interface\\Icons\\inv_relics_hourglass"
end

local function UpdateCooldown(row)
  if InCombatLockdown() or addon._DT_mplus_suppressed then
    return
  end
  row.cooldown:Hide()
  if DungeonTeleportsDB.disableCooldownOverlay then
    return
  end
  if not row.spellID or not C_Spell or not C_Spell.GetSpellCooldown then
    return
  end
  local ok, info = pcall(C_Spell.GetSpellCooldown, row.spellID)
  if not ok or not Public(info) or type(info) ~= "table" then
    return
  end
  local start, duration, rate = info.startTime, info.duration, info.modRate
  if not Public(start) or not Public(duration) or not Public(rate) then
    return
  end
  if type(start) == "number" and type(duration) == "number" and duration > 1.5 then
    row.cooldown:SetCooldown(start, duration, type(rate) == "number" and rate or 1)
    row.cooldown:Show()
  end
end

local scopes = { "party", "guild", "characters" }
local scopeLabels =
  { party = "KEYSTONE_TAB_PARTY", guild = "KEYSTONE_TAB_GUILD", characters = "KEYSTONE_TAB_CHARACTERS" }

local function StyleTab(tab, theme, hovered)
  local colors = theme.colors
  local background = tab.selected and colors.accentDark or (hovered and colors.hover or colors.bgCard)
  theme.StylePanel(tab, background, (tab.selected or hovered) and colors.border or colors.borderSoft)
  tab.label:SetTextColor(unpack(colors.text))
  tab.activeBar:SetShown(tab.selected)
end

function Browser.Create(main, theme, callbacks)
  local self = { main = main, theme = theme, callbacks = callbacks, rows = {}, query = "" }
  setmetatable(self, { __index = Browser })
  local colors = theme.colors
  DungeonTeleportsDB.keystoneView = DungeonTeleportsDB.keystoneView or {}
  self.options = DungeonTeleportsDB.keystoneView
  if not scopeLabels[self.options.scope] then
    self.options.scope = IsInGroup() and "party" or "characters"
  end

  local toolbar = theme.CreatePanel(nil, main.content, 1)
  self.toolbar = toolbar
  toolbar:SetPoint("TOPLEFT", main.contentHeader, "BOTTOMLEFT", 0, -8)
  toolbar:SetPoint("TOPRIGHT", main.contentHeader, "BOTTOMRIGHT", 0, -8)
  toolbar:SetHeight(96)
  theme.StylePanel(toolbar, colors.bg, colors.borderSoft)
  self.tabs = {}
  for i, scope in ipairs(scopes) do
    local tab = CreateFrame("Button", nil, toolbar, "BackdropTemplate")
    tab:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    tab:SetSize(180, 28)
    tab:SetPoint("TOPLEFT", 8 + (i - 1) * 186, -6)
    tab.label = Text(tab)
    tab.label:SetPoint("LEFT", 8, 0)
    tab.label:SetPoint("RIGHT", -8, 0)
    tab.label:SetWordWrap(false)
    tab.label:SetJustifyH("CENTER")
    tab.activeBar = tab:CreateTexture(nil, "OVERLAY")
    tab.activeBar:SetColorTexture(unpack(colors.accent))
    tab.activeBar:SetPoint("BOTTOMLEFT", 1, 1)
    tab.activeBar:SetPoint("BOTTOMRIGHT", -1, 1)
    tab.activeBar:SetHeight(3)
    tab.activeBar:Hide()
    tab:SetScript("OnEnter", function(widget)
      StyleTab(widget, theme, true)
    end)
    tab:SetScript("OnLeave", function(widget)
      StyleTab(widget, theme, false)
    end)
    tab:SetScript("OnClick", function()
      self.options.scope = scope
      self.resetScroll = true
      callbacks.refresh()
    end)
    self.tabs[scope] = tab
  end

  local function edit(label, x, width, numeric, initial, changed)
    local caption = Text(toolbar, "GameFontHighlightSmall")
    caption:SetPoint("TOPLEFT", x, -42)
    caption:SetWidth(width)
    caption:SetWordWrap(false)
    caption:SetText(label)
    local box = CreateFrame("EditBox", nil, toolbar, "InputBoxTemplate")
    box:SetSize(width - 8, 24)
    box:SetPoint("TOPLEFT", x + 4, -60)
    box:SetAutoFocus(false)
    box:SetNumeric(numeric)
    box:SetMaxLetters(numeric and 3 or 80)
    box:SetText(initial or "")
    box:SetScript("OnEscapePressed", function(widget)
      widget:ClearFocus()
    end)
    box:SetScript("OnEnterPressed", function(widget)
      widget:ClearFocus()
    end)
    box:SetScript("OnTextChanged", function(widget, userInput)
      if not userInput then
        return
      end
      changed(widget:GetText())
      self.resetScroll = true
      callbacks.refresh()
    end)
    return box
  end
  self.search = edit(L["KEYSTONE_SEARCH"], 12, 226, false, "", function(value)
    self.query = value
  end)
  self.minimum = edit(L["KEYSTONE_MIN_LEVEL"], 252, 72, true, self.options.minLevel, function(value)
    self.options.minLevel = tonumber(value)
  end)
  self.maximum = edit(L["KEYSTONE_MAX_LEVEL"], 336, 72, true, self.options.maxLevel, function(value)
    self.options.maxLevel = tonumber(value)
  end)
  self.hideNoKey = CreateFrame("CheckButton", nil, toolbar, "ChatConfigCheckButtonTemplate")
  self.hideNoKey:SetPoint("TOPLEFT", 426, -60)
  self.hideNoKey.Text:SetText(L["KEYSTONE_HIDE_NO_KEY"])
  self.hideNoKey.Text:SetWidth(130)
  self.hideNoKey.Text:SetWordWrap(true)
  self.hideNoKey:SetChecked(self.options.hideNoKey == true)
  self.hideNoKey:SetScript("OnClick", function(widget)
    self.options.hideNoKey = widget:GetChecked() == true
    self.resetScroll = true
    callbacks.refresh()
  end)
  self.reset = CreateFrame("Button", nil, toolbar, "BackdropTemplate")
  theme.StyleButton(self.reset, L["KEYSTONE_RESET_FILTERS"], 24)
  self.reset:SetNormalFontObject("GameFontHighlightSmall")
  self.reset:SetSize(66, 24)
  self.reset:SetPoint("TOPRIGHT", -8, -6)
  self.reset:SetScript("OnClick", function()
    self.options.minLevel, self.options.maxLevel, self.options.hideNoKey = nil, nil, false
    self.query = ""
    self.search:SetText("")
    self.minimum:SetText("")
    self.maximum:SetText("")
    self.hideNoKey:SetChecked(false)
    self.resetScroll = true
    callbacks.refresh()
  end)

  self.header = theme.CreatePanel(nil, main.scrollChild, 1)
  self.header:SetPoint("TOPLEFT")
  self.header:SetHeight(28)
  theme.StylePanel(self.header, colors.accentDark, colors.borderSoft)
  self.columns = {}
  for _, key in ipairs({ "name", "level", "dungeon", "rating" }) do
    local button = CreateFrame("Button", nil, self.header)
    button.label = Text(button, "GameFontHighlightSmall")
    button.label:SetPoint("LEFT")
    button.label:SetPoint("RIGHT", -14, 0)
    button.label:SetWordWrap(false)
    button.arrow = button:CreateTexture(nil, "OVERLAY")
    button.arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
    button.arrow:SetSize(10, 10)
    button.arrow:SetPoint("RIGHT", -2, 0)
    button:SetScript("OnClick", function()
      callbacks.sort(key)
      callbacks.refresh()
    end)
    self.columns[key] = button
  end
  self.empty = Text(main.scrollChild)
  self.empty:SetPoint("TOPLEFT", 12, -48)
  self.empty:SetJustifyH("CENTER")
  self.empty:SetWordWrap(true)
  self.events = CreateFrame("Frame")
  self.events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
  self.events:RegisterEvent("PLAYER_REGEN_ENABLED")
  self.events:RegisterEvent("SPELLS_CHANGED")
  self.events:SetScript("OnEvent", function(_, event)
    if main:IsShown() and toolbar:IsShown() then
      if event == "SPELLS_CHANGED" then
        callbacks.refresh()
        return
      end
      for _, row in ipairs(self.rows) do
        if row:IsShown() then
          UpdateCooldown(row)
        end
      end
    end
  end)
  return self
end

function Browser:NewRow()
  local theme, colors, main = self.theme, self.theme.colors, self.main
  local row = theme.CreatePanel(nil, main.scrollChild, 1)
  theme.StylePanel(row, colors.bgCard, colors.borderSoft)
  row:SetHeight(60)
  row:EnableMouse(true)
  row.player, row.age, row.level, row.dungeon, row.rating =
    Text(row), Text(row, "GameFontHighlightSmall"), Text(row), Text(row), Text(row)
  row.player:SetWordWrap(false)
  row.age:SetWordWrap(false)
  row.dungeon:SetWordWrap(true)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(30, 30)
  row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  row.teleport = CreateFrame("Button", nil, row, "SecureActionButtonTemplate,BackdropTemplate")
  theme.StyleButton(row.teleport, "", 32)
  row.teleport:SetPoint("RIGHT", -10, 0)
  row.teleport:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
  row.teleport.icon = row.teleport:CreateTexture(nil, "ARTWORK")
  row.teleport.icon:SetPoint("TOPLEFT", 2, -2)
  row.teleport.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  row.cooldown = CreateFrame("Cooldown", nil, row.teleport, "CooldownFrameTemplate")
  row.cooldown:SetAllPoints()
  row.cooldown:SetDrawEdge(false)
  row.teleport:SetScript("OnEnter", function(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if row.spellID then
      GameTooltip:SetSpellByID(row.spellID)
    end
    GameTooltip:AddLine(L["CLICK_TO_TELEPORT"])
    GameTooltip:Show()
  end)
  row.teleport:SetScript("OnLeave", GameTooltip_Hide)
  row.teleport:SetScript("PostClick", function(_, _, down)
    if not down and row.spellID and DungeonTeleportsDB.closeOnTeleport and not InCombatLockdown() then
      main:Hide()
    end
  end)
  row:SetScript("OnEnter", function(widget)
    theme.StylePanel(widget, colors.hover, colors.border)
    GameTooltip:SetOwner(widget, "ANCHOR_RIGHT")
    local record = widget.record
    GameTooltip:AddLine(record.fullName or record.name or "")
    GameTooltip:AddLine(widget.dungeon:GetText(), 1, 1, 1, true)
    GameTooltip:AddLine(widget.age:GetText(), 1, 1, 1)
    if record.source then
      GameTooltip:AddDoubleLine(L["KEYSTONE_SOURCE"], record.source)
    end
    if record.updated and record.updated > 0 then
      GameTooltip:AddDoubleLine(L["KEYSTONE_UPDATED"], date("%d/%m %H:%M", record.updated))
    end
    if not widget.spellID and Browser.State(record) == "key" then
      GameTooltip:AddLine(L["TELEPORT_NOT_KNOWN"])
    end
    GameTooltip:AddLine(L["KEYSTONE_SHARING_NOTE"], 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", function(widget)
    theme.StylePanel(widget, colors.bgCard, colors.borderSoft)
    GameTooltip:Hide()
  end)
  return row
end

function Browser:Hide()
  if InCombatLockdown() then
    return
  end
  self.toolbar:Hide()
  self.header:Hide()
  self.empty:Hide()
  for _, row in ipairs(self.rows) do
    row:Hide()
  end
  self.main.scrollFrame:SetPoint("TOPLEFT", self.main.contentHeader, "BOTTOMLEFT", 0, -12)
end

function Browser:Render(scopedRecords)
  if InCombatLockdown() then
    return
  end
  local main, colors = self.main, self.theme.colors
  self.toolbar:Show()
  self.header:Show()
  main.scrollFrame:SetPoint("TOPLEFT", self.toolbar, "BOTTOMLEFT", 0, -8)
  local width = math.max(640, (main.scrollFrame:GetWidth() or 700) - 8)
  local playerWidth = math.floor(width * 0.27)
  local positions = { name = 12, level = playerWidth + 20, dungeon = playerWidth + 80, rating = width - 120 }
  local widths = { name = playerWidth, level = 52, dungeon = width - playerWidth - 208, rating = 66 }
  local labels =
    { name = "KEYSTONE_Player", level = "KEYSTONE_Level", dungeon = "KEYSTONE_Dungeon", rating = "KEYSTONE_Rating" }
  local sortKey, ascending = self.callbacks.getSort()
  self.header:SetWidth(width)
  for key, column in pairs(self.columns) do
    column:SetPoint("LEFT", positions[key], 0)
    column:SetSize(widths[key], 28)
    column.label:SetText(L[labels[key]])
    column.arrow:SetShown(sortKey == key)
    column.arrow:SetTexCoord(0, 1, ascending and 0 or 1, ascending and 1 or 0)
  end
  for _, scope in ipairs(scopes) do
    local tab = self.tabs[scope]
    tab.label:SetText(string.format("%s (%d)", L[scopeLabels[scope]], #scopedRecords[scope]))
    tab.selected = self.options.scope == scope
    StyleTab(tab, self.theme, false)
  end
  local all = scopedRecords[self.options.scope]
  local records = Browser.Filter(all, self.options, self.query)
  main.contentSubtitle:SetText(string.format(L["KEYSTONE_RESULTS"], #records, #all))
  local now = time()
  for _, row in ipairs(self.rows) do
    if GameTooltip and (GameTooltip:IsOwned(row) or GameTooltip:IsOwned(row.teleport)) then
      GameTooltip:Hide()
    end
  end
  for i, record in ipairs(records) do
    local row = self.rows[i]
    if not row then
      row = self:NewRow()
      self.rows[i] = row
    end
    row.record = record
    row:SetPoint("TOPLEFT", main.scrollChild, "TOPLEFT", 0, -34 - (i - 1) * 66)
    row:SetWidth(width)
    self.theme.StylePanel(row, colors.bgCard, colors.borderSoft)
    row.player:SetPoint("TOPLEFT", 12, -12)
    row.player:SetWidth(playerWidth)
    row.player:SetText(record.name or record.fullName or "")
    row.age:SetPoint("TOPLEFT", 12, -34)
    row.age:SetWidth(playerWidth)
    local age, stale = Browser.Freshness(record.updated, now)
    row.age:SetText(age)
    row.age:SetTextColor(unpack(stale and colors.warning or colors.textDim))
    row.level:SetPoint("LEFT", positions.level, 0)
    row.level:SetWidth(widths.level)
    local state = Browser.State(record)
    row.level:SetText(state == "key" and ("+" .. record.level) or "-")
    row.icon:SetPoint("LEFT", positions.dungeon, 0)
    row.icon:SetTexture(DungeonIcon(state == "key" and record.mapID or nil))
    row.dungeon:SetPoint("LEFT", positions.dungeon + 38, 0)
    row.dungeon:SetSize(widths.dungeon - 38, 44)
    row.dungeon:SetText(
      state == "key" and record.dungeon or L[state == "none" and "KEYSTONE_NO_KEY" or "KEYSTONE_NOT_RECEIVED"]
    )
    row.rating:SetPoint("LEFT", positions.rating, 0)
    row.rating:SetWidth(widths.rating)
    row.rating:SetText((record.rating or 0) > 0 and tostring(record.rating) or "-")
    local spellID = state == "key" and addon:GetKeystoneTeleportSpellID(record.mapID) or nil
    row.spellID = spellID and self.callbacks.known(spellID) and spellID or nil
    row.teleport:SetAttribute("type", row.spellID and "spell" or nil)
    row.teleport:SetAttribute("spell", row.spellID)
    row.teleport:SetShown(row.spellID ~= nil)
    if row.spellID then
      row.teleport.icon:SetTexture(C_Spell.GetSpellTexture(row.spellID))
    end
    UpdateCooldown(row)
    row:Show()
  end
  for i = #records + 1, #self.rows do
    local row = self.rows[i]
    row:Hide()
    row.record, row.spellID = nil, nil
    row.teleport:SetAttribute("type", nil)
    row.teleport:SetAttribute("spell", nil)
  end
  self.empty:SetWidth(width - 24)
  self.empty:SetShown(#records == 0)
  local emptyText = L["KEYSTONE_NO_MATCHES"]
  if #all == 0 then
    if self.options.scope == "party" then
      emptyText = L[IsInGroup() and "KEYSTONE_NO_PARTY_KEYSTONES_RECEIVED_YET" or "KEYSTONE_JOIN_PARTY"]
    elseif self.options.scope == "guild" then
      emptyText = L[IsInGuild() and "KEYSTONE_NO_GUILD_KEYSTONES_RECEIVED_YET" or "KEYSTONE_JOIN_GUILD"]
    else
      emptyText = L["KEYSTONE_NO_CHARACTER_KEYSTONES_SAVED_YET"]
    end
  end
  self.empty:SetText(emptyText)
  local height = math.max(110, 34 + #records * 66)
  main.scrollChild:SetSize(width, height)
  local scroll = self.resetScroll and 0 or main.scrollFrame:GetVerticalScroll()
  main.scrollFrame:SetVerticalScroll(math.min(scroll, math.max(0, height - main.scrollFrame:GetHeight())))
  self.resetScroll = nil
end
