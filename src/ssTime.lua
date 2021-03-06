---------------------------------------------------------------------------------------------------------
-- TIME SCRIPT
---------------------------------------------------------------------------------------------------------
-- Purpose:  To adjust the day/night system
-- Authors:  Jarvixes
--

ssTime = {}

ssTime.latitude = 51.9
ssTime.settingsProperties = { "latitude" }

function ssTime.preSetup()
    ssSettings.add("time", ssTime)
end

function ssTime.setup()
    ssSettings.load("time", ssTime)

    addModEventListener(ssTime)
end

function ssTime:loadMap(name)
    -- Calculate some constants for the daytime calculator
    self.sunRad = ssTime.latitude * math.pi / 180
    self.pNight = 6 * math.pi / 180 -- Suns inclination below the horizon for 'civil twilight'
    self.pDay = -10 * math.pi / 180 -- Suns inclination above the horizon for 'daylight' assumed to be one degree above horizon

    -- Update time before game start to prevent sudden change of darkness
    self:adaptTime()

    g_currentMission.environment:addDayChangeListener(self);

    g_currentMission.missionInfo.timeScale = 120*6*2
end

function ssTime:deleteMap()
    -- g_currentMission.environment:removeDayChangeListener(self);
end

function ssTime:mouseEvent(posX, posY, isDown, isUp, button)
end

function ssTime:keyEvent(unicode, sym, modifier, isDown)
end

function ssTime:draw()
end

function ssTime:update(dt)
    -- Visual
    g_currentMission:addExtraPrintText(string.format("sun: %s, lights: %s", tostring(g_currentMission.environment.isSunOn), tostring(g_currentMission.environment.needsLights)))

    if ssSeasonsUtil then
        g_currentMission:addExtraPrintText("Season '"..ssSeasonsUtil:seasonName().."', day "..ssSeasonsUtil:currentDayNumber())
    end
end

-- Change the night/day times according to season
function ssTime:adaptTime()
    local env = g_currentMission.environment;

    -- All local values are in minutes
    local dayStart, dayEnd, nightEnd, nightStart = self:calculateStartEndOfDay(ssSeasonsUtil:currentDayNumber())
    -- local dayStart, dayEnd, nightEnd, nightStart = self:calculateStartEndOfDay(35) -- 15 = midsummer, 35 = midwinter

    -- Restrict the values to prevent errors
    nightEnd = math.max(nightEnd, 1.01) -- nightEnd > 1.0
    if dayStart == dayEnd then
        dayEnd = dayEnd + 0.01
    end
    nightStart = math.min(nightStart, 22.99) -- nightStart < 23

    -- GIANTS values:
    -- nightEnd: 4
    -- dayStart: 9
    -- dayEnd: 17
    -- nightStart: 22

    log(string.format("-- night --> %f -> %f -- day --> %f -> %f -- night -- >", nightEnd, dayStart, dayEnd, nightStart))

    -- This is for the logical night. Used for turning on lights in houses / streets. Might need some more adjustment.
    -- FIXME(jos): Maybe turn them on between the beginOfNight and fullNight?
    env.nightStart = dayStart * 60
    env.nightEnd = dayEnd * 60

    -- FIXME what is this for?
    env.skyDayTimeStart = nightEnd * 60 * 60 * 1000
    env.skyDayTimeEnd = dayEnd * 60 * 60 * 1000

    -- For the visual looks
    env.skyCurve = self:generateSkyCurve(nightEnd, dayStart, dayEnd, nightStart)
    env.ambientCurve = self:generateAmbientCurve(nightEnd, dayStart, dayEnd, nightStart)
    env.sunRotCurve = self:generateSunRotCurve(nightEnd, dayStart, dayEnd, nightStart)
    env.sunColorCurve = self:generateSunColorCurve(nightEnd, dayStart, dayEnd, nightStart)
    env.distanceFogCurve = self:generateDistanceFogCurve(nightEnd, dayStart, dayEnd, nightStart)


    self.lastUpdate = ssSeasonsUtil:currentDayNumber()
end

-- Output in hours
function ssTime:calculateStartEndOfDay(dayNumber)
    local dayStart, dayEnd, julianDay, theta, eta

    julianDay = ssSeasonsUtil:julianDay(dayNumber)

    -- Call radii for current day
    theta = 0.216 + 2 * math.atan(0.967 * math.tan(0.0086 * (julianDay - 186)))
    eta = math.asin(0.4 * math.cos(theta))

    -- Calculate the day
    dayStart, dayEnd = self:_calculateDay(self.pDay, eta, julianDay)

    -- True blackness
    nightStart, nightEnd = self:_calculateDay(self.pNight, eta, julianDay)

    return dayStart, dayEnd, nightStart, nightEnd
end

function ssTime:_calculateDay(p, eta, julianDay)
    local timeStart, timeEnd
    local D = 0, offset, hasDST
    local gamma = (math.sin(p) + math.sin(self.sunRad) * math.sin(eta)) / (math.cos(self.sunRad) * math.cos(eta))

    -- Account for polar day and night
    if gamma < -1 then
        D = 0
    elseif gamma > 1 then
        D = 24
    else
        D = 24 - 24 / math.pi * math.acos(gamma)
    end

    -- Daylight saving between 1 April and 31 October as an approcimation
    -- local hasDST = not ((julianDay < 91 or julianDay > 304) or ((julianDay >= 91 and julianDay <= 304) and (gamma < -1 or gamma > 1)))
    -- offset = hasDST and 1 or 0
    offset = 1

    timeStart = 12 - D / 2 + offset
    timeEnd = 12 + D / 2 + offset

    return timeStart, timeEnd
end

function ssTime:generateAmbientCurve(nightEnd, dayStart, dayEnd, nightStart)
    local curve = AnimCurve:new(linearInterpolator3) -- degree 2

    local morningStep = (dayStart - nightEnd) / 5
    local eveningStep = (nightStart - dayEnd) / 5

    curve:addKeyframe({x = 0.020, y = 0.020, z = 0.032, time = 0.00 * 60})
    curve:addKeyframe({x = 0.020, y = 0.020, z = 0.032, time = (nightEnd - 0.25 * morningStep) * 60})
    curve:addKeyframe({x = 0.065, y = 0.065, z = 0.075, time = (nightEnd + 0.01) * 60}) -- light up ambient to compensate for switch to sunlight
    curve:addKeyframe({x = 0.065, y = 0.065, z = 0.075, time = (nightEnd + 0.02) * 60})
    curve:addKeyframe({x = 0.040, y = 0.040, z = 0.060, time = (nightEnd + 0.25 * morningStep) * 60}) -- back to regular ambient settings
    curve:addKeyframe({x = 0.080, y = 0.080, z = 0.140, time = (nightEnd + 1 * morningStep) * 60})
    curve:addKeyframe({x = 0.140, y = 0.140, z = 0.120, time = (nightEnd + 2 * morningStep) * 60})
    curve:addKeyframe({x = 0.200, y = 0.200, z = 0.200, time = dayStart * 60})

    curve:addKeyframe({x = 0.200, y = 0.200, z = 0.200, time = dayEnd * 60})
    curve:addKeyframe({x = 0.160, y = 0.140, z = 0.160, time = (dayEnd + 1 * eveningStep) * 60})
    curve:addKeyframe({x = 0.020, y = 0.020, z = 0.032, time = (dayEnd + 4 * eveningStep) * 60}) -- ambient night
    curve:addKeyframe({x = 0.024, y = 0.024, z = 0.036, time = (nightStart - 0.15 * eveningStep) * 60})
    curve:addKeyframe({x = 0.072, y = 0.072, z = 0.088, time = (nightStart + 0.01) * 60}) -- light up ambient to compensate for switch to moonlight
    curve:addKeyframe({x = 0.072, y = 0.072, z = 0.088, time = (nightStart + 0.02) * 60})
    curve:addKeyframe({x = 0.020, y = 0.020, z = 0.032, time = (nightStart + 0.15 * eveningStep) * 60}) -- back to regular ambient settings
    curve:addKeyframe({x = 0.020, y = 0.020, z = 0.032, time = 24.00 * 60})

    return curve;
end

function ssTime:generateSunColorCurve(nightEnd, dayStart, dayEnd, nightStart)
    local curve = AnimCurve:new(linearInterpolator3) -- degree 2

    local morningStep = (dayStart - nightEnd) / 5
    local eveningStep = (nightStart - dayEnd) / 5

    curve:addKeyframe({x = 0.060, y = 0.070, z = 0.150, time = 0.00 * 60})
    curve:addKeyframe({x = 0.060, y = 0.070, z = 0.150, time = (nightEnd - 0.25 * morningStep) * 60})
    curve:addKeyframe({x = 0.000, y = 0.000, z = 0.000, time = (nightEnd + 0.01) * 60}) -- shift to brief complete darkness for switch to sunlight
    curve:addKeyframe({x = 0.000, y = 0.000, z = 0.000, time = (nightEnd + 0.02) * 60})
    curve:addKeyframe({x = 0.060, y = 0.050, z = 0.030, time = (nightEnd + 0.25 * morningStep) * 60})
    curve:addKeyframe({x = 0.700, y = 0.450, z = 0.350, time = (nightEnd + 2 * morningStep) * 60}) -- lighten, red
    curve:addKeyframe({x = 1.100, y = 0.850, z = 0.600, time = (nightEnd + 3 * morningStep) * 60}) -- shift to orange
    curve:addKeyframe({x = 0.750, y = 0.750, z = 0.750, time = dayStart * 60})

    curve:addKeyframe({x = 0.750, y = 0.750, z = 0.750, time = dayEnd * 60})
    curve:addKeyframe({x = 0.750, y = 0.700, z = 0.650, time = (dayEnd + 1 * eveningStep) * 60}) -- darken
    curve:addKeyframe({x = 1.000, y = 0.900, z = 0.300, time = (dayEnd + 2 * eveningStep) * 60}) -- orange sunset
    curve:addKeyframe({x = 0.900, y = 0.400, z = 0.100, time = (dayEnd + 3 * eveningStep) * 60}) -- shift to red
    curve:addKeyframe({x = 0.300, y = 0.250, z = 0.500, time = (dayEnd + 4 * eveningStep) * 60}) -- shift to blue
    curve:addKeyframe({x = 0.050, y = 0.060, z = 0.100, time = (nightStart - 0.15 * eveningStep) * 60})
    curve:addKeyframe({x = 0.000, y = 0.000, z = 0.000, time = (nightStart + 0.01) * 60}) -- shift to brief complete darkness for switch to moonlight
    curve:addKeyframe({x = 0.000, y = 0.000, z = 0.000, time = (nightStart + 0.02) * 60})
    curve:addKeyframe({x = 0.050, y = 0.060, z = 0.100, time = (nightStart + 0.15 * eveningStep) * 60})
    curve:addKeyframe({x = 0.060, y = 0.070, z = 0.150, time = 24.00 * 60}) -- shift to bluish darkness

    return curve
end

function ssTime:generateSkyCurve(nightEnd, dayStart, dayEnd, nightStart)
    local curve = AnimCurve:new(linearInterpolator4) -- degree 2

    local morningStep = (dayStart - nightEnd) / 10
    local eveningStep = (nightStart - dayEnd) / 5

    -- The sum of the 4 elements should always be 1
    -- x = daySky, y = eveningSky, z = nightSky, w = morningSky
    -- 4.5 -> 5.5 -> 6.0 = night morning transition
    -- 6.0 -> 7.0 -> 8.0 = morning day transition
    curve:addKeyframe({x = 0.0, y = 0.0, z = 1.0, w = 0.0, time = 0.0 * 60}) -- night
    curve:addKeyframe({x = 0.0, y = 0.0, z = 1.0, w = 0.0, time = (nightEnd + 1 * morningStep) * 60}) -- night
    curve:addKeyframe({x = 0.0, y = 0.0, z = 0.5, w = 0.5, time = (nightEnd + 3 * morningStep) * 60}) -- night/morning
    curve:addKeyframe({x = 0.0, y = 0.0, z = 0.0, w = 1.0, time = (nightEnd + 4 * morningStep) * 60}) -- morning
    curve:addKeyframe({x = 0.5, y = 0.0, z = 0.0, w = 0.5, time = (nightEnd + 6 * morningStep) * 60}) -- morning/day
    curve:addKeyframe({x = 1.0, y = 0.0, z = 0.0, w = 0.0, time = (nightEnd + 8 * morningStep) * 60}) -- day

    curve:addKeyframe({x = 1.0, y = 0.0, z = 0.0, w = 0.0, time = dayEnd * 60}) -- day
    curve:addKeyframe({x = 0.0, y = 1.0, z = 0.0, w = 0.0, time = (dayEnd + 2 * eveningStep) * 60}) -- evening
    curve:addKeyframe({x = 0.0, y = 1.0, z = 0.0, w = 0.0, time = (dayEnd + 3 * eveningStep) * 60}) -- evening
    curve:addKeyframe({x = 0.0, y = 0.0, z = 1.0, w = 0.0, time = nightStart * 60}) -- night
    curve:addKeyframe({x = 0.0, y = 0.0, z = 1.0, w = 0.0, time = 24.0 * 60}) -- night

    return curve
end

function ssTime:generateSunRotCurve(nightEnd, dayStart, dayEnd, nightStart)
    local curve = AnimCurve:new(linearInterpolator1) -- degree 2

    curve:addKeyframe({v = Utils.degToRad(-15), time = 0.00 * 60}) -- start (moon)
    curve:addKeyframe({v = Utils.degToRad(  0), time = 1.00 * 60}) -- 15 per hour
    curve:addKeyframe({v = Utils.degToRad( 45), time = nightEnd * 60}) -- 15 per hour
    curve:addKeyframe({v = Utils.degToRad( 45), time = (nightEnd + 0.01) * 60})
    curve:addKeyframe({v = Utils.degToRad(-70), time = (nightEnd + 0.02) * 60}) -- switch to Sun

    if dayStart > 12.0 then
        curve:addKeyframe({v = Utils.degToRad(0), time = dayStart * 60}) -- rotate over the day
    else
        curve:addKeyframe({v = Utils.degToRad(0), time = 12.00 * 60}) -- rotate over the day
    end

    curve:addKeyframe({v = Utils.degToRad( 70), time = (nightStart + 0.01) * 60}) -- end rotation of sun
    curve:addKeyframe({v = Utils.degToRad(-35), time = (nightStart + 0.02) * 60}) -- switch to moon light
    curve:addKeyframe({v = Utils.degToRad(-15), time = 24.00 * 60}) -- 10 per hour

    return curve
end

function ssTime:generateDistanceFogCurve(nightEnd, dayStart, dayEnd, nightStart)
    local curve = AnimCurve:new(linearInterpolator4) -- degree 2

    local ex = function(rgb)
        return (rgb/255)^2.2
    end

    local morningStep = (dayStart - nightEnd) / 5
    local eveningStep = (nightStart - dayEnd) / 5

    -- Nothing at night (darkness)
    -- When dawn, go red-ish. At 8AM go blue (compensate), at 9AM blue but less intense
    -- Do reverse in the evening,
    curve:addKeyframe({x = 0, y = 0, z = 0, w = 0.003, time = 0 * 60}) -- night
    curve:addKeyframe({x = ex(010), y = ex(012), z = ex(015), w = 0.0008, time = (nightEnd + 1 * morningStep) * 60})
    curve:addKeyframe({x = ex(085), y = ex(060), z = ex(055), w = 0.0006, time = (nightEnd + 2 * morningStep) * 60})
    curve:addKeyframe({x = ex(085), y = ex(070), z = ex(065), w = 0.0005, time = (nightEnd + 3 * morningStep) * 60})
    curve:addKeyframe({x = ex(105), y = ex(130), z = ex(150), w = 0.0006, time = (nightEnd + 4 * morningStep) * 60})
    curve:addKeyframe({x = ex(105), y = ex(130), z = ex(150), w = 0.0003, time = dayStart * 60})

    curve:addKeyframe({x = ex(105), y = ex(130), z = ex(150), w = 0.0003, time = dayEnd * 60})
    curve:addKeyframe({x = ex(070), y = ex(045), z = ex(030), w = 0.0004, time = (dayEnd + 2 * eveningStep) * 60})
    curve:addKeyframe({x = ex(045), y = ex(040), z = ex(050), w = 0.0006, time = (dayEnd + 3 * eveningStep) * 60})
    curve:addKeyframe({x = ex(020), y = ex(020), z = ex(030), w = 0.0008, time = (dayEnd + 4 * eveningStep) * 60})
    curve:addKeyframe({x = 0, y = 0, z = 0, w = 0.003, time = nightStart * 60}) -- night

    return curve
end

function ssTime:dayChanged()
    -- Update the time of the day
    self:adaptTime();
end
