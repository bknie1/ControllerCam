## ControllerCam 1.2.0

This release adds **ControllerCam: HUD**, an optional second addon in the same download: a controller interface for the Gamepad UI. It asks before it does anything. The camera addon works as before if you answer "Camera only".

For WoW: Forever (interface 16001). The HUD is new: please report anything that looks wrong.

### ControllerCam (camera)
- Shapeshift forms (druid forms, ghost wolf) no longer push the camera further to the side. `/ccam formoffset <percent>` tunes it for the form you are in.
- Two more situations to pick a camera profile for: **Indoors** and **Fishing**.

### ControllerCam: HUD (new, optional)
- **Your choice first.** The first time it loads it asks **Camera + HUD** or **Camera only**, and touches nothing until you answer. `/cchud on` and `/cchud off` change your mind later.
- **Runs only with the Gamepad UI.** It steps aside in the mouse and keyboard UI, and switching it off or removing it leaves the game as it was.
- **Frames.** Slim player, pet, target, target-of-target and focus frames, or two upright bars beside your character that follow the camera. Party and raid frames in the same look. All movable in the game's Edit Mode.
- **Nameplates.** Names, levels by difficulty, rank art for elites and rares, threat as a shield and a glow, your debuffs, crowd control, quest progress, and enemy casts that get louder until they land.
- **Cast bar.** Shows what is being cast, not only how far along it is: picks chip at it while mining, lightning runs along it for nature, a vine flowers for a heal, light sears wounds shut for a holy heal, fire kindles and leaps, ice freezes on and shatters, runes take shape for arcane. Fishing turns the bar into a line with a float.
- **Feedback you can feel.** Hit flashes and particles by damage school, stylised numbers for what you take, controller vibration for hits, crits and interrupts, and a light bar that shows your health.
- **A screen that rests.** Out of combat the gamepad bars, minimap, quest list, damage meter, experience bar and cooldown rows fade together, and come back for a fight or a pull of a trigger.
- **Gamepad bars.** The stance and pet buttons sit above the bars so their wheel opens fully on screen. The game's cooldown rows no longer sit on the gamepad buttons.
- **One-button fishing.** With a pole in your hands, your interact button casts when there is nothing to interact with, and hooks the fish when the float bobs.
- **Chat.** `[class icon level] Name: text`, bigger text for a TV, gold sellers and repeated adverts hidden.
- **Bags, bank and vendor.** Sort and quick-move with the stick buttons, junk rules with a confirmation, deposit to the bank, automatic repairs, item counts across your characters.
- **Auction house.** A Market tab you can work with the controller: what is worth selling, at what price, and why.
- **Presets.** Eleven whole-HUD presets (Action, Classic, Minimal, Open world, Adventure, Soulslike, Shooter, Crossbar, ARPG, Compass, Raid), and `/cchud sizefor tv | monitor`.
- **Setup and sharing.** An Edit Mode layout named CCHUD is offered for the game's own frames. `/cchud export` puts your whole setup (HUD, camera, layout) in one line of text; `/cchud import` reads one. `/cchud reset all` puts everything back.
- **Ten languages.**

### Good to know
- Options: Options > AddOns > ControllerCam > HUD. `/cchud help` lists the commands, `/cchud demo` shows the frames reacting, `/cchud check` compares the screen with your settings.
- The game does not let addons choose an Edit Mode layout: the CCHUD layout is added to the list, and you pick it there.
- The full list of changes is in `CHANGELOG.md` inside the download.
