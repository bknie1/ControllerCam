# Changelog

## 1.1.0

- Localization is complete: the profile descriptions, tooltips, messages and the `/ccam help` text are translated in all ten game languages (they were English before).
- Descriptions where you pick a camera: hover any profile button in the options to see what it feels like and every setting it changes, and `/ccam describe <profile>` prints the same. The options show the description of the profile in use.
- Advanced editing: tick "Advanced: edit built-in profiles" on the Profiles page (or `/ccam advanced on`) to change any setting of a built-in profile. Your changes are kept, an edited profile is marked "(edited)", and "Reset to original" (`/ccam reset <profile>`) brings the original back. Without Advanced the built-in profiles stay locked, and copies of them can always be edited.

## 1.0.0

- First release.
- An Action camera out of the box: close third-person view over your shoulder, head tracking, the camera follows where you run.
- Built-in profiles: Action, Hybrid, Classic, Shooter, Tactical, Cinematic, Target focus, Raid view, Mounted cruise, Flying and Town stroll. `/ccam use <name>` switches the whole game to one of them.
- A profile for each situation: vehicle, flying, swimming, mounted, combat, raid, dungeon, city or inn, and everywhere else. A fresh install uses a recommended mix (`/ccam starter`).
- Shoulder offset that follows the camera zoom (Action: +2 at normal distances, smaller when zoomed in so the character stays on screen, fading to 0 when zoomed out), mirror option for the other shoulder. `/ccam info` shows what the camera is doing.
- Custom profiles: save your current camera, copy and edit built-in ones, share with versioned, validated import/export strings.
- The camera's terrain following is off in the built-in profiles (except Classic); a profile that does not mention it leaves your own setting alone.
- Options panel under Options > AddOns > ControllerCam, with a Profiles page that edits every setting.
- Settings that survive the UI reload the Gamepad UI switch causes (your original camera values and the motion-sickness settings are saved), and CVars the game refuses in combat are applied when combat ends.
- Localization: German, Spanish (Spain and Mexico), French, Italian, Korean, Brazilian Portuguese, Russian, Simplified Chinese and Traditional Chinese for the interface. Long profile descriptions and the help text are English for now.
