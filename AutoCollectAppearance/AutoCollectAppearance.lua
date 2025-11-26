-- AutoCollectAppearance v6.0 - Ascension
-- Automatically accepts the transmog/appearance collection confirmation popup for Ascension by Ashi-Ryu
-- Added: Floating clickable button to automatically collect appearances from bags
-- Added: Options page with scale slider and text change
-- Added: Button position saving

local ADDON_NAME = "AutoCollectAppearance"
local BUTTON_NAME = "AutoCollectAppearanceButton"
local ADDON_VERSION = "6.0"
local DB

local function AcceptAppearancePopups()
    for i = 1, STATICPOPUP_NUMDIALOGS do
        local frame = _G["StaticPopup"..i]
        if frame and frame:IsShown() and frame.which then
            local text = frame.text and frame.text:GetText()
            if text and string.find(text, "Are you sure you want to collect the appearance of") then
                if frame.button1 and frame.button1:IsVisible() then
                    frame.button1:Click()
                    print("|cFF00FF00AutoCollectAppearance: Appearance collected automatically!|r")
                end
            end
        end
    end
end

-- Hook popup show and also run periodically
hooksecurefunc("StaticPopup_Show", function(name, text, ... )
    C_Timer.After(0.01, AcceptAppearancePopups)
end)

-- Run every frame to catch delayed popups
local f = CreateFrame("Frame")
f:SetScript("OnUpdate", function(_, elapsed)
    AcceptAppearancePopups()
end)

-- Create the floating clickable button first
local button = CreateFrame("Button", BUTTON_NAME, UIParent, "UIPanelButtonTemplate")
button:SetSize(120, 30)
button:SetPoint("CENTER", UIParent, "CENTER", 0, 0)  -- Default position
button:SetMovable(true)
button:EnableMouse(true)
button:RegisterForDrag("LeftButton")
button:SetScript("OnDragStart", button.StartMoving)
button:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
    DB.position = {
        point = point,
        relativeToName = relativeTo and relativeTo:GetName() or "UIParent",
        relativePoint = relativePoint,
        xOfs = xOfs,
        yOfs = yOfs
    }
end)

-- Macro logic as OnClick script
button:SetScript("OnClick", function(self, btn)
    if btn == "LeftButton" then
        local c = C_AppearanceCollection
        for b = 0, 4 do
            for s = 1, GetContainerNumSlots(b) do
                if not c.IsAppearanceCollected(C_Appearance.GetItemAppearanceID(GetContainerItemID(b, s))) then
                    c.CollectItemAppearance(GetContainerItemGUID(b, s))
                end
            end
        end
        print("|cFF00FF00" .. ADDON_NAME .. ": Automatic transmog collection from bags completed!|r")
    end
end)

-- Make the button visible on load
button:Show()

-- Event frame for ADDON_LOADED (after button creation)
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, addon)
    if event == "ADDON_LOADED" and addon == ADDON_NAME then
        AutoCollectAppearanceDB = AutoCollectAppearanceDB or {}
        DB = AutoCollectAppearanceDB
        DB.scale = DB.scale or 1.0
        DB.text = DB.text or "Collect Tmog"
        DB.position = DB.position or { point = "CENTER", relativeToName = "UIParent", relativePoint = "CENTER", xOfs = 0, yOfs = 0 }

        -- Apply settings to button
        button:ClearAllPoints()
        button:SetPoint(DB.position.point, DB.position.relativeToName, DB.position.relativePoint, DB.position.xOfs, DB.position.yOfs)
        button:SetScale(DB.scale)
        button:SetText(DB.text)

        -- Create options panel
        local panel = CreateFrame("Frame", "AutoCollectAppearanceOptions", UIParent)
        panel.name = ADDON_NAME
        InterfaceOptions_AddCategory(panel)

        -- Title
        local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText(ADDON_NAME .. " Options")

        -- Scale Slider
        local slider = CreateFrame("Slider", "ACA_ScaleSlider", panel, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -32)
        slider:SetWidth(200)
        slider:SetMinMaxValues(0.5, 2.0)
        slider:SetValueStep(0.1)
        slider:SetValue(DB.scale)
        _G[slider:GetName() .. "Low"]:SetText("0.5")
        _G[slider:GetName() .. "High"]:SetText("2.0")
        _G[slider:GetName() .. "Text"]:SetText("Button Scale")
        slider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value * 10 + 0.5) / 10  -- Round to 1 decimal place
            DB.scale = value
            button:SetScale(value)
            self.tooltipText = tostring(value)  -- Optional: Show current value in tooltip if desired
        end)

        -- Button Text EditBox
        local editLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        editLabel:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -32)
        editLabel:SetText("Button Text:")

        local edit = CreateFrame("EditBox", "ACA_TextEdit", panel, "InputBoxTemplate")
        edit:SetPoint("LEFT", editLabel, "RIGHT", 8, 0)
        edit:SetSize(150, 20)
        edit:SetAutoFocus(false)
        edit:SetText(DB.text)
        edit:SetScript("OnEnterPressed", function(self)
            local newText = self:GetText()
            if newText and newText ~= "" then
                DB.text = newText
                button:SetText(newText)
            end
            self:ClearFocus()
        end)
        edit:SetScript("OnEscapePressed", function(self)
            self:SetText(DB.text)
            self:ClearFocus()
        end)

        self:UnregisterEvent("ADDON_LOADED")
    end
end)

print("|cFF00FF00AutoCollectAppearance loaded v" .. ADDON_VERSION .. " - will auto-accept appearance collection popups and a draggable 'Collect Tmog' button, options panel, and position saving.|r")
