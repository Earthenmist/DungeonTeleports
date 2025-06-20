local addonName, addon = ...
local L = addon.L
local LDBIcon = LibStub("LibDBIcon-1.0")

-- Create the polished settings frame
local ConfigFrame = CreateFrame("Frame", "DungeonTeleportsConfigFrame", UIParent, "BackdropTemplate")
ConfigFrame:SetSize(375, 300)
ConfigFrame:SetPoint("CENTER")
ConfigFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = {left = 5, right = 5, top = 5, bottom = 5}
})
ConfigFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)

-- Improved layering
ConfigFrame:SetFrameStrata("DIALOG")
ConfigFrame:SetFrameLevel(100)
ConfigFrame:SetToplevel(true)

-- Soft rounded border and shadow
if not ConfigFrame.shadow then
    ConfigFrame.shadow = CreateFrame("Frame", nil, ConfigFrame, "BackdropTemplate")
    ConfigFrame.shadow:SetPoint("TOPLEFT", -5, 5)
    ConfigFrame.shadow:SetPoint("BOTTOMRIGHT", 5, -5)
    ConfigFrame.shadow:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        edgeSize = 16,
    })
    ConfigFrame.shadow:SetBackdropBorderColor(0, 0, 0, 0.75)
end

-- Movable and keyboard responsive
ConfigFrame:SetMovable(true)
ConfigFrame:EnableMouse(true)
ConfigFrame:RegisterForDrag("LeftButton")
ConfigFrame:SetScript("OnDragStart", ConfigFrame.StartMoving)
ConfigFrame:SetScript("OnDragStop", ConfigFrame.StopMovingOrSizing)

-- Escape key closes the frame
ConfigFrame:EnableKeyboard(true)
ConfigFrame:SetPropagateKeyboardInput(false)
ConfigFrame:SetScript("OnKeyDown", function(self, key)
    if key == "ESCAPE" then
        self:Hide()
        self:SetPropagateKeyboardInput(false)
    end
end)

ConfigFrame:Hide()

-- Title
local title = ConfigFrame:CreateFontString(nil, "OVERLAY")
title:SetFontObject("GameFontHighlightLarge")
title:SetFont(select(1, title:GetFont()), 18, "OUTLINE") -- Increased size & bold outline
title:SetShadowOffset(1, -1)
title:SetShadowColor(0, 0, 0, 0.75)
title:SetPoint("TOP", ConfigFrame, "TOP", 0, -15)
title:SetText(L["CONFIG_TITLE"])
title:SetTextColor(1, 1, 0)

-- Display Addon Version in Config Window
local versionText = ConfigFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
versionText:SetPoint("BOTTOMLEFT", ConfigFrame, "BOTTOMLEFT", 15, 10) -- More padding from reset button
versionText:SetText("vLoading...")

-- Function to update version when it's available
local function UpdateVersionText()
    if addon.version and addon.version ~= "Unknown" then
        versionText:SetText("v" .. addon.version)
    else
        C_Timer.After(1, UpdateVersionText) -- Keep checking every 1 second until version is set
    end
end

-- Start checking for the correct version
UpdateVersionText()

-- Close button
local closeButton = CreateFrame("Button", nil, ConfigFrame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", ConfigFrame, "TOPRIGHT", -5, -5)
closeButton:SetScript("OnClick", function() ConfigFrame:Hide() end)


-- Minimap Checkbox
local minimapCheckbox = CreateFrame("CheckButton", nil, ConfigFrame, "ChatConfigCheckButtonTemplate")
minimapCheckbox:SetPoint("TOPLEFT", ConfigFrame, "TOPLEFT", 20, -60)
minimapCheckbox.Text:SetText(L["SHOW_MINIMAP"])
minimapCheckbox:SetScript("OnClick", function(self)
    local isHidden = not self:GetChecked()
    DungeonTeleportsDB.minimap.hidden = isHidden
    if isHidden then LDBIcon:Hide("DungeonTeleports") else LDBIcon:Show("DungeonTeleports") end
end)
minimapCheckbox:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["SHOW_MINIMAP"], 1, 1, 1)
    GameTooltip:AddLine(L["TOGGLE_MINIMAP"], 1, 1, 1, true)
    GameTooltip:Show()
end)
minimapCheckbox:SetScript("OnLeave", GameTooltip_Hide)

-- Background Checkbox
local backgroundCheckbox = CreateFrame("CheckButton", nil, ConfigFrame, "ChatConfigCheckButtonTemplate")
backgroundCheckbox:SetPoint("TOPLEFT", minimapCheckbox, "BOTTOMLEFT", 0, -20)
backgroundCheckbox.Text:SetText(L["DISABLE_BACKGROUND"])
backgroundCheckbox.tooltipText = L["DISABLE_BACKGROUND_TOOLTIP"]
backgroundCheckbox:SetScript("OnClick", function(self)
    DungeonTeleportsDB.disableBackground = self:GetChecked()
    if DungeonTeleportsMainFrame and DungeonTeleportsMainFrame:IsShown() then
        DungeonTeleportsMainFrame:Hide()
    end
end)

-- Expansion Dropdown
local expansionLabel = ConfigFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
expansionLabel:SetPoint("TOPLEFT", backgroundCheckbox, "BOTTOMLEFT", 0, -20)
expansionLabel:SetText(L["DEFAULT_EXPANSION"])

local expansionDropdown = CreateFrame("Frame", "DungeonTeleportsExpansionDropdown", ConfigFrame, "UIDropDownMenuTemplate")
expansionDropdown:SetPoint("LEFT", expansionLabel, "RIGHT", -10, -5)
UIDropDownMenu_SetWidth(expansionDropdown, 150)
UIDropDownMenu_Initialize(expansionDropdown, function()
    local info = UIDropDownMenu_CreateInfo()
    for _, exp in ipairs(addon.constants.orderedExpansions) do
        info.text = exp
        info.arg1 = exp
        info.func = function(_, arg1)
            DungeonTeleportsDB.defaultExpansion = arg1
            UIDropDownMenu_SetText(expansionDropdown, arg1)
        end
        UIDropDownMenu_AddButton(info)
    end
end)

-- Transparency Slider
local slider = CreateFrame("Slider", "DungeonTeleportsOpacitySlider", ConfigFrame, "OptionsSliderTemplate")
slider:SetPoint("TOPLEFT", expansionLabel, "BOTTOMLEFT", 0, -30)
slider:SetMinMaxValues(0, 1)
slider:SetValueStep(0.05)
slider:SetObeyStepOnDrag(true)
slider:SetWidth(200)
slider.tooltipText = L["OPACITY_TOOLTIP"]
slider:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["OPACITY_TOOLTIP"], 1, 1, 1)
    GameTooltip:AddLine(L["OPACITY_WARNING"], 1, 0, 0, true)
    GameTooltip:Show()
end)
slider:SetScript("OnLeave", GameTooltip_Hide)
slider.Text = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
slider.Text:SetPoint("TOP", slider, "BOTTOM", 0, -5)
slider.Text:SetText(L["OPACITY_SLIDER"])
slider:SetScript("OnValueChanged", function(self, value)
    DungeonTeleportsDB.backgroundAlpha = value
    if DungeonTeleportsMainFrame and DungeonTeleportsMainFrame.backgroundTexture then
        local bg = DungeonTeleportsMainFrame.backgroundTexture
        local exp = DungeonTeleportsDB.lastExpansion or L["Current Season"]
        if not addon.constants.mapExpansionToBackground[exp] then exp = L["Current Season"] end
        if DungeonTeleportsDB.disableBackground then
            bg:SetTexture(nil)
            bg:SetColorTexture(0, 0, 0, value)
        else
            local tex = addon.constants.mapExpansionToBackground[exp]
            if tex then
                bg:SetTexture(tex)
                bg:SetAlpha(value)
            else
                bg:SetTexture(nil)
                bg:SetColorTexture(0, 0, 0, value)
            end
        end
        DungeonTeleportsDB.lastExpansion = exp
    end
end)

-- Reset Button
local reset = CreateFrame("Button", nil, ConfigFrame, "UIPanelButtonTemplate")
reset:SetPoint("BOTTOM", ConfigFrame, "BOTTOM", 0, 35)
reset:SetText(L["RESET_SETTINGS"])
reset:SetWidth(reset:GetTextWidth() + 20)
reset:SetHeight(25)
reset:SetScript("OnClick", function()
    DungeonTeleportsDB = {}
    ReloadUI()
end)
reset:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["RESET_SETTINGS"], 1, 1, 1)
    GameTooltip:AddLine(L["RESET_TOOLTIP"], 1, 1, 1, true)
    GameTooltip:Show()
end)
reset:SetScript("OnLeave", GameTooltip_Hide)

-- Update UI state when shown
ConfigFrame:SetScript("OnShow", function()
    minimapCheckbox:SetChecked(not DungeonTeleportsDB.minimap.hidden)
    backgroundCheckbox:SetChecked(DungeonTeleportsDB.disableBackground or false)
    slider:SetValue(DungeonTeleportsDB.backgroundAlpha or 0.7)
    UIDropDownMenu_SetText(expansionDropdown, DungeonTeleportsDB.defaultExpansion or L["Current Season"])
end)

-- Toggle function
function ToggleConfig()
    if ConfigFrame:IsShown() then ConfigFrame:Hide() else ConfigFrame:Show() end
end

-- Slash command
SLASH_DUNGEONTELEPORTSCONFIG1 = "/dtpconfig"
SlashCmdList["DUNGEONTELEPORTSCONFIG"] = ToggleConfig
