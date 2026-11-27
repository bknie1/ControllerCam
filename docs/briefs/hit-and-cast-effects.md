# Brief: hit and cast effects, the animated pass

For a Fable session. **Design first:** show a short plan and, where you can, a mock-up or two, and wait for a yes
before building.

## What was asked (in the user's words, 2026-11-26)

> It seems like a lot of the damage type effects source from the middle of the target frame, cast bar. But the
> cast bars build left to right, or effects should probably come in from the border of the task bar, rather than
> being generated from the middle of it. Certain effects, like physical slashes, bashes, could be placed in a few
> different key locations around the hot bar, say 8 different potential spots. Below 50%, and then 25%, those
> would be where the wounds on humanoids bleed, elementals crumble/shatter, undead gas/sludge pours out of. Know
> what I mean? Again, offer both full (consistently placed and randomly placed effects, like the 8 "hit areas"),
> subtle (consistently placed hit areas, maybe one in the middle as it kind of is now. Or showing effects on the
> left/right coming in), no effects (accessible, minimalistic. Purely colors, status effects, icons).

> To be clear I like where the current animations are right now so worst case we'll revert back to this as the
> "classic" but I would like to try a more animated experience, based on different types of damage, cast
> effects. We have a great MVP but I'd almost want to send Fable after it to really bring it home.

> Fable could create a unique cast animation and even damage type for every spell/ability/effect in the game.
> But for now, let's continue to group them into damage and class type buckets.

"Hot bar" and "task bar" here mean the bar the effect lands on: the target, focus and nameplate health bars, and
the cast bar. If that reading changes the design, ask.

## Scope: buckets, not every spell

- **Now:** looks are grouped by **damage type** and by **class type** (what kind of class or ability it comes
  from): a fire spell, a warrior's strike, a rogue's, a druid's roots. Say in the plan which buckets there are
  and how a spell lands in one, including what happens when the game keeps the spell or its school secret.
- **Later, not now:** an animation, even a damage look, of its own for every spell, ability and effect. Keep
  the way a look is chosen open to that (a spell could one day override its bucket), without building it.

> See on this how it kind of sources from the middle? Actually, this makes sense for Wrath since it's a kind of
> circular wind up ability, almost like a shoryuken type ball. Almost that circular, hearthstone like effect but
> much faster and then it explodes towards the enemy at the end.

## Where an effect starts depends on the spell

Starting in the middle is not wrong everywhere: it suits some casts. Choose the origin by what the ability does,
rather than moving everything to the edges.

- **Wrath** (said above, with a screenshot of its cast bar): a circular wind-up gathering at one point, like a
  ball of force charging; close to the Hearthstone's whirlpool (`travel` in `CastArt.lua`) but much faster;
  then at the end of the cast it **bursts toward the enemy**.

## The shape of it

- **Classic stays, as a choice in the options,** not only as something to revert to: today's look, unchanged.
- **Effects come from where they should:** in from a bar's edges; along a cast bar the way it fills (left to
  right), not out of its middle.
- **Eight hit areas** around a bar for slashes and bashes.
- **Wounds below 50% and again below 25%** open at those areas and keep going: humanoids bleed, elementals
  crumble and shatter, undead leak gas and sludge. Other kinds of foe have their own already (see below).
- **Levels** (the user's three, plus Classic; settle the names in the plan):
  - **Full:** the eight hit areas, with both fixed and random placement.
  - **Subtle:** fixed places only: the middle much as now, or effects coming in from the left and right.
  - **No effects:** accessible and minimal: colour, status effects and icons only.
- Cast effects get the same treatment: more movement, by kind of damage and kind of cast.

## What is there today

- `ControllerCam_HUD/Impact.lua`: hit effects. `IM.PROFILES` (a look per damage school), shaking, bursts, and
  **wounds by the kind of foe** already (setting `woundFx`: beasts, humanoids and dragonkin bleed; demons spill
  fel ichor; elementals shatter; machines throw sparks; undead wither to ash; stronger as health runs low).
  Settings: `impacts`, `impactFx`, `woundFx`, `playerShake`. Read how it handles each of these before planning.
- `ControllerCam_HUD/CastArt.lua`: what plays on a cast bar as it fills, one `STYLES` entry per kind (mining,
  herbs, skinning, nature, lightning, roots, heals, arcane, fire, frost, shadow, holy, physical, travel...). Its
  header describes each. `CastLook.lua` picks the style; `CastBar.lua` draws the bar (`castArt`, `castWindup`).
  The spell's name and time keep `CB.ROOM` (16) from the bar so leaves and roots don't cover the name: art that
  reaches further needs that room widened.
- Textures are in `ControllerCam_HUD/Media`, generated by the `docs/make_*art.py` scripts. A new `.tga` needs a
  full game restart, not just `/reload`.
- `/cchud casttest` plays every cast kind once; `/cchud hittest` plays every hit effect.
- Tests: classes `HitEffects`, `HitsOnTheTarget`, `Effects`, `CastBarArt`, `CastLooks`, `CastBars` in
  `tests/test_controllercam_hud.py`.

## What the game limits (check these before designing around them)

- **Health and creature type can be secret** (in instances and in fights). A secret number can't be compared, so
  "below 50%" may not be knowable there: `Impact.lua` only uses a health fraction when it is plain, and
  `UnitCreatureType` may be secret too. Decide what each level does when it can't know, and say so in the plan.
  Never do arithmetic or comparisons on secret values (`ns.IsSecret`, `ns.Plain`).
- The combat log isn't always readable; the unit hit events are the fallback, and an amount may be secret.
- **Reduce animations** (`ns.Calm()`) must keep meaning still: no shakes, no bursts.
- Cost matters: many nameplates take hits at once. Pool textures; nothing per frame while nothing is happening.
- **Native is law** (`docs/DESIGN.md`, top): our own frames beside or over the game's, never writing into them.

## Working rules

- **Work on a branch.** Today's effects are committed on `main` ("1.6.0 restore point before the effects
  sweep"). Before changing anything, make a branch from it (`git switch -c effects-sweep`) **in this same
  folder**: the game loads this folder's working tree, so what is checked out is what plays. `main` stays as
  the way back. Check that no other session is working in the folder first: switching branches changes the files
  under them.
- The game loads this folder's working tree; code changes need `/reload`.
- Option and tooltip texts are translated: add `docs/locales/hud/new_enUS.txt` plus the 9 languages in
  extraction order, run `python docs/locales/merge_hud.py`, then `python docs/locales/gen_hud_locales.py`; all 10
  `hud/*.txt` files keep equal line counts.
- Run the affected test classes while working:
  `cd tests; CONTROLLERCAM_WOW_EXE=/nonexistent python -W ignore -m unittest test_controllercam_hud.<Class>`.
- Note changes under 1.6.0 (or the next version) in `CHANGELOG.md`.
- Commit, push or publish only when the user asks.
