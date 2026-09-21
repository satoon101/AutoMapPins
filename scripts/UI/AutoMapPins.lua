-- ===========================================================================
--  Auto Map Pins - UI Script
--  Provides Auto Map Pins UI scripts.
-- ===========================================================================

print("=== Auto Map Pins (UI) Loading ===")

include("AutoMapPins_Managers")

FinishedInitialization = false

function AddMapPinsForCityCenter(playerID, pinID, iconName, iX, iY)
    local config = PlayerConfigurations[playerID]
    if config == nil then
        return
    end

    local cityCenterPlotID = nil
    local cityWonderPlotID = nil
    local cityWonder = nil
    iconName = iconName:gsub("^ICON_", "")
    if iconName == "DISTRICT_CITY_CENTER" then
        cityCenterPlotID = Map.GetPlot(iX, iY):GetIndex()
        cityWonder, cityWonderPlotID = MatchCityCenterAndWonderPins(
            playerID, iX, iY, GetWonderForPlot
        )
        local cityWonderPlot = Map.GetPlotByIndex(cityWonderPlotID)
        local x = cityWonderPlot:GetX()
        local y = cityWonderPlot:GetY()
    end

    if iconName == "DISTRICT_DIPLOMATIC_QUARTER" then
        _, cityCenterPlotID = MatchCityCenterAndWonderPins(
            playerID, iX, iY, GetCityCenterForPlot
        )
        cityWonder = iconName
    end

    local buildingInfo = GameInfo.Buildings[iconName]
    if buildingInfo ~= nil and buildingInfo.IsWonder then
        _, cityCenterPlotID = MatchCityCenterAndWonderPins(
            playerID, iX, iY, GetCityCenterForPlot
        )
        cityWonder = buildingInfo.BuildingType
        cityWonderPlotID = Map.GetPlot(iX, iY):GetIndex()
    end

    if cityCenterPlotID == nil or cityWonder == nil then
        return
    end

    local obj = CityMapPinManager:new(
        playerID, cityCenterPlotID, cityWonderPlotID, cityWonder
    )
    if obj.finishedInitialization then
        return
    end

    obj:RefreshMapPinMapping()
    -- fix a timing issue with creating the first city
    if (
        cityWonderPlotID ~= nil and
        obj.mapPinIDsByPlot[cityWonderPlotID] == nil
    ) then
        obj.mapPinIDsByPlot[cityWonderPlotID] = pinID
        obj.mapPinNamesByID[pinID] = cityWonder
        obj.mapPinPlotsByName[cityWonder] = cityWonderPlotID
        obj.wonderName = cityWonder
    end

    local pinPlotIDs = obj:FindDamPlotsForRivers()
    if #pinPlotIDs > 0 then
        for i = 1, #pinPlotIDs do
            local plotID = pinPlotIDs[i]
            obj:AddPin("DISTRICT_DAM", plotID, false)
        end
    end

    if obj.wonderName ~= "DISTRICT_DIPLOMATIC_QUARTER" then
        local districtType, adjacent = obj:GetDistrictForWonder()
        if districtType ~= nil and districtType ~= "DISTRICT_CITY_CENTER" then
            local plotID = obj:FindPlotForDistrict(districtType, adjacent)
            if plotID ~= nil then
                obj:AddPin(districtType, plotID, false)
            end
        end
    end

    local districtTypes = {
        "DISTRICT_WATER_ENTERTAINMENT_COMPLEX",
        "DISTRICT_ENTERTAINMENT_COMPLEX",
        "DISTRICT_HARBOR",
        "DISTRICT_COMMERCIAL_HUB",
        "DISTRICT_HOLY_SITE",
        "DISTRICT_INDUSTRIAL_ZONE",
        "DISTRICT_THEATER",
        "DISTRICT_ENCAMPMENT",
    }
    for i = 1, #districtTypes do
        local districtType = districtTypes[i]
        local plotID = obj:FindPlotForDistrict(districtType)
        if plotID ~= nil then
            obj:AddPin(districtType, plotID, false)
        end
    end
end

LuaEvents.MapPinPopup_OnAdd.Add(AddMapPinsForCityCenter)

function RefreshAllCityData()
    FinishedInitialization = true
    local function RefreshDataForCity(playerID, iX, iY)
        local cityCenterPlotID = Map.GetPlot(iX, iY):GetIndex()
        local cityWonder, cityWonderPlotID = MatchCityCenterAndWonderPins(
            playerID, iX, iY, GetWonderForPlot
        )
        if cityWonderPlotID ~= nil then
            local obj = CityMapPinManager:new(
                playerID, cityCenterPlotID, cityWonderPlotID, cityWonder
            )
            if obj ~= nil then
                obj:RefreshMapPinMapping()
            end
        end
    end
    local allPlayers = PlayerManager.GetAliveIDs()
    for playerID = 0, #allPlayers do
        local player = Players[playerID]
        if player:IsHuman() then
            local config = PlayerConfigurations[playerID]
            if config ~= nil then
                local pins = config:GetMapPins()
                for _, pin in pairs(pins) do
                    local iconName = pin:GetIconName():gsub("^ICON_", "")
                    if iconName == "DISTRICT_CITY_CENTER" then
                        local x = pin:GetHexX()
                        local y = pin:GetHexY()
                        RefreshDataForCity(playerID, x, y)
                    end
                end
            end
            local cities = player:GetCities()
            for _, city in cities:Members() do
                RefreshDataForCity(playerID, city:GetX(), city:GetY())
            end
        end
    end
end

Events.LoadGameViewStateDone.Add(RefreshAllCityData)

function MoveDistrictMapPinIfInConflict(iX, iY)
    if not FinishedInitialization then
        return
    end

    local plot = Map.GetPlot(iX, iY)
    local plotID = plot:GetIndex()
    local obj = CityMapPinManager.FindInstanceForMapPinConflict(plotID)
    if obj ~= nil then
        obj:MovePin(plotID)
    end
end

Events.ResourceAddedToMap.Add(MoveDistrictMapPinIfInConflict)

function AddInitialCityIcon(playerID, _, iX, iY)
    local player = Players[playerID]
    if not player:IsAlive() or not player:IsHuman() then
        return
    end

    local cities = player:GetCities()
    if cities:GetCount() > 1 then
        return
    end

    local config = PlayerConfigurations[playerID]
    local pins = config:GetMapPins()
    if next(pins) ~= nil then
        return
    end

    local function GetBestPlotID(mountain, nonWoodland, nonFloodplains)
        for direction = 0, 5 do
            local plot = Map.GetAdjacentPlot(iX, iY, direction)
            if not plot:IsWater() then
                if mountain then
                    if (
                        plot:IsMountain() and
                        plot:GetFeatureType() ~= VOLCANO_INDEX
                    ) then
                        return plot:GetIndex()
                    end
                elseif plot:GetResourceType() == -1 then
                    local isValid = true
                    local feature = plot:GetFeatureType()
                    if (
                        nonWoodland and
                        (feature == WOODS_INDEX or feature == JUNGLE_INDEX)
                    ) then
                        isValid = false
                    end
                    if nonFloodplains and feature == FLOODPLAINS_INDEX then
                        isValid = false
                    end
                    if isValid then
                        return plot:GetIndex()
                    end
                end
            end
        end
    end

    local arguments = {
        {true, false, false},
        {false, true, true},
        {false, false, true},
        {false, false, false},
    }

    local plotID = nil
    for i = 1, #arguments do
        local currentArguments = arguments[i]
        local currentPlotID = GetBestPlotID(
            unpack(currentArguments)
        )
        if currentPlotID ~= nil then
            plotID = currentPlotID
            break
        end
    end

    if plotID ~= nil then
        AddPin(playerID, "ICON_BUILDING_APADANA", plotID)
    end
end

Events.CityInitialized.Add(AddInitialCityIcon)

function RemoveMapPinForDistrict(playerID, _, cityID, iX, iY, districtType)
    if not FinishedInitialization then
        return
    end

    if districtType == CITY_CENTER_INDEX then
        local config = PlayerConfigurations[playerID]
        if config ~= nil then
            local pins = config:GetMapPins()
            for pinID, pin in pairs(pins) do
                local x = pin:GetHexX()
                local y = pin:GetHexY()
                if x == iX and y == iY then
                    RemovePin(playerID, pinID)
                    return
                end
            end
        end
        return
    end
    local plot = Map.GetPlot(iX, iY)
    local plotID = plot:GetIndex()
    local city = CityManager.GetCity(playerID, cityID)
    local cityPlot = Map.GetPlot(city:GetX(), city:GetY())
    local cityPlotID = cityPlot:GetIndex()
    local obj = CityMapPinManager:new(playerID, cityPlotID)
    if obj ~= nil then
        if districtType == WONDER_INDEX then
            local pinID = obj.mapPinIDsByPlot[plotID]
            local iconName = obj.mapPinNamesByID[pinID]
            obj.wonderName = iconName
        end
        obj:RemoveMapPinForDistrict(iX, iY, districtType)
    end
end

Events.DistrictAddedToMap.Add(RemoveMapPinForDistrict)

function RemoveMapPinForImprovement(iX, iY, improvementType, playerID)
    if not FinishedInitialization then
        return
    end

    local config = PlayerConfigurations[playerID]
    if config == nil then
        return
    end

    local pins = config:GetMapPins()
    if pins == nil then
        return
    end

    for pinID, pin in pairs(pins) do
        if iX == pin:GetHexX() and iY == pin:GetHexY() then
            RemovePin(playerID, pinID)
        end
    end
end

Events.ImprovementAddedToMap.Add(RemoveMapPinForImprovement)

print("=== Auto Map Pins (UI) Loaded ===")
