# ControllerCam

Camera profiles for **World of Warcraft: Forever**, made for playing with a controller. Install it and you get an **Action camera** straight away: a close third-person view over your shoulder, head tracking, and a camera that follows where you run. Prefer something calmer? `/ccam use hybrid` or `/ccam use classic` and you are there. Every situation (mounted, combat, raid, city, ...) can use its own profile.

> **Status: 1.0.0, not yet played in the game.** The addon was written against the CVar names found in the Forever client and is covered by automated tests with a mocked game API, but nobody has tuned it on a live character yet. Expect to adjust the numbers. See [What is not verified](#what-is-not-verified).

## Install

Copy the `ControllerCam` folder into `World of Warcraft\_forever_\Interface\AddOns\`, or install the release zip with WoWUp (GitHub source). **Turn off DynamicCam** (or any other camera addon): two addons changing the same camera settings fight each other. ControllerCam prints a warning if it finds DynamicCam loaded.

## Quick start

| Command | What it does |
| --- | --- |
| `/ccam use action` | Action camera everywhere |
| `/ccam use hybrid` | Between Classic and Action |
| `/ccam use classic` | The game's own camera |
| `/ccam starter` | The recommended mix (default for a new install): Action, with calmer profiles for cities, mounts, flying, raids |
| `/ccam help` | Everything else |

Options: **Options > AddOns > ControllerCam** (a page with the situations, and a *Profiles* page to edit and share). Left-click a profile button to go to the next profile, right-click for the previous one.

## Built-in profiles

| Profile | Feel |
| --- | --- |
| **Action** | Close camera over the right shoulder (offset +2 at normal distances, smaller as you zoom in so your character stays on screen, fading to 0 as you zoom out), head tracking on, dynamic pitch, camera follows your movement. You run facing your movement out of combat and strafe in combat. |
| **Hybrid** | Medium distance, light shoulder offset, gentle head tracking. |
| **Classic** | Every setting ControllerCam manages goes back to the game's default. |
| **Shooter** | Tight camera, strong shoulder offset, fast stick aim, strafing in combat. |
| **Tactical** | Even closer and steadier; the character always turns with the camera. |
| **Cinematic** | Slow and wide with strong head tracking and dynamic pitch. |
| **Target focus** | The camera leans toward your target and NPCs you talk to. |
| **Raid view** | Far, steady, no offset or head tracking. |
| **Mounted cruise** | Far camera that swings behind you while riding. |
| **Flying** | Far camera that follows your climb and dive. |
| **Town stroll** | Relaxed, slower camera for cities. |

Built-in profiles are read-only. Make a copy (`/ccam copy action "My Action"` or the *Make a copy* button) and change that.

A profile lists only what it wants different. **Everything it does not mention goes back to the game's default**, so switching profiles never leaves settings behind. (Camera distance is the exception: a profile without a distance leaves your zoom alone.)

## Situations

A profile can be chosen for each situation. The first one that applies, from the top, wins:

1. In a vehicle
2. Flying
3. Swimming
4. Mounted
5. In combat
6. In a raid
7. In a dungeon
8. In a city or inn
9. Everywhere else (default)

A situation with no profile is skipped, so the next one down applies. The recommended setup leaves *In combat* empty on purpose: you keep the camera of the place you are in. Assign one with `/ccam set combat shooter` (use `none` to clear it).

A situation is kept for a moment after it ends (1.5 seconds by default, `/ccam delay <s>`) so the camera does not flicker when you hop on and off a mount.

`/ccam force <profile>` uses a profile no matter what, until `/ccam auto`.

## Shoulder offset by zoom

The over-the-shoulder offset can follow your camera distance, for example +2 when the camera is close and fading to 0 when you zoom out. Action uses `0:0 6:2 8:2 20:0` (zoom in yards : offset). The offset has to shrink as you zoom in: a sideways offset in yards takes up more of the screen the closer the camera is, and a fixed +2 would push the character out of view. Edit it for a custom profile in the Profiles page, or with

```
/ccam curve "My Action" 0:2 8:2 20:0
```

Up to 8 points; between points the offset changes in a straight line. `/ccam curve "My Action"` with no points removes the curve. `/ccam flip` mirrors every offset to the other shoulder. Positive offsets are meant as the right shoulder; if yours looks like the left, use `/ccam flip`.

## Head tracking

Head tracking (the camera moves a little with your character's head and body) is part of Action, Hybrid, Shooter, Cinematic and others. The settings are in the Profiles page: strength, strength while standing, strength while moving, and range. Strength 0 switches it off.

## Sharing profiles

`/ccam export <profile>` shows a string starting with `CC1:`. Give it to someone; they run `/ccam import <string>` (or use *Import* in the Profiles page). Strings are checked before anything is stored: format version, checksum, only known settings, every value inside its allowed range, size limits. A string that fails any check changes nothing and the addon says why. Strings from a newer ControllerCam are refused with a message to update.

## Commands

```
/ccam                                  status
/ccam list                             the profiles
/ccam use <profile>                    one profile everywhere
/ccam starter                          the recommended setup
/ccam set <situation> <profile|none>   vehicle, flying, swimming, mounted, combat, raid, dungeon, city, default
/ccam force <profile> | auto
/ccam save <name>                      save your current camera settings as a profile
/ccam copy <profile> [new name]
/ccam edit <profile> <setting> <value|default>     /ccam settings lists the settings
/ccam curve <profile> <zoom:offset ...>
/ccam delete <profile>
/ccam export <profile> | import <string>
/ccam flip | delay <s>
/ccam on | off                         off restores the camera settings you had before
/ccam info                             zoom, shoulder offset and motion settings right now (troubleshooting)
/ccam config | help
```

Profile names can be typed in part (`/ccam use cla`) or quoted (`/ccam use "Town stroll"`). The alias `/controllercam` works too.

## How it behaves

- **UI reloads.** Switching the Gamepad UI on or off reloads the interface. Anything kept only in memory is lost, so ControllerCam saves what matters: your profiles, the profile of each situation, the camera settings you had before it touched them (restored by `/ccam off`), and the motion-sickness settings it had to switch off. Your camera distance is not reset by a reload.
- **Combat.** The game refuses to change some CVars during combat. A refused setting is retried when combat ends; the rest are applied right away.
- **Motion-sickness settings.** The shoulder offset, dynamic pitch, target focus and head tracking only work while the game's *Keep Character Centered* and *Reduce Unexpected Movement* settings are off. While a profile uses any of those features, ControllerCam switches them off and puts them back afterwards. In the Gamepad UI the game forces its own temporary values for them, so there the temporary value is overridden instead of your stored one.
- **Camera settings used** (all names were found in the Forever client): `cameraDistanceMaxZoomFactor`, `GamePadCameraYawSpeed`, `GamePadCameraPitchSpeed`, `GamepadCameraFollowOnStick`, `CameraFollowOnStick`, `CameraFollowYawSpeed`, `CameraFollowPitchSpeed`, `CameraFollowGamepadAdjustDelay`, `GamePadFaceMovementMaxAngle`, `GamePadFaceMovementMaxAngleCombat`, `GamePadTurnWithCamera`, `GamePadFaceMovementMount`, `GamePadFaceMovementSwimming`, `GamePadFaceMovementFreeFlying`, `test_cameraOverShoulder`, `test_cameraDynamicPitch`, `test_cameraHeadMovement*`, `test_cameraTargetFocus*`, `cameraSmoothStyle`, plus the two motion-sickness settings above. Speeds are stored as multiples of the game's own default (`x1.25`), so the profiles do not depend on a guessed default value.

## What is not verified

- Everything was checked against the names and descriptions inside the Forever client and against a mocked game API, **not in the live game**. In particular: whether a positive shoulder offset is the right shoulder, whether the head-tracking ranges (0 to 1, 0 to 2 and 1 to 10) match what the game accepts, and how the Gamepad UI treats the temporary override.
- Translations cover the interface (labels, situations, profile names, buttons and messages). The long profile descriptions and the `/ccam help` text are English for now. The translations are machine-quality; corrections are welcome.

## Testing

```
pip install lupa
python tests/test_controllercam.py
```

The tests run the real addon files in a Lua 5.1 interpreter against a mocked WoW API (`tests/wow_mock.lua`). They cover the schema and built-in profiles, import/export validation, situations and priorities, applying and restoring CVars, combat retries, UI-reload persistence, the motion-sickness handling, slash commands, the options panel and localization.

## Credits and license

MIT, see [LICENSE](LICENSE). Copyright (c) 2026 bknie1.

ControllerCam is an independent implementation. It was inspired by [DynamicCam](https://github.com/mpstark/DynamicCam) (MIT, mpstark and LudiusMaximus), which pioneered per-situation camera settings for WoW. No DynamicCam code or presets are included.
