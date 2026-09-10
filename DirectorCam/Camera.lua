local _, DC = ...

local Camera = {}
DC.Camera = Camera

local function SetCVarSafe(cvar, value)
    pcall(SetCVar, cvar, value)
end

-- Axis control -------------------------------------------------------------
-- WoW only exposes the view as relative, speed-driven axes (no getter for
-- current yaw/pitch), so everything above this layer is dead reckoning built
-- on top of these three holds.

local AXIS = {
    yaw = {
        LEFT  = { MoveViewLeftStart,  MoveViewLeftStop  },
        RIGHT = { MoveViewRightStart, MoveViewRightStop },
    },
    pitch = {
        UP   = { MoveViewUpStart,   MoveViewUpStop   },
        DOWN = { MoveViewDownStart, MoveViewDownStop },
    },
    zoom = {
        IN  = { MoveViewInStart,  MoveViewInStop  },
        OUT = { MoveViewOutStart, MoveViewOutStop },
    },
}

local active = {}

function Camera.StopAxis(axis)
    local dir = active[axis]
    if dir then
        AXIS[axis][dir][2]()
        active[axis] = nil
    end
end

-- Re-calling Start on the same direction just updates its speed, which is how
-- the eased shots in Shots.lua ramp a move without a stutter every tick.
function Camera.StartAxis(axis, dir, speed)
    if active[axis] and active[axis] ~= dir then
        Camera.StopAxis(axis)
    end
    AXIS[axis][dir][1](speed)
    active[axis] = dir
end

function Camera.StopAll()
    for axis in pairs(AXIS) do Camera.StopAxis(axis) end
end

function Camera.IsActive(axis)
    return active[axis] ~= nil
end

-- Zoom / radius --------------------------------------------------------------
-- Unlike yaw/pitch, the game *does* report camera distance in yards, so radius
-- is the one axis DirectorCam can drive closed-loop instead of by dead
-- reckoning: nudge, read back, repeat until within tolerance.

function Camera.CurrentRadius()
    if not GetCameraZoom then return nil end
    local ok, zoom = pcall(GetCameraZoom)
    if ok then return zoom end
    return nil
end

local radiusToken = 0

-- Converges toward targetYards by repeated small nudges, then calls
-- onDone(finalRadius) - or onDone(nil) if this client has no zoom readback.
function Camera.SetRadius(targetYards, onDone)
    if not (GetCameraZoom and CameraZoomIn and CameraZoomOut) then
        DC:Print("this client doesn't expose camera zoom readback, can't set an exact radius.")
        if onDone then onDone(nil) end
        return
    end

    radiusToken = radiusToken + 1
    local token = radiusToken
    local tolerance = DC:Get("radiusTolerance")
    local attempts = 0

    local function Step()
        if token ~= radiusToken then return end
        attempts = attempts + 1
        local current = Camera.CurrentRadius()
        if not current then if onDone then onDone(nil) end return end

        local diff = targetYards - current
        if math.abs(diff) <= tolerance or attempts > 60 then
            if onDone then onDone(current) end
            return
        end

        -- Bigger nudges further out, smaller close in, so it doesn't hunt
        -- forever around the target.
        local step = math.min(math.abs(diff), math.max(0.05, math.abs(diff) * 0.5))
        if diff > 0 then CameraZoomOut(step) else CameraZoomIn(step) end
        C_Timer.After(0.05, Step)
    end
    Step()
end

-- Pitch dead reckoning -------------------------------------------------------

function Camera.PitchOffset()
    return DC:Get("pitchOffsetDeg")
end

function Camera.MarkEyeLevel()
    DC:Set("pitchOffsetDeg", 0)
    DC:Print("eye level marked. Angle presets are now relative to the camera's current pitch.")
end

-- Drives pitch for the duration needed to move `degrees` (signed, + is up)
-- at the calibrated rate, updating the tracked offset as it goes.
function Camera.NudgePitch(degrees, onDone)
    local rate = DC:PitchRate()
    if rate <= 0 or degrees == 0 then if onDone then onDone() end return end

    local duration = math.abs(degrees) / rate
    local dir = degrees > 0 and "UP" or "DOWN"
    Camera.StartAxis("pitch", dir, 1.0)
    C_Timer.After(duration, function()
        Camera.StopAxis("pitch")
        DC:Set("pitchOffsetDeg", DC:Get("pitchOffsetDeg") + degrees)
        if onDone then onDone() end
    end)
end

-- Calibration ----------------------------------------------------------------
-- The game never tells us how many degrees a given Start-speed actually
-- turns per second, so we measure it: run a full-speed turn for a length of
-- time the user times by eye (e.g. a full 360 orbit, or pitching between two
-- landmarks) and tell us the result. Same technique a real grip uses with a
-- stopwatch and marks on the floor rather than an angle readout.

function Camera.CalibrateYaw(measuredSeconds, degreesTurned)
    degreesTurned = degreesTurned or 360
    if measuredSeconds <= 0 then
        DC:Print("calibrate yaw needs a positive number of seconds.")
        return
    end
    local rate = degreesTurned / measuredSeconds
    DC:Set("yawDegPerSec", rate)
    DC:Set("yawCalibrated", true)
    DC:Print(string.format("yaw calibrated: %.2f deg/sec at Start-speed 1.0.", rate))
end

function Camera.CalibratePitch(measuredSeconds, degreesTurned)
    if measuredSeconds <= 0 then
        DC:Print("calibrate pitch needs a positive number of seconds.")
        return
    end
    local rate = degreesTurned / measuredSeconds
    DC:Set("pitchDegPerSec", rate)
    DC:Set("pitchCalibrated", true)
    DC:Print(string.format("pitch calibrated: %.2f deg/sec at Start-speed 1.0.", rate))
end

function Camera.ReleaseAll()
    Camera.StopAll()
end

-- Commands -------------------------------------------------------------

DC:Command("mark", function(what)
    what = (what or "eyelevel"):lower()
    if what ~= "eyelevel" and what ~= "eye" then
        DC:Print("only 'eyelevel' can be marked right now: /dcam mark eyelevel")
        return
    end
    Camera.MarkEyeLevel()
end, "eyelevel - set the camera's current pitch as your 0 deg reference")

DC:Command("angle", function(target)
    if not target then
        DC:Print(string.format("current offset from eye level: %.1f deg.", Camera.PitchOffset()))
        return
    end
    local degrees = DC.ANGLE_MARKS[target:lower()]
    if not degrees then
        degrees = tonumber(target)
        if not degrees then
            DC:Print("angle needs a preset (worm/low/eye/high/bird) or a number of degrees.")
            return
        end
    end
    local delta = degrees - Camera.PitchOffset()
    if math.abs(delta) < 0.05 then
        DC:Print("already there.")
        return
    end
    Camera.NudgePitch(delta, function()
        DC:Print(string.format("pitched to %.1f deg from eye level.", degrees))
    end)
end, "<worm|low|eye|high|bird|deg> - pitch to a marked angle (needs /dcam mark eyelevel first)")

DC:Command("radius", function(yards)
    yards = tonumber(yards)
    if not yards or yards <= 0 then
        local current = Camera.CurrentRadius()
        DC:Print(current and string.format("current radius: %.2f yd.", current) or "radius needs a positive number of yards.")
        return
    end
    Camera.SetRadius(yards, function(final)
        if final then
            DC:Print(string.format("radius set to %.2f yd (target %.2f).", final, yards))
        end
    end)
end, "<yards> - zoom to an exact orbit radius, reads back to converge")

DC:Command("calibrate", function(axis, seconds, degrees)
    axis = (axis or ""):lower()
    seconds = tonumber(seconds)
    degrees = tonumber(degrees) or 360
    if axis == "yaw" and seconds then
        Camera.CalibrateYaw(seconds, degrees)
    elseif axis == "pitch" and seconds then
        Camera.CalibratePitch(seconds, degrees)
    else
        DC:Print("usage: /dcam calibrate yaw <seconds> [degrees=360]")
        DC:Print("       /dcam calibrate pitch <seconds> <degrees>")
        DC:Print("Time a full orbit (or a pitch move between two known landmarks) by eye, then tell DirectorCam how long it took.")
    end
end, "yaw|pitch <seconds> [degrees] - measure your client's real turn rate")
