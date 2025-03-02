local addonName, addon = ...
local L = addon.L
local LDBIcon = LibStub("LibDBIcon-1.0") -- Ensure LDBIcon is properly initialized

-- Create the settings frame
local ConfigFrame = CreateFrame("Frame", "DungeonTeleportsConfigFrame", UIParent, "BackdropTemplate")
ConfigFrame:SetSize(350, 280) -- Adjusted height to accommodate spacing
ConfigFrame:SetPoint("CENTER")
ConfigFrame:SetBackdrop(
    {
        bgFile = "Interface\\Buttons\\WHITE8x8", -- Use a solid texture
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = false, tileSize = 0, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    }
)

-- Allow the frame to respond to key presses
ConfigFrame:EnableKeyboard(true)
ConfigFrame:SetPropagateKeyboardInput(false) -- Prevents the escape key from affecting other UI elements

-- Register the Escape key to close the frame
ConfigFrame:SetScript("OnKeyDown", function(self, key)
    if key == "ESCAPE" then
        self:Hide()
        self:SetPropagateKeyboardInput(false) -- Stop ESC from propagating
    end
end)


-- Set dark grey background
ConfigFrame:SetBackdropColor(0.15, 0.15, 0.15, 1) -- Slightly Lighter Grey

-- Ensure full opacity
ConfigFrame:SetAlpha(1)

-- Hook into OnShow to force opacity every time it opens
ConfigFrame:HookScript("OnShow", function(self)
    self:SetAlpha(1) -- Ensure frame itself is fully visible

    -- Ensure all children (buttons, text, sliders) are fully opaque
    for _, child in ipairs({self:GetChildren()}) do
        if child and child.SetAlpha then
            child:SetAlpha(1)
        end
    end

end)

ConfigFrame:SetMovable(true)
ConfigFrame:EnableMouse(true)
ConfigFrame:RegisterForDrag("LeftButton")
ConfigFrame:SetScript("OnDragStart", ConfigFrame.StartMoving)
ConfigFrame:SetScript("OnDragStop", ConfigFrame.StopMovingOrSizing)
ConfigFrame:Hide() -- Hide by default

-- Title
ConfigFrame.title = ConfigFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
ConfigFrame.title:SetPoint("TOP", ConfigFrame, "TOP", 0, -10)
ConfigFrame.title:SetText(L["CONFIG_TITLE"])
ConfigFrame.title:SetTextColor(1, 1, 0)

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
closeButton:SetSize(24, 24)
closeButton:SetPoint("TOPRIGHT", ConfigFrame, "TOPRIGHT", -5, -5)
closeButton:SetScript(
    "OnClick",
    function()
        ConfigFrame:Hide()
    end
)

--------------------------------------
-- 🧭 **Minimap Button Toggle**
--------------------------------------
local minimapCheckbox =
    CreateFrame("CheckButton", "DungeonTeleportsMinimapCheckbox", ConfigFrame, "ChatConfigCheckButtonTemplate")
minimapCheckbox:SetPoint("TOPLEFT", ConfigFrame, "TOPLEFT", 20, -40)
minimapCheckbox.Text:SetText(L["SHOW_MINIMAP"])
minimapCheckbox:SetScript(
    "OnClick",
    function(self)
        local isHidden = not self:GetChecked()
        DungeonTeleportsDB.minimap.hidden = isHidden
        if isHidden then
            LDBIcon:Hide("DungeonTeleports")
        else
            LDBIcon:Show("DungeonTeleports")
        end
    end
)

-- Tooltip for Minimap Checkbox
minimapCheckbox:SetScript(
    "OnEnter",
    function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["SHOW_MINIMAP"], 1, 1, 1)
        GameTooltip:AddLine(L["TOGGLE_MINIMAP"], 1, 1, 1, true)
        GameTooltip:Show()
    end
)
minimapCheckbox:SetScript(
    "OnLeave",
    function()
        GameTooltip:Hide()
    end
)

--------------------------------------
-- 🖼️ **Disable Background Images**
--------------------------------------
local backgroundCheckbox =
    CreateFrame("CheckButton", "DungeonTeleportsBackgroundCheckbox", ConfigFrame, "ChatConfigCheckButtonTemplate")
backgroundCheckbox:SetPoint("TOPLEFT", minimapCheckbox, "BOTTOMLEFT", 0, -20)
backgroundCheckbox.Text:SetText(L["DISABLE_BACKGROUND"])
backgroundCheckbox.tooltipText = L["DISABLE_BACKGROUND_TOOLTIP"]

backgroundCheckbox:SetScript(
    "OnClick",
    function(self)
        local isDisabled = self:GetChecked()
        DungeonTeleportsDB.disableBackground = isDisabled

        -- Close the main frame to apply changes next time it's opened
        if DungeonTeleportsMainFrame and DungeonTeleportsMainFrame:IsShown() then
            DungeonTeleportsMainFrame:Hide()
        end
    end
)

--------------------------------------
-- 📂 **Default Expansion Dropdown**
--------------------------------------
local expansionLabel = ConfigFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
expansionLabel:SetPoint("TOPLEFT", backgroundCheckbox, "BOTTOMLEFT", 0, -20)
expansionLabel:SetText(L["DEFAULT_EXPANSION"])

local expansionDropdown =
    CreateFrame("Frame", "DungeonTeleportsExpansionDropdown", ConfigFrame, "UIDropDownMenuTemplate")
expansionDropdown:SetPoint("LEFT", expansionLabel, "RIGHT", -10, -5)
UIDropDownMenu_SetWidth(expansionDropdown, 150)
UIDropDownMenu_SetText(expansionDropdown, L["Current Season"])

UIDropDownMenu_Initialize(
    expansionDropdown,
    function(self, level, menuList)
        local info = UIDropDownMenu_CreateInfo()
        for _, expansion in ipairs(addon.constants.orderedExpansions) do
            info.text = expansion
            info.arg1 = expansion
            info.func = function(self, arg1)
                DungeonTeleportsDB.defaultExpansion = arg1
                UIDropDownMenu_SetText(expansionDropdown, arg1)
            end
            UIDropDownMenu_AddButton(info)
        end
    end
)

-- Tooltip for Expansion Dropdown
expansionDropdown:SetScript(
    "OnEnter",
    function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["DEFAULT_EXPANSION"], 1, 1, 1)
        GameTooltip:AddLine(L["SELECT_EXPANSIONCONFIG"], 1, 1, 1, true)
        GameTooltip:Show()
    end
)
expansionDropdown:SetScript(
    "OnLeave",
    function()
        GameTooltip:Hide()
    end
)

--------------------------------------
-- 🎨 **Background Transparency Slider**
--------------------------------------
local transparencySlider = CreateFrame("Slider", "DungeonTeleportsOpacitySlider", ConfigFrame, "OptionsSliderTemplate")
transparencySlider:SetPoint("TOPLEFT", expansionLabel, "BOTTOMLEFT", 0, -30)
transparencySlider:SetMinMaxValues(0, 1)
transparencySlider:SetValueStep(0.05)
transparencySlider:SetObeyStepOnDrag(true)
transparencySlider:SetWidth(200)

-- Tooltip for the slider
transparencySlider.tooltipText = L["OPACITY_TOOLTIP"]
transparencySlider:SetScript(
    "OnEnter",
    function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["OPACITY_TOOLTIP"], 1, 1, 1)
        GameTooltip:AddLine(L["OPACITY_WARNING"], 1, 0, 0, true)
        GameTooltip:Show()
    end
)
transparencySlider:SetScript(
    "OnLeave",
    function(self)
        GameTooltip:Hide()
    end
)

-- Label for slider
transparencySlider.Text = transparencySlider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
transparencySlider.Text:SetPoint("TOP", transparencySlider, "BOTTOM", 0, -5) -- Adjust position if needed
transparencySlider.Text:SetText(L["OPACITY_SLIDER"] or "Background Opacity")

transparencySlider:SetScript(
    "OnValueChanged",
    function(self, value)
        DungeonTeleportsDB.backgroundAlpha = value

        -- Ensure the main frame and background exist before applying changes
        if DungeonTeleportsMainFrame and DungeonTeleportsMainFrame.backgroundTexture then
            local background = DungeonTeleportsMainFrame.backgroundTexture

            -- Get the **current expansion that is being displayed** in the UI
            local selectedExpansion =
                DungeonTeleportsDB.lastExpansion or UIDropDownMenu_GetText(DungeonTeleportsExpansionDropdown) or
                "Current Season"

            -- Ensure the expansion exists in the backgrounds table
            if not addon.constants.mapExpansionToBackground[selectedExpansion] then
                selectedExpansion = "Current Season"
            end

            -- If backgrounds are disabled, apply solid colour instead
            if DungeonTeleportsDB.disableBackground then
                background:SetTexture(nil)
                background:SetColorTexture(0, 0, 0, value) -- Apply opacity to solid background
            else
                local bgPath = addon.constants.mapExpansionToBackground[selectedExpansion]

                if bgPath then
                    background:SetTexture(bgPath)
                    background:SetAlpha(value)
                else
                    background:SetTexture(nil)
                    background:SetColorTexture(0, 0, 0, value) -- Ensure solid background with alpha
                end
            end

            -- 🔥 **New Fix:** Save the currently displayed expansion so it persists!
            DungeonTeleportsDB.lastExpansion = selectedExpansion
        end
    end
)

--------------------------------------
-- 🔄 **Reset Button**
--------------------------------------
local resetButton = CreateFrame("Button", nil, ConfigFrame, "UIPanelButtonTemplate")
resetButton:SetPoint("BOTTOM", ConfigFrame, "BOTTOM", 0, 35)
resetButton:SetText(L["RESET_SETTINGS"])
resetButton:SetWidth(resetButton:GetTextWidth() + 20) -- Dynamically adjust width
resetButton:SetHeight(25)
resetButton:SetScript(
    "OnClick",
    function()
        DungeonTeleportsDB = {}
        ReloadUI()
    end
)

-- Tooltip for Reset Button
resetButton:SetScript(
    "OnEnter",
    function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["RESET_SETTINGS"], 1, 1, 1)
        GameTooltip:AddLine(L["RESET_TOOLTIP"], 1, 1, 1, true)
        GameTooltip:Show()
    end
)
resetButton:SetScript(
    "OnLeave",
    function()
        GameTooltip:Hide()
    end
)

--------------------------------------
-- 🔄 **Update UI on Show**
--------------------------------------
ConfigFrame:SetScript(
    "OnShow",
    function()
        minimapCheckbox:SetChecked(not DungeonTeleportsDB.minimap.hidden)
        backgroundCheckbox:SetChecked(DungeonTeleportsDB.disableBackground or false)
        transparencySlider:SetValue(DungeonTeleportsDB.backgroundAlpha or 0.7)
        UIDropDownMenu_SetText(expansionDropdown, DungeonTeleportsDB.defaultExpansion or L["Current Season"])
    end
)

--------------------------------------
-- ⚙️ **Function to toggle the config window**
--------------------------------------
function ToggleConfig()
    if ConfigFrame:IsShown() then
        ConfigFrame:Hide()
    else
        ConfigFrame:ClearAllPoints()
        ConfigFrame:SetPoint("CENTER", UIParent, "CENTER") -- Always open in center
        ConfigFrame:Show()
    end
end

--------------------------------------
-- 🔣 **Slash command to open config**
--------------------------------------
SLASH_DUNGEONTELEPORTSCONFIG1 = "/dtpconfig"
SlashCmdList["DUNGEONTELEPORTSCONFIG"] = function()
    ToggleConfig()
end
