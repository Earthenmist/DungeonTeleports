local addonName, addon = ...
local constants = addon.constants
local L = addon.L

addon.version = "Unknown"

-- Event frame to get version
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        if _G.GetAddOnMetadata then
            addon.version = _G.GetAddOnMetadata(addonName, "Version") or "Unknown"
        elseif C_AddOns and C_AddOns.GetAddOnMetadata then
            addon.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "Unknown"
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
mainFrame:SetSize(275, 600)
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
closeButton:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -15, -15)
closeButton:SetScript("OnClick", function()
    mainFrame:Hide()
    DungeonTeleportsDB.isVisible = false
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

-- Initialize the dropdown before setting the OnShow script
UIDropDownMenu_Initialize(
    dropdown,
    function(self, level, menuList)
        local info = UIDropDownMenu_CreateInfo()
        for _, expansion in ipairs(constants.orderedExpansions) do
            info.text = L[expansion] or expansion
            info.arg1 = expansion
            info.func = OnExpansionSelected
            UIDropDownMenu_AddButton(info)
        end
    end
)

-- Now set the OnShow script AFTER dropdown is ready
mainFrame:SetScript(
    "OnShow",
    function()
        local defaultExpansion = DungeonTeleportsDB.defaultExpansion or L["Current Season"]

        -- Only set text if dropdown exists
        if dropdown then
            UIDropDownMenu_SetText(dropdown, defaultExpansion)
        else
            print("Dropdown not initialized!")
        end

        createTeleportButtons(defaultExpansion)
        C_Timer.After(
            0.5,
            function()
                addon.updateBackground(DungeonTeleportsDB.defaultExpansion or L["Current Season"])
            end
        )
    end
)

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

    local mapIDs = constants.mapExpansionToMapID[selectedExpansion]
    if not mapIDs then
        return
    end

    local index = 0
    local buttonHeight = 50 -- Height per button (including padding)
    local topPadding = 20 -- Padding at the top (dropdown + title space)
    local bottomPadding = 140 -- Padding at the bottom

    for _, mapID in ipairs(mapIDs) do
        local spellID = constants.mapIDtoSpellID[mapID]
        local dungeonName = constants.mapIDtoDungeonName[mapID] or "Unknown Dungeon"

        if spellID then
            local button =
                CreateFrame("Button", "DungeonTeleportButton" .. mapID, mainFrame, "SecureActionButtonTemplate")
            button:SetSize(40, 40)
            button:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 20, -(index * buttonHeight + topPadding))

            -- Button icon
            local texture = button:CreateTexture(nil, "BACKGROUND")
            texture:SetAllPoints(button)
            texture:SetTexture(C_Spell.GetSpellTexture(spellID))

            -- Cooldown overlay (created but conditionally shown)
            local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
            cooldown:SetAllPoints(button)
            cooldown:SetFrameStrata("HIGH")
            cooldown:SetDrawEdge(true)
            cooldown:SetDrawBling(false)
            cooldown:SetSwipeColor(0, 0, 0, 0.8)

            -- Dungeon name text
            local nameText = DungeonTeleportsMainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            nameText:SetPoint("LEFT", button, "RIGHT", 10, 0)
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
                    local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
                    if cooldownInfo and cooldownInfo.isEnabled and cooldownInfo.duration > 0 then
                        cooldown:SetCooldown(cooldownInfo.startTime, cooldownInfo.duration, cooldownInfo.modRate or 1)
                        cooldown:Show()
                    else
                        cooldown:Hide()
                    end
                end

                -- Register cooldown update events only if the spell is known
                button:RegisterEvent("SPELL_UPDATE_COOLDOWN")
                button:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
                button:RegisterEvent("PLAYER_ENTERING_WORLD")
                button:SetScript(
                    "OnEvent",
                    function(self, event)
                        UpdateCooldown()
                    end
                )

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
            button:SetScript(
                "OnEnter",
                function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetSpellByID(spellID)

                    -- Function to update the tooltip in real-time
                    local function updateTooltip()
                        GameTooltip:ClearLines()
                        GameTooltip:SetSpellByID(spellID)

                        if IsSpellKnown(spellID) then
                            local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
                            if cooldownInfo and cooldownInfo.isEnabled and cooldownInfo.duration > 0 then
                                local remaining = (cooldownInfo.startTime + cooldownInfo.duration) - GetTime()
                                GameTooltip:AddLine(L["COOLDOWN_NOT_READY"], 1, 0, 0)
                                GameTooltip:AddLine("Cooldown: " .. SecondsToTime(remaining), 1, 0, 0)
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
                    self:SetScript(
                        "OnUpdate",
                        function()
                            updateTooltip()
                        end
                    )
                end
            )

            -- Stop updating tooltip when mouse leaves
            button:SetScript(
                "OnLeave",
                function(self)
                    self:SetScript("OnUpdate", nil) -- Stop updating tooltip
                    GameTooltip:Hide()
                end
            )

            createdButtons[mapID] = button
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

-- Dropdown selection handler
local function OnExpansionSelected(self, arg1)
    UIDropDownMenu_SetText(dropdown, arg1)
    DungeonTeleportsDB.lastExpansion = arg1 -- Save selection

    -- Ensure Background Resets Correctly
    addon.updateBackground(arg1)
    createTeleportButtons(arg1)
end

-- Initialise dropdown
UIDropDownMenu_Initialize(
    dropdown,
    function(self, level, menuList)
        local info = UIDropDownMenu_CreateInfo()
        for _, expansion in ipairs(constants.orderedExpansions) do
            info.text = expansion
            info.arg1 = expansion
            info.func = OnExpansionSelected
            UIDropDownMenu_AddButton(info)
        end
    end
)

SetFactionSpecificSpells() -- Set faction-specific spell IDs

-- Load default expansion on login
DungeonTeleports:RegisterEvent("PLAYER_LOGIN")
DungeonTeleports:SetScript(
    "OnEvent",
    function()
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
    end
)

-- Slash command to toggle the frame
SLASH_DUNGEONTELEPORTS1 = "/dungeonteleports"
SLASH_DUNGEONTELEPORTS2 = "/dtp"
SlashCmdList["DUNGEONTELEPORTS"] = function()
    if DungeonTeleportsMainFrame:IsShown() then
        DungeonTeleportsMainFrame:Hide()
        DungeonTeleportsDB.isVisible = false
    else
        DungeonTeleportsMainFrame:Show()
        DungeonTeleportsDB.isVisible = true

        -- Use stored default expansion or fallback to "Current Season"
        local defaultExpansion = DungeonTeleportsDB.defaultExpansion or L["Current Season"]

        UIDropDownMenu_SetText(dropdown, defaultExpansion)
        createTeleportButtons(defaultExpansion)
        C_Timer.After(
            0.5,
            function()
                addon.updateBackground(DungeonTeleportsDB.defaultExpansion or L["Current Season"])
            end
        )
    end
end
