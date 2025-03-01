local addonName, addon = ...
local L = addon.L
local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

local function ToggleDungeonTeleportsFrame()
    if not DungeonTeleportsMainFrame then
        print(L["NOT_INITIALIZED_MAIN"])
        return
    end

    if DungeonTeleportsMainFrame:IsShown() then
        DungeonTeleportsMainFrame:Hide()
        DungeonTeleportsDB.isVisible = false
    else
        DungeonTeleportsMainFrame:Show()
        DungeonTeleportsDB.isVisible = true
    end
end

local function ToggleConfigFrame()
    if not DungeonTeleportsConfigFrame then
        print(L["NOT_INITIALIZED_CONFIG"])
        return
    end

    if DungeonTeleportsConfigFrame:IsShown() then
        DungeonTeleportsConfigFrame:Hide()
    else
        DungeonTeleportsConfigFrame:Show()
    end
end

local minimapButton = LDB:NewDataObject("DungeonTeleports", {
    type = "data source",
    text = L["ADDON_TITLE"],
    icon = "Interface\\ICONS\\inv_spell_arcane_telepotdornogal",
    OnClick = function(_, button)
        if button == "LeftButton" then
            ToggleDungeonTeleportsFrame()
        elseif button == "RightButton" then
            ToggleConfigFrame()
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine(L["ADDON_TITLE"])
        tooltip:AddLine(L["|cFFFFFF00Left Click:|r Open Teleports"])
        tooltip:AddLine(L["|cFFFFFF00Right Click:|r Open Settings"])
    end,
})

-- Register minimap button
local MinimapHandler = CreateFrame("Frame")
MinimapHandler:RegisterEvent("PLAYER_LOGIN")
MinimapHandler:SetScript("OnEvent", function()
    DungeonTeleportsDB = DungeonTeleportsDB or {}
    DungeonTeleportsDB.minimap = DungeonTeleportsDB.minimap or {}

    LDBIcon:Register("DungeonTeleports", minimapButton, DungeonTeleportsDB.minimap)

    -- Ensure the frame isn't shown unless it was open before logout
    if DungeonTeleportsDB.isVisible and DungeonTeleportsMainFrame then
        DungeonTeleportsMainFrame:Show()
    else
        DungeonTeleportsMainFrame:Hide()
    end
end)
