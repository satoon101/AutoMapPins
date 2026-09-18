-- ===========================================================================
--  Auto Map Pins - UI Script
--  Overrides MapPinPopup to call events on Ok & Delete.
-- ===========================================================================

print("=== Auto Map Pins (MapPinPopup) Loading ===")

include("MapPinPopup")

local BASE_OnOk = OnOk

function OnOk()
    BASE_OnOk()
    local editPin = GetEditPinConfig()
    local playerID = editPin:GetPlayerID()
    local pinID = editPin:GetID()
    local iconName = editPin:GetIconName()
    local iX = editPin:GetHexX()
    local iY = editPin:GetHexY()
    LuaEvents.MapPinPopup_OnAdd(playerID, pinID, iconName, iX, iY)
end

local BASE_OnDelete = OnDelete

function OnDelete()
    local editPin = GetEditPinConfig()
    local playerID = editPin:GetPlayerID()
    local pinID = editPin:GetID()
    local iconName = editPin:GetIconName()
    local iX = editPin:GetHexX()
    local iY = editPin:GetHexY()
    BASE_OnDelete()
    LuaEvents.MapPinPopup_OnDelete(playerID, pinID, iconName, iX, iY)
end

local BASE_OnMapPinPlayerInfoChanged = OnMapPinPlayerInfoChanged

function OnMapPinPlayerInfoChanged(playerID)
    -- If VisibilityPull is nil, the window is closing; don't try to update it
    if Controls.VisibilityPull ~= nil then
        BASE_OnMapPinPlayerInfoChanged(playerID)
    end
end

if Controls.OkButton then
    Controls.OkButton:RegisterCallback(Mouse.eLClick, OnOk)
end

if Controls.DeleteButton then
    Controls.DeleteButton:RegisterCallback(Mouse.eLClick, OnDelete)
end

print("=== Auto Map Pins (MapPinPopup) Loaded ===")
