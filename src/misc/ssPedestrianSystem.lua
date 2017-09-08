----------------------------------------------------------------------------------------------------
-- PEDESTRIAN SCRIPT
----------------------------------------------------------------------------------------------------
-- Purpose:  To disable pedestrian spawning in winter
-- Authors:  Rahkiin
--
-- Copyright (c) Realismus Modding, 2017
----------------------------------------------------------------------------------------------------

ssPedestrianSystem = {}
g_seasons.pedestrianSystem = ssPedestrianSystem

function ssPedestrianSystem:loadMap(name)
    g_seasons.environment:addSeasonChangeListener(self)

    ssUtil.overwrittenFunction(PedestrianSystem, "update", ssPedestrianSystem.psUpdate)
end

function ssPedestrianSystem:deleteMap()
    g_seasons.environment:removeSeasonChangeListener(self)
end

function ssPedestrianSystem:loadGameFinished()
    self:seasonChanged()
end

function ssPedestrianSystem:seasonChanged()
    local season = g_seasons.environment:currentSeason()

    self.showPedestrians = not (season == g_seasons.environment.SEASON_WINTER)
end

function ssPedestrianSystem:psUpdate(superFunc, dt)
    local dayTime = g_currentMission.environment.dayTime

    if not ssPedestrianSystem.showPedestrians then
        dayTime = 0 -- midnight, do not spawn
    end

    setPedestrianSystemDaytime(self.pedestrianSystemId, dayTime);
end
