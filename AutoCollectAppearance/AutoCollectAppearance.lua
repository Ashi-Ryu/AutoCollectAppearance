-- AutoCollectAppearance v6.0 - Ascension
-- Automatically accepts the transmog/appearance collection confirmation popup for Ascension by Ashi-Ryu
-- Added: Floating clickable button to Bulk collect appearances from bags
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
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

-- Create action-button-like border for icon mode
local border = button:CreateTexture(nil, "BACKGROUND")
border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
border:SetBlendMode("ADD")
border:SetAlpha(0.5)
border:SetAllPoints(button)
button.border = border
border:Hide()

-- Create icon texture
local icon = button:CreateTexture(nil, "ARTWORK")
icon:SetAllPoints(button)
icon:SetTexture("Interface\\Icons\\Spell_ChargePositive")
icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)  -- Crop icon edges for better look
button.icon = icon
icon:Hide()  -- Hidden by default

-- Create count text overlay
local countText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
countText:SetPoint("CENTER", button, "CENTER", 0, 0)
countText:SetTextColor(0, 0, 0, 1)
countText:SetShadowOffset(1, -1)
countText:SetShadowColor(1, 1, 1, 0.8)
button.countText = countText
countText:Hide()

-- Store button template textures for toggling
button.templateTextures = {
    button:GetNormalTexture(),
    button:GetPushedTexture(),
    button:GetHighlightTexture(),
    button:GetDisabledTexture()
}

-- Function to count uncollected appearances in bags
local function CountUncollectedAppearances()
    local count = 0
    local c = C_AppearanceCollection
    for b = 0, 4 do
        for s = 1, GetContainerNumSlots(b) do
            local itemID = GetContainerItemID(b, s)
            if itemID then
                local appearanceID = C_Appearance.GetItemAppearanceID(itemID)
                if appearanceID and not c.IsAppearanceCollected(appearanceID) then
                    count = count + 1
                end
            end
        end
    end
    return count
end

-- Function to update button text/count
local function UpdateButtonDisplay()
    local count = CountUncollectedAppearances(not DB.addUnbound)
    
    -- Hide button if count is zero and hideWhenZero is enabled
    if DB.hideWhenZero and count == 0 then
        button:Hide()
        return
    else
        button:Show()
    end
    
    if DB.useIcon then
        -- Icon mode: show count on icon only if > 0
        if count > 0 then
            button.countText:SetText(count)
            button.countText:Show()
        else
            button.countText:Hide()
        end
    else
        -- Text mode: always show count
        button:SetText(DB.text .. " (" .. count .. ")")
        button.countText:Hide()
    end
end

-- Tooltip
button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(ADDON_NAME, 1, 1, 1)
    if DB.addUnbound then
        GameTooltip:AddLine("Left-click: Add all appearances to collection", 0.2, 1, 0.2)
    else
        GameTooltip:AddLine("Left-click: Add bound item appearances", 0.2, 1, 0.2)
    end
    GameTooltip:AddLine("Shift-click: Add all including unbound items", 1, 0.82, 0)
    GameTooltip:AddLine("Left-click and drag: Move button", 0.5, 0.5, 1)
    GameTooltip:AddLine("Right-click: Open settings", 0.5, 0.5, 1)
    GameTooltip:Show()
end)

button:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

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
        local forceAll = IsShiftKeyDown()
        local c = C_AppearanceCollection
        local collected = 0
        local skipped = 0
        
        for b = 0, 4 do
            for s = 1, GetContainerNumSlots(b) do
                local itemID = GetContainerItemID(b, s)
                if itemID then
                    local appearanceID = C_Appearance.GetItemAppearanceID(itemID)
                    if appearanceID and not c.IsAppearanceCollected(appearanceID) then
                        -- Check if we should skip unbound items
                        local shouldCollect = true
                        if not DB.addUnbound and not forceAll then
                        local tooltip = CreateFrame("GameTooltip", "ACA_CollectTooltip" .. b .. s, nil, "GameTooltipTemplate")
                        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
                        tooltip:SetBagItem(b, s)
                        local isBound = false
                        for i = 1, tooltip:NumLines() do
                            local line = _G["ACA_CollectTooltip" .. b .. s .. "TextLeft" .. i]
                            if line then
                                local text = line:GetText()
                                if text and (string.find(text, "Soulbound") or string.find(text, "Bound to")) then
                                    isBound = true
                                    break
                                end
                            end
                        end
                        tooltip:Hide()
                        shouldCollect = isBound
                    end
                    
                        if shouldCollect then
                            c.CollectItemAppearance(GetContainerItemGUID(b, s))
                            collected = collected + 1
                        else
                            skipped = skipped + 1
                        end
                    end
                end
            end
        end
        
        if collected > 0 then
            print("|cFF00FF00" .. ADDON_NAME .. ": Collected " .. collected .. " appearance(s)!|r")
        end
        if skipped > 0 then
            print("|cFFFFFF00" .. ADDON_NAME .. ": " .. skipped .. " unbound item(s) not added.|r")
        end
        if collected == 0 and skipped == 0 then
            print("|cFFFFFF00" .. ADDON_NAME .. ": No uncollected appearances found in bags.|r")
        end
        -- Update counter to reflect collections
        UpdateButtonDisplay()
    elseif btn == "RightButton" then
        -- Open settings panel
        InterfaceOptionsFrame_OpenToCategory("AutoCollectAppearance")
        InterfaceOptionsFrame_OpenToCategory("AutoCollectAppearance")  -- Called twice to fix Blizzard bug
    end
end)

-- Event frame for bag updates and appearance collection
local bagUpdateFrame = CreateFrame("Frame")
bagUpdateFrame:RegisterEvent("BAG_UPDATE")
bagUpdateFrame:RegisterEvent("APPEARANCE_COLLECTED")
bagUpdateFrame:SetScript("OnEvent", function(self, event)
    -- Small delay to allow item data to load
    C_Timer.After(0.1, UpdateButtonDisplay)
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
        DB.useIcon = DB.useIcon or false  -- Default to text mode
        DB.hideWhenZero = DB.hideWhenZero or false  -- Default to always show
        DB.addUnbound = DB.addUnbound ~= false  -- Default to true (will bind items)
        DB.position = DB.position or { point = "CENTER", relativeToName = "UIParent", relativePoint = "CENTER", xOfs = 0, yOfs = 0 }

        -- Apply settings to button
        button:ClearAllPoints()
        button:SetPoint(DB.position.point, DB.position.relativeToName, DB.position.relativePoint, DB.position.xOfs, DB.position.yOfs)
        button:SetScale(DB.scale)
        
        -- Apply icon or text mode
        if DB.useIcon then
            button:SetSize(40, 40)  -- Square for icon
            button:SetText("")
            button.icon:Show()
            button.border:Show()
            -- Hide button template textures to show icon cleanly
            for _, tex in pairs(button.templateTextures) do
                if tex then tex:Hide() end
            end
        else
            button:SetSize(140, 30)  -- Wider rectangle for text + count
            button:SetText(DB.text)
            button.icon:Hide()
            button.border:Hide()
            -- Restore button template textures
            for _, tex in pairs(button.templateTextures) do
                if tex then tex:Show() end
            end
        end
        
        -- Initial count update
        UpdateButtonDisplay()

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

        -- Icon Mode Checkbox
        local checkbox = CreateFrame("CheckButton", "ACA_IconCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -16)
        _G[checkbox:GetName() .. "Text"]:SetText("Use Icon Instead of Text")
        checkbox:SetChecked(DB.useIcon)
        checkbox:SetScript("OnClick", function(self)
            DB.useIcon = self:GetChecked()
            if DB.useIcon then
                button:SetSize(40, 40)  -- Square for icon
                button:SetText("")
                button.icon:Show()
                button.border:Show()
                -- Hide button template textures to show icon cleanly
                for _, tex in pairs(button.templateTextures) do
                    if tex then tex:Hide() end
                end
            else
                button:SetSize(140, 30)  -- Wider rectangle for text + count
                button:SetText(DB.text)
                button.icon:Hide()
                button.border:Hide()
                -- Restore button template textures
                for _, tex in pairs(button.templateTextures) do
                    if tex then tex:Show() end
                end
            end
            UpdateButtonDisplay()
        end)

        -- Hide When Zero Checkbox
        local hideCheckbox = CreateFrame("CheckButton", "ACA_HideCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
        hideCheckbox:SetPoint("TOPLEFT", checkbox, "BOTTOMLEFT", 0, -8)
        _G[hideCheckbox:GetName() .. "Text"]:SetText("Hide Button When No Uncollected Items")
        hideCheckbox:SetChecked(DB.hideWhenZero)
        hideCheckbox:SetScript("OnClick", function(self)
            DB.hideWhenZero = self:GetChecked()
            UpdateButtonDisplay()
        end)

        -- Add Unbound Items Checkbox
        local unboundCheckbox = CreateFrame("CheckButton", "ACA_UnboundCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
        unboundCheckbox:SetPoint("TOPLEFT", hideCheckbox, "BOTTOMLEFT", 0, -8)
        _G[unboundCheckbox:GetName() .. "Text"]:SetText("Always add unbound items (will bind them)")
        unboundCheckbox:SetChecked(DB.addUnbound)
        unboundCheckbox:SetScript("OnClick", function(self)
            DB.addUnbound = self:GetChecked()
            UpdateButtonDisplay()
        end)

        self:UnregisterEvent("ADDON_LOADED")
    end
end)

print("|cFF00FF00AutoCollectAppearance loaded v" .. ADDON_VERSION .. " - will auto-accept appearance collection popups and a draggable 'Collect Tmog' button, options panel, and position saving.|r")