
include("AutoMapPins_Constants")

function GetRiverHasDam(playerID, riverName)
    local rivers = RiverManager.EnumerateRivers()
    local plotsMarkedForDam = GetPlotsMarkedForDam(playerID)
    for i1 = 1, #rivers do
        local river = rivers[i1]
        if river.Name == riverName then
            for i2 = 1, #river.Edges do
                local edge = river.Edges[i2]
                for i3 = 1, #edge do
                    local plotID = edge[i3]
                    local plot = Map.GetPlotByIndex(plotID)
                    if (
                        plot:GetDistrictType() == DAM_INDEX
                        or plotsMarkedForDam[plotID] ~= nil
                    ) then
                        return true
                    end
                end
            end
        end
    end
end

function GetPlotsMarkedForDam(playerID)
    local plotsMarkedForDam = {}
    local config = PlayerConfigurations[playerID]
    if config == nil then
        return plotsMarkedForDam
    end

    local pins = config:GetMapPins()
    if pins == nil or #pins == 0 then
        return plotsMarkedForDam
    end

    for i = 1, #pins do
        local pin = pins[i]
        local pinName = pin:GetIconName():gsub("^ICON_", "")
        if pinName == "DISTRICT_DAM" then
            local plot = Map.GetPlot(pin:GetHexX(), pin:GetHexY())
            plotsMarkedForDam[plot:GetIndex()] = true
        end
    end
    return plotsMarkedForDam
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
    PlayerConfigurations[playerID]:DeleteMapPin(pinID)
    Network.BroadcastPlayerInfo()
end
