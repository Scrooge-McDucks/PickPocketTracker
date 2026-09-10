local _, DC = ...
local Camera = DC.Camera

local Shots = {}
DC.Shots = Shots

-- Velocity profile: a trapezoidal / S-curve ramp, the same shape real motion-
-- control camera rigs use so a move doesn't snap to speed or slam to a stop.
-- t is progress through the move (0..1), rampFraction is how much of that
-- gets spent easing in and out (the rest runs at full speed).
local function smoothstep(u)
    return u * u * (3 - 2 * u)
end

local function velocityProfile(t, rampFraction)
    if rampFraction <= 0 then return 1.0 end
    if t < rampFraction then
        return smoothstep(t / rampFraction)
    elseif t > 1 - rampFraction then
        return smoothstep((1 - t) / rampFraction)
    end
    return 1.0
end

-- Average of the profile over [0,1] with a smoothstep ramp of width
-- rampFraction at each end is (1 - rampFraction): the two ramps integrate to
-- half their width each, the cruise section runs at 1. Used to turn a target
-- angle into a duration at a calibrated rate.
local function averageSpeedFactor(rampFraction)
    return 1 - rampFraction
end

-- A position curve for target-seeking moves (dolly), same ease shape but
-- expressed cumulatively rather than as an instantaneous rate.
local function smootherstep(t)
    return t * t * t * (t * (t * 6 - 15) + 10)
end

-- Bumping this cancels every ticker in flight - Stop() and starting a new
-- shot both do it, so overlapping moves never fight over the same axis.
Shots.generation = 0

local function NewGeneration()
    Shots.generation = Shots.generation + 1
    return Shots.generation
end

local activeDescription = nil

local function RunAxisDegrees(axis, totalDegrees, duration, rampFraction, gen, onDone)
    if totalDegrees == 0 then if onDone then onDone() end return end

    local rate = axis == "yaw" and DC:YawRate() or DC:PitchRate()
    duration = duration or (math.abs(totalDegrees) / math.max(0.01, rate * averageSpeedFactor(rampFraction)))

    local positive = totalDegrees > 0
    local dir = axis == "yaw"
        and (positive and "LEFT" or "RIGHT")
        or (positive and "UP" or "DOWN")

    local elapsed = 0
    local function Tick()
        if gen ~= Shots.generation then return end
        elapsed = elapsed + 0.05
        local t = math.min(1, elapsed / duration)
        local speed = velocityProfile(t, rampFraction)
        Camera.StartAxis(axis, dir, speed)
        if t >= 1 then
            Camera.StopAxis(axis)
            if axis == "pitch" then
                DC:Set("pitchOffsetDeg", DC:Get("pitchOffsetDeg") + totalDegrees)
            end
            if onDone then onDone() end
        else
            C_Timer.After(0.05, Tick)
        end
    end
    Tick()
end

local function DollyTo(targetYards, duration, rampFraction, gen, onDone)
    local start = Camera.CurrentRadius()
    if not start or not (CameraZoomIn and CameraZoomOut) then
        DC:Print("no zoom control on this client, can't dolly to an exact distance.")
        if onDone then onDone() end
        return
    end

    local elapsed = 0
    local function Tick()
        if gen ~= Shots.generation then return end
        elapsed = elapsed + 0.05
        local t = math.min(1, elapsed / duration)
        local wantRadius = start + (targetYards - start) * smootherstep(t)
        local current = Camera.CurrentRadius() or wantRadius
        local diff = wantRadius - current
        if math.abs(diff) > 0.02 then
            local step = math.min(math.abs(diff), 0.3)
            if diff > 0 then CameraZoomOut(step) else CameraZoomIn(step) end
        end
        if t >= 1 then
            Camera.SetRadius(targetYards, onDone)
        else
            C_Timer.After(0.05, Tick)
        end
    end
    Tick()
end

function Shots.Stop()
    NewGeneration()
    Camera.StopAll()
    activeDescription = nil
    DC:Print("stopped.")
end

-- Orbit: pure yaw around whatever radius you're currently at (radius is
-- yours to set first with /dcam radius). Degrees default to a full loop.
function Shots.Orbit(degrees, seconds)
    degrees = tonumber(degrees) or DC:Get("defaultOrbitDegrees")
    seconds = tonumber(seconds)
    local rampFraction = DC:Get("rampFraction")
    local gen = NewGeneration()
    activeDescription = string.format("orbit %g deg", degrees)
    DC:Print(string.format("orbiting %g deg%s...", degrees, seconds and (" over " .. seconds .. "s") or ""))
    RunAxisDegrees("yaw", degrees, seconds, rampFraction, gen, function()
        if gen == Shots.generation then
            activeDescription = nil
            DC:Print("orbit complete.")
        end
    end)
end

-- Dolly: closed-loop move to an exact yard distance over a duration.
function Shots.Dolly(targetYards, seconds)
    targetYards = tonumber(targetYards)
    seconds = tonumber(seconds) or 4
    if not targetYards or targetYards <= 0 then
        DC:Print("dolly needs a target radius in yards: /dcam dolly <yards> [seconds]")
        return
    end
    local gen = NewGeneration()
    activeDescription = string.format("dolly to %g yd", targetYards)
    DC:Print(string.format("dollying to %g yd over %gs...", targetYards, seconds))
    DollyTo(targetYards, seconds, DC:Get("rampFraction"), gen, function(final)
        if gen == Shots.generation then
            activeDescription = nil
            if final then DC:Print(string.format("dolly complete, %.2f yd.", final)) end
        end
    end)
end

-- Crane: pitch through a number of degrees over a duration - same eased
-- axis-degrees mover as orbit, just on pitch instead of yaw.
function Shots.Crane(degrees, seconds)
    degrees = tonumber(degrees)
    if not degrees then
        DC:Print("crane needs signed degrees (+ up, - down): /dcam crane <deg> [seconds]")
        return
    end
    seconds = tonumber(seconds)
    local gen = NewGeneration()
    activeDescription = string.format("crane %g deg", degrees)
    DC:Print(string.format("craning %g deg%s...", degrees, seconds and (" over " .. seconds .. "s") or ""))
    RunAxisDegrees("pitch", degrees, seconds, DC:Get("rampFraction"), gen, function()
        if gen == Shots.generation then
            activeDescription = nil
            DC:Print("crane complete.")
        end
    end)
end

-- Reveal: orbit and dolly out at once - the classic "pull back and around".
function Shots.Reveal(degrees, pullToYards, seconds)
    degrees = tonumber(degrees) or DC:Get("defaultOrbitDegrees")
    pullToYards = tonumber(pullToYards)
    seconds = tonumber(seconds) or 8
    if not pullToYards or pullToYards <= 0 then
        DC:Print("reveal needs a pull-back radius: /dcam reveal <deg> <yards> [seconds]")
        return
    end

    local gen = NewGeneration()
    activeDescription = string.format("reveal %g deg / %g yd", degrees, pullToYards)
    DC:Print(string.format("revealing: %g deg over %gs while pulling to %g yd...", degrees, seconds, pullToYards))

    local remaining = 2
    local function OneDone()
        remaining = remaining - 1
        if remaining == 0 and gen == Shots.generation then
            activeDescription = nil
            DC:Print("reveal complete.")
        end
    end
    RunAxisDegrees("yaw", degrees, seconds, DC:Get("rampFraction"), gen, OneDone)
    DollyTo(pullToYards, seconds, DC:Get("rampFraction"), gen, OneDone)
end

function Shots.PrintStatus()
    DC:Print("status:")
    print(string.format("  lens: %gmm", DC:Get("lensMM")))
    print(string.format("  yaw rate: %.2f deg/sec%s", DC:YawRate(), DC:Get("yawCalibrated") and "" or "  |cffff8080(uncalibrated placeholder)|r"))
    print(string.format("  pitch rate: %.2f deg/sec%s", DC:PitchRate(), DC:Get("pitchCalibrated") and "" or "  |cffff8080(uncalibrated, reusing yaw)|r"))
    print(string.format("  angle offset from eye level: %.1f deg", Camera.PitchOffset()))
    local radius = Camera.CurrentRadius()
    print("  radius: " .. (radius and string.format("%.2f yd", radius) or "no zoom readback"))
    print("  active shot: " .. (activeDescription or "none"))
end

DC:Command("orbit", Shots.Orbit, "[degrees=360] [seconds] - eased orbit around current radius")
DC:Command("dolly", Shots.Dolly, "<yards> [seconds=4] - move to an exact orbit radius")
DC:Command("crane", Shots.Crane, "<+/-degrees> [seconds] - eased pitch move")
DC:Command("reveal", Shots.Reveal, "<degrees> <yards> [seconds=8] - orbit + pull back together")
DC:Command("stop", Shots.Stop, "stop every active camera move")
DC:Command("status", Shots.PrintStatus, "show lens, calibration and current move")
DC:Command("reset", function()
    for key, value in pairs(DC.defaults) do DC:Set(key, value) end
    DC.Lens.Init()
    DC:Print("settings reset to defaults.")
end, "restore default settings")
