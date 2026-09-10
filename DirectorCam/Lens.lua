local _, DC = ...

local Lens = {}
DC.Lens = Lens

-- Real optics, not tuned-by-eye numbers: horizontal FOV for a full-frame
-- (36mm-wide sensor) lens of a given focal length is
--   hfov = 2 * atan( (sensorWidth/2) / focalLength )
-- WoW's camera FOV cvar (test_cameraFov) takes a horizontal FOV in degrees,
-- so we can put an actual mm value in and get the degrees that lens would
-- really produce, rather than a guessed slider position.
local SENSOR_WIDTH_MM = 36

local function FovForFocalLength(mm)
    return 2 * math.deg(math.atan((SENSOR_WIDTH_MM / 2) / mm))
end
Lens.FovForFocalLength = FovForFocalLength

-- A spread of common real photo/cine focal lengths, full-frame equivalent.
Lens.PRESETS = {
    { mm = 14,  name = "14mm",  desc = "Ultra-wide, distorted edges"        },
    { mm = 18,  name = "18mm",  desc = "Wide establishing"                  },
    { mm = 24,  name = "24mm",  desc = "Wide, minimal distortion"           },
    { mm = 35,  name = "35mm",  desc = "Reportage / environmental"          },
    { mm = 50,  name = "50mm",  desc = "Natural, human-eye-ish"             },
    { mm = 85,  name = "85mm",  desc = "Portrait, background compression"   },
    { mm = 105, name = "105mm", desc = "Tight portrait"                     },
    { mm = 135, name = "135mm", desc = "Long, heavy compression"            },
    { mm = 200, name = "200mm", desc = "Telephoto"                          },
}

local PRESET_BY_NAME = {}
for _, p in ipairs(Lens.PRESETS) do
    PRESET_BY_NAME[p.name:lower()] = p
    PRESET_BY_NAME[tostring(p.mm)] = p
end

-- The engine's own zoom slider tops out well short of true wide, and there is
-- no documented floor either; clamp to something sane rather than trust an
-- unbounded CVar write.
local MIN_FOV, MAX_FOV = 5, 150

function Lens.Apply(mm)
    mm = tonumber(mm)
    if not mm or mm <= 0 then
        DC:Print("lens needs a positive focal length in mm.")
        return
    end
    local fov = FovForFocalLength(mm)
    if fov < MIN_FOV or fov > MAX_FOV then
        DC:Print(string.format("%gmm works out to %.1f deg FOV, outside what the client will accept (%d-%d).", mm, fov, MIN_FOV, MAX_FOV))
        return
    end
    pcall(SetCVar, "test_cameraFov", fov)
    DC:Set("lensMM", mm)
    DC:Print(string.format("%gmm equiv -> %.1f deg horizontal FOV.", mm, fov))
end

function Lens.ApplyPreset(nameOrMM)
    local preset = PRESET_BY_NAME[tostring(nameOrMM):lower()]
    if preset then
        Lens.Apply(preset.mm)
    else
        Lens.Apply(nameOrMM)
    end
end

function Lens.PrintList()
    DC:Print("lens presets (real focal length -> horizontal FOV):")
    for _, p in ipairs(Lens.PRESETS) do
        print(string.format("  |cff4fa8ff%-5s|r %5.1f deg  %s", p.name, FovForFocalLength(p.mm), p.desc))
    end
end

-- Reapply whatever lens was last set, since the FOV cvar doesn't persist
-- itself the way our saved variable does.
function Lens.Init()
    local mm = DC:Get("lensMM")
    if mm then Lens.Apply(mm) end
end

-- Steps to the next/previous preset in Lens.PRESETS relative to the closest
-- match for the current lens, for the next/prev-lens key bindings.
function Lens.Cycle(direction)
    local current = DC:Get("lensMM")
    local index = 1
    local bestDiff = math.huge
    for i, p in ipairs(Lens.PRESETS) do
        local diff = math.abs(p.mm - current)
        if diff < bestDiff then bestDiff, index = diff, i end
    end
    index = ((index - 1 + direction) % #Lens.PRESETS) + 1
    Lens.Apply(Lens.PRESETS[index].mm)
end

DC:Command("lens", function(arg)
    if not arg or arg == "" then
        DC:Print(string.format("current lens: %gmm.", DC:Get("lensMM")))
        return
    end
    if arg:lower() == "list" then Lens.PrintList() return end
    Lens.ApplyPreset(arg)
end, "<mm|preset|list> - set FOV from a real focal length, e.g. /dcam lens 85")
