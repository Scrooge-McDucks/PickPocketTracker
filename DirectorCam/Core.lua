local ADDON, DC = ...

DC.VERSION = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "0"
DC.PREFIX_HEX = "|cff4fa8ffDirectorCam|r"

function DC:Print(msg)
    print(DC.PREFIX_HEX .. " " .. msg)
end

-- Keybinding labels, read by the game's key bindings panel.
BINDING_NAME_DIRECTORCAM_ORBIT_TOGGLE  = "DirectorCam: Toggle Default Orbit"
BINDING_NAME_DIRECTORCAM_STOP_ALL      = "DirectorCam: Stop All Movement"
BINDING_NAME_DIRECTORCAM_MARK_EYELEVEL = "DirectorCam: Mark Eye Level"
BINDING_NAME_DIRECTORCAM_ANGLE_LOW     = "DirectorCam: Angle - Low"
BINDING_NAME_DIRECTORCAM_ANGLE_EYE     = "DirectorCam: Angle - Eye Level"
BINDING_NAME_DIRECTORCAM_ANGLE_HIGH    = "DirectorCam: Angle - High"
BINDING_NAME_DIRECTORCAM_LENS_NEXT     = "DirectorCam: Next Lens"
BINDING_NAME_DIRECTORCAM_LENS_PREV     = "DirectorCam: Previous Lens"

-- Saved settings. Anything not listed here is pruned from the DB on load, so
-- a stale key from an older version never lingers silently.
DC.defaults = {
    -- Lens
    lensMM              = 50,      -- last focal length applied (real-world mm, full-frame equivalent)

    -- Calibration: degrees turned per second of game time at Start-speed 1.0.
    -- These are placeholders until you run `/dcam calibrate` - see README.
    -- Camera moves derived from them are only as accurate as the calibration.
    yawDegPerSec        = 26,
    yawCalibrated       = false,
    pitchDegPerSec      = nil,     -- nil = reuse yawDegPerSec until calibrated separately
    pitchCalibrated     = false,

    -- Where "eye level" is, tracked relative to the last time you marked it.
    -- This is dead reckoning (we sum the degrees we've driven the pitch axis
    -- ourselves) - it has no way to see the actual camera angle, so it drifts
    -- if you hand-adjust pitch with the mouse. Re-mark when that happens.
    pitchOffsetDeg      = 0,

    -- Motion-control style velocity profile: fraction of a move's duration
    -- spent ramping speed up/down at each end (trapezoidal/S-curve), rather
    -- than snapping to full speed like a held key. 0 = no ramp (instant).
    rampFraction        = 0.25,

    -- How close CameraZoomIn/Out has to land to the requested yard distance
    -- before the closed-loop radius convergence calls it done.
    radiusTolerance     = 0.05,

    defaultOrbitDegrees = 360,
}

DC.ANGLE_MARKS = {
    worm = -35,
    low  = -15,
    eye  = 0,
    high = 20,
    bird = 45,
}

local PRESERVED = { version = true }

function DC:InitDB()
    DirectorCamDB = DirectorCamDB or {}
    local db = DirectorCamDB

    for key, value in pairs(self.defaults) do
        if db[key] == nil then db[key] = value end
    end
    for key in pairs(db) do
        if self.defaults[key] == nil and not PRESERVED[key] then db[key] = nil end
    end

    db.version = self.VERSION
    self.db = db
end

function DC:Get(key) return self.db[key] end
function DC:Set(key, value) self.db[key] = value end

function DC:YawRate()
    return self.db.yawDegPerSec
end

function DC:PitchRate()
    return self.db.pitchDegPerSec or self.db.yawDegPerSec
end

-- Slash command routing ---------------------------------------------------

local function splitArgs(msg)
    local words = {}
    for w in msg:gmatch("%S+") do words[#words + 1] = w end
    return words
end

local COMMANDS = {}

function DC:Command(name, fn, help)
    COMMANDS[name] = { fn = fn, help = help }
end

local function PrintHelp()
    DC:Print("commands:")
    -- Stable order, not table iteration order.
    local order = {
        "lens", "angle", "mark", "radius",
        "orbit", "dolly", "crane", "reveal", "stop",
        "calibrate", "status", "reset", "help",
    }
    for _, name in ipairs(order) do
        local cmd = COMMANDS[name]
        if cmd then print("  |cff4fa8ff/dcam " .. name .. "|r - " .. cmd.help) end
    end
end
DC:Command("help", PrintHelp, "show this list")

local function HandleSlash(msg)
    local words = splitArgs(msg or "")
    local name = table.remove(words, 1)
    if not name then
        DC.Shots.PrintStatus()
        return
    end
    name = name:lower()
    local cmd = COMMANDS[name]
    if not cmd then
        DC:Print("unknown command '" .. name .. "'. Try /dcam help.")
        return
    end
    cmd.fn(unpack(words))
end

SLASH_DIRECTORCAM1 = "/dcam"
SLASH_DIRECTORCAM2 = "/directorcam"
SlashCmdList.DIRECTORCAM = HandleSlash

-- Keybinding entry points --------------------------------------------------
-- These read DC.Camera/DC.Shots/DC.Lens through the closure at call time, so
-- it doesn't matter that this file loads before those modules exist.

function DirectorCam_ToggleOrbit()
    if DC.Camera.IsActive("yaw") then
        DC.Shots.Stop()
    else
        DC.Shots.Orbit()
    end
end

function DirectorCam_StopAll()
    DC.Shots.Stop()
end

function DirectorCam_MarkEyeLevel()
    DC.Camera.MarkEyeLevel()
end

local function GoToAngle(name)
    local degrees = DC.ANGLE_MARKS[name]
    local delta = degrees - DC.Camera.PitchOffset()
    DC.Camera.NudgePitch(delta, function()
        DC:Print(string.format("pitched to %.1f deg from eye level.", degrees))
    end)
end

function DirectorCam_AngleLow()  GoToAngle("low")  end
function DirectorCam_AngleEye()  GoToAngle("eye")  end
function DirectorCam_AngleHigh() GoToAngle("high") end

function DirectorCam_LensNext() DC.Lens.Cycle(1) end
function DirectorCam_LensPrev() DC.Lens.Cycle(-1) end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, _, addon)
    if addon ~= ADDON then return end
    DC:InitDB()
    DC.Lens.Init()
    DC:Print("loaded. /dcam help to get started, /dcam calibrate before trusting any degree numbers.")
end)
