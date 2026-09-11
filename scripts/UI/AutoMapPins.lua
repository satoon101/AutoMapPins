-- ===========================================================================
--  Auto Map Pins - UI Script
--  Provides Auto Map Pins UI scripts.
-- ===========================================================================

print("=== Auto Map Pins (UI) Loading ===")

include("AutoMapPins_Managers")

function GetWonderFromPinName(pinName, plotID)
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

function GetCityCenterFromPinName(pinName, plotID)
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
    for i = 1, #pins do
        local pin = pins[i]
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

function AddMapPinsForCityCenter(playerID, pinID, pinName, iX, iY)
    local config = PlayerConfigurations[playerID]
    if config == nil then
        return
    end

    local cityCenterPlotID = nil
    local cityWonderPlotID = nil
    local cityWonder = nil
    pinName = pinName:gsub("^ICON_", "")
    if pinName == "DISTRICT_CITY_CENTER" then
        cityCenterPlotID = Map.GetPlot(iX, iY):GetIndex()
        cityWonderPlotID = MatchCityCenterAndWonderPins(
            playerID, iX, iY, GetWonderFromPinName
        )
        local cityWonderPlot = Map.GetPlotByIndex(cityWonderPlotID)
        local x = cityWonderPlot:GetX()
        local y = cityWonderPlot:GetY()
        local pin = config:GetMapPin(x, y)
        cityWonder = pin:gsub("^ICON_", "")
    end

    if pinName == "DISTRICT_DIPLOMATIC_QUARTER" then
        cityCenterPlotID = MatchCityCenterAndWonderPins(
            playerID, iX, iY, GetCityCenterFromPinName
        )
        cityWonder = pinName
    end

    local buildingInfo = GameInfo.Buildings[pinName]
    if buildingInfo ~= nil and buildingInfo.IsWonder then
        cityCenterPlotID = MatchCityCenterAndWonderPins(
            playerID, iX, iY, GetCityCenterFromPinName
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
        if districtType ~= nil then
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

    -- Notes for AutoQueue
    --      if HARBOR is not necessary for Wonder,
    --          and is not adjacent to city center,
    --          then create COMMERCIAL_HUB first
    --      if ENCAMPMENT not necessary for Wonder,
    --          then create the HOLD_SITE first
end

LuaEvents.MapPinPopup_OnAdd.Add(AddMapPinsForCityCenter)

function RefreshAllCityData()
    local function RefreshDataForCity(playerID, iX, iY)
        local cityCenterPlotID = Map.GetPlot(iX, iY):GetIndex()
        local cityWonder, cityWonderPlotID = MatchCityCenterAndWonderPins(
            playerID, iX, iY, GetWonderFromPinName
        )
        if cityWonderPlotID ~= nil then
            local obj = CityMapPinManager:new(
                playerID, cityCenterPlotID, cityWonderPlotID, cityWonder
            )
            obj:RefreshMapPinMapping()
        end
    end
    local allPlayers = PlayerManager.GetAliveIDs()
    for playerID = 0, #allPlayers do
        local config = PlayerConfigurations[playerID]
        if config ~= nil then
            local pins = config:GetMapPins()
            if #pins > 0 then
                for i = 1, #pins do
                    local pin = pins[i]
                    local pinName = pin:GetIconName():gsub("^ICON_", "")
                    if pinName == "DISTRICT_CITY_CENTER" then
                        local x = pin:GetHexX()
                        local y = pin:GetHexY()
                        RefreshDataForCity(playerID, x, y)
                    end
                end
            end
        end
        local player = Players[playerID]
        local cities = player:GetCities()
        if cities ~= nil and cities:GetCount() > 0 then
            for _, city in cities:Members() do
                RefreshDataForCity(playerID, city:GetX(), city:GetY())
            end
        end
    end
end

Events.LoadGameViewStateDone.Add(RefreshAllCityData)

function MoveDistrictMapPinIfInConflict(iX, iY)
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
    if #pins > 0 then
        return
    end

    local function GetBestPlotID(mountain, nonWoodland, nonFloodplains)
        for direction = 0, 5 do
            local plot = Map.GetAdjacentPlot(iX, iY, direction)
            if mountain then
                if plot:IsMountain() then
                    return plot:GetIndex()
                end
            elseif plot:GetResourceType() == -1 then
                local isValid = true
                local feature = plot:GetFeatureType()
                if (
                    nonWoodland and
                    (feature == FOREST_INDEX or feature == JUNGLE_INDEX)
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
    if districtType == CITY_CENTER_INDEX then
        local config = PlayerConfigurations[playerID]
        if config ~= nil then
            local pins = config:GetMapPins()
            for i = 1, #pins do
                local pin = pins[i]
                local x = pin:GetHexX()
                local y = pin:GetHexY()
                if x == iX and y == iY then
                    local pinID = pin:GetID()
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
    local obj = CityMapPinManager:new(playerID, cityPlotID, plotID, nil)
    if districtType == WONDER_INDEX then
        local pinID = obj.mapPinIDsByPlot[plotID]
        local pinName = obj.mapPinNamesByID[pinID]
        obj.wonderName = pinName
    end
    obj:RemoveMapPinForDistrict(iX, iY, districtType)
end

Events.DistrictAddedToMap.Add(RemoveMapPinForDistrict)

-- use for creating farms
-- cityPopulationSizesByEra = {
--     [0] = 1,
--     [1] = 4,
--     [2] = 7,
--     [3] = 10,
--     [4] = 13,
--     [5] = 16,
--     [6] = 19,
--     [7] = 22,
-- }


-- function IsPlotInteriorWater(pPlot)
--     if pPlot == nil or not pPlot:IsWater() then return false end
--
--     -- 1. Grab the native engine "Area" object for this group of connected tiles
--     local pArea = pPlot:GetArea()
--     if pArea == nil then return false end
--
--     -- 2. Get the exact number of water tiles connected in this body of water
--     local totalWaterTiles = pArea:GetPlotCount()
--
--     -- 3. Determine if it's an interior body of water
--     -- If it's 9 or less, it's a standard gameplay Lake.
--     -- If it's larger than 9 but bounded, we check if it connects to the main ocean.
--     if totalWaterTiles <= 9 then
--         -- It's a standard fresh-water lake
--         return true
--     else
--         -- It's a large inland sea/interior coast (10+ tiles)
--         -- We can verify it's an interior body by comparing it to the largest ocean
--         local pBiggestOceanArea = Areas.FindBiggestArea(true) -- Pass true for water areas
--
--         if pBiggestOceanArea ~= nil then
--             -- If this plot's area doesn't match the global map's primary ocean area,
--             -- it is completely landlocked and interior!
--             if pArea:GetID() ~= pBiggestOceanArea:GetID() then
--                 return true
--             end
--         end
--     end
--
--     return false -- This tile is part of the boundless open ocean
-- end

print("=== Auto Map Pins (UI) Loaded ===")
