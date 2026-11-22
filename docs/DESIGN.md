# ControllerCam: design rules

The goal: the definitive controller experience for WoW: Forever, as one light addon family that sits on top
of the game's own Gamepad UI and can be added or removed without leaving a trace.

## Rules

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
| The screen rests out of combat: bars, minimap, quest list, damage meter and XP bar fade together | built, mock-tested only |
| Stance and pet buttons moved above the bars (in place of the targeting icons) | built, mock-tested only: the icons' names are a guess (`/cchud padinfo` shows what is there) |
| Cast bar animations by kind of cast (your bar, and a lighter show on nameplates) | built, mock-tested only (`/cchud casttest`) |
| One-button fishing | built, seen in the game |
| Fish journal, fishing interface, bait on a double press, a game while the float is out | built, mock-tested only |
| Quest list: no group quests while alone, only the nearest, nearest first, recommended order | built, mock-tested only |
| Button icons: the game's own style for the controller in use, found or chosen | built, mock-tested only |
| Shields as a ward round the health bar | built, mock-tested only |
| Market: a tab of the auction house with its own controller keys, and a pane that only shows | built, mock-tested only |
| Levelling plan beside a profession's window, broken down to raw materials; a farm list beside the quest list | built, mock-tested only |
| First run: beside ControllerCam the HUD rests and asks "Camera + HUD" or "Camera only" (`/cchud welcome` asks again) | built, mock-tested only |
| Setup: after the first-run choice the screen is offered too, a layout named ControllerCam added to the game's Edit Mode (`/cchud setup`) | built, mock-tested only: adding a layout has not been seen in the game |
| The whole setup as one line: HUD settings, camera setup and the game's Edit Mode layout (`/cchud export`, `/cchud import`) | built, mock-tested only: adding a layout to the game's own has not been seen in the game |

## Before publishing

- `Debug.DEFAULT` in `ControllerCam_HUD/Debug.lua` is `false` (the tests check it): a new install gathers no
  troubleshooting reports. Whoever has it switched on (`/cchud debug on`) keeps it on: with it on, the HUD gathers
  its reports by itself at login and at every reload or logout, in `ControllerCamHUDDB.debugReport` (`login`,
  `logout`, `notes`).
- The download holds `ControllerCam` and `ControllerCam_HUD` (as `.github/workflows/release.yml` builds it).

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
