-- AutoCollectAppearance v5.1 - Ascension
-- Automatically accepts the transmog/appearance collection confirmation popup for Ascension by Ashi-Ryu

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

print("|cFF00FF00AutoCollectAppearance loaded v5.1 - will auto-accept appearance collection popups.|r")
