
include("AutoMapPins_Constants")

function GetWonderForPlot(pinName, plotID)
    local building = GameInfo.Buildings[pinName]
    if building ~= nil then
        if (
            building.IsWonder or
            building.Index == DIPLOMATIC_INDEX
        ) then
            return plotID
        end
    end
    return nil
end

function GetCityCenterForPlot(pinName, plotID)
    if pinName == "DISTRICT_CITY_CENTER" then
        return plotID
    end
    local plot = Map.GetPlotByIndex(plotID)
    if plot:IsCity() then
        return plotID
    end
    return nil
end

function MatchCityCenterAndWonderPins(playerID, iX, iY, checkFunction)
    local config = PlayerConfigurations[playerID]
    if config == nil then
        return
    end

    local pinsByPlot = {}
    local pins = config:GetMapPins()
    for _, pin in pairs(pins) do
        local x = pin:GetHexX()
        local y = pin:GetHexY()
        local distance = Map.GetPlotDistance(x, y, iX, iY)
        if distance <= 3 then
            local plot = Map.GetPlot(x, y)
            local plotID = plot:GetIndex()
            local pinName = pin:GetIconName():gsub("^ICON_", "")
            pinsByPlot[plotID] = pinName
        end
    end

    local radiusPlots = Map.GetNeighborPlots(iX, iY, 3)
    for i = 1, #radiusPlots do
        local plot = radiusPlots[i]
        local plotID = plot:GetIndex()
        local pinName = pinsByPlot[plotID]
        local value = checkFunction(pinName, plotID)
        if value then
            return value
        end
    end
    return nil
end

function GetValidTerrainsForDistrict(districtType)
    local validTerrains = {}
    local districtInfo = GameInfo.Districts[districtType]
    if #districtInfo.ValidTerrains == 0 then
        return validTerrains
    end
    for i = 1, #districtInfo.ValidTerrains do
        local terrain = districtInfo.ValidTerrains[i]
        local index = GameInfo.Terrains[terrain.TerrainType].Index
        validTerrains[index] = true
    end
    return validTerrains
end

function GetRequiredFeaturesForDistrict(districtType)
    local requiredFeatures = {}
    local districtInfo = GameInfo.Districts[districtType]
    if #districtInfo.RequiredFeatures == 0 then
        return requiredFeatures
    end
    for i = 1, #districtInfo.RequiredFeatures do
        local feature = districtInfo.RequiredFeatures[i]
        local index = GameInfo.Features[feature.FeatureType].Index
        requiredFeatures[index] = true
    end
    return requiredFeatures
end

function AddPin(playerID, pinName, plotID)
    local config = PlayerConfigurations[playerID]
    local plot = Map.GetPlotByIndex(plotID)
    local x = plot:GetX()
    local y = plot:GetY()
    local pin = config:GetMapPin(x, y)
    pin:SetIconName(pinName)
    Network.BroadcastPlayerInfo()
    LuaEvents.MapPinPopup_OnAdd(playerID, pin:GetID(), pinName, x, y)
    return pin
end

function RemovePin(playerID, pinID)
    local config = PlayerConfigurations[playerID]
    local pins = config:GetMapPins()
    local pin = pins[pinID]
    local iconName = pin:GetIconName()
    local iX = pin:GetHexX()
    local iY = pin:GetHexY()
    PlayerConfigurations[playerID]:DeleteMapPin(pinID)
    Network.BroadcastPlayerInfo()
    LuaEvents.MapPinPopup_OnDelete(playerID, pinID, iconName, iX, iY)
end

print("=== Auto Map Pins (Helpers) Loaded ===")
