
include("AutoMapPins_Helpers")

CityMapPinManager = {}
CityMapPinManager.__index = CityMapPinManager
CityMapPinManager.Registry = {}

function CityMapPinManager:new(playerID, centerPlotID, wonderPlotID, wonderName)
    if CityMapPinManager.Registry[centerPlotID] then
        return CityMapPinManager.Registry[centerPlotID]
    end

    local plotArray = {}
    local plotMap = {}
    local plotsByRange = {}
    local riverNameMapping = {}
    local riverNamesForCity = {}
    local centerPlot = Map.GetPlotByIndex(centerPlotID)
    local iX = centerPlot:GetX()
    local iY = centerPlot:GetY()
    local radiusPlots = Map.GetNeighborPlots(iX, iY, 3)
    for i = 1, #radiusPlots do
        local plot = radiusPlots[i]
        local plotID = plot:GetIndex()
        local x = plot:GetX()
        local y = plot:GetY()
        local distance = Map.GetPlotDistance(x, y, iX, iY)
        if plotsByRange[distance] == nil then
            plotsByRange[distance] = {}
        end
        plotsByRange[distance][plotID] = true
        table.insert(plotArray, plotID)
        plotMap[plotID] = {
            X = plot:GetX(),
            Y = plot:GetY()
        }
        local riverName = RiverManager.GetRiverName(plot)
        if riverName ~= nil and riverNameMapping[riverName] == nil then
            riverNameMapping[riverName] = true
            table.insert(riverNamesForCity, riverName)
        end
    end
    local idealDistrictPlots = {}
    for direction = 0, 5 do
        local midPlot = Map.GetAdjacentPlot(iX, iY, direction)
        local midX = midPlot:GetX()
        local midY = midPlot:GetY()
        local plot = Map.GetAdjacentPlot(midX, midY, direction)
        local plotID = plot:GetIndex()
        idealDistrictPlots[plotID] = true
    end

    local config = PlayerConfigurations[playerID]
    local civType = config:GetCivilizationTypeName()

    local instance = {
        playerID = playerID,
        plotID = centerPlotID,
        civType = civType,
        idealDistrictPlots = idealDistrictPlots,
        mapPinIDsByPlot = {},
        mapPinNamesByID = {},
        mapPinPlotsByName = {},
        mapPinsForDams = {},
        riverNamesForCity = riverNamesForCity,
        plotArray = plotArray,
        plotMap = plotMap,
        plotsByRange = plotsByRange,
        wonderPlotID = wonderPlotID,
        wonderName = wonderName,
        cananlPlotIDs = nil,
        finishedInitialization = false
    }

    setmetatable(instance, self)
    if wonderName == "BUILDING_PANAMA_CANAL" then
        instance:MarkCanalPlots()
    end
    CityMapPinManager.Registry[centerPlotID] = instance
    return instance
end

function CityMapPinManager:MarkCanalPlots()
    local cityCenterPlot = Map.GetPlotByIndex(self.plotID)
    local wonderPlot = Map.GetPlotByIndex(self.wonderPlotID)
    local x1 = cityCenterPlot:GetX()
    local y1 = cityCenterPlot:GetY()
    local x2 = wonderPlot:GetX()
    local y2 = wonderPlot:GetY()
    if Map.GetPlotDistance(x1, y1, x2, y2) > 2 then
        return
    end

    self.canalPlotIDs = {}
    for direction = 0, 5 do
        local checkPlot = Map.GetAdjacentPlot(x1, y1, direction)
        if checkPlot ~= nil then
            local x3 = checkPlot:GetX()
            local y3 = checkPlot:GetY()
            if Map.GetPlotDistance(x2, y2, x3, y3) == 1 then
                local checkPlotID = checkPlot:GetIndex()
                table.insert(self.canalPlotIDs, checkPlotID)
                self:AddPin("DISTRICT_CANAL", checkPlotID, false)
            end
        end
    end
end

function CityMapPinManager:RefreshMapPinMapping()
    self.mapPinIDsByPlot = {}
    self.mapPinNamesByID = {}
    self.mapPinPlotsByName = {}
    local config = PlayerConfigurations[self.playerID]
    local pins = config:GetMapPins()
    for pinID, pin in pairs(pins) do
        local x = pin:GetHexX()
        local y = pin:GetHexY()
        local plot = Map.GetPlot(x, y)
        local plotID = plot:GetIndex()
        if self.plotMap[plotID] ~= nil then
            self.mapPinIDsByPlot[plotID] = pinID
            local iconName = pin:GetIconName():gsub("^ICON_", "")
            self.mapPinNamesByID[pinID] = iconName
            self.mapPinPlotsByName[iconName] = plotID
            if (
                iconName == "DISTRICT_DAM" or
                iconName == "BUILDING_GREAT_BATH"
            ) then
                local riverName = RiverManager:GetRiverName(plot)
                self.mapPinsForDams[plotID] = riverName
                RiverDamManager.RegisterDamMapPinForPlot(plotID)
            end
        end
    end
    local cityPlot = Map.GetPlotByIndex(self.plotID)
    local city = Cities.GetPlotPurchaseCity(cityPlot)
    if city ~= nil then
        local districts = city:GetDistricts()
        for _, district in districts:Members() do
            local districtTypeID = district:GetType()
            local districtInfo = GameInfo.Districts[districtTypeID]
            local districtType = districtInfo.DistrictType
            local x = district:GetX()
            local y = district:GetY()
            local plot = Map.GetPlot(x, y)
            local plotID = plot:GetIndex()
            local pinID = "district" .. tostring(plotID)
            self.mapPinIDsByPlot[plotID] = pinID
            self.mapPinNamesByID[pinID] = districtType
            self.mapPinPlotsByName[districtType] = plotID
            if districtTypeID == WONDER_INDEX then
                local location = district:GetLocation()
                local buildingIndex = nil
                if district:IsComplete() then
                    local buildings = city:GetBuildings()
                    buildings = buildings:GetBuildingsAtLocation(location)
                    buildingIndex = buildings[1]
                else
                    local queue = city:GetBuildQueue()
                    local buildings = queue:GetConstructionsAtLocation(location)
                    buildingIndex = buildings[1]
                end
                if buildingIndex == GREAT_BATH_BUILDING_INDEX then
                    RiverDamManager.RegisterDamMapPinForPlot(plotID)
                end
            end
        end
    end
    self.finishedInitialization = true
end

function CityMapPinManager:AddPin(name, plotID, refreshMapping)
    if self.mapPinIDsByPlot[plotID] ~= nil then
        print("Accidentally tried to create pin where one existed: " .. plotID)
        return
    end

    local iconName = "ICON_" .. name
    local pin = AddPin(self.playerID, iconName, plotID)
    if refreshMapping then
        self:RefreshMapPinMapping()
    else
        local pinID = pin:GetID()
        self.mapPinIDsByPlot[plotID] = pinID
        self.mapPinNamesByID[pinID] = name
        self.mapPinPlotsByName[name] = plotID
        if name == "DISTRICT_DAM" then
            local plot = Map.GetPlotByIndex(plotID)
            local riverName = RiverManager:GetRiverName(plot)
            self.mapPinsForDams[plotID] = riverName
            RiverDamManager.RegisterDamMapPinForPlot(plotID)
        end
    end
end

function CityMapPinManager:MovePin(plotID)
    local pinID = self.mapPinIDsByPlot[plotID]
    local iconName = self.mapPinNamesByID[pinID]
    if iconName ~= nil and pinID ~= nil then
        if GameInfo.Buildings[iconName] ~= nil then
            -- pin is a wonder
            self:RemovePin(pinID, false)
            -- TODO: how to handle this?
        elseif GameInfo.Districts[iconName] ~= nil then
            -- pin is a district
            self:RemovePin(pinID, false)
            local baseDistrictType = GameInfo.Districts[iconName].DistrictType
            local wonderDistrictType, adjacent = self:GetDistrictForWonder()
            if wonderDistrictType ~= baseDistrictType then
                adjacent = false
            end

            local newPlotID = self:FindPlotForDistrict(
                baseDistrictType, adjacent
            )
            if newPlotID ~= nil then
                self:AddPin(baseDistrictType, newPlotID, true)
            end
        end
    end
end

function CityMapPinManager:RemovePin(pinID, refreshMapping)
    RemovePin(self.playerID, pinID)
    if refreshMapping then
        self:RefreshMapPinMapping()
    else
        local iconName = self.mapPinNamesByID[pinID]
        local plotID = self.mapPinPlotsByName[iconName]
        self.mapPinIDsByPlot[plotID] = nil
        self.mapPinNamesByID[pinID] = nil
        self.mapPinPlotsByName[iconName] = nil
        if iconName == "DISTRICT_DAM" then
            self.mapPinsForDams[plotID] = nil
        end
    end
end

function CityMapPinManager:RemoveMapPinForDistrict(iX, iY, districtType)
    local districtInfo = GameInfo.Districts[districtType]
    districtType = districtInfo.DistrictType
    local iconName = districtType
    local replaceInfo = GameInfo.DistrictReplaces[districtType]
    if replaceInfo ~= nil then
        iconName = replaceInfo.ReplacesDistrictType
    end
    local plot = Map.GetPlot(iX, iY)
    local plotID = plot:GetIndex()
    local pinID = self.mapPinIDsByPlot[plotID]
    if iconName == "DISTRICT_WONDER" and plotID == self.wonderPlotID then
        iconName = self.wonderName
        if self.wonderName == "BUILDING_PANAMA_CANAL" then
            if self.canalPlotIDs ~= nil and #self.canalPlotIDs > 0 then
                for i = 1, #self.canalPlotIDs do
                    local canalPlotID = self.canalPlotIDs[i]
                    local canalPlot = Map.GetPlotByIndex(canalPlotID)
                    local x = canalPlot:GetX()
                    local y = canalPlot:GetY()
                    self:RemoveMapPinForDistrict(x, y, CANAL_INDEX)
                end
            end
        end
    end
    if self.mapPinPlotsByName[iconName] == plotID then
        self:RemovePin(pinID, false)
    end
end

function CityMapPinManager:FindDamPlotsForRivers()
    local pinPlotIDs = {}
    for i = 1, #self.riverNamesForCity do
        local riverName = self.riverNamesForCity[i]
        local obj = RiverDamManager:new(riverName)
        if obj.damMapPinPlotID == nil and obj.damDistrictPlotID == nil then
            local plotID = self:FindDamPlotForRiver(obj.damPlotMap)
            if plotID ~= nil then
                table.insert(pinPlotIDs, plotID)
            end
        end
    end
    return pinPlotIDs
end

function CityMapPinManager:FindDamPlotForRiver(plotIDs)
    if #plotIDs == 1 then
        return plotIDs[1]
    end

    local arguments = {
        {plotIDs, 3, false, true},
        {plotIDs, 1, false, true},
        {plotIDs, 2, true, true},
        {plotIDs, 2, false, true},
        {plotIDs, 3, false, false},
        {plotIDs, 1, false, false},
        {plotIDs, 2, true, false},
        {plotIDs, 2, false, false},
    }

    for i = 1, #arguments do
        local currentArguments = arguments[i]
        local plotID = self:FindDamPlotForRiverByRange(
            unpack(currentArguments)
        )
        if plotID ~= nil then
            return plotID
        end
    end
    return nil
end

function CityMapPinManager:FindDamPlotForRiverByRange(
    plotIDs, distance, excludeIdeal, excludeResources
)
    local excludePlots = {}
    if excludeIdeal then
        excludePlots = self.idealDistrictPlots
    end
    for plotID in pairs(self.plotsByRange[distance]) do
        if plotIDs[plotID] ~= nil and excludePlots[plotID] == nil then
            local plot = Map.GetPlotByIndex(plotID)
            if not excludeResources or plot:GetResourceType() == -1 then
                return plotID
            end
        end
    end
end

function CityMapPinManager:GetDistrictForWonder()
    if self.wonderName == nil then
        return nil, nil
    end

    local buildingInfo = GameInfo.Buildings[self.wonderName]
    if buildingInfo.AdjacentDistrict ~= nil then
        return buildingInfo.AdjacentDistrict, true
    end

    if #buildingInfo.PrereqBuildingCollection == 0 then
        return nil, nil
    end

    local buildingType = buildingInfo.PrereqBuildingCollection[1]
    local districtType = GameInfo.Districts[buildingType].PrereqDistrict
    return districtType, false
end

function CityMapPinManager:FindPlotForDistrict(baseDistrictType, adjacent)
    if self.mapPinPlotsByName[baseDistrictType] ~= nil then
        return nil
    end

    local exclusiveDistricts = {
        DISTRICT_WATER_ENTERTAINMENT_COMPLEX = "DISTRICT_ENTERTAINMENT_COMPLEX",
        DISTRICT_ENTERTAINMENT_COMPLEX = "DISTRICT_WATER_ENTERTAINMENT_COMPLEX",
    }

    if exclusiveDistricts[baseDistrictType] ~= nil then
        local checkDistrictType = exclusiveDistricts[baseDistrictType]
        if self.mapPinPlotsByName[checkDistrictType] ~= nil then
            return nil
        end
    end

    local districtType = self:GetDistrictForCivByType(baseDistrictType)
    if adjacent then
        local plotID = self:FindAdjacentPlotForDistrict(
            self.wonderPlotID, districtType, baseDistrictType, false, true
        )
        if plotID ~= nil then
            return plotID
        end

        plotID = self:FindAdjacentPlotForDistrict(
            self.wonderPlotID, districtType, baseDistrictType, true, false
        )
        if plotID ~= nil then
            return plotID
        end

        return self:FindAdjacentPlotForDistrict(
            self.wonderPlotID, districtType, baseDistrictType, false, false
        )
    end

    local districtInfo = GameInfo.Districts[baseDistrictType]
    if districtInfo.AdjacentToLand then
        return self:FindPlotForWaterDistrict(districtType, baseDistrictType)
    end
    if baseDistrictType == "DISTRICT_HOLY_SITE" then
        if (
            self.wonderName == "BUILDING_APADANA" or
            self.wonderName == "BUILDING_STONEHENGE"
        ) then
            return self:FindPlotForEarlyHolySite(
                districtType, baseDistrictType
            )
        end
    end

    local arguments = {
        {2, true, false, false},
        {2, false, false, false},
        {1, false, false, false},
        {3, false, false, false},
    }
    for i = 1, #arguments do
        local currentArguments = arguments[i]
        local plotID = self:FindPlotForForDistrictByRange(
            districtType, baseDistrictType, unpack(currentArguments)
        )
        if plotID ~= nil then
            return plotID
        end
    end
    return nil
end

function CityMapPinManager:FindAdjacentPlotForDistrict(
    centerPlotID, districtType, baseDistrictType, idealOnly, range1Only
)
    local validTerrains = GetValidTerrainsForDistrict(districtType)
    local requiredFeatures = GetRequiredFeaturesForDistrict(districtType)
    local centerPlot = Map.GetPlotByIndex(centerPlotID)
    local x = centerPlot:GetX()
    local y = centerPlot:GetY()
    for direction = 0, 5 do
        local plot = Map.GetAdjacentPlot(x, y, direction)
        local plotID = plot:GetIndex()
        if (
            self.plotMap[plotID] ~= nil and
            self.mapPinIDsByPlot[plotID] == nil
        ) then
            if not idealOnly or self.idealDistrictPlots[plotID] ~= nil then
                if not range1Only or self.plotsByRange[1][plotID] ~= nil then
                    if self:IsPlotValidForDistrict(
                        districtType, baseDistrictType, plotID,
                        validTerrains, requiredFeatures
                    ) then
                        return plotID
                    end
                end
            end
        end
    end
    return nil
end

function CityMapPinManager:FindPlotForForDistrictByRange(
    districtType, baseDistrictType, distance, idealOnly, lakeOnly, coastOnly
)
    local validTerrains = GetValidTerrainsForDistrict(districtType)
    local requiredFeatures = GetRequiredFeaturesForDistrict(districtType)
    for plotID in pairs(self.plotsByRange[distance]) do
        if self.mapPinIDsByPlot[plotID] == nil then
            if not idealOnly or self.idealDistrictPlots[plotID] ~= nil then
                if self:IsPlotValidForDistrict(
                    districtType, baseDistrictType, plotID,
                    validTerrains, requiredFeatures, lakeOnly, coastOnly
                ) then
                    return plotID
                end
            end
        end
    end
    return nil
end

function CityMapPinManager:GetDistrictForCivByType(districtType)
    for row in GameInfo.DistrictReplaces() do
        if row.ReplacesDistrictType == districtType then
            local districtInfo = GameInfo.Districts[row.CivUniqueDistrictType]
            local traitType = districtInfo.TraitType
            for row2 in GameInfo.CivilizationTraits() do
                if (
                    row2.CivilizationType == self.civType and
                    row2.TraitType == traitType
                ) then
                    return row.CivUniqueDistrictType
                end
            end
        end
    end
    return districtType
end

function CityMapPinManager:IsPlotValidForDistrict(
    districtType, baseDistrictType, plotID, validTerrains,
    requiredFeatures, lakeOnly, coastOnly
)
    if self.mapPinIDsByPlot[plotID] ~= nil then
        return false
    end

    local centerPlot = Map.GetPlotByIndex(self.plotID)
    local x = centerPlot:GetX()
    local y = centerPlot:GetY()
    local plot = Map.GetPlotByIndex(plotID)
    local x2 = plot:GetX()
    local y2 = plot:GetY()
    local districtInfo = GameInfo.Districts[districtType]

    local resource = plot:GetResourceType()
    if resource ~= -1 then
        return false
    end

    -- Check for Harbor/Pier
    if districtInfo.AdjacentToLand then
        if not plot:IsWater() then
            return false
        end
        if not plot:IsAdjacentToLand() then
            return false
        end
        if lakeOnly and not plot:IsLake() then
            return false
        end
        if coastOnly and plot:IsLake() then
            -- TODO: look into figuring out if plot is in large lake that says it's ocean
            return false
        end
        for direction2 = 0, 5 do
            local adjacentPlot = Map.GetAdjacentPlot(x2, y2, direction2)
            if adjacentPlot ~= nil and not adjacentPlot:IsWater() then
                return true
            end
        end
        return false
    end
    if plot:IsWater() or plot:IsMountain() or plot:GetDistrictID() ~= -1 then
        return false
    end

    local terrain = plot:GetTerrainType()
    if #validTerrains > 0 and validTerrains[terrain] == nil then
        return false
    end

    local feature = plot:GetFeatureType()
    if #requiredFeatures > 0 and requiredFeatures[feature] == nil then
        return false
    end

    if feature == VOLCANO_INDEX or plot:IsNaturalWonder() then
        return false
    end

    -- Check for Gaul/Encampment
    if (
        self.civType == "CIVILIZATION_GAUL"
        or districtInfo.NoAdjacentCity
    ) then
        -- check for non-adjacency to city center
        local distance = Map.GetPlotDistance(x, y, x2, y2)
        return distance > 1
    end

    -- Check for Aqueduct
    if baseDistrictType == "BUILDING_AQUEDUCT" then
        -- check for adjacency to city center
        local distance = Map.GetPlotDistance(x, y, x2, y2)
        if distance > 1 then
            return false
        end

        -- check for river, lake, oasis, mountain
        if plot:IsRiver() then
            return true
        end
        for direction3 = 0, 5 do
            local checkPlot = Map.GetAdjacentPlot(
                x2, y2, direction3
            )
            if (
                checkPlot:IsLake() or
                checkPlot:IsMountain() or
                checkPlot:GetFeatureType() == OASIS_INDEX
            ) then
                return true
            end
        end
        return false
    end
    return true
end

function CityMapPinManager:FindPlotForWaterDistrict(
    districtType, baseDistrictType
)
    local arguments = {}
    if baseDistrictType == "DISTRICT_HARBOR" then
        arguments = {
            {1, false, false, true},
            {2, true, false, true},
            {2, false, false, true},
            {3, false, false, true},
        }
    else
        arguments = {
            {2, true, true, false},
            {3, false, true, false},
            {2, false, true, false},
            {1, false, true, false},
            {2, true, false, false},
            {3, false, false, false},
            {2, false, false, false},
            {1, false, false, false},
        }
    end
    for i = 1, #arguments do
        local currentArguments = arguments[i]
        local plotID = self:FindPlotForForDistrictByRange(
            districtType, baseDistrictType, unpack(currentArguments)
        )
        if plotID ~= nil then
            return plotID
        end
    end
    return nil
end

function CityMapPinManager:FindPlotForEarlyHolySite(
    districtType, baseDistrictType
)
    local arguments = {
        {1, false, false, false},
        {2, true, false, false},
        {2, false, false, false},
    }
    for i = 1, #arguments do
        local currentArguments = arguments[i]
        local plotID = self:FindPlotForForDistrictByRange(
            districtType, baseDistrictType, unpack(currentArguments)
        )
        if plotID ~= nil then
            return plotID
        end
    end
    return nil
end

-------------------------------------------------------------------------------
-- CITY MANAGER FUNCTIONS
-------------------------------------------------------------------------------
function CityMapPinManager.FindInstanceForMapPinConflict(plotID)
    for _, instance in pairs(CityMapPinManager.Registry) do
        if instance.mapPinIDsByPlot[plotID] ~= nil then
            return instance
        end
    end
    return nil
end

-------------------------------------------------------------------------------
-- RIVER MANAGER
-------------------------------------------------------------------------------

RiverDamManager = {}
RiverDamManager.__index = RiverDamManager
RiverDamManager.Registry = {}

function RiverDamManager:new(riverName)
    if RiverDamManager.Registry[riverName] then
        return RiverDamManager.Registry[riverName]
    end

    local riverPlots = {}
    local damPlotArray = {}
    local damPlotMap = {}
    local rivers = RiverManager.EnumerateRivers()
    for i1 = 1, #rivers do
        local river = rivers[i1]
        if river.Name == riverName then
            for i2 = 1, #river.Edges do
                local edge = river.Edges[i2]
                for i3 = 1, #edge do
                    local plotID = edge[i3]
                    local plot = Map.GetPlotByIndex(plotID)
                    if RiverManager.CanBeFlooded(plot) then
                        local resourceType = plot:GetResourceType()
                        local resourceInfo = GameInfo.Resources[resourceType]
                        if (
                            resourceInfo == nil or
                            resourceInfo.ResourceClassType == "RESOURCECLASS_BONUS"
                        ) then
                            local count = riverPlots[plotID] or 0
                            riverPlots[plotID] = count + 1
                            if riverPlots[plotID] == 2 then
                                table.insert(damPlotArray, plotID)
                                damPlotMap[plotID] = true
                            end
                        end
                    end
                end
            end
        end
    end

    local instance = {
        riverName = riverName,
        riverPlots = riverPlots,
        damPlotArray = damPlotArray,
        damPlotMap = damPlotMap,
        damMapPinPlotID = nil,
        damDistrictPlotID = nil,
    }

    setmetatable(instance, self)
    self.damDistrictPlotID = instance:FindDamDistrict()
    RiverDamManager.Registry[riverName] = instance
    return instance
end

function RiverDamManager:FindDamDistrict()
    for i = 0, #self.damPlotArray do
        local plotID = self.damPlotArray[i]
        local plot = Map.GetPlotByIndex(plotID)
        local districtType = plot:GetDistrictType()
        if districtType == DAM_INDEX then
            return plotID
        elseif districtType == WONDER_INDEX then
            local city = CityManager.GetCity(self.playerID, self.cityID)
            local districts = city:GetDistricts()
            local queue = city:GetBuildQueue()
            local district = districts:GetDistrict(WONDER_INDEX)
            local location = district:GetLocation()
            local buildingIndex = nil
            if district:IsComplete() then
                local buildings = city:GetBuildings()
                buildingIndex = buildings:GetBuildingsAtLocation(location)
            else
                local buildings = queue:GetConstructionsAtLocation(location)
                buildingIndex = buildings[1]
            end
            if buildingIndex == GREAT_BATH_BUILDING_INDEX then
                return plotID
            end
        end
    end
    return nil
end

-------------------------------------------------------------------------------
-- RIVER MANAGER FUNCTIONS
-------------------------------------------------------------------------------
function RiverDamManager.RegisterDamMapPinForPlot(plotID)
    local plot = Map.GetPlotByIndex(plotID)
    local riverName = RiverManager.GetRiverName(plot)
    if riverName ~= nil then
        local instance = RiverDamManager:new(riverName)
        instance.damMapPinPlotID = plotID
    end
end

print("=== Auto Map Pins (Managers) Loaded ===")
