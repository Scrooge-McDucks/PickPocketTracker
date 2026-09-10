# DirectorCam

A personal camera-operator addon for capturing WoW footage: orbits, dollies
and cranes with a real acceleration/deceleration curve, framing set from real
camera lens math, and radius/angle controls grounded in numbers your own
client actually measured rather than guessed slider positions.

It's the movement half of a toolkit like EmberCam, without the screenshot
viewfinder, aspect-ratio crops or filters - this is for footage, not stills,
and the plan is to record it with external capture software while
DirectorCam drives the camera hands-free.

## Why it's built this way

WoW's addon API only exposes the camera as three relative, speed-driven
holds (`MoveViewLeftStart`, `MoveViewUpStart`, `MoveViewInStart` and their
opposites/stops) - there is no "set yaw to 47 degrees" call, and no getter
for the current yaw or pitch at all. The one exception is zoom: the client
*will* tell you the current camera distance (`GetCameraZoom`), and lets you
nudge it by an exact amount (`CameraZoomIn`/`CameraZoomOut`).

DirectorCam leans on that split:

- **Radius is closed-loop.** `/dcam radius 8` reads the current distance and
  nudges toward 8 yards until it's within tolerance - it's driving to a real,
  verified number, not holding a key and hoping.
- **Yaw and pitch are dead reckoning, calibrated against your own client.**
  There's no way to read the actual angle, so DirectorCam times how long a
  full-speed turn takes and asks *you* to tell it how far that really went
  (a full 360 orbit is the easy one to eyeball) - the same technique a real
  camera grip uses with a stopwatch and marks on the floor instead of a
  digital readout. Run `/dcam calibrate yaw <seconds>` once, and every
  degree-based command after that is computed from your measured rate
  instead of a guess. Skipped calibration still works, it just uses a
  placeholder rate and says so in `/dcam status`.
- **Lens choices are real optics.** `/dcam lens 85` doesn't pick a point on a
  slider - it takes 85mm as a real full-frame-equivalent focal length and
  computes the horizontal FOV a lens like that actually produces
  (`2 * atan(18 / mm)` in degrees), then sets the client's FOV to match.
- **Moves ease like a motion-control rig.** Every timed move ramps speed up
  and back down over a fraction of its duration (a trapezoidal/S-curve
  velocity profile) instead of snapping to full speed - the same shape real
  gimbal and dolly rigs use so a shot doesn't start or stop on a hard cut.

## Getting started

1. `/dcam lens 50` - or any mm value - to set a real focal length.
2. Turn your camera to what you'd call eye level, then `/dcam mark eyelevel`.
3. `/dcam calibrate yaw 12` after timing a 360-degree orbit at default speed
   by eye (run `/dcam orbit 360` with a stopwatch once, or just estimate;
   redo it any time for a better number). Optionally `/dcam calibrate pitch`
   the same way if you want pitch timed separately from yaw.
4. `/dcam radius 8` to set an exact orbit distance.
5. `/dcam orbit` for a full eased loop, or `/dcam reveal 90 20 6` for a
   90-degree orbit while pulling back to 20 yards over 6 seconds.

## Slash commands

| Command | |
|---|---|
| `/dcam lens <mm\|preset\|list>` | set FOV from a real focal length |
| `/dcam mark eyelevel` | set the camera's current pitch as your 0 deg reference |
| `/dcam angle <worm\|low\|eye\|high\|bird\|deg>` | pitch to a marked angle |
| `/dcam radius <yards>` | zoom to an exact orbit radius (closed-loop) |
| `/dcam orbit [degrees=360] [seconds]` | eased orbit around the current radius |
| `/dcam dolly <yards> [seconds=4]` | move to an exact radius over time |
| `/dcam crane <+/-degrees> [seconds]` | eased pitch move |
| `/dcam reveal <degrees> <yards> [seconds=8]` | orbit and pull back together |
| `/dcam stop` | stop every active camera move |
| `/dcam calibrate yaw\|pitch <seconds> [degrees=360]` | measure your real turn rate |
| `/dcam status` | show lens, calibration and the current move |
| `/dcam reset` | restore default settings |

`/directorcam` works as a longer alias.

## Key bindings

Under the **DirectorCam** category in the game's key bindings: toggle the
default orbit, stop all movement, mark eye level, jump to the low/eye/high
angle marks, and step to the next/previous lens preset.

## Honesty about the limits

- Angle numbers are estimates. Without a real angle readout, `/dcam angle`
  and `/dcam crane` are timed moves based on your calibration, not a
  guaranteed absolute pitch. Hand-adjusting the camera with the mouse will
  desync the tracked offset from eye level - re-run `/dcam mark eyelevel`
  after you do.
- Orbit/crane degree targets assume the Start-speed parameter scales
  linearly with turn rate (i.e. speed 0.5 turns half as fast as speed 1.0).
  That's the simplest honest assumption and it's what the calibration
  measures against, but it isn't a documented guarantee from Blizzard.
- Radius and lens are the two numbers you can actually trust exactly,
  since those have real client-side readouts/formulas behind them.
