# ControllerCam

**Camera profiles for controller play in World of Warcraft: Forever.**

Install it and you get an **over-the-shoulder Action camera** right away: a close third-person view with head tracking, a camera that follows where you run, and a character that faces where you move. Want something calmer? One command switches to **Hybrid** or **Classic**. Every situation (mounted, flying, combat, raid, city...) can use its own camera.

## Features

- **Action camera out of the box.** No setup. A fresh install uses a recommended mix: Action camera, calmer profiles for cities, mounts, flying and raids.
- **11 built-in profiles.** Action, Hybrid, Classic, Shooter, Tactical, Cinematic, Target focus, Raid view, Mounted cruise, Flying and Town stroll. Every profile has a description (hover it in the options, or `/ccam describe <profile>`).
- **A camera for each situation.** In a vehicle, flying, swimming, mounted, in combat, in a raid, in a dungeon, in a city or inn, and everywhere else. You pick the profile for each one.
- **Over-the-shoulder offset that follows your zoom.** The offset grows with the camera distance, so your character stays in view when you zoom in, and fades out when you zoom far away. Mirror it for the other shoulder with one command.
- **Head tracking, dynamic pitch, target and NPC focus** as profile settings.
- **Terrain following is off** in the built-in profiles (Classic leaves your own setting alone).
- **Edit everything.** Copy any profile and change every setting, or switch on *Advanced* to edit the built-in ones (with *Reset to original*). Save your current camera as a profile.
- **Share profiles.** Export a short string, import someone else's. Strings are versioned, checksummed and fully validated: a bad string never changes your settings.
- **Built for the Gamepad UI.** Settings survive the UI reload that switching to or from the Gamepad UI causes, and settings the game refuses in combat are applied when combat ends. Your original camera settings are saved and restored when you turn the addon off.
- **Options panel and slash commands.** Options > AddOns > ControllerCam, or `/ccam help`.
- **Localized.** German, Spanish (Spain and Mexico), French, Italian, Korean, Brazilian Portuguese, Russian, Simplified and Traditional Chinese.

## Quick start

| Command | What it does |
| --- | --- |
| `/ccam use action` | Action camera everywhere |
| `/ccam use hybrid` | Between Classic and Action |
| `/ccam use classic` | The game's own camera |
| `/ccam starter` | The recommended mix (the default on a new install) |
| `/ccam set combat shooter` | Use the Shooter profile in combat |
| `/ccam describe action` | What a profile feels like and every setting it changes |
| `/ccam export action` | A string you can share |
| `/ccam import <string>` | Add a shared profile |
| `/ccam off` | Turn off and restore your original camera settings |

## Good to know

- **Turn off other camera addons** (DynamicCam, for example). Two addons changing the same camera settings fight each other. ControllerCam warns you if it finds DynamicCam loaded.
- This is an **early release**. It was built against the camera settings found in the Forever client and covered by automated tests, but it is new, so expect to tweak the profiles to your taste. Bug reports and suggestions are welcome on GitHub.
- The shoulder offset assumes a positive value is the right shoulder. If yours looks like the left, run `/ccam flip`.

## Links

- Source, issues and releases: https://github.com/bknie1/ControllerCam
- Works well alongside [InputSwap](https://github.com/bknie1/InputSwap), which switches the Gamepad UI on and off depending on how you last moved.

## License

MIT. Copyright (c) 2026 bknie1. Inspired by [DynamicCam](https://github.com/mpstark/DynamicCam) (MIT); no DynamicCam code or presets are included.
