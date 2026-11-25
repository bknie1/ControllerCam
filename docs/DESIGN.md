# ControllerCam: design rules

The goal: the definitive controller experience for WoW: Forever, as one light addon family that sits on top
of the game's own Gamepad UI and can be added or removed without leaving a trace.

## Rules

**Native is law.** Whatever the game's own API and windows allow, we work with them and never against them.
(Decided 2026-11-25, after the bag window, the bank and the Market tab each redrew a native window and each then
fell out of step with the game: visual sync problems, tooltips lost, controls stolen.)

- **Extend, don't replace.** The game's own inventory, bank, vendor, auction house, tooltips and menus stay on
  screen and in charge. We add to them: a key binding (quick sort, quick deposit), a line under a tooltip, an entry
  in a menu through the game's own menu API, a button beside the game's own. A window of ours is the last resort,
  for something the game has no window for at all.
- **Ask the API first.** Before anything is drawn again, look for what the game offers to do it: a setting, a
  mixin, a hook (`hooksecurefunc`), a menu modifier, an Edit Mode option, a `SmartNavigation` call. Use it.
- **Where we must change how something looks, change it in place** (an anchor, a layer, an alpha) and put it back
  when the thing is off; never rebuild what the game builds.
- **Self-managing.** Every part tests what it needs when it starts and as it runs, and handles a problem as it
  arrives: a handler that fails steps aside for a while (`ns.BREAKER`, Core.lua) and is tried again; a part the
  game will not let us touch (protected, in combat, secret) is left alone and noted in the debug report, never
  forced. One part failing never stops another, and no error may escape to the game as a Lua error.
- **Our own window is opt-in, and labelled experimental,** until it has run a week in the game without a problem
  the native one does not have (the bag window now: Options > Bags).

1. **Lightweight.** Small files, no libraries, nothing running when it has nothing to do.
2. **Classic inspired, modern feel.** Things sit where WoW players expect them. Quality of life, animation and
   a little flash come on top.
3. **"What if WoW was built for the console today?"** Every choice should have an answer to that. The feel to
   aim for is Breath of the Wild, made from WoW: a clear screen, information that shows up when it matters
   and steps back when it does not, and reactions you can feel.
4. **Attractive.** It has to look good, in motion and in a screenshot.
5. **Immersive.** Show what matters when it matters; get out of the way otherwise.
6. **Great controller UX everywhere.** Every interface and game mode: combat, nameplates, quests, fishing.
   One stop shop.
7. **Self-contained.** Turning a module off, or removing the addon, leaves the game exactly as it was.
8. **Tightly coupled to the game's own options.** Apart from the gamepad action bars, everything on screen is
   the native UI, shared by mouse and controller, and usually has a switch in the game's Options or Edit
   Mode. We override how those things look, not how they are controlled: if the game has a setting for
   something, that setting is the only one. A switch of ours flips the game's setting (so its menus always
   agree), and we never force on something the player turned off there. Our frames move in Edit Mode like
   the game's own.
9. **Follows the Gamepad UI switch.** Our elements show while `InputDeviceInterfaceStyle` is 1 and the game's
   own show otherwise, so both look right when InputSwap flips between them. InputSwap stays a separate
   addon; this design only reads the setting it controls.
10. **Proven end to end.** Every module has mock tests, a grid over every combination of its switches,
    an in-game self-check (`/cchud check`) and a demo (`/cchud demo`).
11. **The game's tooltips are only looked at.** Nothing is added to one (`AddLine`, `AddDoubleLine`) and none
    is opened, filled or closed by our code (`SetOwner`, `SetText`, `Hide`). Our lines for an item hang under
    its tooltip on a panel of our own (`Tooltip.Annex`); our windows use a tooltip of our own (`Tooltip.Own`).
    A piece of a game tooltip made by an addon taints what the game does after reading it: on 2026-11-20 that
    was the gamepad bars refusing their own actions after a vendor, until a reload. The debug report's
    `tainted` section lists every value of the game's that carries our name; it should stay empty.
12. **The game's dialogs, buttons and lists of windows are the game's.** No dialog of ours goes in the game's
    dialog box (`StaticPopup_Show`) and none of the game's is pressed by us (`StaticPopup_OnClick`); no script
    of a game button is replaced (`SetScript`); no window of ours is put on `UISpecialFrames`. The controller's
    cursor works on all of those with the game's own code, which then runs in our name and is refused what it
    does next. Our questions are asked by `ns.Dialog`, our windows take their keys with `ns.PadKeys` (Escape
    among them). Still on the game's dialog box: `/cchud export` and `/cchud import` (`Share.lua`).

## Modules

| Module | State |
| --- | --- |
| ControllerCam: camera profiles, with Indoors and Fishing situations | built |
| HUD: player, pet, target, target-of-target and focus frames | built, seen in the game |
| HUD: party and raid look over the game's frames | built, mock-tested only |
| HUD: nameplates | built, mock-tested only |
| HUD: cast bar, your effects on the target, combo points | built, mock-tested only |
| Vendor and bank: sell by rule or quality, quick move, marks, deposits | built, mock-tested only |
| Quest list: current zone only | built, mock-tested only |
| Gamepad action bars: slimmer look (art hidden, smaller) | built, mock-tested only, off by default |
| Options panel, translations (ten languages) | built |
| Gamepad action bars: a fully custom layout | not started: needs work in the running game |
| Chat fades when quiet, coordinates on the world map | built, mock-tested only |
| The game's own frames in the HUD's look (gamepad bars, tooltips, buffs, tracker, minimap, XP bar, chat) | built, mock-tested only |
| Bags: sorting, item counts across characters, gold; repairs at vendors | built, mock-tested only |
| Chat: class icon and level, spam filter | built, mock-tested only |
| Items your quests need: a Quest verdict beside auction, vendor and keep (Quests.lua decides, Market.lua says it, Vendor.lua and the Market keep it) | built, mock-tested only |
| Quest progress in chat; flights: destination, learned times and a countdown bar; a reminder to drink water; repeated guild recruitment hidden | built, mock-tested only: how the flight map says the chosen place under the Gamepad UI has not been seen in the game |
| A game on the way under the flight bar (`FlightGame.lua`): its buttons bound only on a flight, A, X and Y only while it is played | built, mock-tested only |
| The screen rests out of combat: bars, minimap, quest list, damage meter and XP bar fade together | built, mock-tested only |
| Stance and pet buttons moved above the bars (in place of the targeting icons) | built, mock-tested only: the icons' names are a guess (`/cchud padinfo` shows what is there) |
| Cast bar animations by kind of cast (your bar, and a lighter show on nameplates) | built, mock-tested only (`/cchud casttest`) |
| One-button fishing | built, seen in the game |
| Fish journal, fishing interface, bait on a double press, a game while the float is out | built, mock-tested only |
| Quest list: no group quests while alone, only the nearest, nearest first, recommended order | built, mock-tested only |
| Quest compass along the top, or the bottom with the experience bar moved to the top (`Compass.lua`, `/cchud compassdemo`) | built, mock-tested only: the game's quest atlases, `GetPlayerFacing` and the bottom fit under the gamepad bars not seen in the game |
| Button icons: the game's own style for the controller in use, found or chosen | built, mock-tested only |
| Shields as a ward round the health bar | built, mock-tested only |
| Market: a tab of the auction house with its own controller keys, and a pane that only shows | built, mock-tested only |
| Transmogrify: the game's hidden Sets tab shown and filled with the sets of your collection (by item name, and the game's own), put on in one press, X to undo (`Transmog.lua`) | built, mock-tested only: the tab's place in the game's layout, the cursor on the first set and Blizzard_Transmog of this client (read from its published UI source) not seen in the game |
| Levelling plan beside a profession's window, broken down to raw materials; a farm list beside the quest list | built, mock-tested only |
| First run: beside ControllerCam the HUD rests and asks "Camera + HUD" or "Camera only" (`/cchud welcome` asks again) | built, mock-tested only |
| Setup: after the first-run choice the screen is offered too, a layout named ControllerCam added to the game's Edit Mode (`/cchud setup`) | built, mock-tested only: adding a layout has not been seen in the game |
| The whole setup as one line: HUD settings, camera setup and the game's Edit Mode layout (`/cchud export`, `/cchud import`) | built, mock-tested only: adding a layout to the game's own has not been seen in the game |

## Load-on-demand modules (built on the hud-modules branch, not yet seen in the game)

The goal: a part you switch off costs nothing. Today a switch in the Modules list only stops a part from
acting. Its code is still loaded and kept in memory, and some of it still runs every frame.

### What the HUD costs now (measured 2026-11-23)

- **Memory at load.** Measured in the test harness: Lua memory taken by each file as it loads (lupa, the
  `hud_mock.lua` frames). This is a stand-in for the game's `GetAddOnMemoryUsage`, which only knows the whole
  addon. In total that is **6.3 MB**:
  - `Locales.lua` takes **1.5 MB**, a quarter of the whole. It keeps all ten translations for good
    (`ns.localeData`, which only the tests read). If it keeps only the language in use, **1.49 MB** is freed,
    without moving any other file.
  - The parts below that could become modules take **2.5 MB** between them.
  - The rest (unit frames, cast bar, auras, effects, quests, skins, options) takes 2.3 MB once the
    translations are fixed.
- **Time per frame.** These figures come from the game's own addon profiler, read from the debug report saved
  today at 12:16. The HUD takes about 1 ms a frame on average (camera addon: 0.02 ms), with a 563 ms peak at
  login. Nearly every slow call in that report (20–43 ms each, in bursts) is `Nameplates.lua:1155`. The
  rest are `Bags.lua:551/668` (92 ms when the bag window opens). The profiler only reports per addon, so today
  it cannot say which part of the HUD is slow. Split into modules, it will report each one.
- **Every-frame handlers when switched off.** I simulated 20 s with a target, first with every switch on, then
  with all 24 switches off. In both runs the same **19 files** were called every frame: Rumble, Quests (×2),
  Bags (×2), Numbers, UnitFrames, Sizes, Farm, Inventory, Ride, Readout, Hydrate, Mail, Levelling, Reticle,
  Campfire, FishPanel, Fishing, PadButtons, FishGame. Switching a part off does not stop its watcher. 11 of
  these 19 are in files that would move to modules.
- **Events.** Parts register their events when switched on and drop them when off (for example
  `Fishing.lua:551`, `Bags.lua:2270`), so a part that is off costs no events now. This won't change.

### The split (as built, branch `hud-modules`)

One core addon that is always loaded, plus twelve load-on-demand addons (`## LoadOnDemand: 1`). A module is
loaded while any one of its switches is on. Its `## Dependencies` are loaded first, by the game itself.

| Addon | Files | Memory | Loaded while on | `## Dependencies` |
| --- | --- | --- | --- | --- |
| `ControllerCam_HUD_Nameplates` | PlateStates, Nameplates | 211 KB | `nameplates` | ControllerCam_HUD |
| `ControllerCam_HUD_Group` (healer, party and raid frames) | Group | 82 KB | `group` | ControllerCam_HUD |
| `ControllerCam_HUD_Numbers` | Numbers, Moments | 237 KB | `numbers`, `readyAlerts`, `soonCallouts`, `soonBuffs`, `bigMoments`, `abilityRumble` | ControllerCam_HUD |
| `ControllerCam_HUD_Bags` | Bags | 309 KB | `bagWindow` | ControllerCam_HUD |
| `ControllerCam_HUD_Market` (auction house) | AuctionPanel | 122 KB | `ahPanel` | ControllerCam_HUD |
| `ControllerCam_HUD_Mentor` (levelling plan, guides, bank counts, farm list) | LevelGuides, Levelling, Farm | 327 KB | `skillPlan`, `skillBank`, `farmList` | ControllerCam_HUD |
| `ControllerCam_HUD_Transmog` | Transmog | 85 KB | `transmogSets`, `tipAppearance` | ControllerCam_HUD |
| `ControllerCam_HUD_Compass` | Compass | 84 KB | `compass` | ControllerCam_HUD |
| `ControllerCam_HUD_Fishing` | Fishing, FishLore, FishLog, FishPanel, FishGame, FishJournal | 193 KB | `fishMode`, `fishJournal`, `fishPanel` | ControllerCam_HUD |
| `ControllerCam_HUD_Narrative` | Narrative | 63 KB | `narrative` | ControllerCam_HUD |
| `ControllerCam_HUD_Campfire` | Campfire | 105 KB | `campScene` | ControllerCam_HUD |
| `ControllerCam_HUD_Flights` (flight bar, flight game, flight film) | Flights, FlightGame, Ride | 224 KB | `flights`, `flightScene`, `flightGame` | ControllerCam_HUD, ControllerCam_HUD_Campfire (the flight film uses the camp fire's) |

**Changes from the plan:**
- **No Items module.** Vendor, Market, Professions, Inventory, ItemInfo and Mail stay in core. Their tooltip
  lines (prices, advice, counts, stat values) are on by default and come through Inventory's tooltip hook, and
  Bags, Market, Mentor, Campfire, Fishing and Narrative all call into them. As a module it would be loaded for
  nearly everyone, so the extra layer would cost more than it saved.
- **Some modules have several switches.** Numbers, Mentor, Transmog, Fishing and Flights each hold parts with
  switches of their own (the cooldown callouts are in Numbers.lua, the fish journal records catches without
  one-button fishing, and so on). Each of those switches loads the module, so nothing that worked before
  stops working. On these switches the tip names the other switches that keep the module loaded.

**What stays in core (`ControllerCam_HUD`), and why:**
- **The base everything else uses:** Locales, Core (settings, saved data, `ns.Protect`, the secret-value
  helpers, `ns.Dialog`, `ns.PadKeys`, `ns.Money`), Modules and Theme.
- **The frames on screen, which are woven together:** UnitFrames, Impact, CastLook, CastArt, CastBar, Auras,
  AuraWidgets, Bloom, Ward and Readout.
- **Items:** Vendor, Market, Professions, Inventory, ItemInfo, Mail, Stats (see above).
- **Quests and QuestItemData.** The "Quest" verdict that stops a quest item being sold must not depend on a
  module being loaded.
- **Small parts and the screen's look:** Chat, Hydrate, Rest, Bars, Skin, SkinAreas, Tooltip, PadButtons,
  PadIcons, Sizes, World, Rumble, Reticle, Breath, Layout, Cooldowns.
- **Settings and setup:** Presets, Share, Welcome, Options, Slash, plus Debug, Probe, Check and Notices.
- **Media and Bindings.xml.**

### How it works

1. **One namespace.** The core makes its table public as `ControllerCamHUD.ns`, on the global that the camera
   addon already calls. Each module file starts with `local ADDON = ...` and `local ns = ControllerCamHUD.ns`;
   nothing else in the files changed. Media paths stay on `ControllerCam_HUD\Media`.
2. **When modules load.** Once the settings are read (the core's `ADDON_LOADED`), and again from every
   `ns.Apply()` (which waits for combat to end), `ns.LoadWanted()` (Modules.lua) loads each module that is
   wanted: the HUD is on and one of its switches is, or a module that needs it is wanted. A first run, where
   the HUD rests until asked, loads none.
3. **Settings of a module that is not loaded are kept.** `InitDB` now keeps what no setting claims (except a
   short list of retired keys, `DROPPED`). When a module loads later, `RegisterSetting` and `RegisterSaved`
   clean its values as they register. Modules.lua also lists each module's other settings with their
   defaults (`keys`), so `/cchud export` and `import`, the presets and `ResetAll` handle them while the module
   is not loaded. A test checks that this list matches what the module registers.
4. **The switches live in core.** Their definitions (same words, so the translations are kept) moved from the
   module files into Modules.lua. Every switch is always in Options and in `/cchud`.
5. **Switching on loads now; switching off frees memory at the next /reload.**
   - Turned on: the module loads at once (after combat), its settings join its Options page
     (`ns.OptionsAddNew`), and it starts.
   - Turned off: the part stops at once, as before; its memory is freed at the next /reload.
   - The switch's tip ends "Turning it off frees its memory at your next /reload.", or names the other
     switches that keep the module loaded.
   - On its Options page, a module that is not loaded shows its switches and "Its settings show here when it
     is on."
6. **Slash commands and key bindings always answer.** A command of a module that is not loaded says, for
   example, "One-button fishing is off: /cchud fishmode on" (or that it is not installed). The key binding
   functions named in Bindings.xml are defined in core as stand-ins that say the same; the module's own
   functions replace them as it loads.
7. **Our addon names.** `ns.IsOurAddon` counts `ControllerCam_HUD` and every `ControllerCam_HUD_*` as ours,
   in Debug's refusal and taint report and in Impact's refusal guard. The report's profiler section lists every
   module that is loaded, so the game's profiler reports each one. A `modules` section shows each module's
   state.
8. **Unticked in the game's AddOns list.** That is the player's choice and it is left so: the module is not
   loaded, its switch is greyed out, and its commands say it is turned off in the game's AddOns list and which
   addon to tick there. A module whose folder is missing is greyed out the same way and says "not installed".
9. **Translations.** One `Locales.lua` in core, built as before. `extract_hud.py` reads the module tocs too.
   `ns.localeData` (every language) is kept only under the test harness (`HUD_TEST_DIR`), which frees about
   1.5 MB in the game.

### Folders, the game install and packaging

- **In the repository**, each module is a folder at the top level, beside `ControllerCam_HUD`: for example
  `ControllerCam_HUD_Bags/ControllerCam_HUD_Bags.toc` and its files. The game reads addons only one folder
  deep, so a module can't sit inside the HUD's folder.
- **In the game install**, each module needs a junction of its own in `Interface\AddOns`, beside the
  ControllerCam and ControllerCam_HUD ones. `docs/link_modules.ps1 -AddOns <the game's AddOns folder>` makes
  the missing ones and touches nothing else (`-WhatIf` only says what it would make).
- **In the download.** `.pkgmeta` has one `move-folders` line per module. `release.yml` checks each module's
  version against ControllerCam's, copies each module folder (toc, Lua files, LICENSE) into `dist/` and zips
  them beside `ControllerCam`, `ControllerCam_HUD` and `InputSwap`, so one download still holds everything.
  `curseforge.yml` uploads that same zip and needs no change.
- **Every toc** shares the version, `## Interface`, the author and the license, and has a `## Notes` line. In the
  game's AddOns list the modules sit under the HUD (`## Group: ControllerCam_HUD`), and the HUD under ControllerCam
  (`## Group: ControllerCam`).

### Tests

- The harness (`Env`) reads the core toc, then each module's toc. `Env(modules="all")`, the default, loads
  every module with the core as before, so the earlier tests keep their meaning. `modules="game"` loads them as
  the game does, by their switches, and `modules=[...]` loads a chosen few. `installed=` says which module
  folders exist, and `disabled=` which are unticked.
- The mock's `LoadAddOn` loads a module's files (after its dependencies) and fires its `ADDON_LOADED`.
- The `LoadOnDemand` tests cover:
  - each file is in exactly one toc, and each module's toc fields are right;
  - Modules.lua matches the folders, and its lists of commands, settings and bindings match what each module
    registers;
  - modules load by their switches, and none load while the HUD is off;
  - a module that is off keeps its settings and answers its commands, then loads when switched on in play,
    but never in a fight;
  - a module's dependency comes with it, and a module unticked in the AddOns list stays off;
  - the core runs alone, and so does each module with only what it needs;
  - the memory line in the switches' tips;
  - the Options pages take in a module switched on in play;
  - export, import and the presets carry an unloaded module's settings;
  - the debug report's names;
  - the translations kept only for the tests;
  - one download carries every module.

### Still to see in the game

- That `LoadAddOn` from the core's `ADDON_LOADED` loads the modules before `PLAYER_LOGIN`, as it does for
  Blizzard's own load-on-demand addons, and that a module switched on in play starts without a /reload. Parts
  that read something only at login or on entering the world (Professions reads skills on
  `PLAYER_ENTERING_WORLD`, and Nameplates and Flights read it too) get it from their own `Apply` or the next
  event when loaded later. Watch for anything that only appears after a /reload.
- The AddOns list: the twelve modules under ControllerCam's heading, ticked, and shown as load-on-demand.
- `GetAddOnMemoryUsage` per module, and the game's profiler per module (the debug report's `slow` section).

## Before publishing

- `Debug.DEFAULT` in `ControllerCam_HUD/Debug.lua` is `false` (the tests check it): a new install gathers no
  troubleshooting reports. Whoever has it switched on (`/cchud debug on`) keeps it on: with it on, the HUD gathers
  its reports by itself at login and at every reload or logout, in `ControllerCamHUDDB.debugReport` (`login`,
  `logout`, `notes`).
- The download holds `ControllerCam`, `ControllerCam_HUD`, the HUD's modules (`ControllerCam_HUD_*`) and `InputSwap` (as `.github/workflows/release.yml` builds it).
- CurseForge: a big release (a tag ending in `.0`, such as `v1.4.0`) is uploaded there by the release workflow;
  a major hotfix by hand, with the "CurseForge upload" workflow (Actions tab, the tag to send). Both need the
  `CF_API_TOKEN` repository secret (a CurseForge API token) and take the game version from the `CF_GAME_VERSION`
  repository variable (1.60.1 when unset). A short changelog for CurseForge goes in `docs/curseforge/<version>.md`.

## Built from the backlog (1.3.0), and what is still unseen in the game

All of it is mock-tested only until played.

1. **Fish journal** (`FishLog.lua` the book, `FishLore.lua` the lines, `FishJournal.lua` the window,
   `FishPanel.lua` the fishing interface). Weights are made up; the lore is translated with every other text. A water's list of fish
   comes from Improved Forever's data when that addon is loaded (read at runtime, never copied) and from what
   was landed there otherwise. To see in the game: that fished loot is told apart, that "got away" counts,
   that the interface fits between the line and the gamepad bars.
2. **Bait on a double press** (`Fishing.lua`). For half a second after a cast of yours begins the button is
   bound to a secure button that uses the bait. To see in the game: that using bait interrupts the cast as
   expected, and whether the bait asks to be put on the pole (the button names slot 16 for that).
3. **Quest list** (`Quests.lua`). The order is kept by tracking quests in that order. To see in the game:
   that the game lists quests in the order they were tracked, and does not sort them again by itself.
4. **Button icons** (`PadIcons.lua`). The game's own label style per controller, through its gamepad settings.
   To see in the game: that the game takes the style and the bars follow it.
5. **A game while the float is out** (`FishGame.lua`), off by default. It reads a trigger and binds nothing.
6. **Wards for shields** (`Ward.lua`): target, focus and player frames.
7. **The Market posts all and greets** (`AuctionPanel.lua`). To see in the game: that one post takes every
   stack (`PostCommodity`/`PostItem` with the whole quantity; the older `PostAuction` with several stacks),
   that `PlaySound(5958, "Dialog")` (GoblinMaleGruffNPCGreetings, 5964 the Zany ones after it) plays on this
   client, and that the auctioneer's portrait draws.

Also from play: inside dungeons and raids, where friendly nameplates are the game's own and closed to every
addon, the game's own options show them as class-coloured names without bars, like ours, with the game's bars
back for a fight (`Nameplates.lua`; to see in the game: that the change shows at once, and at the start and end
of a fight), and a frame the game holds still in a fight is no longer asked about every frame
(`Impact.lua`).

## Order of work

Each module is finished (tests, grid, self-check, demo, a look in the game) before the next one starts.
Whatever the game's Gamepad UI already does well is kept and restyled; only what it does badly is replaced.

## Credits and inspiration

DynamicCam (camera), Improved Forever (controller quality of life), GatherMate2 (gathering nodes on the maps).
No code or data is copied from any of them.
