local addonName, addon = ...
local constants = addon.constants
local L = addon.L

addon.version = "Unknown" -- Default if retrieval fails

-- Event frame to retrieve version at the right time
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

-- Ensure both buttons and texts are tracked for clearing
local createdButtons = {}
local createdTexts = {}

-- Create the main moveable frame
local mainFrame = CreateFrame("Frame", "DungeonTeleportsMainFrame", UIParent, "BackdropTemplate")
mainFrame:SetSize(275, 600)
mainFrame:SetPoint("CENTER")
mainFrame:SetBackdrop(
    {
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    }
)
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)

-- Register the frame to close with the Escape key
tinsert(UISpecialFrames, "DungeonTeleportsMainFrame")

-- Add title
local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
title:SetPoint("TOP", mainFrame, "TOP", 0, -10)
title:SetText(L["ADDON_TITLE"])
title:SetTextColor(1, 1, 0) -- Yellow title

-- Close button
local closeButton = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
closeButton:SetSize(24, 24)
closeButton:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -5, -5)
closeButton:SetScript(
    "OnClick",
    function()
        mainFrame:Hide()
        DungeonTeleportsDB.isVisible = false
    end
)

-- Add background texture to the frame
local backgroundTexture = mainFrame:CreateTexture(nil, "BACKGROUND")
backgroundTexture:SetAllPoints(mainFrame)
backgroundTexture:SetColorTexture(0, 0, 0, 1) -- Default semi-transparent background

-- Dropdown Menu for Expansions
local dropdown = CreateFrame("Frame", "DungeonTeleportsDropdown", mainFrame, "UIDropDownMenuTemplate")
dropdown:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -30)
UIDropDownMenu_SetWidth(dropdown, 200)
UIDropDownMenu_SetText(dropdown, L["SELECT_EXPANSION"])

-- Function to update the background when switching expansions
function addon.updateBackground(selectedExpansion)
    -- Ensure backgroundTexture exists
    if not DungeonTeleportsMainFrame.backgroundTexture then
        DungeonTeleportsMainFrame.backgroundTexture = DungeonTeleportsMainFrame:CreateTexture(nil, "BACKGROUND")
        DungeonTeleportsMainFrame.backgroundTexture:SetAllPoints(DungeonTeleportsMainFrame)
    end

    local background = DungeonTeleportsMainFrame.backgroundTexture
    local alpha = DungeonTeleportsDB.backgroundAlpha or 0.7
    local bgPath = addon.constants.mapExpansionToBackground[selectedExpansion]

    -- **Step 1: Check if Backgrounds are Disabled**
    if DungeonTeleportsDB.disableBackground then
        background:SetTexture(nil) -- Remove any image texture
        background:SetColorTexture(0, 0, 0, alpha) -- Ensure solid black background with correct opacity
        return -- Stop further execution
    end

    -- **Step 2: Load Correct Background**
    if bgPath then
        background:SetTexture(bgPath)
    else
        background:SetTexture(nil)
        background:SetColorTexture(0, 0, 0, alpha) -- Fallback solid color
    end

    -- **Step 3: Ensure the Background Stays Visible**
    C_Timer.After(
        0.1,
        function()
            if background:GetTexture() == bgPath or not bgPath then
                background:SetAlpha(alpha) -- Apply correct transparency
            end
        end
    )
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
    local bottomPadding = 100 -- Padding at the bottom

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
