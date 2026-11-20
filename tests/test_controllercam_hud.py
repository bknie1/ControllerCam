"""Automated tests for the ControllerCam HUD module.

They run the real addon Lua files inside a Lua 5.1 interpreter against a mock of the WoW API
(tests/wow_mock.lua plus tests/hud_mock.lua). Nothing here talks to the game.

    pip install lupa
    python tests/test_controllercam_hud.py
"""
import os
import re
import struct
import unittest

from lupa.lua51 import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
HUD = os.path.join(ROOT, "ControllerCam_HUD")
TOC = os.path.join(HUD, "ControllerCam_HUD.toc")


def toc_files():
    return [l.strip() for l in open(TOC, encoding="utf-8").read().splitlines() if l.strip() and not l.startswith("#")]


def lua_path(p):
    return p.replace("\\", "/")


def plain(text):
    """The words of a text, without the game's colour codes."""
    return re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "", str(text))


class Env:
    """One fresh game session with the HUD loaded. style "1" is the Gamepad UI."""

    def __init__(self, db=None, style="1", combat=False, login=True, addons=(), setup=None, locale="enUS"):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        lua = self.lua
        lua.execute("HUD_TEST_DIR = '%s'" % lua_path(HERE))
        self.mock = lua.execute("return dofile('%s')" % lua_path(os.path.join(HERE, "hud_mock.lua")))
        self.mock.cvars["InputDeviceInterfaceStyle"] = style
        self.mock.state.combat = combat
        self.mock.locale = locale
        for name in addons:
            self.mock.addons[name] = True
        if setup:
            setup(self)
        if db is not None:
            lua.execute("ControllerCamHUDDB = " + db)
        self.ns = lua.table()
        for f in toc_files():
            self.mock.loadHud(lua_path(os.path.join(HUD, f)), self.ns)
        self.g = lua.globals()
        if login:
            self.mock.fire("ADDON_LOADED", "ControllerCam_HUD")
            self.mock.fire("PLAYER_LOGIN")
            self.mock.fire("PLAYER_ENTERING_WORLD")

    @property
    def db(self):
        return self.ns.db

    @property
    def frames(self):
        return self.ns.UnitFrames.frames

    def cmd(self, text):
        del_from = len(self.mock.printed)
        self.g.SlashCmdList["CCHUD"](text)
        return "\n".join(list(self.mock.printed.values())[del_from:])

    def update(self, seconds, step=0.05):
        self.mock.update(seconds, step)

    def target(self, **kw):
        data = self.lua.table(name="Zengu", health=800, healthMax=800, level=40, attackable=True, reaction=2)
        for k, v in kw.items():
            data[k] = v
        self.mock.setUnit("target", data)
        return data

    def same(self, a, b):
        return bool(self.lua.eval("rawequal")(a, b))

    def aside(self, name):
        """The game's frame is made invisible by us (and never moved away from where the game keeps it)."""
        f = self.g[name]
        assert f.parent["__name"] == "UIParent", name + " was moved"
        return bool(self.ns.IsBlizzardFaded(name)) and f.alpha == 0

    def parent(self, name):
        """Global name of the frame a game frame is parented to."""
        return self.g[name].parent["__name"]

    def errors(self):
        return list(self.ns.errors.values())

    def color(self, bar):
        c = bar.fill.color
        return (round(c[1], 2), round(c[2], 2), round(c[3], 2))

    def theme(self, name):
        c = self.ns.colors[name]
        return (round(c[1], 2), round(c[2], 2), round(c[3], 2))


class Files(unittest.TestCase):
    def test_toc_files_exist(self):
        for f in toc_files():
            self.assertTrue(os.path.isfile(os.path.join(HUD, f)), f)

    def test_textures_are_valid_tga(self):
        names = sorted(os.listdir(os.path.join(HUD, "Media")))
        self.assertEqual(names, ["bar.tga", "bobber.tga", "bolt.tga", "crystal.tga", "disc.tga", "flame.tga",
                                 "flower.tga", "ghost.tga", "halo.tga", "hammer.tga", "leaf.tga", "mapring.tga",
                                 "mark.tga", "mask.tga", "pick.tga", "quest.tga", "ring.tga", "roots.tga",
                                 "runes.tga", "skull.tga", "soft.tga", "spark.tga", "threat.tga", "vine.tga",
                                 "vines.tga", "wing.tga"])
        for n in names:
            data = open(os.path.join(HUD, "Media", n), "rb").read()
            image_type = data[2]
            w, h, bpp = struct.unpack("<HHB", data[12:17])
            self.assertEqual(image_type, 2, n)                 # uncompressed true colour
            self.assertEqual(bpp, 32, n)
            for side in (w, h):
                self.assertEqual(side & (side - 1), 0, "%s: %d is not a power of two" % (n, side))

    def test_every_texture_used_exists(self):
        theme = open(os.path.join(HUD, "Theme.lua"), encoding="utf-8").read()
        for name in re.findall(r'MEDIA \.\. "(\w+)"', theme):
            self.assertTrue(os.path.isfile(os.path.join(HUD, "Media", name + ".tga")), name)


class Packaging(unittest.TestCase):
    def test_every_lua_file_is_loaded(self):
        on_disk = sorted(f for f in os.listdir(HUD) if f.endswith(".lua"))
        self.assertEqual(on_disk, sorted(toc_files()))
        self.assertEqual(toc_files()[0], "Locales.lua")              # texts first: every other file uses them

    def test_one_version_for_both_addons(self):
        version = lambda path: re.search(r"^## Version: (.+)$", open(path, encoding="utf-8").read(), re.M).group(1).strip()
        self.assertEqual(version(TOC), version(os.path.join(ROOT, "ControllerCam.toc")))

    def test_the_release_ships_the_hud_as_its_own_folder(self):
        wf = open(os.path.join(ROOT, ".github", "workflows", "release.yml"), encoding="utf-8").read()
        for piece in ("ControllerCam_HUD/ControllerCam_HUD.toc", "ControllerCam_HUD/*.lua", "ControllerCam_HUD/Bindings.xml",
                      "cp -r ControllerCam_HUD/Media dist/ControllerCam_HUD/Media", "python tests/test_controllercam_hud.py",
                      "ControllerCam ControllerCam_HUD)"):
            self.assertIn(piece, wf)
        self.assertIn("python tests/test_controllercam_hud.py",
                      open(os.path.join(ROOT, ".github", "workflows", "tests.yml"), encoding="utf-8").read())
        self.assertIn("ControllerCam/ControllerCam_HUD: ControllerCam_HUD",
                      open(os.path.join(ROOT, ".pkgmeta"), encoding="utf-8").read())
        self.assertTrue(os.path.isfile(os.path.join(HUD, "Bindings.xml")))

    def test_bindings_call_functions_that_exist(self):
        xml = open(os.path.join(HUD, "Bindings.xml"), encoding="utf-8").read()
        e = Env()
        names = re.findall(r'name="(\w+)"', xml)
        self.assertEqual(len(names), 9)
        for name in names:
            self.assertIsNotNone(e.g["BINDING_NAME_" + name], name)
        for fn in re.findall(r"(\w+)\(\)", xml):
            self.assertIsNotNone(e.g[fn], fn)


class Locales(unittest.TestCase):
    NAMES = ["deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW"]
    PLACEHOLDER = re.compile(r"%[-.\d]*[sd]|%%|\\n")

    @classmethod
    def setUpClass(cls):
        import sys
        sys.path.insert(0, os.path.join(ROOT, "docs", "locales"))
        import extract_hud
        import gen_hud_locales
        cls.extract, cls.gen = extract_hud, gen_hud_locales

    def test_the_generated_file_is_up_to_date(self):
        self.assertEqual(self.gen.main(True), 0)
        data = Env().ns.localeData
        # the keys are Lua string contents: "\n" in the file is a line break once Lua has read it
        self.assertEqual(list(data.english.values()), [k.replace("\\n", "\n") for k in self.extract.keys()])

    def test_every_text_is_translated_everywhere(self):
        data = Env().ns.localeData
        english = list(data.english.values())
        self.assertGreater(len(english), 150)
        for name in self.NAMES:
            table = list(data.translations[name].values())
            self.assertEqual(len(table), len(english), name)
            for en, tr in zip(english, table):
                self.assertTrue(tr.strip(), "%s: %s" % (name, en))
                self.assertEqual(self.PLACEHOLDER.findall(tr), self.PLACEHOLDER.findall(en), "%s: %s" % (name, en))
                self.assertEqual(tr.count("/cchud"), en.count("/cchud"), "%s: %s" % (name, en))

    def test_translations_are_not_just_english(self):
        data = Env().ns.localeData
        english = list(data.english.values())
        for name in self.NAMES:
            table = list(data.translations[name].values())
            same = sum(1 for en, tr in zip(english, table) if en == tr and len(en) > 12)
            self.assertLess(same, 6, name)

    def test_a_german_session_speaks_german(self):
        e = Env(locale="deDE")
        self.assertEqual(e.errors(), [])
        L = e.ns.L
        self.assertNotEqual(L["Changes are applied when combat ends."], "Changes are applied when combat ends.")
        self.assertEqual(L["something nobody translated"], "something nobody translated")
        self.assertTrue(e.frames.player.on)                          # and everything still works
        e.target()
        self.assertEqual(e.ns.RunCheck(False)[0], 0)
        help_text = e.cmd("help")
        self.assertIn("/cchud unlock", help_text)
        self.assertNotIn("show this list", help_text)

    def test_every_locale_loads_and_runs(self):
        for name in self.NAMES + ["enGB", "xxXX"]:
            e = Env(locale=name)
            e.target()
            e.cmd("demo")
            e.update(3)
            e.cmd("demo")
            e.cmd("")
            e.ns.BuildOptions()
            self.assertEqual(e.errors(), [], name)

    def test_mexican_spanish_uses_the_spanish_text(self):
        a, b = Env(locale="esMX"), Env(locale="esES")
        key = "Changes are applied when combat ends."
        self.assertEqual(a.ns.L[key], b.ns.L[key])
        self.assertNotEqual(a.ns.L[key], key)


class UnitMenu(unittest.TestCase):
    def test_the_games_frames_stay_in_place_for_the_unit_menu(self):
        e = Env()
        e.target()
        for name in ("PlayerFrame", "TargetFrame", "FocusFrame"):
            self.assertEqual(e.parent(name), "UIParent")            # still where the game keeps it
            self.assertTrue(e.aside(name))
            f = e.g[name]
            f.SetAlpha(f, 1)                                         # the game fades it back in (range, ...)
            e.update(0.15)                                           # our timer puts ours back (no hooks)
            self.assertEqual(f.alpha, 0)
        e.cmd("off")
        self.assertEqual(e.g.TargetFrame.alpha, 1)                  # and it is given back as the game wants it
        e.g.TargetFrame.SetAlpha(e.g.TargetFrame, 0.5)
        self.assertEqual(e.g.TargetFrame.alpha, 0.5)


class Gate(unittest.TestCase):
    def test_mouse_ui_leaves_everything_alone(self):
        e = Env(style="0")
        self.assertIsNone(e.frames.player)
        self.assertEqual(e.aside("PlayerFrame"), False)
        self.assertEqual(e.aside("TargetFrame"), False)
        self.assertEqual(e.g.ChatFrame1.points[1][1], "CENTER")
        self.assertEqual(e.errors(), [])

    def test_gamepad_ui_takes_over(self):
        e = Env()
        self.assertTrue(e.frames.player.on)
        self.assertTrue(e.frames.player.button.shown)
        self.assertEqual(e.frames.player.button.attrs.unit, "player")
        self.assertEqual(e.aside("PlayerFrame"), True)
        self.assertEqual(e.aside("TargetFrame"), True)
        self.assertFalse(e.g.ControllerCamHUDHidden.shown)
        self.assertEqual(e.g.ChatFrame1.points[1][1], "CENTER")       # chat stays put unless asked
        self.assertEqual(e.errors(), [])

    def test_chat_moves_only_when_asked(self):
        e = Env()
        e.cmd("chat on")
        self.assertEqual(e.g.ChatFrame1.points[1][1], "TOPLEFT")
        e2 = Env(db="{ chat = true }")                # saved by the first version, where it was the default
        self.assertEqual(e2.g.ChatFrame1.points[1][1], "CENTER")
        e3 = Env(db="{ v = 2, chat = true }")
        self.assertEqual(e3.g.ChatFrame1.points[1][1], "TOPLEFT")

    def test_player_sits_top_left_and_target_top(self):
        e = Env()
        self.assertEqual(e.frames.player.mover.points[1][1], "TOPLEFT")
        self.assertEqual(e.frames.target.mover.points[1][1], "TOP")

    def test_always_runs_in_the_mouse_ui_too(self):
        e = Env(style="0", db="{ always = true }")
        self.assertTrue(e.frames.player.on)

    def test_off_gives_everything_back(self):
        e = Env(db="{ v = 2, chat = true }")
        e.target()
        e.cmd("off")
        self.assertEqual(e.aside("PlayerFrame"), False)
        self.assertEqual(e.aside("TargetFrame"), False)
        self.assertFalse(e.frames.player.button.shown)
        self.assertFalse(e.frames.target.button.shown)
        self.assertEqual(e.g.ChatFrame1.points[1][1], "CENTER")
        self.assertEqual(e.mock.anchorCalls, 1)
        e.cmd("on")
        self.assertEqual(e.aside("PlayerFrame"), True)
        self.assertEqual(e.g.ChatFrame1.points[1][1], "TOPLEFT")

    def test_nothing_is_changed_in_combat(self):
        e = Env(combat=True)
        self.assertIsNone(e.frames.player)
        self.assertEqual(e.aside("PlayerFrame"), False)
        self.assertTrue(e.ns.IsPending())
        e.mock.state.combat = False
        e.mock.fire("PLAYER_REGEN_ENABLED")
        self.assertTrue(e.frames.player.on)
        self.assertEqual(e.aside("PlayerFrame"), True)

    def test_a_change_in_combat_waits_and_says_so(self):
        e = Env()
        e.mock.state.combat = True
        out = e.cmd("target off")
        self.assertIn("when combat ends", out)
        self.assertTrue(e.frames.target.on)
        e.mock.state.combat = False
        e.mock.fire("PLAYER_REGEN_ENABLED")
        self.assertFalse(e.frames.target.on)
        self.assertEqual(e.aside("TargetFrame"), False)       # the game's target frame is back

    def test_chat_move_survives_the_game_reapplying_its_layout(self):
        e = Env(db="{ v = 2, chat = true }")
        e.g.ChatFrame1.ApplySystemAnchor(e.g.ChatFrame1)
        self.assertEqual(e.g.ChatFrame1.points[1][1], "TOPLEFT")
        e.cmd("chat off")
        self.assertEqual(e.g.ChatFrame1.points[1][1], "CENTER")
        e.g.ChatFrame1.ApplySystemAnchor(e.g.ChatFrame1)
        self.assertEqual(e.g.ChatFrame1.points[1][1], "CENTER")

    def test_nothing_about_the_layout_is_saved(self):
        e = Env()
        saved = e.mock.serialize(e.g.ControllerCamHUDDB)
        self.assertNotIn("TOPLEFT", saved)
        self.assertNotIn("Chat", saved)


class FirstRun(unittest.TestCase):
    """Beside ControllerCam the HUD first asks whether it is wanted, and rests until it is told."""

    CAMERA = ("ControllerCam",)

    def test_a_first_run_beside_the_camera_rests_and_asks(self):
        e = Env(addons=self.CAMERA)
        self.assertFalse(e.ns.ShouldRun())
        self.assertIsNone(e.frames.player)                           # nothing of ours, nothing of the game's touched
        self.assertEqual(e.aside("PlayerFrame"), False)
        self.assertEqual(len(list(e.mock.popups.values())), 0)
        e.update(4)
        self.assertEqual(e.mock.visiblePopup.which, "CCHUD_WELCOME")
        self.assertEqual((e.mock.visiblePopup.dialog.button1, e.mock.visiblePopup.dialog.button2),
                         ("Camera + HUD", "Camera only"))
        self.assertFalse(e.ns.ShouldRun())                           # still resting while the question is up
        said = e.mock.answer("accept")
        self.assertTrue(e.db.asked and e.db.enabled)
        self.assertTrue(e.frames.player.on)
        self.assertEqual(e.aside("PlayerFrame"), True)
        self.assertEqual(e.errors(), [])

    def test_camera_only_leaves_the_game_as_it_was(self):
        e = Env(addons=self.CAMERA)
        e.update(4)
        e.mock.answer("cancel")
        self.assertTrue(e.db.asked)
        self.assertFalse(e.db.enabled)
        self.assertIsNone(e.frames.player)
        self.assertEqual(e.aside("PlayerFrame"), False)
        self.assertIn("/cchud on", list(e.mock.printed.values())[-1])
        again = Env(addons=self.CAMERA, db="{ v = 8, asked = true, enabled = false }")    # and it does not ask again
        again.update(4)
        self.assertEqual(len(list(again.mock.popups.values())), 0)
        self.assertFalse(again.ns.ShouldRun())
        again.cmd("on")                                              # until you switch it on yourself
        self.assertTrue(again.frames.player.on)

    def test_no_answer_asks_again_next_time(self):
        e = Env(addons=self.CAMERA)
        e.update(4)
        e.mock.visiblePopup.dialog.OnCancel(None, None, "override")  # another dialog took its place
        self.assertFalse(e.db.asked)
        later = Env(addons=self.CAMERA, db="{ v = 8, asked = false, enabled = false }")
        later.update(4)
        self.assertEqual(later.mock.visiblePopup.which, "CCHUD_WELCOME")

    def test_switching_it_on_yourself_is_an_answer(self):
        e = Env(addons=self.CAMERA)
        e.cmd("on")
        self.assertTrue(e.frames.player.on)
        e.update(4)
        self.assertEqual(len(list(e.mock.popups.values())), 0)       # the question never comes
        ticked = Env(addons=self.CAMERA, db="{ v = 8, asked = false, enabled = true }")   # ticked in the options
        ticked.update(4)
        self.assertTrue(ticked.db.asked)
        self.assertEqual(len(list(ticked.mock.popups.values())), 0)
        off = Env(addons=self.CAMERA)
        off.cmd("off")
        off.update(4)
        self.assertEqual(len(list(off.mock.popups.values())), 0)

    def test_on_its_own_or_with_settings_from_before_it_does_not_ask(self):
        alone = Env()                                                # no camera addon: the HUD was what you wanted
        alone.update(4)
        self.assertTrue(alone.db.asked and alone.db.enabled)
        self.assertTrue(alone.frames.player.on)
        self.assertEqual(len(list(alone.mock.popups.values())), 0)
        before = Env(addons=self.CAMERA, db="{ v = 7 }")             # you had it already
        before.update(4)
        self.assertTrue(before.db.asked and before.db.enabled)
        self.assertTrue(before.frames.player.on)
        self.assertEqual(len(list(before.mock.popups.values())), 0)

    @staticmethod
    def last_popup(e):
        popups = list(e.mock.popups.values())
        return popups[-1].which if popups else None

    def test_the_screen_is_set_up_after_the_hud_is_chosen(self):
        e = Env(setup=MarketAndItems.game("{ activeLayout = 1, layouts = {} }"))    # a first run, on the game's Modern
        e.update(4)
        self.assertEqual(self.last_popup(e), "CCHUD_WELCOME")
        e.mock.answer("accept")
        e.update(1)
        self.assertEqual(self.last_popup(e), "CCHUD_SCREEN")                        # the second question
        e.mock.answer("accept")
        mine = e.mock.layouts.layouts[1]
        self.assertEqual((mine.layoutName, mine.layoutType), ("CCHUD", 1))  # added to the game's own
        self.assertEqual(mine.text, e.ns.Presets.SCREEN.text)
        self.assertEqual((e.mock.layouts.activeLayout, e.mock.layoutChosen), (1, None))   # choosing it is yours to do
        self.assertIn("Edit Mode", list(e.mock.printed.values())[-1])                   # and you are told where
        self.assertTrue(e.db.screenAsked)
        self.assertIn("CCHUD", list(e.mock.printed.values())[-1])
        self.assertRegex(e.ns.Presets.SCREEN.text, r"^1 52 [ -~]+$")
        self.assertEqual(len(e.ns.Presets.SCREEN.text.split(" ")), 2 + 52 * 10)     # the game's own share text, whole
        self.assertEqual(e.errors(), [])

    def test_the_screen_is_offered_once_and_only_on_a_built_in_layout(self):
        have = Env(setup=MarketAndItems.game("{ activeLayout = 2, layouts = {} }", camera=False), db="{ v = 8 }")
        have.update(4)                                                              # you had the HUD already
        self.assertEqual(self.last_popup(have), "CCHUD_SCREEN")
        have.mock.answer("cancel")                                                  # "Not now"
        self.assertTrue(have.db.screenAsked)
        self.assertIsNone(have.mock.layoutsWritten)                                 # nothing of the game's was touched
        again = Env(setup=MarketAndItems.game("{ activeLayout = 2, layouts = {} }", camera=False),
                    db="{ v = 8, screenAsked = true }")
        again.update(4)
        self.assertIsNone(self.last_popup(again))                                   # and it does not ask again
        again.cmd("setup")                                                          # until you ask for it
        self.assertEqual(self.last_popup(again), "CCHUD_SCREEN")
        own = Env(setup=MarketAndItems.game(MarketAndItems.MINE, camera=False), db="{ v = 8 }")
        own.update(4)
        self.assertIsNone(self.last_popup(own))                                     # a layout of your own: not asked
        off = Env(setup=MarketAndItems.game("{ activeLayout = 1, layouts = {} }", camera=False),
                  db="{ v = 8, enabled = false }")
        off.update(4)
        self.assertIsNone(self.last_popup(off))                                     # nor with the HUD off
        bare = Env(db="{ v = 8 }")                                                  # a client without these functions
        bare.update(4)
        self.assertIsNone(self.last_popup(bare))
        self.assertIn("does not let addons", bare.cmd("setup"))

    def test_a_layout_the_game_takes_but_will_not_switch_to_is_said_so(self):
        e = Env(setup=MarketAndItems.game("{ activeLayout = 1, layouts = {} }", camera=False), db="{ v = 8 }")
        e.lua.execute("local save = C_EditMode.SaveLayouts; "
                      "C_EditMode.SaveLayouts = function(all) all.activeLayout = 1; save(all) end")   # it keeps its own
        e.update(4)
        e.mock.answer("accept")
        said = list(e.mock.printed.values())[-1]
        self.assertIn("was added", said)
        self.assertIn("Edit Mode", said)
        refuses = Env(setup=MarketAndItems.game("{ activeLayout = 1, layouts = {} }", camera=False), db="{ v = 8 }")
        refuses.lua.execute("C_EditMode.SaveLayouts = function() end; "                  # a refused call says nothing
                            "C_EditMode.GetLayouts = function() return { activeLayout = 1, layouts = {} } end")
        refuses.update(4)
        refuses.mock.answer("accept")
        self.assertIn("left as it is", list(refuses.mock.printed.values())[-1])

    def test_a_preset_brings_the_screen_layout_once_and_reset_puts_it_back(self):
        e = Env(setup=MarketAndItems.game("{ activeLayout = 1, layouts = {} }", camera=False),
                db="{ v = 8, screenAsked = true }")
        said = e.cmd("preset action")
        self.assertIn("A layout named 'CCHUD' was added", said)             # the game's side of the screen
        mine = e.mock.layouts.layouts[1]
        self.assertEqual(mine.layoutName, "CCHUD")
        mine.text = "arranged by hand"                                              # you arrange it in Edit Mode
        self.assertNotIn("was added", e.cmd("preset arpg"))                         # another preset leaves it be
        self.assertEqual(e.mock.layouts.layouts[1].text, "arranged by hand")
        self.assertEqual(e.mock.layoutsWritten, 1)
        e.db.plateTitles, e.db.pos.target = False, e.lua.table(x=5, y=6)
        e.db.sell.junk[1234] = True
        said = e.cmd("reset all")                                                   # over your head: everything back
        self.assertIn("back to how it started", said)
        self.assertEqual(e.mock.layouts.layouts[1].text, e.ns.Presets.SCREEN.text)  # the layout as we made it
        self.assertEqual(len(list(e.mock.layouts.layouts.values())), 1)
        self.assertTrue(e.db.plateTitles)
        self.assertIsNone(e.db.pos.target)
        self.assertIsNone(e.db.preset)
        self.assertTrue(e.db.sell.junk[1234])                                       # what you collected is kept
        self.assertTrue(e.db.enabled and e.db.asked)
        self.assertEqual(e.errors(), [])
        own = Env(setup=MarketAndItems.game(MarketAndItems.MINE, camera=False), db="{ v = 8 }")
        self.assertNotIn("was added", own.cmd("preset action"))                     # on a layout of your own: left alone
        self.assertIsNone(own.mock.layoutsWritten)

    def test_the_screen_waits_for_the_fight_to_end(self):
        e = Env(setup=MarketAndItems.game("{ activeLayout = 1, layouts = {} }", camera=False), db="{ v = 8 }")
        e.update(4)
        e.mock.state.combat = True
        e.mock.answer("accept")
        self.assertIsNone(e.mock.layoutsWritten)
        self.assertFalse(e.db.screenAsked)                                          # it asks again next time

    def test_the_camera_counts_however_the_game_reports_it(self):
        e = Env(setup=lambda env: env.lua.execute(
            "C_AddOns = { IsAddOnLoaded = function(name) return name == 'ControllerCam' and 1 or nil end }"))
        self.assertTrue(e.ns.Welcome.CameraLoaded())                                # older clients answer 1, not true
        self.assertFalse(e.db.enabled)                                              # so this first run rests and asks
        e.update(4)
        self.assertEqual(self.last_popup(e), "CCHUD_WELCOME")

    def test_it_can_be_asked_again_and_is_not_part_of_a_shared_line(self):
        e = Env(addons=self.CAMERA, db="{ v = 8, asked = true, enabled = false }")
        self.assertIn("welcome", e.cmd("help"))
        e.cmd("welcome")
        e.mock.answer("accept")
        self.assertTrue(e.db.enabled)
        self.assertNotIn("enabled=", e.ns.Share.Export())            # on or off stays yours
        self.assertNotIn("asked=", e.ns.Share.Export())
        off = Env(addons=self.CAMERA, db="{ v = 8, asked = true, enabled = false }")
        off.ns.Share.Import(e.ns.Share.Export() + ";enabled=b1")
        self.assertFalse(off.db.enabled)


class Bars(unittest.TestCase):
    def test_health_starts_full_without_animation(self):
        e = Env()
        bar = e.frames.player.health
        self.assertEqual((bar.fill.value, bar.fill.max), (1000, 1000))
        self.assertIsNone(bar.scripts.OnUpdate)

    def test_damage_drains_the_fill_and_leaves_a_trail(self):
        e = Env()
        bar = e.frames.player.health
        e.mock.units.player.health = 600
        e.mock.fire("UNIT_HEALTH", "player")
        e.update(0.1)
        self.assertLess(bar.fill.value, 1000)
        self.assertGreater(bar.fill.value, 600)
        self.assertEqual(bar.trail.value, 1000)          # the trail holds for a moment
        e.update(3)
        self.assertEqual(bar.fill.value, 600)
        self.assertEqual(bar.trail.value, 600)
        self.assertIsNone(bar.scripts.OnUpdate)          # and the bar stops working once it is done

    def test_healing_has_no_trail(self):
        e = Env()
        e.mock.units.player.health = 400
        e.mock.fire("UNIT_HEALTH", "player")
        e.update(3)
        bar = e.frames.player.health
        e.mock.units.player.health = 900
        e.mock.fire("UNIT_HEALTH", "player")
        e.update(0.1)
        self.assertEqual(bar.trail.value, bar.fill.value)
        e.update(3)
        self.assertEqual(bar.fill.value, 900)

    def test_colour_and_warning_follow_health(self):
        e = Env()
        f = e.frames.player
        self.assertEqual(e.color(f.health), (0.67, 0.83, 0.45))       # the player's class colour
        e.cmd("classcolor off")
        self.assertEqual(e.color(f.health), e.theme("health"))
        self.assertFalse(f.text.shown)
        for hp, name, glow in ((450, "caution", False), (200, "danger", True)):
            e.mock.units.player.health = hp
            e.mock.fire("UNIT_HEALTH", "player")
            self.assertEqual(e.color(f.health), e.theme(name))
            self.assertEqual(bool(f.glow.shown), glow)
        self.assertEqual(f.text.text, "20%")
        self.assertTrue(f.text.shown)

    def test_max_health_of_zero_does_not_break(self):
        e = Env()
        e.mock.units.player.health, e.mock.units.player.healthMax = 0, 0
        e.mock.fire("UNIT_MAXHEALTH", "player")
        e.update(3)
        self.assertEqual(e.errors(), [])
        self.assertEqual(e.frames.player.health.fill.value, 0)

    def test_secret_values_go_straight_to_the_game_bar(self):
        e = Env()
        secret, secret_max = e.mock.secret(), e.mock.secret()
        e.mock.units.player.health, e.mock.units.player.healthMax = secret, secret_max
        e.mock.fire("UNIT_HEALTH", "player")
        bar = e.frames.player.health
        self.assertTrue(e.same(bar.fill.value, secret))
        self.assertTrue(e.same(bar.fill.max, secret_max))
        self.assertIsNone(bar.GetFraction(bar))
        self.assertFalse(e.frames.player.text.shown)
        e.update(1)
        self.assertEqual(e.errors(), [])
        # and back to readable numbers afterwards
        e.mock.units.player.health, e.mock.units.player.healthMax = 500, 1000
        e.mock.fire("UNIT_HEALTH", "player")
        self.assertEqual(bar.fill.value, 500)

    def test_resource_colour_follows_its_kind(self):
        e = Env()
        e.mock.units.player.powerToken = "RAGE"
        e.mock.fire("UNIT_DISPLAYPOWER", "player")
        c = e.ns.colors.power.RAGE
        self.assertEqual(e.color(e.frames.player.power), (round(c[1], 2), round(c[2], 2), round(c[3], 2)))

    def test_bars_have_slanted_ends(self):
        e = Env()
        bar = e.frames.player.health
        self.assertIsNotNone(bar.mask)
        self.assertTrue(e.same(bar.fill.barTex.mask, bar.mask))

    def test_an_error_in_an_update_is_reported_once_and_does_not_spread(self):
        e = Env()
        e.lua.execute("UnitHealth = function() error('boom') end")
        e.mock.fire("UNIT_HEALTH", "player")
        e.mock.fire("UNIT_HEALTH", "player")
        self.assertEqual(len(e.errors()), 1)
        self.assertIn("boom", e.cmd(""))


class Target(unittest.TestCase):
    def test_no_target_no_frame(self):
        e = Env()
        self.assertTrue(e.frames.target.on)
        self.assertFalse(e.frames.target.button.shown)

    def test_target_is_described(self):
        e = Env()
        e.target(classification="elite")
        f = e.frames.target
        self.assertTrue(f.button.shown)
        self.assertIn("40", f.name.text)
        self.assertIn("Zengu", f.name.text)
        self.assertTrue(f.mark.shown)
        self.assertEqual(e.color(f.health), e.theme("hostile"))
        self.assertEqual(f.text.text, "800  100%")                  # full size: the health left and the percent
        self.assertEqual(f.health.fill.value, 800)
        self.assertEqual(e.errors(), [])

    def test_colours_tell_what_the_target_is(self):
        e = Env()
        for kw, name in ((dict(reaction=4), "neutral"), (dict(attackable=False), "friendly"),
                         (dict(tapped=True), "tapped"), (dict(dead=True), "tapped")):
            f = e.frames.target
            e.target(**kw)
            self.assertEqual(e.color(f.health), e.theme(name), kw)
        e.target(isPlayer=True, **{"class": "MAGE"})
        self.assertEqual(e.color(e.frames.target.health), (0.25, 0.78, 0.92))
        e.cmd("classcolor off")
        self.assertEqual(e.color(e.frames.target.health), e.theme("hostile"))

    def test_unknown_level_and_plain_targets(self):
        e = Env()
        e.target(level=-1, classification="worldboss")
        self.assertIn("??", e.frames.target.name.text)
        self.assertTrue(e.frames.target.mark.shown)
        e.target()
        self.assertFalse(e.frames.target.mark.shown)

    def test_switching_target_does_not_animate_from_the_old_one(self):
        e = Env()
        e.target()
        e.target(health=100, healthMax=1000)
        bar = e.frames.target.health
        self.assertEqual((bar.fill.value, bar.fill.max, bar.trail.value), (100, 1000, 100))

    def test_cast_bar_runs_and_ends(self):
        e = Env()
        t = e.target()
        now = e.mock.time
        t.cast = e.lua.table(name="Fireball", start=now * 1000, stop=(now + 2) * 1000)
        e.mock.fire("UNIT_SPELLCAST_START", "target")
        cast = e.frames.target.cast
        self.assertTrue(cast.shown)
        self.assertEqual(cast.label.text, "Fireball")
        e.update(1)
        self.assertAlmostEqual(cast.fill.value, 0.5, places=1)
        e.update(1.2)
        self.assertFalse(cast.shown)
        self.assertFalse(cast.label.shown)

    def test_channel_runs_backwards_and_stop_hides(self):
        e = Env()
        t = e.target()
        now = e.mock.time
        t.cast = e.lua.table(name="Drain", start=now * 1000, stop=(now + 4) * 1000, channel=True)
        e.mock.fire("UNIT_SPELLCAST_CHANNEL_START", "target")
        cast = e.frames.target.cast
        e.update(1)
        self.assertAlmostEqual(cast.fill.value, 0.75, places=1)
        t.cast = None
        e.mock.fire("UNIT_SPELLCAST_CHANNEL_STOP", "target")
        self.assertFalse(cast.shown)

    def test_cast_with_secret_times_shows_a_full_bar(self):
        e = Env()
        t = e.target()
        t.cast = e.lua.table(name="Hidden", start=e.mock.secret(), stop=e.mock.secret(), shielded=True)
        e.mock.fire("UNIT_SPELLCAST_START", "target")
        cast = e.frames.target.cast
        self.assertTrue(cast.shown)
        self.assertEqual(cast.fill.value, 1)
        self.assertEqual(e.color(cast), e.theme("shielded"))
        e.update(1)
        self.assertEqual(e.errors(), [])

    def test_pet_bar_appears_with_a_pet(self):
        e = Env()
        self.assertFalse(e.frames.pet.button.shown)
        e.mock.setUnit("pet", e.lua.table(name="Wolf", health=300, healthMax=600))
        self.assertTrue(e.frames.pet.button.shown)
        self.assertEqual(e.frames.pet.health.fill.value, 300)
        self.assertTrue(e.same(e.frames.pet.mover.points[1][2], e.frames.player.mover))


class Reading(unittest.TestCase):
    def test_target_of_target_follows_along(self):
        e = Env()
        e.target()
        tot = e.frames.tot
        self.assertFalse(tot.button.shown)
        e.mock.setUnit("targettarget", e.lua.table(name="Tank", health=500, healthMax=1000, isPlayer=True,
                                                   **{"class": "MAGE"}))
        self.assertTrue(tot.button.shown)
        e.update(0.3)
        self.assertIn("Tank", tot.name.text)
        self.assertIn("??", tot.name.text)                       # its level, coloured
        self.assertEqual(tot.health.fill.value, 500)
        self.assertEqual(e.color(tot.health), (0.25, 0.78, 0.92))
        # the target looks at someone else: no animation or flash carried over from the last one
        e.mock.units.targettarget = e.lua.table(name="Healer", health=100, healthMax=1000)
        e.update(0.3)
        self.assertIn("Healer", tot.name.text)
        self.assertEqual(tot.health.fill.value, 100)
        self.assertEqual(tot.flash.alpha, 0)
        e.cmd("tot off")
        self.assertFalse(tot.button.shown)
        self.assertEqual(e.errors(), [])

    def test_text_shade_can_be_switched(self):
        e = Env()
        shade = e.frames.target.shade
        self.assertTrue(shade.shown)
        e.cmd("shade off")
        self.assertFalse(shade.shown)
        e2 = Env(db=e.mock.serialize(e.g.ControllerCamHUDDB))
        self.assertFalse(e2.frames.target.shade.shown)

    def test_text_size(self):
        e = Env()
        name = e.frames.target.name
        self.assertAlmostEqual(name.fontSize, 13 * 1.5)                   # sized for a TV
        self.assertEqual(name.fontFlags, "OUTLINE")
        self.assertIn("140%", e.cmd("text 140"))
        self.assertAlmostEqual(name.fontSize, 13 * 1.4)
        self.assertAlmostEqual(e.frames.player.text.fontSize, 11 * 1.4)
        e.cmd("text 9000")
        self.assertEqual(e.db.textScale, 2.5)
        old = Env(db="{ v = 2, textScale = 1.15 }")                       # the earlier desktop default
        self.assertAlmostEqual(old.db.textScale, 1.5)
        kept = Env(db="{ v = 4, textScale = 1.2 }")
        self.assertAlmostEqual(kept.db.textScale, 1.2)
        self.assertIn("usage", e.cmd("text big"))


class EditMode(unittest.TestCase):
    def test_frames_can_be_dragged_while_edit_mode_is_open(self):
        e = Env()
        mover = e.frames.player.mover
        self.assertFalse(mover.movable)
        e.mock.editMode(True)
        self.assertTrue(mover.movable)
        self.assertTrue(mover.overlay.shown)
        self.assertTrue(e.frames.target.mover.movable)
        mover.cx, mover.cy = 300, 500
        mover.scripts.OnDragStop(mover)
        e.mock.editMode(False)
        self.assertFalse(mover.movable)
        self.assertFalse(mover.overlay.shown)
        self.assertEqual((e.db.pos.player.x, e.db.pos.player.y), (300 - 512, 500 - 384))

    def test_edit_mode_does_not_lock_what_you_unlocked_yourself(self):
        e = Env()
        e.cmd("unlock")
        e.mock.editMode(True)
        e.mock.editMode(False)
        self.assertTrue(e.frames.player.mover.movable)

    def test_edit_mode_is_ignored_when_the_hud_is_not_running_or_in_combat(self):
        e = Env(style="0")
        e.mock.editMode(True)
        self.assertIsNone(e.frames.player)
        self.assertEqual(e.errors(), [])
        e = Env()
        e.mock.state.combat = True
        e.mock.editMode(True)
        self.assertFalse(e.frames.player.mover.movable)


class GameOptions(unittest.TestCase):
    """Things that are the game's own settings: we flip the game's switch and never keep one of our own."""

    def alphas(self, e):
        return [e.g[name].alpha for name in e.mock.cooldownFrames.values()]

    def test_the_hud_never_switches_the_cooldown_manager_by_itself(self):
        e = Env(login=False)
        e.mock.cvars.cooldownViewerEnabled = "0"
        for ev in ("ADDON_LOADED", "PLAYER_LOGIN"):
            e.mock.fire(ev, "ControllerCam_HUD")
        e.mock.state.combat = True
        e.update(1)
        self.assertEqual(e.mock.cvars.cooldownViewerEnabled, "0")
        self.assertEqual(self.alphas(e), [1, 1, 1, 1])              # and its frames are never touched
        self.assertNotIn("cooldown", e.mock.serialize(e.g.ControllerCamHUDDB).lower())

    def test_our_switch_is_the_games_switch(self):
        e = Env()
        self.assertIn("off", e.cmd("cooldowns off"))
        self.assertEqual(e.mock.cvars.cooldownViewerEnabled, "0")
        e.cmd("cooldowns")
        self.assertEqual(e.mock.cvars.cooldownViewerEnabled, "1")
        e.cmd("resource on")
        self.assertEqual(e.mock.cvars.nameplateShowSelf, "1")
        self.assertIn("personal resource", e.cmd(""))

    def test_what_an_earlier_version_forced_on_is_put_back_once(self):
        e = Env(db="{ v = 2, saved = { cooldownViewerEnabled = '0' } }")
        self.assertEqual(e.mock.cvars.cooldownViewerEnabled, "0")
        self.assertIsNone(e.db.saved.cooldownViewerEnabled)

    def test_target_of_target_follows_the_games_option(self):
        e = Env(login=False)
        e.mock.cvars.showTargetOfTarget = "0"
        for ev in ("ADDON_LOADED", "PLAYER_LOGIN"):
            e.mock.fire(ev, "ControllerCam_HUD")
        e.target()
        e.mock.setUnit("targettarget", e.lua.table(name="Tank", health=5, healthMax=10))
        self.assertFalse(e.frames.tot.button.shown)
        e.cmd("tot on")
        self.assertEqual(e.mock.cvars.showTargetOfTarget, "1")
        self.assertTrue(e.frames.tot.button.shown)
        # switched off in the game's own options menu
        e.mock.cvars.showTargetOfTarget = "0"
        e.mock.fire("CVAR_UPDATE", "showTargetOfTarget", "0")
        self.assertFalse(e.frames.tot.button.shown)
        self.assertEqual(e.ns.RunCheck(False)[0], 0)

    def test_the_buff_tooltip_is_off_once_and_can_come_back(self):
        e = Env()
        self.assertEqual(e.mock.cvars.GamepadShowAutoAuraTooltip, "0")     # off to begin with
        e.cmd("auratooltip on")
        self.assertEqual(e.mock.cvars.GamepadShowAutoAuraTooltip, "1")
        saved = e.mock.serialize(e.g.ControllerCamHUDDB)
        e2 = Env(db=saved)
        self.assertEqual(e2.mock.cvars.GamepadShowAutoAuraTooltip, "1")    # never switched off again

    def test_a_client_without_the_option_says_so(self):
        e = Env()
        e.mock.cvars.nameplateShowSelf = None
        self.assertIn("does not have", e.cmd("resource on"))

    def test_focus_has_its_own_frame(self):
        e = Env()
        f = e.frames.focus
        self.assertFalse(f.button.shown)
        self.assertEqual(e.aside("FocusFrame"), True)
        e.mock.setUnit("focus", e.lua.table(name="Healer", level=60, health=300, healthMax=600, isPlayer=True,
                                            **{"class": "MAGE"}))
        self.assertTrue(f.button.shown)
        self.assertIn("Healer", f.name.text)
        self.assertEqual(f.health.fill.value, 300)
        self.assertEqual(e.color(f.health), (0.25, 0.78, 0.92))
        e.cmd("focus off")
        self.assertFalse(f.button.shown)
        self.assertEqual(e.aside("FocusFrame"), False)

    def test_target_of_target_and_focus_move_on_their_own(self):
        e = Env()
        e.mock.editMode(True)
        for key in ("player", "target", "tot", "focus"):
            mover = e.frames[key].mover
            self.assertTrue(mover.movable, key)
            mover.cx, mover.cy = 100, 100
            mover.scripts.OnDragStop(mover)
            self.assertIsNotNone(e.db.pos[key], key)
        self.assertFalse(e.frames.pet.mover.movable)
        e2 = Env(db=e.mock.serialize(e.g.ControllerCamHUDDB))
        self.assertEqual(e2.frames.tot.mover.points[1][1], "CENTER")


class CastLooks(unittest.TestCase):
    """Casts look like what they are: gathering, crafting, travel, or the school of the spell."""

    def player_cast(self, e, seconds=2, **kw):
        now = e.mock.time
        e.mock.units.player.cast = e.lua.table(start=now * 1000, stop=(now + seconds) * 1000, **kw)
        e.mock.fire("UNIT_SPELLCAST_START", "player")
        return e.ns.CastBar

    def test_mining_throws_chips_and_lands_its_own_way(self):
        e = Env()
        e.mock.spellNames = e.lua.table_from({2575: "Mining"})
        cb = self.player_cast(e, name="Mining", spellId=99999)          # another rank: known by its name
        self.assertEqual(cb.look.kind, "mining")
        ore = e.ns.CastLook.KINDS.mining.color
        self.assertEqual(round(cb.bar.fill.color[1], 2), round(ore[1], 2))
        self.assertEqual(cb.art.kind, "mining")                         # picks work on the bar
        self.assertEqual(len(list(e.ns.Impact.live.keys())), 0)
        chips = 0
        for _ in range(14):
            e.update(0.05)
            chips = max(chips, len(list(e.ns.Impact.live.keys())))
        self.assertGreater(cb.art.state.strikes, 0)                     # a pick came down
        self.assertGreater(chips, 0)                                    # and chips flew at the strike
        self.assertEqual(e.errors(), [])

    def test_opening_says_what_you_open(self):
        e = Env()
        cb = self.player_cast(e, name="Opening - No Text", spellId=22810)
        self.assertEqual(cb.look.kind, "opening")
        self.assertEqual(cb.frame.label.text, "Opening")
        e.mock.units.player.cast = None
        e.mock.fire("UNIT_SPELLCAST_STOP", "player")
        e.update(1)
        e.mock.units.softinteract = e.lua.table(name="Sweet Nectar Barrel")
        cb = self.player_cast(e, name="Opening - No Text", spellId=22810)
        self.assertEqual(cb.frame.label.text, "Opening: Sweet Nectar Barrel")
        e.mock.units.player.cast = None
        e.mock.fire("UNIT_SPELLCAST_STOP", "player")
        e.update(1)
        cb = self.player_cast(e, name="Holy Light", spellId=635)            # a spell keeps its own name
        self.assertEqual(cb.frame.label.text, "Holy Light")

    def test_crafting_and_the_hearthstone(self):
        e = Env()
        cb = self.player_cast(e, name="Copper Bar", spellId=2657, trade=True)
        self.assertEqual(cb.look.kind, "crafting")
        e.mock.units.player.cast = None
        e.mock.fire("UNIT_SPELLCAST_STOP", "player")
        e.update(1)
        cb = self.player_cast(e, name="Hearthstone", spellId=8690)
        self.assertEqual(cb.look.kind, "travel")

    def test_known_spells_have_their_school_from_the_start(self):
        e = Env()
        e.mock.spellNames = e.lua.table_from({635: "Holy Light", 585: "Smite"})
        cb = self.player_cast(e, name="Smite", spellId=10934)            # a higher rank: known by its name
        self.assertEqual(cb.look.kind, "holy")
        self.assertIsNotNone(cb.look.every)                             # its effect while it is cast
        holy = e.ns.Impact.PROFILES.holy.color
        self.assertEqual(round(cb.bar.fill.color[1], 2), round(holy[1], 2))
        e.mock.units.player.cast = None
        e.mock.fire("UNIT_SPELLCAST_STOP", "player")
        e.update(1)
        cb = self.player_cast(e, name="Holy Light", spellId=10329)       # a heal, whatever its school
        self.assertEqual((cb.look.kind, cb.look.school), ("heal", "holy"))
        self.assertEqual(round(cb.bar.fill.color[1], 2), round(holy[1], 2))

    def test_other_spells_learn_their_school_from_the_log(self):
        e = Env()
        cb = self.player_cast(e, name="Odd Bolt", spellId=99001)
        self.assertIsNone(cb.look)                                      # not known yet: the plain look
        e.mock.units.player.cast = None
        e.mock.fire("UNIT_SPELLCAST_STOP", "player")
        e.update(1)
        e.mock.logHit("SPELL_DAMAGE", "player", "target", 4)
        e.mock.logEntry[12] = 99001                                     # the same, as spell 99001
        e.mock.fire("COMBAT_LOG_EVENT_UNFILTERED")
        cb = self.player_cast(e, name="Odd Bolt", spellId=99001)
        self.assertEqual(cb.look.kind, "fire")

    def test_or_from_the_hit_that_follows_your_cast(self):
        e = Env()
        e.target()
        e.mock.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 99002)
        e.mock.fire("UNIT_COMBAT", "target", "WOUND", "", 120, 32)      # shadow, a moment later
        self.assertEqual(e.ns.Impact.SCHOOL_OF[99002], "shadow")
        e.mock.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 99003)
        e.mock.advance(3)
        e.mock.fire("UNIT_COMBAT", "target", "WOUND", "", 120, 16)      # too late to be that cast's
        self.assertIsNone(e.ns.Impact.SCHOOL_OF[99003])

    def test_your_bars_give_a_small_shake_when_you_are_hit(self):
        e = Env(db="{ v = 6, units = { vertical = true, player = true } }")
        IM = e.ns.Impact
        e.mock.fire("UNIT_COMBAT", "player", "WOUND", "", 80, 1)
        v = e.frames.vertical.visual
        self.assertIsNotNone(IM.shaking[v])
        amp = IM.shaking[v].amp
        self.assertLess(amp, IM.PROFILES.physical.amp)                  # a little: less than your own hits
        self.assertGreater(amp, 0)
        e.update(1)
        self.assertIsNone(IM.shaking[v])
        e.cmd("playershake off")
        e.mock.fire("UNIT_COMBAT", "player", "WOUND", "", 80, 1)
        self.assertIsNone(IM.shaking[v])

    def test_the_target_of_target_keeps_clear_of_the_target(self):
        e = Env()
        p = e.frames.tot.mover.points[1]
        self.assertEqual((p[1], p[3], p[4]), ("BOTTOMLEFT", "BOTTOMRIGHT", 56))
        self.assertTrue(e.same(p[2], e.frames.target.health))

    def test_a_long_target_name_stops_before_the_threat_shield(self):
        e = Env()
        f = e.frames.target
        self.assertEqual(f.name.width, 300)                             # the bar's width: the shield is beside it
        e.target(combat=True, threat=3)
        e.update(0.3)
        e.db.targetCompact = True                                       # (an options switch)
        e.ns.UnitFrames.ApplyLook(e.ns.UnitFrames)
        self.assertEqual(f.name.width, 260)                             # more room than the compact bar
        p = f.threatIcon.points[1]
        self.assertEqual((p[1], p[3]), ("LEFT", "RIGHT"))               # the shield beside the bar
        t = e.frames.tot.mover.points[1]
        self.assertEqual(t[4], 260 - 180 + 24)                          # the target of target out of the way

    def test_heals_light_up_the_bar_they_land_on(self):
        e = Env()
        e.target(attackable=False, reaction=5)
        before = len(list(e.ns.Impact.live.keys()))
        e.mock.fire("UNIT_COMBAT", "target", "HEAL", "", 300, 2)        # a holy heal on your target
        heal = e.ns.Impact.lastHeal
        self.assertTrue(e.same(heal.bar, e.frames.target.health))
        self.assertEqual(heal.school, "holy")
        self.assertGreater(e.frames.target.health.flashA, 0)
        self.assertGreater(len(list(e.ns.Impact.live.keys())), before)
        e.mock.advance(1)
        e.mock.fire("UNIT_COMBAT", "player", "HEAL", "", 300, 8)        # nature, on you
        self.assertEqual(e.ns.Impact.lastHeal.school, "nature")
        self.assertEqual(e.errors(), [])

    def enemy(self, e):
        data = e.lua.table(name="Witch Doctor", level=33, health=5, healthMax=5, attackable=True, reaction=2,
                           combat=True)
        plate = e.mock.addPlate("nameplate1", data)
        return data, e.ns.Nameplates.byPlate[plate]

    def enemy_cast(self, e, data, **kw):
        now = e.mock.time
        data.cast = e.lua.table(start=now * 1000, stop=(now + 2) * 1000, **kw)
        e.mock.fire("UNIT_SPELLCAST_START", "nameplate1")

    def test_enemy_casts_show_their_icon_and_school(self):
        e = Env()
        e.mock.logHit("SPELL_DAMAGE", "player", "target", 4)           # spell 133: fire
        data, o = self.enemy(e)
        self.enemy_cast(e, data, name="Fireball", spellId=133, icon=135812)
        self.assertTrue(o.castIcon.shown)
        self.assertEqual(o.castIcon.texture, 135812)
        fire = e.ns.Impact.PROFILES.fire.color
        self.assertEqual(round(o.cast.fill.color[1], 2), round(fire[1], 2))

    def test_an_interrupted_cast_shatters_and_lingers(self):
        e = Env()
        data, o = self.enemy(e)
        self.enemy_cast(e, data, name="Healing Ward", spellId=5000)
        e.update(0.5)
        before = len(list(e.ns.Impact.live.keys()))
        data.cast = None
        e.mock.fire("UNIT_SPELLCAST_INTERRUPTED", "nameplate1")
        e.mock.fire("UNIT_SPELLCAST_STOP", "nameplate1")             # the game says it stopped, too
        self.assertTrue(o.cast.shown)                                   # still there, saying so
        self.assertEqual(o.castText.text, "Interrupted")
        self.assertGreater(len(list(e.ns.Impact.live.keys())), before)  # the shatter
        e.update(0.6)
        self.assertFalse(o.cast.shown)
        self.assertFalse(o.castIcon.shown)
        self.assertEqual(e.errors(), [])

    def test_a_reused_plate_never_keeps_the_last_units_cast(self):
        e = Env()
        data, o = self.enemy(e)
        self.enemy_cast(e, data, name="Healing Ward", spellId=5000)
        data.cast = None
        e.mock.fire("UNIT_SPELLCAST_INTERRUPTED", "nameplate1")
        self.assertEqual(o.castText.text, "Interrupted")
        plate = e.mock.plates["nameplate1"]
        e.mock.removePlate("nameplate1")                              # the unit goes while it still says so
        other = e.lua.table(name="Headhunter", level=35, health=5, healthMax=5, attackable=True, reaction=2)
        e.mock.plates["nameplate1"], e.mock.units["nameplate1"] = plate, other
        e.mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")            # the game reuses the plate
        self.assertFalse(o.cast.shown)
        self.assertFalse(o.castText.shown)
        e.update(2)
        self.assertFalse(o.cast.shown)

    def test_a_landed_cast_bursts(self):
        e = Env()
        data, o = self.enemy(e)
        self.enemy_cast(e, data, name="Shadow Bolt", spellId=686)
        e.update(0.5)
        data.cast = None
        e.mock.fire("UNIT_SPELLCAST_SUCCEEDED", "nameplate1")
        self.assertTrue(o.cast.shown)
        self.assertEqual(o.cast.fill.value, 1)
        e.update(0.6)
        self.assertFalse(o.cast.shown)


class PresetsAndCamera(unittest.TestCase):
    CRITICAL = ("nameplates", "castbar", "group", "auras", "targetThreat", "numbers", "plateThreat",
                "plateDebuffs", "plateCC", "plateCastAlert", "plateTargetName", "plateLevels")

    def test_no_preset_takes_away_what_you_need(self):
        off = ", ".join("%s = false" % k for k in self.CRITICAL)
        for preset in ("action", "classic", "minimal", "openworld", "adventure", "soulslike", "shooter",
                       "crossbar", "arpg", "compass", "raid"):
            e = Env(db="{ v = 5, %s, units = { player = false, vertical = false, target = false } }" % off)
            self.assertIn("preset", e.cmd("preset " + preset))
            for key in self.CRITICAL:
                self.assertTrue(e.db[key], "%s: %s" % (preset, key))
            self.assertTrue(e.db.units.target, preset)
            self.assertTrue(e.db.units.player or e.db.units.vertical, preset)   # your vitals, one way or another
            self.assertEqual(e.errors(), [], preset)

    PRESETS = ("action", "classic", "minimal", "openworld", "adventure", "soulslike", "shooter", "crossbar",
               "arpg", "compass", "raid")

    def settings(self, e):
        keys = sorted(k for k in e.ns.Presets.Keys(e.ns.Presets).keys())
        return {k: e.db[k] for k in keys}

    def test_a_preset_is_the_same_whatever_came_before(self):
        fresh = {}
        for name in self.PRESETS:
            e = Env()
            e.cmd("preset " + name)
            fresh[name] = self.settings(e)
        e = Env()
        for before in ("crossbar", "arpg", "minimal", "raid"):          # whatever came before...
            for name in self.PRESETS:
                e.cmd("preset " + before)
                e.cmd("preset " + name)
                self.assertEqual(self.settings(e), fresh[name], "%s after %s" % (name, before))

    def test_crossbars_extras_do_not_linger(self):
        e = Env()
        e.cmd("preset crossbar")
        self.assertEqual(e.db.idle, 1)
        e.cmd("preset action")
        self.assertAlmostEqual(e.db.idle, 0.3)                      # back to what action wants
        self.assertTrue(e.db.plateSubtitles)

    def test_most_presets_name_npcs_jobs_and_guilds(self):
        with_subtitles = []
        for name in self.PRESETS:
            e = Env()
            e.cmd("preset " + name)
            if e.db.plateSubtitles:
                with_subtitles.append(name)
        self.assertGreaterEqual(len(with_subtitles), 7, with_subtitles)
        for name in ("action", "classic", "minimal", "openworld", "adventure", "crossbar", "compass", "raid"):
            self.assertIn(name, with_subtitles)

    def test_the_bar_style_is_yours_whatever_the_preset(self):
        e = Env()
        self.assertIn("compactall", e.cmd("help"))
        e.cmd("compactall on")
        self.assertTrue(e.db.targetCompact and e.db.plateCompact)
        self.assertEqual(e.frames.target.mover.width, int(300 * 0.6))
        for name in self.PRESETS:
            e.cmd("preset " + name)
            self.assertTrue(e.db.targetCompact and e.db.plateCompact, name)
        e.target()
        self.assertEqual(e.frames.target.text.text, "100%")         # compact target: the percent alone
        e.cmd("targetcompact off")
        self.assertEqual(e.frames.target.text.text, "800  100%")    # full: the health left too
        self.assertFalse(e.db.targetCompact)
        self.assertTrue(e.db.plateCompact)                          # one by one
        self.assertEqual(e.frames.target.mover.width, 300)
        self.assertIn("usage", e.cmd("compactall maybe"))
        keys = {d.key for d in e.ns.settings.values() if d.key} | {d.id for d in e.ns.settings.values() if d.id}
        for key in e.ns.STYLE.values():
            self.assertIn(key, keys)

    def test_camera_presets_choose_the_matching_hud_preset(self):
        e = Env()
        e.mock.state.zoom = 9
        self.assertTrue(e.g.ControllerCamHUD.CameraPreset("targetlock"))
        self.assertEqual(e.db.preset, "soulslike")
        self.assertEqual(e.mock.state.zoom, 9)                      # the camera keeps its own distance
        self.assertFalse(e.g.ControllerCamHUD.CameraPreset("nonsense"))
        e.cmd("followcamera off")
        self.assertFalse(e.g.ControllerCamHUD.CameraPreset("raid"))
        self.assertEqual(e.db.preset, "soulslike")

    def test_minimal_keeps_townsfolk_out_of_sight_until_pointed_at(self):
        e = Env()
        e.cmd("preset minimal")
        self.assertTrue(e.db.plateHoverNPC)
        e.cmd("preset action")
        self.assertFalse(e.db.plateHoverNPC)

    def test_a_preset_sets_the_camera_once(self):
        e = Env()
        e.cmd("preset arpg")
        self.assertAlmostEqual(e.mock.state.zoom, 28)
        self.assertEqual(e.db.followRef, 28)
        e.mock.state.zoom = 9                                       # you zoom as you like afterwards
        e.update(1)
        self.assertEqual(e.mock.state.zoom, 9)
        e.cmd("presetzoom off")
        e.cmd("preset shooter")
        self.assertEqual(e.mock.state.zoom, 9)

    def test_vertical_bars_follow_the_camera(self):
        e = Env(db="{ v = 5, units = { vertical = true }, followZoom = true, followRef = 10 }")
        f = e.frames.vertical
        f.mover.cx, f.mover.cy = 512 - 300, 384                     # 300 left of the middle
        e.mock.state.zoom = 10
        e.update(2)
        self.assertAlmostEqual(f.visual.baseX or 0, 0, delta=1)
        e.mock.state.zoom = 5                                       # closer: you look bigger, the bars ease out
        e.update(1)
        self.assertLess(f.visual.baseX, -30)                        # (gliding there, not jumping)
        self.assertGreater(f.visual.baseX, -105)
        e.update(5)
        self.assertAlmostEqual(f.visual.baseX, -105, delta=3)       # by how much you grew, not by their whole distance
        e.mock.state.zoom = 20                                      # further: they come in a little
        e.update(6)
        self.assertAlmostEqual(f.visual.baseX, 52, delta=3)
        e.mock.state.zoom = 60                                      # however far your camera goes: never onto you
        e.update(6)
        self.assertAlmostEqual(f.visual.baseX, 75, delta=3)         # a quarter of the way in, and no further
        e.mock.state.zoom = 1                                       # very close: held as at three yards,
        e.update(8)
        held = f.visual.baseX
        self.assertGreaterEqual(held, -(212 - e.ns.UnitFrames.FOLLOW.margin) - 1)   # and never off the screen
        self.assertLess(held, -150)
        e.mock.state.zoom = 0                                       # first person: they stay where they were
        e.update(3)
        self.assertAlmostEqual(f.visual.baseX, held, delta=1)
        e.cmd("followzoom off")
        e.update(3)
        self.assertAlmostEqual(f.visual.baseX, 0, delta=1)
        self.assertEqual(e.errors(), [])

    def test_full_names_everywhere(self):
        e = Env()
        faith = e.lua.table(name="Faith", realm="Ashborne", level=33, health=5, healthMax=5, isPlayer=True,
                            attackable=False, reaction=5, **{"class": "MAGE"})
        e.mock.setUnit("target", faith)
        e.mock.fire("PLAYER_TARGET_CHANGED")
        self.assertIn("Faith Ashborne", e.frames.target.name.text)
        o = e.ns.Nameplates.byPlate[e.mock.addPlate("nameplate1", faith)]
        self.assertEqual(o.name.text, "Faith Ashborne")             # no hyphen, nothing greyed
        titled = e.lua.table(name="Uther", realm="Lightbringer", title="Justicar Uther-Lightbringer", level=60,
                             health=5, healthMax=5, isPlayer=True, attackable=False, reaction=5)
        o2 = e.ns.Nameplates.byPlate[e.mock.addPlate("nameplate2", titled)]
        self.assertEqual(o2.name.text, "Justicar Uther Lightbringer")
        e.cmd("lastnames off")
        e.mock.fire("PLAYER_TARGET_CHANGED")
        self.assertNotIn("Ashborne", e.frames.target.name.text)

    def test_a_last_name_is_never_doubled(self):
        e = Env()
        titled = e.lua.table(name="Joric", realm="Millius", title="Joric Millius", level=33, health=5, healthMax=5,
                             isPlayer=True, attackable=False, reaction=5)
        o = e.ns.Nameplates.byPlate[e.mock.addPlate("nameplate1", titled)]
        self.assertEqual(o.name.text, "Joric Millius")
        champ = e.lua.table(name="Voriel", realm="Dawnsword", title="Champion Voriel Dawnsword", level=33, health=5,
                            healthMax=5, isPlayer=True, attackable=False, reaction=5)
        o2 = e.ns.Nameplates.byPlate[e.mock.addPlate("nameplate2", champ)]
        self.assertEqual(o2.name.text, "Champion Voriel Dawnsword")

    def test_a_name_handed_over_joined_loses_its_hyphen(self):
        e = Env()
        joined = e.lua.table(name="Faith-Ashborne", level=33, health=5, healthMax=5, isPlayer=True,
                             attackable=False, reaction=5)
        o = e.ns.Nameplates.byPlate[e.mock.addPlate("nameplate1", joined)]
        self.assertEqual(o.name.text, "Faith Ashborne")
        e.mock.setUnit("target", joined)
        out = e.cmd("names")
        self.assertIn("UnitName: Faith-Ashborne", out)
        self.assertIn("we show: Faith Ashborne", out)

    def test_errors_are_kept_to_report_them(self):
        e = Env()
        e.ns.Error("something broke")
        out = e.cmd("errors")
        self.assertIn("something broke", out)
        e2 = Env(db=e.mock.serialize(e.g.ControllerCamHUDDB))           # also after a reload
        self.assertIn("something broke", e2.cmd("errors"))
        e2.cmd("errors clear")
        self.assertIn("No errors", e2.cmd("errors"))

    def test_bars_left_at_an_old_spot_move_out_yours_stay(self):
        e = Env(db="{ v = 5, units = { vertical = true }, pos = { vertical = { x = -240, y = -20 } } }")
        self.assertIsNone(e.db.pos.vertical)
        e2 = Env(db="{ v = 5, units = { vertical = true }, pos = { vertical = { x = -333, y = 10 } } }")
        self.assertEqual(e2.db.pos.vertical.x, -333)

    def test_vertical_bars_start_further_left(self):
        e = Env(db="{ v = 5, units = { vertical = true } }")
        p = e.frames.vertical.mover.points[1]
        self.assertEqual((p[1], p[4]), ("CENTER", -280))

    def test_incoming_numbers_sit_at_the_vertical_bars(self):
        e = Env(db="{ v = 5, units = { vertical = true } }")
        N = e.ns.Numbers
        self.assertEqual(N.side, -1)
        self.assertTrue(e.same(N.holder.points[1][2], e.frames.vertical.visual))
        self.assertGreater(N.holder.points[1][5], 48)               # just above the top of the bars, not on them
        self.assertLess(N.holder.points[1][5], 48 + 30)             # (and not far above)
        e.mock.fire("UNIT_COMBAT", "player", "WOUND", "", 50, 1)
        n = list(N.live.values())[0]
        self.assertLess(n.dx, 0)                                    # falling away outward, to the left
        e.cmd("vertical off")
        self.assertEqual(N.side, 1)                                 # without them: beside your character

    def test_the_experience_bar_keeps_its_look_only_smaller(self):
        e = Env()
        mgr = e.g.StatusTrackingBarManager
        self.assertAlmostEqual(mgr.scale, 0.8)
        self.assertEqual(mgr.MainStatusTrackingBarContainer.BarFrameTexture.alpha, 1)   # its own art
        e.cmd("xpscale 60")
        self.assertAlmostEqual(mgr.scale, 0.6)
        e.cmd("skin off")
        self.assertAlmostEqual(mgr.scale, 1)


class Junk(unittest.TestCase):
    """What counts as junk: tools, gear with a use and possible upgrades never do; anything beyond grey is asked."""

    def env(self):
        e = Env(db="{ v = 5, sell = { auto = true, gear = true } }")
        put, T = e.mock.put, e.lua.table
        put(0, 1, T(id=2901, name="Mining Pick", quality=1, price=40, loc="INVTYPE_WEAPONMAINHAND", sub=0,
                    **{"class": 2}))                                                     # a tool that is a weapon
        put(0, 2, T(id=6256, name="Fishing Pole", quality=1, price=5, loc="INVTYPE_2HWEAPON", sub=20,
                    **{"class": 2}))
        put(0, 3, T(id=900, name="Odd Hammer", quality=1, price=30, loc="INVTYPE_WEAPON", sub=14,
                    **{"class": 2}))                                                     # miscellaneous: a tool
        put(0, 4, T(id=901, name="Old Boots", quality=1, price=20, loc="INVTYPE_FEET", ilvl=5, **{"class": 4}))
        put(0, 5, T(id=902, name="New Gloves", quality=1, price=20, loc="INVTYPE_HAND", ilvl=30, **{"class": 4}))
        put(0, 6, T(id=903, name="Trinket Toy", quality=1, price=20, loc="INVTYPE_HEAD", ilvl=2, use="Fun",
                    **{"class": 4}))                                                     # has a use
        put(0, 7, T(id=904, name="Grey Rag", quality=0, price=7, **{"class": 4}))
        for slot, (iid, lvl) in {8: (950, 20), 10: (951, 20), 1: (952, 20)}.items():   # what you wear
            e.mock["items"][iid] = T(id=iid, name="worn", quality=2, ilvl=lvl, price=1)
            e.mock.worn[slot] = iid
        return e

    def ids(self, e, mode="rules", quality=None):
        items, _ = e.ns.Vendor.Collect(e.ns.Vendor, mode, quality)
        return sorted(i.id for i in items.values())

    def test_tools_gear_with_a_use_and_upgrades_are_never_junk(self):
        e = self.env()
        self.assertEqual(self.ids(e), [901, 904])              # old boots (worse than yours) and the grey rag
        self.assertEqual(self.ids(e, "quality", 2), [901, 904])
        e.mock.worn[8] = None                                   # nothing on your feet: the boots could be worn
        self.assertEqual(self.ids(e), [904])

    def test_your_own_junk_mark_still_counts(self):
        e = self.env()
        e.db.sell.junk[2901] = True
        self.assertIn(2901, self.ids(e))

    def test_auto_sell_sells_grey_and_asks_about_the_rest(self):
        e = self.env()
        e.mock.openMerchant(True)
        e.mock.advance(2)
        self.assertEqual(list(e.mock.sold.values()), [904])    # the grey rag went by itself
        dialog = e.mock.answer("cancel")                        # the boots are asked about
        self.assertEqual(dialog.which, "CCHUD_SELL_CONFIRM")
        self.assertIn("Old Boots", dialog.text)
        self.assertNotIn(2901, list(e.mock.sold.values()))
        out = e.cmd("sold")
        self.assertIn("Grey Rag", out)
        self.assertIn("Buyback", out)


class Vendor(unittest.TestCase):
    def stock(self, e):
        put, T = e.mock.put, e.lua.table
        put(0, 1, T(id=1, name="Broken Fang", quality=0, price=50, count=4, **{"class": 15}))    # grey, 2s
        put(0, 2, T(id=2, name="Worn Sword", quality=1, price=300, **{"class": 2}))              # white weapon
        put(0, 3, T(id=3, name="Green Helm", quality=2, price=2500, **{"class": 4}))             # green armor
        put(1, 1, T(id=4, name="Linen Cloth", quality=1, price=13, count=20, **{"class": 7}))    # white trade good
        put(1, 2, T(id=5, name="Blue Staff", quality=3, price=10000, **{"class": 2}))            # blue weapon
        put(1, 3, T(id=6, name="Quest Rock", quality=1, price=0, **{"class": 12}))               # no price
        put(2, 1, T(id=7, name="Grey Rag", quality=0, price=7, **{"class": 4}))                  # grey armor
        return e

    def shop(self, **kw):
        e = self.stock(Env(**kw))
        e.mock.openMerchant(True)
        return e

    def ids(self, e, mode, quality=None):
        items, total = e.ns.Vendor.Collect(e.ns.Vendor, mode, quality)
        return sorted(i.id for i in items.values()), total

    def click(self, e):
        b = e.g.MerchantSellAllJunkButton
        b.scripts.OnClick(b)

    def said(self, e):
        return "\n".join(e.mock.printed.values())

    def test_junk_is_grey_items_by_default(self):
        e = self.shop()
        self.assertEqual(self.ids(e, "rules"), ([1, 7], 207))

    def test_white_gear_can_count_as_junk(self):
        e = self.shop()
        e.cmd("sellgear on")
        self.assertEqual(self.ids(e, "rules")[0], [1, 2, 7])       # the sword, not the cloth

    def test_by_quality_only_ever_takes_weapons_and_armor(self):
        e = self.shop()
        self.assertEqual(self.ids(e, "quality", 1)[0], [1, 2, 7])
        self.assertEqual(self.ids(e, "quality", 2)[0], [1, 2, 3, 7])
        self.assertEqual(self.ids(e, "quality", 3)[0], [1, 2, 3, 5, 7])

    def test_marks_win_over_rules(self):
        e = self.shop()
        e.cmd("keep 1")
        e.cmd("junk |Hitem:4|h[Linen Cloth]|h")
        self.assertEqual(self.ids(e, "rules")[0], [4, 7])
        self.assertEqual(self.ids(e, "quality", 3)[0], [2, 3, 4, 5, 7])
        e.cmd("keep 4")                                            # a mark replaces the other one
        self.assertEqual(self.ids(e, "rules")[0], [7])

    def test_what_is_never_sold(self):
        e = self.shop()
        T = e.lua.table
        e.mock.put(3, 1, T(id=20, name="Locked Junk", quality=0, price=5, locked=True, **{"class": 15}))
        e.mock.put(3, 2, T(id=21, name="Worthless", quality=0, price=5, noValue=True, **{"class": 15}))
        e.mock.put(3, 3, T(id=22, name="Set Piece", quality=0, price=5, inSet=True, **{"class": 4}))
        e.mock.put(4, 1, T(id=23, name="Safe Junk", quality=0, price=5, **{"class": 15}))
        e.mock.leftOut[4] = True                                   # the game is told to leave this bag alone
        self.assertEqual(self.ids(e, "rules")[0], [1, 7])
        e.mock.leftOut[0] = True
        self.assertEqual(self.ids(e, "rules")[0], [7])

    def test_the_sell_junk_button_asks_and_sells(self):
        e = self.shop()
        self.click(e)
        self.assertEqual(e.mock.nativeJunkClicks, 0)               # ours, not the game's
        asked = e.mock.answer("accept")
        self.assertEqual(asked.which, "CCHUD_SELL")
        self.assertIn("2 items for 2s 7c", asked.text)
        self.assertEqual(list(e.mock.sold.values()), [1])          # one at a time
        e.mock.advance(1)
        self.assertEqual(list(e.mock.sold.values()), [1, 7])
        self.assertEqual(e.mock.gold, 207)
        self.assertIn("sold 2 items for 2s 7c", self.said(e))
        self.assertEqual(e.errors(), [])

    def test_selling_by_quality_is_listed_and_confirmed(self):
        e = self.shop()
        self.click(e)
        e.mock.answer("alt")                                       # "By quality"
        which = e.mock.answer("alt")                               # "Uncommon"
        self.assertEqual(which.which, "CCHUD_SELL_QUALITY")
        self.assertIn("Common (white): 3, 5s 7c", which.text)
        self.assertIn("Uncommon (green): 4, 30s 7c", which.text)
        self.assertEqual(len(e.mock.sold), 0)
        confirm = e.mock.answer("accept")
        self.assertEqual(confirm.which, "CCHUD_SELL_CONFIRM")
        self.assertIn("Sell 4 items?", confirm.text)
        self.assertIn("30s 7c: Green Helm, Worn Sword", confirm.text)      # most valuable first
        e.mock.advance(2)
        self.assertEqual(sorted(e.mock.sold.values()), [1, 2, 3, 7])

    def test_cancelling_sells_nothing(self):
        e = self.shop()
        self.click(e)
        e.mock.answer("alt")
        e.mock.answer("accept")                                    # "Common"
        e.mock.answer("cancel")
        e.mock.advance(2)
        self.assertEqual(len(e.mock.sold), 0)
        self.assertIsNone(e.ns.Vendor.pending)

    def test_junk_beyond_grey_is_confirmed_first(self):
        e = self.shop()
        e.cmd("sellgear on")
        e.cmd("sell junk")
        self.assertEqual(len(e.mock.sold), 0)
        self.assertIn("Sell 3 items", e.mock.answer("accept").text)
        e.mock.advance(2)
        self.assertEqual(len(e.mock.sold), 3)

    def test_leaving_the_vendor_stops_the_sale(self):
        e = self.shop()
        e.cmd("sell junk")
        e.mock.openMerchant(False)
        e.mock.advance(2)
        self.assertEqual(list(e.mock.sold.values()), [1])
        self.assertIn("sold 1 items", self.said(e))
        self.assertIsNone(e.ns.Vendor.queue)

    def test_an_item_that_changed_is_not_sold(self):
        e = self.shop()
        e.cmd("sell junk")
        e.mock.put(2, 1, e.lua.table(id=99, name="Precious", quality=4, price=5, **{"class": 4}))
        e.mock.advance(2)
        self.assertEqual(list(e.mock.sold.values()), [1])

    def test_auto_sell_is_off_until_asked(self):
        e = self.shop()
        e.mock.advance(2)
        self.assertEqual(len(e.mock.sold), 0)
        e.mock.openMerchant(False)
        self.assertIn("on", e.cmd("autosell on"))
        e.mock.openMerchant(True)
        e.mock.advance(2)
        self.assertEqual(sorted(e.mock.sold.values()), [1, 7])
        e2 = Env(db=e.mock.serialize(e.g.ControllerCamHUDDB))
        self.assertTrue(e2.db.sell.auto)

    def test_commands(self):
        e = self.stock(Env())
        self.assertIn("Open a vendor first", e.cmd("sell"))
        e.mock.openMerchant(True)
        self.assertIn("usage", e.cmd("sell purple"))
        e.cmd("sell green")
        self.assertIn("Sell 4 items", e.mock.answer("cancel").text)
        e.cmd("sell")
        self.assertEqual(e.mock.answer("cancel").which, "CCHUD_SELL")
        self.assertIn("usage", e.cmd("junk"))
        self.assertIn("auto-sell", e.cmd(""))

    def test_nothing_to_sell(self):
        e = Env()
        e.mock.openMerchant(True)
        self.assertIn("Nothing to sell", e.cmd("sell junk"))

    def test_the_button_is_given_back(self):
        e = Env()
        b = e.g.MerchantSellAllJunkButton
        self.assertFalse(e.same(b.scripts.OnClick, e.mock.nativeJunkClick))
        e.cmd("vendor off")
        self.assertTrue(e.same(b.scripts.OnClick, e.mock.nativeJunkClick))
        e.mock.openMerchant(True)
        self.assertFalse(e.ns.Vendor.merchantOpen)                 # not even listening any more
        self.assertIn("off", e.cmd("sell"))
        e.cmd("vendor on")
        e.cmd("off")
        self.assertTrue(e.same(b.scripts.OnClick, e.mock.nativeJunkClick))
        e = Env(style="0")
        self.assertTrue(e.same(e.g.MerchantSellAllJunkButton.scripts.OnClick, e.mock.nativeJunkClick))

    def test_quick_move_sells_or_banks_and_never_uses_an_item(self):
        e = self.stock(Env())
        e.mock.pointAt(0, 2)
        e.g.ControllerCamHUD_QuickMove()
        self.assertIsNone(e.mock.usedItem)                         # nothing open: must not equip or eat it
        self.assertIn("vendor", self.said(e))
        e.mock.openBank(True)
        e.g.ControllerCamHUD_QuickMove()
        self.assertEqual(list(e.mock.moved.values()), [2])
        e.mock.openBank(False)
        e.mock.openMerchant(True)
        e.mock.pointAt(0, 3)
        e.g.ControllerCamHUD_QuickMove()
        self.assertEqual(list(e.mock.sold.values()), [3])
        e.mock.pointAt(None)
        e.g.ControllerCamHUD_QuickMove()
        self.assertIn("Point at an item first", self.said(e))
        e.mock.pointAt(1, 1)
        e.mock.state.combat = True
        e.g.ControllerCamHUD_QuickMove()
        self.assertEqual(len(e.mock.sold), 1)
        self.assertEqual(e.errors(), [])

    def test_marking_the_pointed_item_cycles_and_is_remembered(self):
        e = self.shop()
        e.mock.pointAt(1, 1)
        e.g.ControllerCamHUD_MarkItem()
        self.assertTrue(e.db.sell.junk[4])
        self.assertIn("Linen Cloth: junk", self.said(e))
        saved = e.mock.serialize(e.g.ControllerCamHUDDB)
        e.g.ControllerCamHUD_MarkItem()
        self.assertTrue(e.db.sell.keep[4])
        self.assertIsNone(e.db.sell.junk[4])
        e.g.ControllerCamHUD_MarkItem()
        self.assertTrue(e.db.sell.bank[4])
        self.assertIsNone(e.db.sell.keep[4])
        e.g.ControllerCamHUD_MarkItem()
        self.assertIsNone(e.db.sell.bank[4])
        e2 = Env(db=saved)
        self.assertTrue(e2.db.sell.junk[4])
        e3 = Env(db="{ v = 2, sell = { auto = 'yes', junk = { [5] = 'x', bad = true, [6] = true }, keep = 3 } }")
        self.assertFalse(e3.db.sell.auto)
        self.assertEqual(sorted(e3.db.sell.junk.keys()), [6])

    def test_items_marked_for_the_bank_are_deposited_and_never_sold(self):
        e = self.stock(Env())
        self.assertIn("Open the bank first", e.cmd("deposit"))
        e.cmd("bank 1")
        e.cmd("bank |Hitem:4|h[Linen Cloth]|h")
        e.mock.openMerchant(True)
        self.assertEqual(self.ids(e, "rules")[0], [7])              # the grey fang is for the bank now
        e.mock.openMerchant(False)
        e.mock.openBank(True)
        e.mock.advance(1)
        self.assertEqual(len(e.mock.moved), 0)                      # not by itself unless asked
        e.cmd("deposit")
        e.mock.advance(1)
        self.assertEqual(sorted(e.mock.moved.values()), [1, 4])
        self.assertIn("deposited 2 items", self.said(e))
        self.assertIn("Nothing to deposit", e.cmd("deposit"))
        e.cmd("depositmatch off")
        self.assertIn("Nothing is marked", e.cmd("deposit"))

    def test_deposit_puts_away_what_the_bank_already_holds(self):
        e = self.stock(Env())
        put, T = e.mock.put, e.lua.table
        e.mock.bags[-1] = T()
        put(-1, 1, T(id=4, name="Linen Cloth", quality=1, price=13, count=40, **{"class": 7}))    # cloth: banked
        put(-1, 2, T(id=1, name="Broken Fang", quality=0, price=50, **{"class": 15}))             # grey: never
        put(-1, 3, T(id=2901, name="Mining Pick", quality=1, price=16, **{"class": 2}))           # a tool: never
        put(-1, 4, T(id=3, name="Green Helm", quality=2, price=2500, **{"class": 4}))             # kept: never
        put(0, 4, T(id=2901, name="Mining Pick", quality=1, price=16, **{"class": 2}))
        e.db.sell.keep[3] = True
        e.mock.openBank(True)
        e.mock.advance(1)
        self.assertEqual(len(e.mock.moved), 0)                      # not by itself unless asked
        e.g.ControllerCamHUD_Deposit()                              # the key binding
        e.mock.advance(1)
        self.assertEqual(list(e.mock.moved.values()), [4])
        self.assertIn("deposited 1 items", self.said(e))
        e.mock.openBank(False)
        self.assertIn("Open the bank first", e.cmd("deposit"))

    def test_auto_deposit_and_the_games_reagent_option(self):
        e = self.stock(Env())
        e.cmd("bank 4")
        e.cmd("autodeposit on")
        e.mock.openBank(True)
        e.mock.advance(1)
        self.assertEqual(list(e.mock.moved.values()), [4])
        e.cmd("reagents on")
        self.assertEqual(e.mock.cvars.bankAutoDepositReagents, "1")
        e2 = Env(db=e.mock.serialize(e.g.ControllerCamHUDDB))
        self.assertTrue(e2.db.sell.deposit)
        self.assertTrue(e2.db.sell.bank[4])

    def test_money(self):
        e = Env()
        self.assertEqual([e.ns.Money(c) for c in (0, 7, 100, 12345, 10000, 10007)],
                         ["0c", "7c", "1s", "1g 23s 45c", "1g", "1g 7c"])


class GroupFrames(unittest.TestCase):
    def member(self, e, i=1, **kw):
        data = e.lua.table(name="Friend%d" % i, health=800, healthMax=1000, power=50, powerMax=100,
                           powerToken="RAGE", isPlayer=True, **{"class": "MAGE"})
        for k, v in kw.items():
            data[k] = v
        e.mock.setUnit("party%d" % i, data)
        return data, e.ns.Group.overlays[e.g.PartyFrame["MemberFrame%d" % i]]

    def test_our_look_sits_over_the_games_party_frame(self):
        e = Env()
        self.assertEqual(e.g.PartyFrame.alpha, 0)                    # invisible, still there and working
        self.assertEqual(e.parent("PartyFrame"), "UIParent")
        data, o = self.member(e)
        self.assertTrue(o.shown)
        self.assertTrue(e.same(o.points[1][2], e.g.PartyFrame.MemberFrame1))
        self.assertEqual(o.name.text, "Friend1")
        self.assertEqual(o.health.fill.value, 800)
        self.assertEqual(o.status.text, "80%")
        self.assertEqual(e.color(o.health), (0.25, 0.78, 0.92))
        self.assertEqual(o.power.fill.value, 50)
        self.assertIsNone(e.ns.Group.overlays[e.g.PartyFrame.MemberFrame2])
        self.assertEqual(e.errors(), [])

    def test_when_nothing_can_be_drawn_the_games_frames_stay_in_sight(self):
        e = Env()
        self.assertEqual(e.g.CompactRaidFrameContainer.alpha, 0)    # alone: nothing to see either way
        e.mock.setUnit("raid1", e.lua.table(name="Raider", health=5, healthMax=5))   # a raid, its frames not found
        e.update(0.3)
        self.assertEqual(e.g.CompactRaidFrameContainer.alpha, 1)    # in a group with nothing of ours: the game's
        failed, rows = e.ns.RunCheck(False)
        bad = [r.detail for r in rows.values() if not r.ok]
        self.assertEqual(failed, 1)
        self.assertIn("0 drawn", bad[0])

    def test_our_own_party_frames_when_the_game_hides_its_own(self):
        e = Env(setup=lambda env: setattr(env.mock, "partyHidden", True))
        data, _ = (None, None)
        e.mock.setUnit("party1", e.lua.table(name="Friend", health=600, healthMax=1000, isPlayer=True,
                                             **{"class": "MAGE"}))
        e.mock.setUnit("party2", e.lua.table(name="Other", health=1000, healthMax=1000))
        e.update(0.3)
        G = e.ns.Group
        self.assertTrue(G.ownParty)
        b1, o1 = G.party[1].button, G.party[1].o
        self.assertTrue(b1.shown)
        self.assertEqual(b1.attrs.unit, "party1")
        self.assertEqual(b1.attrs.type2, "togglemenu")               # the unit menu works on them
        self.assertTrue(o1.shown)
        self.assertEqual(o1.name.text, "Friend")
        self.assertEqual(o1.health.fill.value, 600)
        self.assertTrue(G.party[2].o.shown)
        self.assertFalse(G.party[3].button.shown)
        self.assertEqual(e.g.PartyFrame.alpha, 0)                    # something of ours is drawn
        e.mock.units.party1.health = 300
        e.mock.fire("UNIT_HEALTH", "party1")
        self.assertEqual(o1.health.goal, 300)
        self.assertEqual(e.ns.RunCheck(False)[0], 0)
        e.cmd("group off")
        self.assertFalse(b1.shown)
        self.assertFalse(G.ownParty)

    def test_members_found_inside_the_games_containers(self):
        e = Env()
        holder = e.g.CreateFrame("Frame", None, e.g.CompactRaidFrameContainer)
        cell = e.g.CreateFrame("Button", None, holder)
        cell.attrs.unit = "party2"
        e.mock.setUnit("party2", e.lua.table(name="Buddy", health=4, healthMax=8))
        e.update(0.3)
        o = e.ns.Group.overlays[cell]
        self.assertTrue(o.shown)
        self.assertEqual(o.name.text, "Buddy")

    def test_members_react_and_show_their_state(self):
        e = Env()
        data, o = self.member(e)
        data.health = 500
        e.mock.fire("UNIT_HEALTH", "party1")
        self.assertGreater(o.health.flashA, 0.4)
        data.health = 200
        e.mock.fire("UNIT_HEALTH", "party1")
        self.assertEqual(e.color(o.health), e.theme("danger"))
        data.dead = True
        e.mock.fire("UNIT_HEALTH", "party1")
        self.assertEqual((o.status.text, e.color(o.health)), ("Dead", e.theme("tapped")))
        data.dead, data.offline = False, True
        e.mock.fire("UNIT_CONNECTION", "party1")
        self.assertEqual(o.status.text, "Offline")

    def test_range_and_target_are_shown_at_a_glance(self):
        e = Env()
        data, o = self.member(e)
        self.assertEqual(o.alpha, 1)
        self.assertFalse(o.edge.shown)
        data.far = True
        e.mock.units.target = data
        e.update(0.3)
        self.assertEqual(o.alpha, 0.45)
        self.assertTrue(o.edge.shown)

    def test_raid_frames_and_changing_units(self):
        e = Env()
        native = e.mock.raidFrame(1, "raid1")
        e.mock.setUnit("raid1", e.lua.table(name="Raider", health=10, healthMax=10))
        e.mock.setUnit("raid2", e.lua.table(name="Other", health=3, healthMax=10))
        o = e.ns.Group.overlays[native]
        self.assertTrue(o.shown)
        self.assertEqual(o.name.text, "Raider")
        self.assertIsNone(o.health.mask)                             # small cells keep square bars
        self.assertEqual(e.g.CompactRaidFrameContainer.alpha, 0)
        native.attrs.unit = "raid2"                                  # the game re-sorted the raid
        e.update(0.3)
        self.assertEqual(o.name.text, "Other")
        self.assertEqual(o.health.fill.value, 3)
        self.assertFalse(bool(o.health.flashA and o.health.flashA > 0))
        native.shown = False
        e.update(0.3)
        self.assertFalse(o.shown)

    def test_off_and_edit_mode_give_the_games_frames_back(self):
        e = Env()
        data, o = self.member(e)
        e.cmd("group off")
        self.assertEqual(e.g.PartyFrame.alpha, 1)
        self.assertFalse(o.shown)
        e.cmd("group on")
        self.assertTrue(o.shown)
        e.mock.editMode(True)
        self.assertEqual((e.g.PartyFrame.alpha, e.g.CompactRaidFrameContainer.alpha), (1, 1))
        self.assertFalse(o.shown)
        self.assertEqual(e.ns.RunCheck(False)[0], 0)
        e.mock.editMode(False)
        self.assertEqual(e.g.PartyFrame.alpha, 0)
        self.assertTrue(o.shown)


class CastBars(unittest.TestCase):
    def cast(self, e, seconds=2, **kw):
        now = e.mock.time
        e.mock.units.player.cast = e.lua.table(name="Aimed Shot", start=now * 1000, stop=(now + seconds) * 1000, **kw)
        e.mock.fire("UNIT_SPELLCAST_CHANNEL_START" if kw.get("channel") else "UNIT_SPELLCAST_START", "player")
        return e.ns.CastBar

    def test_it_runs_where_the_games_bar_sits(self):
        e = Env()
        self.assertEqual(e.parent("PlayerCastingBarFrame"), "ControllerCamHUDHidden")
        cb = self.cast(e)
        self.assertTrue(cb.frame.shown)
        self.assertTrue(e.same(cb.frame.points[1][2], e.g.PlayerCastingBarFrame))
        self.assertEqual(cb.frame.label.text, "Aimed Shot")
        e.update(1)
        self.assertAlmostEqual(cb.bar.fill.value, 0.5, places=1)
        self.assertEqual(cb.frame.time.text, "1.0")
        e.mock.units.player.cast = None
        e.mock.fire("UNIT_SPELLCAST_STOP", "player")
        self.assertTrue(cb.frame.shown)                              # the result lingers a moment
        self.assertGreater(cb.bar.flashA, 0)
        e.update(0.6)
        self.assertFalse(cb.frame.shown)
        self.assertEqual(e.errors(), [])

    def test_an_interrupt_is_shown_as_one(self):
        e = Env()
        cb = self.cast(e)
        e.mock.units.player.cast = None
        e.mock.fire("UNIT_SPELLCAST_INTERRUPTED", "player")
        self.assertEqual(cb.frame.label.text, "Interrupted")
        self.assertEqual(e.color(cb.bar), e.theme("danger"))
        e.update(0.6)
        self.assertFalse(cb.frame.shown)

    def test_channels_secret_times_and_other_units(self):
        e = Env()
        cb = self.cast(e, 4, channel=True)
        e.update(1)
        self.assertAlmostEqual(cb.bar.fill.value, 0.75, places=1)
        e.mock.units.player.cast = e.lua.table(name="Hidden", start=e.mock.secret(), stop=e.mock.secret())
        e.mock.fire("UNIT_SPELLCAST_START", "player")
        self.assertEqual(cb.bar.fill.value, 1)
        e.update(0.5)
        self.assertEqual(e.errors(), [])
        e.mock.units.player.cast = None
        e.mock.fire("UNIT_SPELLCAST_STOP", "player")
        e.update(1)
        e.target(cast=e.lua.table(name="Enemy spell", start=0, stop=99999999))
        e.mock.fire("UNIT_SPELLCAST_START", "target")
        self.assertFalse(cb.frame.shown)

    def test_the_cast_winds_up_and_lands(self):
        e = Env()
        cb = self.cast(e, 2)
        e.update(0.2)
        early = cb.bar.charge.alpha
        e.update(1.5)
        self.assertGreater(cb.bar.charge.alpha, early)
        self.assertGreater(cb.bar.spark.width, 20)
        e.mock.units.player.cast = None
        e.mock.fire("UNIT_SPELLCAST_STOP", "player")
        self.assertEqual(cb.bar.charge.alpha, 0)
        self.assertGreater(len(list(e.ns.Impact.live.keys())), 0)               # it lands with a burst
        e.cmd("windup off")
        self.cast(e, 2)
        e.update(1.5)
        self.assertEqual(cb.bar.charge.alpha, 0)

    def test_fishing_shows_a_float_and_what_bites(self):
        e = Env(setup=lambda env: env.lua.execute("""
            ImprovedForever = { FishingData = {
                items = { [6303] = "Raw Slitherskin Mackerel|1|fish", [6356] = "Raw Rainbow Fin Albacore|1|fish",
                          [6307] = "Message in a Bottle|1|treasure" },
                zones = { [14] = "Durotar|6303:98:0,6356:2:0,6307:0.5:0" },
                areas = { [2] = "Longshore|40|6356:50:0,6307:0.5:0" } } }"""))
        e.mock.zone = "Durotar"
        cb = self.cast(e, 20, channel=True, spellId=7620)
        self.assertTrue(cb.fishing)
        self.assertTrue(cb.bar.bobber.shown)
        self.assertFalse(cb.bar.spark.shown)                         # nothing bright standing on the float
        p = cb.frame.points[1]                                       # the main event: in the middle, and larger
        self.assertEqual(p[1], "CENTER")
        self.assertTrue(e.same(p[2], e.g.UIParent))
        self.assertAlmostEqual(cb.frame.scale, 1.35 * 1.5)
        self.assertAlmostEqual(p[5] * cb.frame.scale, -100)
        self.assertIn("Raw Slitherskin Mackerel 98%", cb.frame.catch.text)
        self.assertIn("Raw Rainbow Fin Albacore 2%", cb.frame.catch.text)
        self.assertNotIn("Message", cb.frame.catch.text)            # fish only
        self.assertEqual(cb.frame.catchIcon.texture, 1000 + 6303)
        y = []
        for _ in range(6):
            e.update(0.1)
            y.append(cb.bar.bobber.points[1][5])
        self.assertGreater(len(set(round(v, 1) for v in y)), 3)      # it bobs
        e.mock.subzone = "Longshore"                                 # a smaller place has its own fish
        e.mock.fire("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
        self.assertIn("Raw Rainbow Fin Albacore 50%", cb.frame.catch.text)
        e.mock.units.player.cast = None
        e.mock.fire("UNIT_SPELLCAST_CHANNEL_STOP", "player")
        e.update(1)
        self.assertFalse(cb.bar.bobber.shown)
        self.assertTrue(e.same(cb.frame.points[1][2], e.g.PlayerCastingBarFrame))   # back where the game's bar sits
        self.assertAlmostEqual(cb.frame.scale, 1.35)
        self.cast(e, 2)                                              # another cast has its bright edge again
        self.assertTrue(cb.bar.spark.shown)
        e.cmd("fishbig off")                                         # or leave fishing where every cast is
        e.mock.units.player.cast = None
        e.mock.fire("UNIT_SPELLCAST_STOP", "player")
        e.update(1)
        self.cast(e, 20, channel=True, spellId=7620)
        self.assertTrue(e.same(cb.frame.points[1][2], e.g.PlayerCastingBarFrame))
        self.assertEqual(e.errors(), [])

    def test_fishing_without_the_fishing_data(self):
        e = Env()
        e.mock.zone = "Arathi Highlands"
        cb = self.cast(e, 20, channel=True, spellId=7620)
        self.assertTrue(cb.bar.bobber.shown)
        self.assertEqual(cb.frame.catch.text, "Arathi Highlands")
        e.cmd("fishing off")
        self.cast(e, 20, channel=True, spellId=7620)
        self.assertFalse(cb.bar.bobber.shown)

    def test_an_unfinished_cast_just_ends(self):
        e = Env()
        cb = self.cast(e, 1)
        e.update(1.2)                                                # no stop event arrived
        self.assertFalse(cb.casting)
        e.update(0.6)
        self.assertFalse(cb.frame.shown)

    def test_off_and_edit_mode_give_the_games_bar_back(self):
        e = Env()
        e.cmd("castbar off")
        self.assertEqual(e.parent("PlayerCastingBarFrame"), "UIParent")
        e.cmd("castbar on")
        e.mock.editMode(True)
        self.assertEqual(e.parent("PlayerCastingBarFrame"), "UIParent")
        e.mock.editMode(False)
        self.assertEqual(e.parent("PlayerCastingBarFrame"), "ControllerCamHUDHidden")


class Effects(unittest.TestCase):
    def aura(self, e, **kw):
        a = e.lua.table(icon=136207, applications=1, duration=18, expirationTime=e.mock.time + 18, mine=True)
        for k, v in kw.items():
            a[k] = v
        return a

    def shown(self, e):
        return [bool(b.shown) for b in e.ns.Auras.icons.values()].count(True)

    def test_your_effects_show_under_the_target(self):
        e = Env()
        e.target(auras=e.lua.table(self.aura(e), self.aura(e, icon=5, applications=3, duration=12)))
        e.mock.fire("UNIT_AURA", "target")
        icons = e.ns.Auras.icons
        self.assertEqual(self.shown(e), 2)
        self.assertTrue(e.mock.auraFilters["HARMFUL|PLAYER"])
        self.assertEqual(icons[1].icon.texture, 136207)
        self.assertEqual((icons[1].cooldown.cdStart, icons[1].cooldown.cdDuration), (e.mock.time, 18))
        self.assertEqual((icons[1].count.text, str(icons[2].count.text)), ("", "3"))
        e.target(attackable=False, auras=e.lua.table(self.aura(e)))
        self.assertTrue(e.mock.auraFilters["HELPFUL|PLAYER"])      # on a friend: your buffs
        self.assertEqual(self.shown(e), 1)
        e.mock.setUnit("target", None)
        self.assertEqual(self.shown(e), 0)
        self.assertEqual(e.errors(), [])

    def test_secret_times_do_not_break_it(self):
        e = Env()
        e.target(auras=e.lua.table(self.aura(e, duration=e.mock.secret(), expirationTime=e.mock.secret(),
                                             applications=e.mock.secret())))
        self.assertEqual(self.shown(e), 1)
        self.assertEqual(e.errors(), [])

    def test_combo_points(self):
        e = Env()
        e.target()
        A = e.ns.Auras
        self.assertFalse(A.pipRow.shown)
        e.mock.combo = 3
        e.mock.fire("UNIT_POWER_UPDATE", "player")
        self.assertTrue(A.pipRow.shown)
        lit = [round(p.vcolor[4], 2) == 1 for p in A.pips.values()]
        self.assertEqual(lit, [True, True, True, False, False])
        e.mock.combo = 5
        e.mock.fire("UNIT_POWER_UPDATE", "player")
        c = e.ns.colors.danger
        self.assertEqual(round(A.pips[5].vcolor[1], 2), round(c[1], 2))       # full: a different colour
        e.cmd("combo off")
        self.assertFalse(A.pipRow.shown)

    def test_switches(self):
        e = Env()
        e.target(auras=e.lua.table(self.aura(e)))
        self.assertEqual(self.shown(e), 1)
        e.cmd("auras off")
        self.assertEqual(self.shown(e), 0)
        e.cmd("auras on")
        e.cmd("target off")                               # no target frame of ours: nothing to hang them on
        self.assertFalse(e.ns.Auras.active)

    def test_the_demo_shows_them(self):
        e = Env()
        e.cmd("demo")
        self.assertEqual(self.shown(e), 3)                # your debuffs on the made-up enemy
        A = e.ns.Auras
        self.assertEqual(sum(1 for b in A.buffIcons.values() if b.shown), 2)     # its buffs
        self.assertTrue(A.ccIcon.shown)                   # and crowd control on it
        e.update(4.5)
        self.assertEqual(e.ns.Auras.points, 4)
        e.update(5.5)
        self.assertTrue(e.ns.CastBar.frame.shown)         # the made-up heal
        e.cmd("demo")
        self.assertEqual(self.shown(e), 0)
        self.assertFalse(e.ns.Auras.pipRow.shown)
        self.assertFalse(A.ccIcon.shown)
        self.assertEqual(e.errors(), [])

    def test_the_demo_needs_no_target_for_aggro_and_hits(self):
        e = Env()
        e.cmd("demo")
        e.update(2.0)
        t = e.frames.target
        self.assertTrue(t.threatIcon.shown)               # aggro on the made-up enemy
        self.assertEqual(e.ns.UnitFrames.threatState, "max")
        self.assertIsNotNone(e.ns.Impact.last)            # hit effects play on its frame
        self.assertGreater(e.ns.Numbers.shown or 0, 0)    # and the numbers on you
        self.assertEqual(e.errors(), [])


class GameAuraRows(unittest.TestCase):
    """A client with the game's own aura display element: it draws the effects, we only point it."""

    def env(self):
        def setup(env):
            env.mock.auraContainer = True
        return Env(setup=setup)

    def test_plates_use_the_games_rows(self):
        e = self.env()
        data = e.lua.table(name="Raptor", level=34, health=600, healthMax=800, attackable=True, reaction=2)
        plate = e.mock.addPlate("nameplate1", data)
        o = e.ns.Nameplates.byPlate[plate]
        self.assertTrue(o.wDebuffs)
        self.assertEqual(o.wDebuffs.unit, "nameplate1")
        self.assertTrue(o.wDebuffs.enabled and o.wDebuffs.shown)
        self.assertEqual(o.wDebuffs.groups["1"].filter, "HARMFUL|!CROWD_CONTROL|PLAYER")
        self.assertEqual(o.wDebuffs.groups["2"].filter, "HARMFUL|!CROWD_CONTROL|IMPORTANT|!PLAYER")
        self.assertEqual(o.wBuffs.groups["1"].filter, "HELPFUL|IMPORTANT|!PLAYER")    # only what matters
        self.assertEqual(o.wCC.groups["1"].filter, "HARMFUL|CROWD_CONTROL")
        self.assertTrue(o.wCC.shown)
        icon = o.wDebuffs.groups["1"].icon                # our look on the game's icon
        self.assertIsNotNone(icon.iconTex)
        self.assertIsNotNone(icon.cd)
        self.assertIsNotNone(icon.timeText)
        for i in range(1, 5):
            self.assertFalse(o.icons[i].shown)            # our own row stays hidden
        e.cmd("platealldebuffs on")
        e.update(0.4)
        self.assertEqual(o.wDebuffs.groups["1"].filter, "HARMFUL|!CROWD_CONTROL")
        e.cmd("platedebuffs off")
        e.update(0.4)
        self.assertFalse(o.wDebuffs.shown)
        self.assertEqual(e.errors(), [])

    def test_countdowns_turn_red_when_running_out(self):
        e = self.env()
        data = e.lua.table(name="Raptor", level=34, health=600, healthMax=800, attackable=True, reaction=2)
        o = e.ns.Nameplates.byPlate[e.mock.addPlate("nameplate1", data)]
        opts = o.wDebuffs.groups["1"].icon.timeOpts
        rules = list(opts.textFormatter.rules.values())
        self.assertEqual(rules[0].threshold, 0)
        self.assertIn("|cff", rules[0].format)                        # under five seconds: red
        self.assertEqual(rules[1].threshold, 5)
        self.assertEqual(rules[1].format, "%d")

    def test_our_own_icons_turn_red_too(self):
        e = Env()                                                     # no game display: our own icons
        T = e.lua.table
        auras = T(T(icon=41, duration=10, expirationTime=e.mock.time + 4.5, mine=True),
                  T(icon=42, duration=30, expirationTime=e.mock.time + 20, mine=True))
        o = e.ns.Nameplates.byPlate[e.mock.addPlate("nameplate1", T(name="Raptor", level=30, health=5, healthMax=5,
                                                                    attackable=True, reaction=2, auras=auras))]
        e.update(0.3)
        danger = e.ns.colors.danger
        self.assertEqual(round(o.icons[1].time.tcolor[1], 2), round(danger[1], 2))   # 4s left: red
        self.assertEqual(o.icons[1].time.text, "5")
        self.assertNotEqual(round(o.icons[2].time.tcolor[2], 2), round(danger[2], 2))  # 20s: not

    def test_a_reused_plate_looks_again(self):
        e = self.env()
        data = e.lua.table(name="Raptor", level=34, health=600, healthMax=800, attackable=True, reaction=2)
        plate = e.mock.addPlate("nameplate1", data)
        o = e.ns.Nameplates.byPlate[plate]
        before = o.wDebuffs.setUnitCalls
        e.update(1)
        self.assertEqual(o.wDebuffs.setUnitCalls, before)  # not every update
        e.mock.removePlate("nameplate1")
        self.assertFalse(o.wDebuffs.shown)
        e.mock.plates["nameplate1"], e.mock.units["nameplate1"] = plate, data
        e.mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
        self.assertGreater(o.wDebuffs.setUnitCalls, before)

    def test_only_the_effects_that_matter(self):
        e = self.env()
        o = e.ns.Nameplates.byPlate[e.mock.addPlate("nameplate1", e.lua.table(
            name="Raptor", level=34, health=600, healthMax=800, attackable=True, reaction=2))]
        g = o.wBuffs.groups
        self.assertEqual(g["1"].filter, "HELPFUL|IMPORTANT|!PLAYER")              # marked important: boss mechanics
        self.assertEqual(g["2"].filter, "HELPFUL|!IMPORTANT|!PLAYER")
        self.assertTrue(g["2"].candidates.includeDispelTypes.Enrage)               # enraged
        self.assertTrue(g["3"].candidates.isStealable)                             # you can dispel or steal it
        self.assertTrue(g["3"].candidates.excludeDispelTypes.Enrage)               # (not twice)
        self.assertTrue(all(g[k].enabled for k in ("1", "2", "3")))
        # the groups share one short line: each icon laid out at our size, a few from each group
        self.assertEqual(g["1"].layout.elementWidth, g["1"].layout.elementHeight)
        self.assertGreater(g["1"].layout.elementWidth, 0)
        self.assertFalse(g["2"].layout.forceNewLine)
        self.assertEqual([g[k].max for k in ("1", "2", "3")], [3, 1, 2])
        A = e.ns.Auras                                          # under the target's bar: starts at the top
        self.assertEqual(A.wBuffs.point, "TOPRIGHT")
        self.assertEqual(A.wBuffs.flowAnchor, "TOPRIGHT")
        self.assertEqual(o.wBuffs.point, "BOTTOMLEFT")          # over a plate's name: starts at the bottom
        self.assertIsNotNone(g["1"].icon.dispelTex)                                # edged in its kind's colour
        e.cmd("smartauras off")                                                    # every buff, as before
        e.update(0.4)
        self.assertEqual(g["1"].filter, "HELPFUL|!PLAYER")
        self.assertEqual(g["1"].candidates and len(g["1"].candidates), 0)
        self.assertFalse(g["2"].enabled or g["3"].enabled)
        # the target: a friend's debuffs you can dispel, then the important ones, then crowd control
        e.cmd("smartauras on")
        e.target(attackable=False, reaction=5)
        h = e.ns.Auras.wHelp.groups
        self.assertEqual([h[k].filter for k in ("1", "2", "3")],
                         ["HARMFUL|RAID", "HARMFUL|IMPORTANT|!RAID", "HARMFUL|CROWD_CONTROL|!IMPORTANT|!RAID"])
        e.cmd("frienddebuffs off")
        e.target(attackable=False, reaction=5)
        self.assertFalse(e.ns.Auras.wHelp.shown)
        self.assertEqual(e.errors(), [])

    def test_a_filter_the_client_does_not_know_shows_nothing_rather_than_everything(self):
        def setup(env):
            env.mock.auraContainer = True
            env.mock.unknownFilters = env.lua.table(IMPORTANT=True)
        e = Env(setup=setup)
        o = e.ns.Nameplates.byPlate[e.mock.addPlate("nameplate1", e.lua.table(
            name="Raptor", level=34, health=600, healthMax=800, attackable=True, reaction=2))]
        g = o.wBuffs.groups
        self.assertFalse(g["1"].enabled)                       # refused: off
        self.assertTrue(g["2"].enabled)                        # enraged: asked without the unknown word
        self.assertEqual(g["2"].filter, "HELPFUL|!PLAYER")
        self.assertTrue(g["2"].candidates.includeDispelTypes.Enrage)
        self.assertFalse(o.wDebuffs.groups["2"].enabled)       # the important debuffs: off, never everyone's
        self.assertTrue(o.wDebuffs.groups["1"].enabled)        # yours: still there
        self.assertEqual(e.errors(), [])

    def test_a_secret_guid_is_never_a_key(self):
        # in a dungeon the game keeps units' GUIDs secret: a secret cannot be a table key there
        e = self.env()
        data = e.lua.table(name="Raptor", level=34, health=600, healthMax=800, attackable=True, reaction=2,
                           guid=e.mock.secret())
        e.mock.addPlate("nameplate1", data)
        o = e.ns.Nameplates.plates["nameplate1"]
        self.assertIsNone(o.guid)
        self.assertEqual(len([k for k in e.ns.Nameplates.byGuid.keys() if e.g.issecretvalue(k)]), 0)
        e.mock.setUnit("target", data)
        e.cmd("hittest")
        e.mock.removePlate("nameplate1")
        self.assertIsNone(e.ns.GUID("nameplate1"))
        self.assertEqual(e.errors(), [])

    def test_no_stale_plates(self):
        e = self.env()
        T = e.lua.table
        NP = e.ns.Nameplates
        plate = e.mock.addPlate("nameplate1", T(name="Raptor", level=34, health=600, healthMax=800,
                                                 attackable=True, reaction=2))
        o = NP.byPlate[plate]
        self.assertTrue(o.shown)
        # the game moves the plate to someone else without telling us it left: the new one is read, not the old
        e.mock.plates["nameplate1"] = None
        e.mock.plates["nameplate2"] = plate
        e.mock.units["nameplate2"] = T(name="Sel Bridalveil", level=30, health=5, healthMax=5, reaction=5)
        e.mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
        self.assertIsNone(NP.plates["nameplate1"])
        self.assertTrue(e.same(NP.plates["nameplate2"], o))
        self.assertIn("Sel Bridalveil", o.name.text)
        # a plate that goes away with no event at all: dropped within a second
        other = e.mock.addPlate("nameplate3", T(name="Takulah", level=28, health=5, healthMax=5, reaction=5))
        e.mock.plates["nameplate3"] = None                 # the game does not hand it out: kept (friends do this)
        e.update(1.2)
        self.assertTrue(NP.byPlate[other].shown)
        e.mock.units["nameplate3"] = None                  # the unit is gone: dropped
        e.update(1.2)
        self.assertIsNone(NP.plates["nameplate3"])
        self.assertFalse(NP.byPlate[other].shown)
        out = e.cmd("plates")
        self.assertIn("nameplate3: gone", out)
        self.assertGreater(len(e.db.plateReport), 1)
        # a plate the game keeps for itself (friends in a dungeon): never ours, nothing of ours left on it
        e.mock.plates["nameplate2"].IsForbidden = lambda *_: True
        e.mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
        self.assertFalse(o.shown)
        self.assertIsNone(NP.plates["nameplate2"])
        self.assertEqual(e.errors(), [])

    def test_friendly_plates_can_be_left_to_the_game(self):
        e = self.env()
        T = e.lua.table
        NP = e.ns.Nameplates
        friend = e.mock.addPlate("nameplate1", T(name="Sel Bridalveil", level=30, health=5, healthMax=5, reaction=5))
        foe = e.mock.addPlate("nameplate2", T(name="Raptor", level=34, health=600, healthMax=800,
                                               attackable=True, reaction=2))
        self.assertTrue(NP.byPlate[friend].shown)                  # ours by default, friends too
        e.cmd("platefriendsgame on")
        e.update(0.4)
        self.assertIsNone(NP.plates["nameplate1"])
        self.assertFalse(NP.byPlate[friend].shown)                 # the game's own plate shows instead
        self.assertTrue(NP.byPlate[foe].shown)                     # enemies stay ours
        e.cmd("platefriendsgame off")
        e.update(0.4)
        self.assertTrue(NP.byPlate[friend].shown)                  # taken back
        self.assertEqual(e.errors(), [])

    def test_secret_facts_about_a_unit_count_as_unknown(self):
        # in a dungeon the game keeps who a unit is secret: class, player or not, name of its target...
        e = self.env()
        e.lua.execute("""
            setmetatable(CLASS_ICON_TCOORDS, { __index = function(_, k)
                if issecretvalue(k) then error("attempted to index a table that cannot be indexed with secret keys") end
            end })
        """)
        S = e.mock.secret
        e.target(isPlayer=S(), attackable=S(), reaction=S(), dead=S(), **{"class": S()})
        e.mock.setUnit("targettarget", e.lua.table(name=S(), health=5, healthMax=5, level=30))
        e.update(1)
        U = e.ns.Unit
        self.assertIsNone(U.Class("target"))
        dead, tapped, isPlayer, attackable, reaction = U.Standing("target")
        self.assertEqual((dead, isPlayer, attackable, reaction), (False, False, False, None))
        self.assertFalse(e.ns.Yes(S()))
        self.assertIsNone(e.ns.Plain(S()))
        self.assertEqual(e.errors(), [])

    def test_friends_get_none(self):
        e = self.env()
        data = e.lua.table(name="Ally", level=34, health=600, healthMax=800, attackable=False, reaction=5)
        o = e.ns.Nameplates.byPlate[e.mock.addPlate("nameplate1", data)]
        self.assertFalse(o.wDebuffs.shown)
        self.assertFalse(o.wCC.shown)

    def test_target_frame_uses_the_games_rows(self):
        e = self.env()
        e.target()
        A = e.ns.Auras
        self.assertTrue(A.wMine.shown)
        self.assertEqual(A.wMine.unit, "target")
        self.assertEqual(A.wMine.groups["1"].filter, "HARMFUL|!CROWD_CONTROL|PLAYER")
        self.assertTrue(A.wBuffs.shown and A.wCC.shown)
        self.assertFalse(A.wHelp.shown)
        calls = A.wMine.setUnitCalls
        e.target(attackable=False, reaction=5)
        self.assertEqual(A.wMine.groups["1"].filter, "HELPFUL|PLAYER")     # a friend: your buffs
        self.assertFalse(A.wMine.groups["2"].enabled)                      # (one group now)
        self.assertFalse(A.wBuffs.shown)
        self.assertTrue(A.wHelp.shown)                                     # and its debuffs worth acting on
        self.assertGreater(A.wMine.setUnitCalls, calls)                    # a new target: the game looks again
        e.mock.setUnit("target", None)
        self.assertFalse(A.wMine.shown)
        e.cmd("demo")                                      # the demo has no real unit: our rows show it
        self.assertFalse(A.wMine.shown)
        self.assertTrue(A.icons[1].shown)
        self.assertEqual(e.errors(), [])


class Plates(unittest.TestCase):
    def enemy(self, e, unit="nameplate1", **kw):
        data = e.lua.table(name="Raptor", level=34, health=600, healthMax=800, attackable=True, reaction=2)
        for k, v in kw.items():
            data[k] = v
        plate = e.mock.addPlate(unit, data)
        return data, plate, e.ns.Nameplates.byPlate[plate]

    def test_our_look_goes_on_the_games_plate(self):
        e = Env()
        data, plate, o = self.enemy(e, classification="elite")
        self.assertTrue(o.shown)
        self.assertTrue(e.same(o.parent, plate))
        self.assertEqual(plate.UnitFrame.alpha, 0)
        self.assertIn("34", o.name.text)
        self.assertIn("Raptor", o.name.text)
        self.assertEqual(o.health.fill.value, 600)
        self.assertEqual(e.color(o.health), e.theme("hostile"))
        self.assertTrue(o.wingL.shown and o.wingR.shown)            # an elite: the classic wings around its name
        self.assertEqual(round(o.name.tcolor[3], 2), round(e.ns.colors.text[3], 2))   # white: readable
        data.health = 300
        e.mock.fire("UNIT_HEALTH", "nameplate1")
        self.assertGreater(o.health.flashA, 0.4)
        self.assertEqual(e.errors(), [])

    def test_friends_show_a_name_only(self):
        e = Env()
        data, plate, o = self.enemy(e, attackable=False, isPlayer=True, **{"class": "MAGE"})
        self.assertFalse(o.health.shown)
        self.assertEqual(o.name.text, "Raptor")
        self.assertEqual(tuple(round(o.name.tcolor[i], 2) for i in (1, 2, 3)), (0.25, 0.78, 0.92))

    def test_your_target_stands_out(self):
        e = Env()
        data, plate, o = self.enemy(e)
        data2, plate2, o2 = self.enemy(e, "nameplate2", name="Other")
        self.assertEqual((o.scale, o.alpha), (1, 1))
        e.mock.setUnit("target", data)
        self.assertEqual((o.scale, o.alpha), (1.15, 1))
        self.assertTrue(o.edge.shown)
        self.assertEqual((o2.scale, o2.alpha), (1, 0.85))

    def test_casts_and_removal(self):
        e = Env()
        data, plate, o = self.enemy(e)
        now = e.mock.time
        data.cast = e.lua.table(name="Bite", start=now * 1000, stop=(now + 2) * 1000)
        e.mock.fire("UNIT_SPELLCAST_START", "nameplate1")
        self.assertTrue(o.cast.shown)
        e.update(1)
        self.assertAlmostEqual(o.cast.fill.value, 0.5, places=1)
        e.mock.removePlate("nameplate1")
        self.assertFalse(o.shown)
        self.assertEqual(plate.UnitFrame.alpha, 1)
        self.assertIsNone(e.ns.Nameplates.plates.nameplate1)
        # the game reuses the plate for another unit
        e.mock.plates.nameplate3 = plate
        e.mock.units.nameplate3 = e.lua.table(name="Wolf", level=30, health=5, healthMax=5, attackable=True)
        e.mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
        self.assertIn("Wolf", o.name.text)
        self.assertFalse(o.cast.shown)

    def test_off_gives_the_games_plates_back(self):
        e = Env()
        data, plate, o = self.enemy(e)
        e.cmd("nameplates off")
        self.assertEqual(plate.UnitFrame.alpha, 1)
        self.assertFalse(o.shown)
        e.cmd("nameplates on")                            # plates already on screen are picked up
        self.assertEqual(plate.UnitFrame.alpha, 0)
        self.assertTrue(o.shown)

    def test_another_nameplate_addon_is_left_in_charge(self):
        e = Env(addons=("Platynator",))
        data, plate, o = self.enemy(e)
        self.assertIsNone(o)
        self.assertEqual(plate.UnitFrame.alpha, 1)
        self.assertFalse(e.ns.Nameplates.active)
        self.assertEqual(e.ns.RunCheck(False)[0], 0)


class VerticalBars(unittest.TestCase):
    def test_off_by_default_then_upright_beside_you(self):
        e = Env()
        self.assertFalse(e.frames.vertical.on)
        self.assertIn("on", e.cmd("vertical on"))
        f = e.frames.vertical
        self.assertTrue(f.button.shown)
        self.assertEqual((f.health.fill.orientation, f.power.fill.orientation), ("VERTICAL", "VERTICAL"))
        self.assertEqual(f.mover.points[1][1], "CENTER")
        self.assertLess(f.mover.points[1][4], 0)                    # left of the middle
        self.assertEqual(f.health.fill.value, 1000)
        self.assertEqual(e.ns.RunCheck(False)[0], 0)

    def test_gone_when_quiet_back_in_a_fight(self):
        e = Env(db="{ v = 4, units = { vertical = true } }")
        f = e.frames.vertical
        e.update(4)
        self.assertAlmostEqual(f.visual.alpha, 0.3)                 # full health, no fight: faded
        e.mock.state.combat = True
        e.mock.units.player.health = 400
        e.mock.fire("UNIT_HEALTH", "player")
        e.update(0.5)
        self.assertEqual(f.visual.alpha, 1)                         # badly hurt in a fight
        self.assertEqual(f.text.text, "40%")
        self.assertEqual(f.ptext.text, "100")
        self.assertEqual((f.health.width, f.health.height), (8, 96))           # slim
        e.mock.state.combat = False
        e.update(4)
        self.assertEqual(f.visual.alpha, 1)                         # still badly hurt: never hidden
        e.mock.units.player.health = 1000
        e.mock.fire("UNIT_HEALTH", "player")
        e.update(4)
        self.assertAlmostEqual(f.visual.alpha, 0.3)                 # healed, fight over: faded again
        e.ns.db.verticalIdle = 0.4
        e.mock.units.player.health = 1000
        e.mock.fire("UNIT_HEALTH", "player")
        e.update(4)
        self.assertAlmostEqual(f.visual.alpha, 0.4)

    def test_it_replaces_the_top_bar_and_reacts_to_hits(self):
        e = Env()
        self.assertTrue(e.frames.player.button.shown)
        e.cmd("vertical on")
        f = e.frames.vertical
        self.assertFalse(e.frames.player.button.shown)              # one or the other
        self.assertFalse(e.frames.pet.on)
        self.assertEqual(e.aside("PlayerFrame"), True)
        e.mock.state.combat = True
        e.mock.units.player.health = 400
        e.mock.fire("UNIT_HEALTH", "player")
        self.assertGreater(f.flash.alpha, 0.4)
        self.assertTrue(e.ns.Impact.IsShaking(e.ns.Impact, f.visual))
        e.update(4)
        self.assertEqual(f.visual.alpha, 1)
        e.cmd("vertical off")                                       # in a fight: waits for it to end
        self.assertFalse(e.frames.player.button.shown)
        e.mock.state.combat = False
        e.mock.fire("PLAYER_REGEN_ENABLED")
        self.assertTrue(e.frames.player.button.shown)
        self.assertEqual(e.ns.RunCheck(False)[0], 0)
        e.mock.editMode(True)
        self.assertTrue(f.mover.movable)
        e.mock.editMode(False)
        e.cmd("off")
        self.assertFalse(f.button.shown)


class Ranks(unittest.TestCase):
    def test_levels_are_coloured_by_difficulty(self):
        e = Env()                                                  # the player is level 33
        c = lambda lvl: tuple(round(v, 2) for v in e.ns.LevelColor(lvl))
        self.assertEqual(c(40), (1, 0.1, 0.1))                     # far above: red
        self.assertEqual(c(36), (1, 0.5, 0.25))                    # orange
        self.assertEqual(c(33), (1, 0.82, 0))                      # yellow
        self.assertEqual(c(28), (0.25, 0.75, 0.25))                # green
        self.assertEqual(c(10), (0.5, 0.5, 0.5))                   # grey
        self.assertEqual(c(-1), (1, 0.1, 0.1))                     # "??"
        e.target(level=36)
        self.assertIn("|cffff7f3f36|r", e.frames.target.name.text)

    def test_normal_rare_elite_and_boss_look_different(self):
        e = Env()
        f = e.frames.target
        e.target()
        self.assertFalse(f.mark.shown)
        self.assertFalse(f.rankGlow.shown)
        looks = {}
        for kind in ("rare", "elite", "rareelite", "worldboss"):
            e.target(classification=kind)
            self.assertTrue(f.mark.shown, kind)
            self.assertTrue(f.rankGlow.shown, kind)
            looks[kind] = (f.mark.texture, tuple(round(v, 2) for v in list(f.mark.vcolor.values())[:3]),
                           tuple(round(v, 2) for v in list(f.rankGlow.vcolor.values())[:3]))
        self.assertEqual(len(set(looks.values())), 4)
        self.assertTrue(looks["worldboss"][0].endswith("skull"))
        self.assertTrue(looks["elite"][0].endswith("mark"))
        self.assertEqual(looks["rareelite"][2], looks["elite"][2])   # gold glow, silver mark
        self.assertEqual(looks["rareelite"][1], looks["rare"][1])
        e.target(level=-1)                                           # "??" level: a skull too
        self.assertTrue(f.mark.texture.endswith("skull"))

    def test_plates_show_rank_and_level_colour(self):
        e = Env()
        plate = e.mock.addPlate("nameplate1", e.lua.table(name="Boss", level=-1, classification="worldboss", health=5,
                                                          healthMax=5, attackable=True, reaction=2))
        o = e.ns.Nameplates.byPlate[plate]
        self.assertTrue(o.mark.texture.endswith("skull"))
        self.assertTrue(o.rankGlow.shown)
        self.assertNotIn("??", o.name.text)                          # the skull says it
        plate2 = e.mock.addPlate("nameplate2", e.lua.table(name="Wolf", level=30, health=5, healthMax=5,
                                                           attackable=True, reaction=2))
        o2 = e.ns.Nameplates.byPlate[plate2]
        self.assertFalse(o2.mark.shown)
        self.assertIn("|cff3fbf3f30|r", o2.name.text)               # green

    def test_class_icons_on_target_and_target_of_target(self):
        e = Env()
        e.target(isPlayer=True, **{"class": "MAGE"})
        icon = e.frames.target.classIcon
        self.assertTrue(icon.shown)
        self.assertEqual(list(icon.texCoord.values()), [0.25, 0.5, 0, 0.25])
        e.mock.setUnit("targettarget", e.lua.table(name="Hunter", level=33, health=5, healthMax=5, isPlayer=True,
                                                    **{"class": "HUNTER"}))
        e.update(0.3)
        self.assertTrue(e.frames.tot.classIcon.shown)
        e.target()                                                   # an NPC: no class icon
        self.assertFalse(e.frames.target.classIcon.shown)
        e.ns.db.classIcons = False
        e.target(isPlayer=True, **{"class": "MAGE"})
        self.assertFalse(e.frames.target.classIcon.shown)

    def test_target_of_target_name_sits_above_its_bar(self):
        e = Env()
        tot = e.frames.tot
        self.assertLessEqual(tot.health.points[1][5], -(10 * 1.5))


class LoudCasts(unittest.TestCase):
    def plate(self, e, **kw):
        data = e.lua.table(name="Caster", level=30, health=5, healthMax=5, attackable=True, reaction=2)
        for k, v in kw.items():
            data[k] = v
        plate = e.mock.addPlate("nameplate1", data)
        return data, e.ns.Nameplates.byPlate[plate]

    def cast(self, e, data, seconds=2, **kw):
        now = e.mock.time
        data.cast = e.lua.table(name="Fireball", start=now * 1000, stop=(now + seconds) * 1000, **kw)
        e.mock.fire("UNIT_SPELLCAST_START", "nameplate1")

    def test_a_cast_starts_with_a_bang_and_pulses_faster_to_the_end(self):
        e = Env()
        data, o = self.plate(e)
        self.cast(e, data)
        self.assertGreater(o.cast.flashA, 0.4)                       # the bang
        e.update(0.05)
        self.assertGreater(o.cast.scale, 1)                          # the swell
        e.update(0.4)
        self.assertEqual(o.cast.scale, 1)
        early = []
        for _ in range(6):
            e.update(0.05)
            early.append(round(o.castGlow.alpha, 2))
        self.assertGreater(max(early), 0.45)
        e.update(0.9)                                                # past 70%: faster and brighter
        late = []
        for _ in range(6):
            e.update(0.02)
            late.append(round(o.castGlow.alpha, 2))
        self.assertGreater(max(late), max(early))
        e.update(1)
        self.assertEqual(o.castGlow.alpha, 0)                        # landed: quiet again

    def test_shielded_casts_stay_calm_and_the_option_turns_it_off(self):
        e = Env()
        data, o = self.plate(e)
        self.cast(e, data, shielded=True)
        e.update(0.3)
        self.assertEqual(o.castGlow.alpha, 0)
        data.cast = None
        e.mock.fire("UNIT_SPELLCAST_STOP", "nameplate1")
        e.cmd("platecastalert off")
        self.cast(e, data)
        e.update(0.3)
        self.assertEqual(o.castGlow.alpha, 0)


class Threat(unittest.TestCase):
    def plate(self, e, **kw):
        data = e.lua.table(name="Raptor", level=30, health=5, healthMax=5, attackable=True, reaction=2, combat=True)
        for k, v in kw.items():
            data[k] = v
        plate = e.mock.addPlate("nameplate1", data)
        return data, e.ns.Nameplates.byPlate[plate]

    def test_taking_aggro_pops_the_name_losing_it_shrinks_it(self):
        e = Env()
        data, o = self.plate(e, threat=1)
        e.update(0.4)
        self.assertEqual(o.threat, "pulling")
        white = tuple(round(v, 2) for v in e.ns.colors.text.values())
        self.assertEqual(tuple(round(o.name.tcolor[i], 2) for i in (1, 2, 3)), white)   # the name stays white
        self.assertEqual(o.threatState, "gaining")                    # the glow says it, red and yellow
        data.threat = 3
        e.update(0.35)
        e.update(0.02)
        self.assertEqual(o.name.fontK, 1)                            # the name keeps its size: no pulsing
        self.assertEqual(o.name.fontFlags, "THICKOUTLINE")           # only bolder
        sizes = set()
        alphas = []
        for _ in range(20):
            e.update(0.05)
            sizes.add(o.name.fontK)
            alphas.append(o.nameGlow.alpha)
        self.assertEqual(sizes, {1})
        self.assertGreaterEqual(min(alphas), 0.69)                   # the glow is strong all the time
        self.assertGreater(max(alphas) - min(alphas), 0.1)           # and breathes
        self.assertEqual(round(o.nameGlow.vcolor[1], 2), round(e.ns.colors.angry[1], 2))
        self.assertEqual(tuple(round(o.name.tcolor[i], 2) for i in (1, 2, 3)), white)
        data.threat = 0
        e.update(0.35)
        e.update(1)
        self.assertEqual(round(o.nameGlow.vcolor[3], 2), round(e.ns.colors.calm[3], 2))   # lost it: calm blue
        self.assertLess(o.nameGlow.alpha, 0.5)
        self.assertEqual((o.name.fontK, o.name.fontFlags), (1, "OUTLINE"))
        data.combat = False                                          # the fight is over: no glow at all
        e.update(0.5)
        self.assertEqual(o.nameGlow.alpha, 0)
        self.assertFalse(o.threatIcon.shown)

    def test_the_target_name_option_is_the_same_for_every_target(self):
        e = Env()
        self.assertTrue(e.db.plateTargetName)                        # names show by default
        e.cmd("platetargetname off")
        for threat in (3, 0):                                        # on you or not: the same
            data, o = self.plate(e, threat=threat)
            e.mock.setUnit("target", data)
            e.mock.fire("PLAYER_TARGET_CHANGED")
            e.update(0.6)
            self.assertEqual(o.name.alpha, 0, threat)
            self.assertEqual(o.nameGlow.alpha, 0)                    # no glow on a hidden name
            e.mock.removePlate("nameplate1")

    def test_names_come_back_on_after_the_update(self):
        e = Env(db="{ v = 4, plateTargetName = false }")
        self.assertTrue(e.db.plateTargetName)
        e2 = Env(db="{ v = 5, plateTargetName = false }")
        self.assertFalse(e2.db.plateTargetName)                      # chosen after it: kept

    def test_a_secret_rank_still_names_the_plate(self):
        e = Env()
        data, o = self.plate(e, classification=e.mock.secret())
        self.assertIn("Raptor", o.name.text)
        self.assertEqual(e.errors(), [])

    def test_without_threat_numbers_the_units_target_says_it(self):
        e = Env()
        data, o = self.plate(e)
        e.mock.units["nameplate1target"] = e.mock.units.player
        e.update(0.4)
        self.assertEqual(o.threat, "tank")


class Compact(unittest.TestCase):
    def test_compact_nameplates(self):
        e = Env()
        plate = e.mock.addPlate("nameplate1", e.lua.table(name="Wolf", level=30, health=5, healthMax=5,
                                                          attackable=True, reaction=2))
        o = e.ns.Nameplates.byPlate[plate]
        full = o.health.width
        e.cmd("platecompact on")
        self.assertAlmostEqual(o.health.width, full * 0.6)
        self.assertEqual(o.health.height, 7)                         # height stays

    def test_compact_target_frame(self):
        e = Env()
        f = e.frames.target
        e.ns.db.targetCompact = True
        e.ns.UnitFrames.ApplyLook(e.ns.UnitFrames)
        self.assertEqual((f.mover.width, f.health.width), (180, 180))
        self.assertEqual(f.health.ticks[1].points[1][4], 45)         # the segment marks follow

    def test_the_gamepad_bars_compact_or_full(self):
        e = Env()
        self.assertIn("compact", e.cmd("compact"))
        self.assertTrue(e.mock.compact)
        self.assertEqual(e.mock.layoutsSaved, 1)                     # kept in the game's own layout
        self.assertIn("full", e.cmd("compact"))
        self.assertFalse(e.mock.compact)
        e.mock.state.combat = True
        self.assertIn("Not in combat", e.cmd("compact on"))

    def test_focus_steps_back_out_of_combat(self):
        e = Env()
        e.mock.setUnit("focus", e.lua.table(name="Healer", health=5, healthMax=5))
        f = e.frames.focus
        e.update(3)
        self.assertAlmostEqual(f.visual.alpha, 0.3)
        e.mock.state.combat = True
        e.update(1)
        self.assertAlmostEqual(f.visual.alpha, 0.7)


class PlateNames(unittest.TestCase):
    def test_your_targets_plate_can_leave_out_its_name(self):
        e = Env()
        data = e.lua.table(name="Raptor", level=30, health=5, healthMax=5, attackable=True, reaction=2)
        plate = e.mock.addPlate("nameplate1", data)
        o = e.ns.Nameplates.byPlate[plate]
        e.update(0.5)
        e.mock.setUnit("target", data)
        self.assertEqual(o.name.alpha, 1)                           # on by default
        e.cmd("platetargetname off")
        e.mock.fire("PLAYER_TARGET_CHANGED")
        self.assertEqual(o.name.alpha, 0)
        e.mock.setUnit("target", None)
        self.assertEqual(o.name.alpha, 1)                           # not your target: the name is back

    def test_levels_can_be_left_out(self):
        e = Env()
        plate = e.mock.addPlate("nameplate1", e.lua.table(name="Raptor", level=30, health=5, healthMax=5,
                                                          attackable=True, reaction=2))
        o = e.ns.Nameplates.byPlate[plate]
        self.assertIn("30", o.name.text)
        e.cmd("platelevels off")
        self.assertNotIn("30", o.name.text)
        self.assertIn("Raptor", o.name.text)


class PlateCasts(unittest.TestCase):
    def test_the_cast_counts_down_and_brightens_before_it_lands(self):
        e = Env()
        data = e.lua.table(name="Raptor", level=30, health=5, healthMax=5, attackable=True, reaction=2)
        plate = e.mock.addPlate("nameplate1", data)
        o = e.ns.Nameplates.byPlate[plate]
        now = e.mock.time
        data.cast = e.lua.table(name="Bite", start=now * 1000, stop=(now + 2) * 1000)
        e.mock.fire("UNIT_SPELLCAST_START", "nameplate1")
        e.update(0.5)
        self.assertEqual(o.castTime.text, "1.5")
        self.assertTrue(o.cast.spark is not None)
        e.update(1.2)
        alphas = set()
        for _ in range(4):
            e.update(0.05)
            alphas.add(round(o.cast.fill.alpha, 2))
        self.assertGreater(len(alphas), 1)
        e.update(1)
        self.assertFalse(o.cast.shown)

    def test_secret_times_run_on_the_games_own_timer(self):
        e = Env()
        data = e.lua.table(name="Raptor", level=30, health=5, healthMax=5, attackable=True, reaction=2)
        plate = e.mock.addPlate("nameplate1", data)
        o = e.ns.Nameplates.byPlate[plate]
        data.cast = e.lua.table(name=e.mock.secret(), start=e.mock.secret(), stop=e.mock.secret(), durationObject="d")
        e.mock.fire("UNIT_SPELLCAST_START", "nameplate1")
        self.assertEqual(o.cast.fill.timer, "d")
        self.assertTrue(o.cast.shown)
        self.assertEqual(e.errors(), [])

    def test_a_secret_name_is_still_shown(self):
        e = Env()
        secret = e.mock.secret()
        plate = e.mock.addPlate("nameplate1", e.lua.table(name=secret, level=30, health=5, healthMax=5,
                                                          attackable=True, reaction=2))
        o = e.ns.Nameplates.byPlate[plate]
        self.assertEqual(e.errors(), [])
        self.assertIsNotNone(o.name.text)


class QuestAndAuras(unittest.TestCase):
    def test_units_your_quests_need_are_marked(self):
        e = Env()
        T = e.lua.table
        lines = T(T(leftText="Raising Spirits", type=17), T(leftText=" - 2/10 Highland Raptor Eye", type=8))
        plate = e.mock.addPlate("nameplate1", T(name="Highland Strider", level=30, health=5, healthMax=5,
                                                attackable=True, reaction=2, questLines=lines))
        o = e.ns.Nameplates.byPlate[plate]
        self.assertTrue(o.questIcon.shown)
        self.assertFalse(o.questText.shown)                          # the icon says it; no count
        lines[2].leftText = " - 10/10 Highland Raptor Eye"           # done: no marker
        e.mock.fire("QUEST_LOG_UPDATE")
        self.assertFalse(o.questIcon.shown)
        plate2 = e.mock.addPlate("nameplate2", T(name="Wolf", level=30, health=5, healthMax=5, attackable=True,
                                                 reaction=2))
        self.assertFalse(e.ns.Nameplates.byPlate[plate2].questIcon.shown)
        e.cmd("platequest off")

    def test_a_client_that_ignores_the_player_filter_still_shows_only_yours(self):
        e = Env(setup=lambda env: env.mock.noModernAuras())             # a client that reads effects one by one
        T = e.lua.table
        auras = T(T(icon=11, duration=10, expirationTime=e.mock.time + 7, sourceUnit="party1"),     # a mage's frost
                  T(icon=12, duration=10, expirationTime=e.mock.time + 7, sourceUnit="party1"),
                  T(icon=13, duration=10, expirationTime=e.mock.time + 7, sourceUnit="raid3"),
                  T(icon=14, duration=10, expirationTime=e.mock.time + 7, isFromPlayerOrPlayerPet=False),
                  T(icon=15, duration=20, expirationTime=e.mock.time + 15, sourceUnit="player"))    # your judgement
        plate = e.mock.addPlate("nameplate1", T(name="Raptor", level=30, health=5, healthMax=5, attackable=True,
                                                reaction=2, auras=auras))
        o = e.ns.Nameplates.byPlate[plate]
        self.assertEqual([b.icon.texture for b in o.icons.values() if b.shown], [15])

    def test_your_debuffs_are_found_even_without_the_player_filter(self):
        e = Env(setup=lambda env: env.mock.noModernAuras())             # a client that reads effects one by one
        T = e.lua.table
        auras = T(T(icon=1, duration=10, expirationTime=e.mock.time + 7, sourceUnit="player"),
                  T(icon=2, duration=10, expirationTime=e.mock.time + 7, sourceUnit="party1"),
                  T(icon=3, duration=10, expirationTime=e.mock.time + 2, isFromPlayerOrPlayerPet=True))
        plate = e.mock.addPlate("nameplate1", T(name="Raptor", level=30, health=5, healthMax=5, attackable=True,
                                                reaction=2, auras=auras, noPlayerFilter=True))
        o = e.ns.Nameplates.byPlate[plate]
        shown = [b.icon.texture for b in o.icons.values() if b.shown]
        self.assertEqual(shown, [1, 3])                              # not the party member's

    def test_effects_you_cast_are_yours_even_when_the_game_does_not_say(self):
        e = Env(setup=lambda env: env.mock.noModernAuras())             # a client that reads effects one by one
        T = e.lua.table
        e.mock.spellNames = T()
        e.mock.spellNames[20271] = "Judgement"
        e.mock.spellNames[853] = "Hammer of Justice"
        e.mock.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 20271)
        e.mock.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 853)
        auras = T(T(icon=21, name="Frost Nova", spellId=122, duration=8, expirationTime=e.mock.time + 6),
                  T(icon=22, name="Judgement of the Crusader", spellId=21183, duration=10, expirationTime=e.mock.time + 9),
                  T(icon=23, name="Hammer of Justice", spellId=853, duration=6, expirationTime=e.mock.time + 5))
        plate = e.mock.addPlate("nameplate1", T(name="Raptor", level=30, health=5, healthMax=5, attackable=True,
                                                reaction=2, auras=auras, noPlayerFilter=True))
        o = e.ns.Nameplates.byPlate[plate]
        self.assertEqual([b.icon.texture for b in o.icons.values() if b.shown], [22, 23])   # not the mage's nova
        e.target(auras=auras, noPlayerFilter=True)
        self.assertEqual([b.icon.texture for b in e.ns.Auras.icons.values() if b.shown], [22, 23])   # and the frame
        out = e.cmd("aurareport")
        self.assertIn("saved", out)
        self.assertIn("one by one", list(e.db.auraReport.values())[0])

    def test_the_quest_marker_sits_on_the_health_bar_line(self):
        e = Env()
        T = e.lua.table
        lines = T(T(leftText="Raising Spirits", type=17), T(leftText=" - 2/10 Highland Raptor Eye", type=8))
        plate = e.mock.addPlate("nameplate1", T(name="Strider", level=30, health=5, healthMax=5, attackable=True,
                                                reaction=2, questLines=lines))
        o = e.ns.Nameplates.byPlate[plate]
        p = o.questIcon.points[1]
        self.assertTrue(e.same(p[2], o.health))
        self.assertEqual((p[1], p[3]), ("LEFT", "RIGHT"))

    def test_the_game_picks_your_effects_from_the_list(self):
        e = Env()
        T = e.lua.table
        auras = T(T(icon=31, name="Frost Nova", duration=8, expirationTime=e.mock.time + 6,
                    sourceUnit=e.mock.secret(), isFromPlayerOrPlayerPet=e.mock.secret()),     # details kept secret
                  T(icon=32, name="Judgement of the Crusader", duration=10, expirationTime=e.mock.time + 9, mine=True),
                  T(icon=33, name="Hammer of Justice", duration=6, expirationTime=e.mock.time + 5, mine=True, cc=True))
        plate = e.mock.addPlate("nameplate1", T(name="Raptor", level=30, health=5, healthMax=5, attackable=True,
                                                reaction=2, auras=auras))
        o = e.ns.Nameplates.byPlate[plate]
        self.assertEqual([b.icon.texture for b in o.icons.values() if b.shown], [32, 33])
        self.assertTrue(o.cc)                                              # the game says it is controlled
        e.target(auras=auras)
        self.assertEqual([b.icon.texture for b in e.ns.Auras.icons.values() if b.shown], [32, 33])
        out = e.cmd("aurareport")
        self.assertIn("saved", out)
        self.assertIn("the list", list(e.db.auraReport.values())[0])
        self.assertEqual(e.errors(), [])

    def test_countdowns(self):
        e = Env()
        T = e.lua.table
        auras = T(T(icon=1, duration=120, expirationTime=e.mock.time + 90, mine=True),
                  T(icon=2, duration=10, expirationTime=e.mock.time + 7, mine=True),
                  T(icon=3, duration=10, expirationTime=e.mock.time + 2, mine=True))
        plate = e.mock.addPlate("nameplate1", T(name="Raptor", level=30, health=5, healthMax=5, attackable=True,
                                                reaction=2, auras=auras))
        icons = e.ns.Nameplates.byPlate[plate].icons
        e.update(0.2)
        self.assertEqual([icons[1].time.text, icons[2].time.text], ["2m", "7"])
        self.assertTrue(icons[3].time.text.startswith("1."))
        self.assertEqual(round(icons[3].time.tcolor[1], 2), round(e.ns.colors.danger[1], 2))
        e.update(2.5)
        self.assertEqual(icons[3].time.text, "")
        e.target(auras=T(T(icon=9, duration=30, expirationTime=e.mock.time + 20, mine=True)))
        e.update(0.2)
        self.assertEqual(e.ns.Auras.icons[1].time.text, "20")


class ThisBatch(unittest.TestCase):
    def test_low_health_shows_your_bars_even_out_of_combat(self):
        e = Env()
        e.cmd("preset minimal")
        f = e.frames.vertical
        e.update(4)
        self.assertAlmostEqual(f.visual.alpha, 0.15)
        e.mock.units.player.health = 300
        e.mock.fire("UNIT_HEALTH", "player")
        e.update(1)
        self.assertEqual(f.visual.alpha, 1)                         # essential: never hidden

    def test_targeting_yourself_brings_your_bars_back(self):
        e = Env(db="{ v = 4, units = { vertical = true } }")
        f = e.frames.vertical
        e.update(4)
        self.assertAlmostEqual(f.visual.alpha, 0.3)
        e.mock.setUnit("target", e.mock.units.player)
        e.update(1)
        self.assertEqual(f.visual.alpha, 1)

    def test_the_target_frame_says_how_your_threat_stands(self):
        e = Env()
        t = e.target(combat=True, threat=3, threatPct=100)
        e.update(0.3)
        f = e.frames.target
        icon, text, glow = f.threatIcon, f.threatText, f.threatGlow

        def shield():
            return round(icon.texCoord[1] * 4)               # 0 max, 1 gaining, 2 losing, 3 calm
        self.assertTrue(icon.shown)
        self.assertEqual(shield(), 0)
        angry = e.ns.colors.angry
        self.assertEqual(round(glow.vcolor[1], 2), round(angry[1], 2))      # max: red
        self.assertGreater(glow.alpha, 0.45)                                # and fairly strong
        self.assertFalse(text.shown)                                        # no number unless wanted
        t.threat, t.threatPct = 1, 85
        e.update(0.3)
        self.assertEqual(shield(), 1)
        greens = set()
        for _ in range(20):
            e.update(0.05)
            greens.add(round(glow.vcolor[2], 2))
        self.assertGreater(max(greens) - min(greens), 0.3)                  # red and yellow, in turn
        t.threat = 2
        e.update(0.3)
        self.assertEqual(shield(), 2)
        blues = set()
        for _ in range(20):
            e.update(0.05)
            blues.add(round(glow.vcolor[3], 2))
        self.assertGreater(max(blues) - min(blues), 0.3)                    # yellow and blue, in turn
        t.threat, t.threatPct = 0, 40
        e.update(0.3)
        self.assertEqual(shield(), 3)
        calm = e.ns.colors.calm
        self.assertEqual(round(glow.vcolor[3], 2), round(calm[3], 2))       # not on you: blue
        e.cmd("threatpercent on")
        e.update(0.3)
        self.assertEqual((text.shown, text.text), (True, "40%"))
        t.combat = False
        e.update(0.3)
        self.assertFalse(icon.shown)
        self.assertFalse(text.shown)
        self.assertEqual(glow.alpha, 0)

    def test_crowd_control_sits_at_the_right_end_after_the_others(self):
        e = Env()
        T = e.lua.table
        auras = T(T(icon=43, duration=4, expirationTime=e.mock.time + 3, mine=True, cc=True))
        plate = e.mock.addPlate("nameplate1", T(name="Raptor", level=30, health=5, healthMax=5, attackable=True,
                                                reaction=2, combat=True, threat=3, auras=auras))
        o = e.ns.Nameplates.byPlate[plate]
        e.update(0.4)
        cc = o.ccIcon.points[1]
        self.assertEqual((cc[1], cc[3]), ("LEFT", "RIGHT"))              # on the right...
        self.assertTrue(e.same(cc[2], o.threatIcon))                    # ...after the threat shield
        data = e.mock.units.nameplate1
        data.threat = None
        data.combat = False
        e.update(0.5)
        self.assertTrue(e.same(o.ccIcon.points[1][2], o.health))        # moves up when the shield goes

    def test_plates_show_debuffs_buffs_and_crowd_control_like_the_games_own(self):
        e = Env()
        T = e.lua.table
        auras = T(T(icon=41, duration=10, expirationTime=e.mock.time + 8, mine=True),
                  T(icon=42, duration=10, expirationTime=e.mock.time + 8, sourceUnit="party1"),
                  T(icon=43, duration=4, expirationTime=e.mock.time + 3, mine=True, cc=True))
        plate = e.mock.addPlate("nameplate1", T(name="Raptor", level=30, health=5, healthMax=5, attackable=True,
                                                reaction=2, auras=auras))
        o = e.ns.Nameplates.byPlate[plate]
        self.assertEqual([b.icon.texture for b in o.icons.values() if b.shown], [41, 43])    # yours
        self.assertTrue(o.ccIcon.shown)
        self.assertEqual(o.ccIcon.icon.texture, 43)
        self.assertTrue(e.mock.auraFilters["HARMFUL|INCLUDE_NAME_PLATE_ONLY|PLAYER"])
        e.cmd("platealldebuffs on")
        self.assertEqual([b.icon.texture for b in o.icons.values() if b.shown], [41, 42, 43])
        self.assertEqual(e.errors(), [])

    def test_the_experimental_notice_is_answered_once_you_have(self):
        e = Env()
        e.g.StaticPopupDialogs.GAMEPAD_EXPERIMENTAL = e.lua.table(text="You have enabled one or more experimental features.")
        e.g.StaticPopup_Show("GAMEPAD_EXPERIMENTAL")
        e.mock.advance(0.1)
        self.assertEqual(e.mock.clicked or 0, 0)                     # not before you have answered it yourself
        e.g.StaticPopup_OnClick(e.mock.visiblePopup, 1)             # you accept it
        self.assertTrue(e.db.acceptedNotices.GAMEPAD_EXPERIMENTAL)
        saved = e.mock.serialize(e.g.ControllerCamHUDDB)
        e2 = Env(db=saved)
        e2.g.StaticPopupDialogs.GAMEPAD_EXPERIMENTAL = e2.lua.table(text="You have enabled one or more experimental features.")
        e2.g.StaticPopup_Show("GAMEPAD_EXPERIMENTAL")
        e2.mock.advance(0.1)
        self.assertEqual(e2.mock.clicked, 1)                         # answered for you
        e2.g.StaticPopupDialogs.OTHER = e2.lua.table(text="Delete this item?")
        e2.g.StaticPopup_Show("OTHER")
        e2.g.StaticPopup_OnClick(e2.mock.visiblePopup, 1)
        self.assertIsNone(e2.db.acceptedNotices.OTHER)               # only that notice, never others
        e2.cmd("autonotice off")
        e2.g.StaticPopup_Show("GAMEPAD_EXPERIMENTAL")
        e2.mock.advance(0.1)
        self.assertEqual(e2.mock.clicked, 2)                         # (the OTHER click) — no new answer
        self.assertIn("asked again", e2.cmd("forgetnotices"))


class PresetsAndLayouts(unittest.TestCase):
    def test_presets_set_the_whole_hud(self):
        e = Env()
        self.assertIn("Action", e.cmd("preset action"))
        self.assertTrue(e.db.units.vertical)
        self.assertTrue(e.db.bars)
        self.assertTrue(e.frames.vertical.on)
        e.cmd("preset classic")
        self.assertFalse(e.db.units.vertical)
        self.assertFalse(e.db.impactFx)
        self.assertTrue(e.frames.player.on)
        e.cmd("preset minimal")
        self.assertTrue(e.db.units.pet)                             # minimal keeps what you need ...
        self.assertAlmostEqual(e.db.idle, 0.15)                     # ... as a faint hint out of combat
        self.assertTrue(e.db.plateTargetName)                       # names stay
        self.assertTrue(e.db.plateSubtitles)                        # and what an NPC does, when it shows
        self.assertFalse(e.db.plateTitles)
        self.assertIn("unknown preset", e.cmd("preset fancy"))
        self.assertIn("usage", e.cmd("preset"))
        self.assertEqual(e.ns.RunCheck(False)[0], 0)
        self.assertEqual(e.errors(), [])

    def test_presets_keep_your_positions_unless_they_place_everything(self):
        e = Env(db="{ v = 4, pos = { target = { x = 5, y = 6 } } }")
        e.cmd("preset action")
        self.assertEqual(e.db.pos.target.x, 5)                      # kept
        e.cmd("preset soulslike")                                   # a whole-screen layout
        self.assertEqual((e.db.pos.target.x, e.db.pos.target.y), (0, -150))
        p = e.frames.target.mover.points[1]
        self.assertEqual((p[1], p[4], p[5]), ("CENTER", 0, -150))
        e.cmd("preset classic")                                     # back where they start
        self.assertIsNone(e.db.pos.target)
        self.assertEqual(e.frames.target.mover.points[1][1], "TOP")

    def test_every_preset_runs_cleanly(self):
        e = Env()
        e.target()
        for p in e.ns.Presets.HUD.values():
            e.cmd("preset " + p.key)
            self.assertEqual(e.ns.RunCheck(False)[0], 0, p.key)
            for k in p.set.keys():
                self.assertIn(k, [d.key for d in e.ns.settings.values() if d.key] + ["idle", "verticalIdle", "scale"], k)
        self.assertGreaterEqual(len(list(e.ns.Presets.HUD.values())), 7)
        self.assertEqual(e.errors(), [])

    def test_back_to_the_games_own_layout(self):
        e = Env(db="{ v = 4, pos = { target = { x = 5, y = 6 } } }")
        said = e.cmd("layout modern")
        self.assertIn("Modern", said)
        self.assertIn("Edit Mode", said)                            # choosing the game's layout is yours to do there
        self.assertIsNone(e.mock.layoutSelected)                    # (the game refuses it to addons: never tried)
        self.assertIsNone(e.db.pos.target)
        self.assertEqual(e.frames.target.mover.points[1][1], "TOP")
        e.cmd("layout classic")
        self.assertIsNone(e.mock.layoutSelected)
        e.mock.state.combat = True
        self.assertIn("Not in combat", e.cmd("layout modern"))
        self.assertIn("usage", e.cmd("layout fancy"))

    def test_options_have_a_page_per_area_and_hide_the_fine_tuning(self):
        e = Env()
        e.ns.BuildOptions()
        rows = {r["def"].label: r for r in e.ns.optionRows.values()}
        self.assertEqual(rows["Player frame"].page, "Frames")
        self.assertEqual(rows["Hit particles"].page, "Effects")
        self.assertEqual(rows["Chat fades when quiet"].page, "Quests, chat and map")
        self.assertTrue(rows["Nameplates"].widget.shown)
        self.assertFalse(rows["Player titles"].widget.shown)         # fine tuning: hidden
        self.assertFalse(rows["Frame size"].widget.shown)
        cb = rows["Show advanced options"].widget
        cb.checked = True
        cb.scripts.OnClick(cb)
        self.assertTrue(rows["Player titles"].widget.shown)
        self.assertTrue(rows["Frame size"].widget.shown)
        self.assertTrue(e.db.advancedOptions)


class VerticalHeal(unittest.TestCase):
    def test_incoming_heals_on_the_vertical_bars(self):
        e = Env(db="{ v = 4, units = { vertical = true } }")
        e.mock.units.player.health, e.mock.units.player.incoming = 600, 200
        e.mock.fire("UNIT_HEAL_PREDICTION", "player")
        bar = e.frames.vertical.health
        self.assertTrue(bar.healBar.shown)
        self.assertEqual(bar.healBar.orientation, "VERTICAL")
        self.assertTrue(e.same(bar.healBar.points[1][2], bar.fill.barTex))       # on top of the filled part
        self.assertEqual(bar.healBar.points[1][3], "TOPLEFT")


class PlateDetails(unittest.TestCase):
    def plate(self, e, unit="nameplate1", **kw):
        data = e.lua.table(name="Slagg", level=35, health=600, healthMax=800, power=40, powerMax=100,
                           powerToken="MANA", attackable=True, reaction=2)
        for k, v in kw.items():
            data[k] = v
        plate = e.mock.addPlate(unit, data)
        return data, e.ns.Nameplates.byPlate[plate]

    def test_npc_jobs_and_player_guilds_and_titles(self):
        e = Env()
        _, o = self.plate(e, attackable=False, reaction=5, job="Superior Butcher")
        self.assertEqual((o.name.text, o.sub.text, o.sub.shown), ("Slagg", "Superior Butcher", True))
        _, p = self.plate(e, "nameplate2", attackable=False, reaction=5, isPlayer=True, title="Sergeant Zengu",
                          guild="Bad Apples")
        self.assertEqual((p.name.text, p.sub.text), ("Sergeant Zengu", "<Bad Apples>"))
        _, q = self.plate(e, "nameplate3", attackable=False, reaction=5)              # level line: not a job
        self.assertFalse(q.sub.shown)
        e.cmd("platetitles off")
        e.cmd("platesubtitles off")
        self.assertEqual(p.name.text, "Slagg")                                          # no title now
        self.assertFalse(p.sub.shown)

    def test_hostile_plates_have_power_and_percent_on_request(self):
        e = Env()
        _, o = self.plate(e)
        self.assertTrue(o.power.shown)
        self.assertEqual(o.power.fill.value, 40)
        self.assertTrue(o.percent.shown)                             # the health left and the percent, by default
        e.cmd("platevalue off")
        self.assertEqual((o.percent.shown, o.percent.text), (True, "75%"))
        e.cmd("platepower off")
        self.assertFalse(o.power.shown)
        _, none = self.plate(e, "nameplate2", powerMax=0)
        self.assertFalse(none.power.shown)
        e.cmd("platepower on")
        data, rage = self.plate(e, "nameplate3", power=0, powerMax=100, powerToken="RAGE")
        self.assertFalse(rage.power.shown)                          # a resource it never builds: no empty track
        data.power = 30
        e.mock.fire("UNIT_POWER_UPDATE", "nameplate3")
        self.assertTrue(rage.power.shown)
        _, caster = self.plate(e, "nameplate4", power=0, powerMax=500, powerToken="MANA")
        self.assertTrue(caster.power.shown)                         # a caster out of mana still has mana

    def test_friends_get_bars_while_they_fight(self):
        e = Env()
        data, o = self.plate(e, attackable=False, reaction=5, isPlayer=True, **{"class": "MAGE"})
        self.assertFalse(o.health.shown)
        data.combat = True
        e.update(0.4)
        self.assertTrue(o.health.shown)
        self.assertTrue(o.power.shown)
        data.combat = False
        e.update(0.4)
        self.assertFalse(o.health.shown)
        e.cmd("platefriendbars off")
        data.combat = True
        e.update(0.4)
        self.assertFalse(o.health.shown)

    def test_cast_shows_the_spell_and_its_target(self):
        e = Env()
        data, o = self.plate(e)
        e.mock.units["nameplate1target"] = e.lua.table(name="Ghostlight")
        now = e.mock.time
        data.cast = e.lua.table(name="Shadow Bolt", start=now * 1000, stop=(now + 2) * 1000)
        e.mock.fire("UNIT_SPELLCAST_START", "nameplate1")
        self.assertTrue(o.cast.shown)
        self.assertIn("Shadow Bolt", o.castText.text)
        self.assertIn("Ghostlight", o.castText.text)
        e.cmd("platecasttarget off")
        e.mock.fire("UNIT_SPELLCAST_START", "nameplate1")
        self.assertNotIn("Ghostlight", o.castText.text)
        e.update(2.2)
        self.assertFalse(o.castText.shown)


class Readable(unittest.TestCase):
    def test_the_bar_moves_down_as_the_name_grows(self):
        e = Env()
        f = e.frames.target
        y = lambda: f.health.points[1][5]
        start = y()
        self.assertLessEqual(start, -(13 * 1.5))                           # below the name, never under it
        e.cmd("text 250")
        self.assertLessEqual(y(), -(13 * 2.5))
        self.assertLess(y(), start)
        self.assertGreater(f.mover.height, 13 * 2.5)
        e.cmd("text 80")
        self.assertGreater(y(), start)

    def test_target_of_target_sits_beside_the_target_bar(self):
        e = Env()
        p = e.frames.tot.mover.points[1]
        self.assertTrue(e.same(p[2], e.frames.target.health))

    def test_incoming_heals_only(self):
        e = Env()
        t = e.target(health=500, healthMax=1000, incoming=200, absorb=100)
        bar = e.frames.target.health
        self.assertTrue(bar.healBar.shown)
        self.assertEqual((bar.healBar.value, bar.healBar.max), (200, 1000))
        self.assertTrue(e.same(bar.healBar.points[1][2], bar.fill.barTex))     # right after the filled part
        self.assertIsNone(bar.shieldBar)                                        # shields are not shown
        t.incoming = None
        e.mock.fire("UNIT_HEAL_PREDICTION", "target")
        self.assertFalse(bar.healBar.shown)
        t.incoming = e.mock.secret()                                           # secret is still drawn
        e.mock.fire("UNIT_HEAL_PREDICTION", "target")
        self.assertTrue(bar.healBar.shown)
        self.assertEqual(e.errors(), [])

    def test_health_colours_follow_the_fight(self):
        e = Env()
        t = e.target(health=800, healthMax=1000)
        bar = e.frames.target.health
        self.assertEqual(e.color(bar), e.theme("hostile"))                      # at peace: what it is
        t.combat = True
        t.health = 500
        e.mock.fire("UNIT_HEALTH", "target")
        self.assertEqual(e.color(bar), e.theme("caution"))                      # in a fight: how much is left
        t.health = 1000
        e.mock.fire("UNIT_HEALTH", "target")
        self.assertEqual(e.color(bar), e.theme("health"))
        t.health = 0
        t.dead = True
        e.mock.fire("UNIT_HEALTH", "target")
        self.assertEqual(e.color(bar), e.theme("tapped"))
        e.mock.state.combat = True
        e.mock.units.player.health = 300
        e.mock.fire("UNIT_HEALTH", "player")
        r, g, b = e.color(e.frames.player.health)
        self.assertGreater(r, g)                                                 # orange-red
        e.ns.db.combatColors = False                                             # the option (Options panel)
        e.mock.fire("UNIT_HEALTH", "player")
        self.assertEqual(e.color(e.frames.player.health), e.theme("caution"))

    def test_percent_when_the_game_keeps_health_secret(self):
        e = Env()
        e.target(health=e.mock.secret(), healthMax=e.mock.secret(), pct=0.25)
        f = e.frames.target
        self.assertEqual((f.text.text, f.text.shown), ("25%", True))           # the game's own percent
        self.assertEqual(e.errors(), [])


class HitEffects(unittest.TestCase):
    def test_your_hits_flash_in_their_school_colour_and_shake(self):
        e = Env()
        e.target()
        f, IM = e.frames.target, e.ns.Impact
        self.assertIn("log", IM.source)
        for mask, school in ((1, "physical"), (4, "fire"), (16, "frost"), (32, "shadow"), (64, "arcane"),
                             (8, "nature"), (2, "holy"), (36, "fire")):
            e.mock.logHit("SPELL_DAMAGE", "player", "target", mask)
            self.assertEqual(IM.last.school, school, mask)
            want = IM.PROFILES[school].color
            got = f.health.flashTex.vcolor
            self.assertEqual(tuple(round(got[i], 2) for i in (1, 2, 3)), tuple(round(v, 2) for v in want.values()))
            self.assertTrue(IM.IsShaking(IM, f.visual))
            e.update(0.6)
            self.assertFalse(IM.IsShaking(IM, f.visual))
            p = f.visual.points[1]
            self.assertEqual((p[4], p[5]), (0, 0))
        self.assertEqual(e.errors(), [])

    def test_an_auto_attack_shakes_even_a_tiny_hit(self):
        e = Env()
        t = e.target(health=100000, healthMax=100000)
        e.mock.logHit("SWING_DAMAGE", "player", "target", 1)
        t.health = 99990
        e.mock.fire("UNIT_HEALTH", "target")
        self.assertTrue(e.ns.Impact.IsShaking(e.ns.Impact, e.frames.target.visual))

    def test_crits_hit_harder(self):
        e = Env()
        e.target()
        IM = e.ns.Impact
        e.mock.logHit("SWING_DAMAGE", "player", "target", 1, True)
        self.assertTrue(IM.last.crit)
        self.assertAlmostEqual(IM.shaking[e.frames.target.visual].amp, 3 * 1.8)

    def test_only_your_own_hits_and_your_pets(self):
        e = Env()
        e.target()
        e.mock.units.someone = e.lua.table(name="Other", guid="other")
        e.mock.logHit("SPELL_DAMAGE", "someone", "target", 4)
        self.assertIsNone(e.ns.Impact.last)
        e.mock.setUnit("pet", e.lua.table(name="Wolf", health=5, healthMax=5))
        e.mock.logHit("SWING_DAMAGE", "pet", "target", 1)
        self.assertEqual(e.ns.Impact.last.school, "physical")

    def test_nameplates_react_too(self):
        e = Env()
        plate = e.mock.addPlate("nameplate1", e.lua.table(name="Raptor", level=34, health=600, healthMax=800,
                                                          attackable=True, reaction=2, guid="raptor"))
        o = e.ns.Nameplates.byPlate[plate]
        e.mock.logHit("SPELL_DAMAGE", "player", "nameplate1", 16)
        self.assertTrue(e.ns.Impact.IsShaking(e.ns.Impact, o))
        e.mock.removePlate("nameplate1")
        self.assertFalse(e.ns.Impact.IsShaking(e.ns.Impact, o))
        self.assertIsNone(e.ns.Nameplates.byGuid.raptor)

    def test_without_the_combat_log_the_games_hit_event_is_used(self):
        e = Env(setup=lambda env: env.lua.execute("CombatLogGetCurrentEventInfo = nil"))
        e.target()
        self.assertEqual(e.ns.Impact.source, "unit+health")
        e.mock.fire("UNIT_COMBAT", "target", "WOUND", "CRITICAL", 50, 32)
        self.assertEqual((e.ns.Impact.last.school, e.ns.Impact.last.crit), ("shadow", True))
        e.ns.Impact.last = None
        e.mock.fire("UNIT_COMBAT", "target", "DODGE", "", 0, 1)
        e.mock.fire("UNIT_COMBAT", "player", "WOUND", "", 50, 1)
        self.assertIsNone(e.ns.Impact.last)

    def test_secret_hits_still_land(self):
        e = Env(setup=lambda env: env.lua.execute("CombatLogGetCurrentEventInfo = nil"))
        e.target()
        IM = e.ns.Impact
        e.mock.fire("UNIT_COMBAT", "target", "WOUND", e.mock.secret(), e.mock.secret(), e.mock.secret())
        self.assertEqual((IM.last.school, IM.last.crit), ("physical", False))
        self.assertEqual((IM.heard, IM.landed), (1, 1))
        # your own bar, when the game hides your health
        e.mock.units.player.health = e.mock.secret()
        e.mock.fire("UNIT_HEALTH", "player")
        e.mock.fire("UNIT_COMBAT", "player", "WOUND", "", e.mock.secret(), 4)
        self.assertTrue(IM.IsShaking(IM, e.frames.player.visual))
        rows = [r.detail for r in e.ns.RunCheck(False)[1].values() if r.name == "hit effects can hear hits"]
        self.assertIn("2 heard", rows[0])
        self.assertEqual(e.errors(), [])

    def test_a_flash_never_sticks_when_health_is_secret(self):
        e = Env()
        t = e.target(health=e.mock.secret(), healthMax=e.mock.secret())
        bar = e.frames.target.health
        e.mock.logHit("SWING_DAMAGE", "player", "target", 1)
        self.assertGreater(bar.flashA, 0)
        for _ in range(5):                                       # secret updates arrive while it fades
            e.mock.fire("UNIT_HEALTH", "target")
            e.update(0.1)
        e.update(1)
        self.assertEqual(bar.flashA, 0)
        self.assertEqual(bar.flashTex.alpha, 0)

    def test_every_school_has_its_own_particles(self):
        e = Env()
        e.target()
        IM = e.ns.Impact
        kinds = {}
        for mask, school in ((1, "physical"), (2, "holy"), (4, "fire"), (8, "nature"), (16, "frost"),
                             (32, "shadow"), (64, "arcane")):
            before = len(list(IM.live.keys()))
            e.mock.logHit("SPELL_DAMAGE", "player", "target", mask)
            self.assertEqual(len(list(IM.live.keys())) - before, IM.PROFILES[school].fx.count, school)
            kinds[school] = IM.PROFILES[school].fx.kind
            e.update(1.2)
            self.assertEqual(len(list(IM.live.keys())), 0, school)            # every particle is gone again
        self.assertEqual(len(set(kinds.values())), 7)
        holy = IM.PROFILES.holy.color
        self.assertGreater(holy[2], holy[3])                     # gold, not violet
        e.cmd("impactfx off")
        e.mock.logHit("SPELL_DAMAGE", "player", "target", 4)
        self.assertEqual(len(list(IM.live.keys())), 0)
        self.assertEqual(e.errors(), [])

    def test_particles_are_reused(self):
        e = Env(db="{ v = 8, debug = false }")                     # (the debug probe makes a frame of its own)
        e.target()
        e.mock.logHit("SPELL_DAMAGE", "player", "target", 4)
        e.update(1.2)
        made = len(e.mock.frames)
        for _ in range(5):
            e.mock.logHit("SPELL_DAMAGE", "player", "target", 4)
            e.update(1.2)
        self.assertEqual(len(e.mock.frames), made)

    def test_hittest_shows_every_school(self):
        e = Env()
        self.assertIn("every damage school", e.cmd("hittest"))     # nothing targeted: on your own frame
        e.update(5)
        e.target()
        self.assertIn("every damage school", e.cmd("hittest"))
        seen = []
        for _ in range(8):
            e.update(0.6)
            if e.ns.Impact.last:
                seen.append(e.ns.Impact.last.school)
        self.assertEqual(len(set(seen)), 7)
        self.assertTrue(e.ns.Impact.last.crit)

    def test_off(self):
        e = Env()
        e.target()
        e.cmd("impacts off")
        e.mock.logHit("SPELL_DAMAGE", "player", "target", 4)
        self.assertIsNone(e.ns.Impact.last)
        self.assertEqual(e.ns.RunCheck(False)[0], 0)


class Numbers(unittest.TestCase):
    """What you take, in the style of your own hits; tied to the game's combat text option for you."""

    def env(self, cvar="1"):
        def setup(env):
            env.mock.cvars["enableFloatingCombatText"] = cvar
        e = Env(setup=setup)
        e.lua.execute('CreateFrame("Frame", "CombatText", UIParent)')
        e.mock.fire("ADDON_LOADED", "Blizzard_CombatText")         # the game's text loads on demand
        return e

    def live(self, e):
        return [n for n in e.ns.Numbers.live.values()]

    def test_hits_heals_and_dodges(self):
        e = self.env()
        self.assertTrue(e.aside("CombatText"))                     # ours stand in for the game's
        e.mock.fire("UNIT_COMBAT", "player", "WOUND", "", 120, 4)
        e.mock.fire("UNIT_COMBAT", "player", "HEAL", "CRITICAL", 300, 2)
        e.mock.fire("UNIT_COMBAT", "player", "DODGE", "", 0, 1)
        e.mock.fire("UNIT_COMBAT", "target", "WOUND", "", 50, 1)   # not you: not here
        live = self.live(e)
        self.assertEqual(len(live), 3)
        self.assertEqual(live[0].fs.text, "-120")
        fire = e.ns.Impact.PROFILES.fire.color
        self.assertEqual(round(live[0].fs.tcolor[1], 2), round(fire[1], 2))   # coloured by the school
        self.assertTrue(live[1].crit)
        self.assertEqual(live[2].fs.text, "Dodge")
        e.update(0.1)
        self.assertGreater(live[0].fs.fontSize if hasattr(live[0].fs, "fontSize") else 1, 0)
        e.update(2)
        self.assertEqual(len(self.live(e)), 0)                      # gone, back in the pool
        e.mock.fire("UNIT_COMBAT", "player", "WOUND", "", e.mock.secret(), 1)    # a secret amount still shows
        self.assertEqual(len(self.live(e)), 1)
        self.assertEqual(e.errors(), [])

    def test_crits_and_dodges_slam_in_stick_then_fade(self):
        e = self.env()
        e.mock.fire("UNIT_COMBAT", "player", "WOUND", "CRITICAL", 900, 1)
        e.mock.fire("UNIT_COMBAT", "player", "PARRY", "", 0, 1)
        e.mock.fire("UNIT_COMBAT", "player", "WOUND", "", 50, 1)
        crit, parry, hit = self.live(e)
        self.assertTrue(crit.sticky and parry.sticky)
        self.assertFalse(hit.sticky)

        def where(n):
            p = n.fs.points[1]
            return (round(p[4], 1), round(p[5], 1))
        e.update(0.25)                                              # slammed in, settled
        spots, alphas = set(), set()
        for _ in range(14):                                         # 0.7 s later: still in place, fully there
            e.update(0.05)
            spots.add(where(crit))
            alphas.add(crit.fs.alpha)
        self.assertEqual(len(spots), 1)
        self.assertEqual(alphas, {1})
        self.assertNotIn(hit, self.live(e))                         # an ordinary hit is long gone by then...
        e.update(0.3)
        self.assertLess(crit.fs.alpha, 1)                           # ...and then the crit fades too
        e.update(0.5)
        self.assertEqual(len(self.live(e)), 0)

    def test_a_burst_spreads_out(self):
        e = self.env()
        for _ in range(3):
            e.mock.fire("UNIT_COMBAT", "player", "WOUND", "", 50, 1)
        xs = [n.x for n in self.live(e)]
        self.assertGreater(max(xs) - min(xs), 30)

    def test_follows_the_games_option(self):
        e = self.env(cvar="0")
        self.assertFalse(e.aside("CombatText"))
        e.mock.fire("UNIT_COMBAT", "player", "WOUND", "", 120, 1)
        self.assertEqual(len(self.live(e)), 0)                      # you turned it off: nothing here either

    def test_off_gives_the_game_its_text_back(self):
        e = self.env()
        e.cmd("numbers off")
        self.assertFalse(e.aside("CombatText"))
        e.mock.fire("UNIT_COMBAT", "player", "WOUND", "", 120, 1)
        self.assertEqual(len(self.live(e)), 0)


class PlateLife(unittest.TestCase):
    def plate(self, e, unit="nameplate1", **kw):
        data = e.lua.table(name="Raptor", level=34, health=600, healthMax=800, attackable=True, reaction=2)
        for k, v in kw.items():
            data[k] = v
        plate = e.mock.addPlate(unit, data)
        return data, plate, e.ns.Nameplates.byPlate[plate]

    def test_every_part_of_the_games_plate_stays_hidden(self):
        e = Env()
        data, plate, o = self.plate(e)
        extra = e.g.CreateFrame("Frame", None, plate)              # another part of the game's plate
        e.mock.removePlate("nameplate1")
        e.mock.plates.nameplate1, e.mock.units.nameplate1 = plate, data
        e.mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
        self.assertEqual((plate.UnitFrame.alpha, extra.alpha, o.alpha), (0, 0, 1))
        plate.UnitFrame.SetAlpha(plate.UnitFrame, 1)                # the game shows it again
        e.update(0.15)
        self.assertEqual(plate.UnitFrame.alpha, 0)
        self.assertEqual(plate.alpha, 1)                            # the plate itself is never touched
        e.mock.removePlate("nameplate1")
        self.assertEqual((plate.UnitFrame.alpha, extra.alpha), (1, 1))
        plate.UnitFrame.SetAlpha(plate.UnitFrame, 0.5)              # given back for good
        self.assertEqual(plate.UnitFrame.alpha, 0.5)

    def test_minor_enemies_and_critters_get_mini_plates(self):
        e = Env()
        _, _, normal = self.plate(e, power=5, powerMax=10, job="Guard")
        _, _, minor = self.plate(e, "nameplate2", classification="minus", power=5, powerMax=10, job="Guard")
        _, _, critter = self.plate(e, "nameplate3", attackable=False, reaction=4, creature="Critter")
        self.assertEqual(normal.scale, 1)
        self.assertEqual((minor.scale, critter.scale), (0.8, 0.8))
        self.assertAlmostEqual(minor.health.width * minor.scale, normal.health.width * 0.5)    # half as wide
        self.assertTrue(minor.health.shown)                       # still a bar for an enemy
        self.assertFalse(minor.power.shown)
        self.assertFalse(minor.sub.shown)
        self.assertTrue(normal.power.shown)
        e.mock.setUnit("target", e.mock.units.nameplate2)
        self.assertAlmostEqual(minor.scale, 0.8 * 1.15)           # targeted: still stands out
        e.cmd("platemini off")
        self.assertEqual(critter.scale, 1)

    def test_health_text_options(self):
        e = Env()
        data, plate, o = self.plate(e, health=12345, healthMax=20000)
        self.assertEqual(o.percent.text, "12.3k  62%")               # full size: both, by default
        e.cmd("platecompact on")
        self.assertEqual(o.percent.text, "62%")                      # compact: the percent alone
        e.cmd("platecompact off")
        e.cmd("platepercent off")
        self.assertEqual(o.percent.text, "12.3k")
        e.cmd("platepercent on")
        e.cmd("platevalue off")
        self.assertEqual(o.percent.text, "62%")

    def test_your_debuffs_show_above_the_name(self):
        e = Env()
        a = e.lua.table(icon=1, applications=2, duration=10, expirationTime=e.mock.time + 6, mine=True)
        data, plate, o = self.plate(e, auras=e.lua.table(a))
        self.assertTrue(o.icons[1].shown)
        self.assertFalse(o.icons[2].shown)
        self.assertEqual(str(o.icons[1].count.text), "2")
        self.assertEqual(o.icons[1].cooldown.cdDuration, 10)
        e.cmd("platedebuffs off")
        self.assertFalse(o.icons[1].shown)

    def test_aggro_pulses_and_changes_colour(self):
        e = Env()
        data, plate, o = self.plate(e, threat=3, combat=True)
        e.update(0.3)
        c = e.ns.colors.angry
        self.assertEqual(round(o.glow.vcolor[1], 2), round(c[1], 2))
        seen = set()
        for _ in range(6):
            e.update(0.05)
            seen.add(round(o.glow.alpha, 2))
        self.assertGreater(len(seen), 3)                            # it breathes
        self.assertTrue(o.threatIcon.shown)                         # the shield above the bar's end
        self.assertEqual(round(o.threatIcon.texCoord[1] * 4), 0)
        data.threat = 1
        e.update(0.4)
        self.assertEqual(o.threatState, "gaining")
        self.assertEqual(round(o.threatIcon.texCoord[1] * 4), 1)
        data.threat = 0
        e.update(0.4)
        e.update(0.1)
        self.assertEqual(o.glow.alpha, 0)                           # not on you: no glow around the bar...
        self.assertEqual(o.threatState, "calm")                     # ...but a blue shield and name glow
        calm = e.ns.colors.calm
        self.assertEqual(round(o.nameGlow.vcolor[3], 2), round(calm[3], 2))
        self.assertGreater(o.nameGlow.alpha, 0.2)
        e.cmd("platethreat off")
        data.threat = 3
        e.update(0.4)
        self.assertEqual(o.glow.alpha, 0)

    def test_low_health_breathes_and_crowd_control_shimmers(self):
        e = Env()
        data, plate, o = self.plate(e, health=100, healthMax=800)
        e.update(0.3)
        alphas = set()
        for _ in range(6):
            e.update(0.05)
            alphas.add(round(o.health.fill.alpha, 2))
        self.assertGreater(len(alphas), 3)
        data.auras = e.lua.table(e.lua.table(icon=1, spellId=118, duration=0, expirationTime=0, cc=True))
        e.mock.fire("UNIT_AURA", "nameplate1")
        e.update(0.1)
        self.assertTrue(o.shimmer.shown)
        x1 = o.shimmer.points[1][4]
        e.update(0.1)
        self.assertNotEqual(o.shimmer.points[1][4], x1)             # it runs along the bar
        data.auras = None
        data.health = 800
        e.mock.fire("UNIT_AURA", "nameplate1")
        e.mock.fire("UNIT_HEALTH", "nameplate1")
        e.update(0.1)
        self.assertFalse(o.shimmer.shown)
        self.assertEqual(o.health.fill.alpha, 1)

    def test_plates_fade_in(self):
        e = Env()
        data, plate, o = self.plate(e)
        self.assertLess(o.name.alpha, 0.5)
        e.update(0.4)
        self.assertEqual(o.name.alpha, 1)
        e.cmd("platemotion off")
        data2, plate2, o2 = self.plate(e, "nameplate2")
        self.assertEqual(o2.name.alpha, 1)


class QuestZone(unittest.TestCase):
    def log(self, e):
        T = e.lua.table
        for i, row in enumerate([
            T(title="Arathi Highlands", isHeader=True), T(title="Raising Spirits", questID=1),
            T(title="Foul Magics", questID=2),
            T(title="Stranglethorn Vale", isHeader=True), T(title="Tiger Mastery", questID=3),
            T(title="Hidden", questID=4, isHidden=True),
            T(title="Dungeons", isHeader=True), T(title="Sigil of Strom", questID=5),
        ], 1):
            e.mock.log[i] = row
        e.mock.tracked[2], e.mock.tracked[3] = True, True          # what the player tracks by hand

    def make(self, **kw):
        return Env(setup=self.log, **kw)

    def test_off_by_default_and_untouched(self):
        e = self.make()
        self.assertEqual(e.mock.trackedList(), "2,3")
        self.assertIsNone(e.db.questSaved)

    def test_tracks_the_zone_and_follows_you(self):
        e = self.make()
        e.cmd("questzone on")
        self.assertEqual(e.mock.trackedList(), "1,2")
        e.mock.zone = "Stranglethorn Vale"
        e.mock.fire("ZONE_CHANGED_NEW_AREA")
        e.mock.advance(0.5)
        self.assertEqual(e.mock.trackedList(), "3")
        e.mock.onMap[1] = e.lua.table(questID=5)                   # the game says this one is on the map here
        e.mock.fire("QUEST_ACCEPTED")
        e.mock.advance(0.5)
        self.assertEqual(e.mock.trackedList(), "3,5")
        self.assertEqual(e.ns.RunCheck(False)[0], 0)

    def test_a_zone_without_quests_shows_your_own_list(self):
        e = self.make()
        e.cmd("questzone on")
        e.mock.zone = "Orgrimmar"
        e.mock.fire("ZONE_CHANGED_NEW_AREA")
        e.mock.advance(0.5)
        self.assertEqual(e.mock.trackedList(), "2,3")

    def test_off_puts_your_tracking_back(self):
        e = self.make()
        e.cmd("questzone on")
        e.cmd("questzone off")
        self.assertEqual(e.mock.trackedList(), "2,3")
        self.assertIsNone(e.db.questSaved)
        e.cmd("questzone on")
        e.cmd("off")                                               # the whole HUD off does the same
        self.assertEqual(e.mock.trackedList(), "2,3")

    def test_the_mouse_ui_gets_your_tracking_back_after_the_reload(self):
        e = self.make()
        e.cmd("questzone on")
        saved = e.mock.serialize(e.g.ControllerCamHUDDB)

        def later(env):                                            # the game kept the zone tracking
            self.log(env)
            env.mock.tracked[3] = None
            env.mock.tracked[1] = True
        e2 = Env(db=saved, style="0", setup=later)
        self.assertEqual(e2.mock.trackedList(), "2,3")
        self.assertIsNone(e2.db.questSaved)

    def test_waits_for_the_quest_log_to_load(self):
        e = self.make()
        e.cmd("questzone on")
        saved = e.mock.serialize(e.g.ControllerCamHUDDB)
        e2 = Env(db=saved, style="0")                              # log still empty at login
        self.assertIsNotNone(e2.db.questSaved)
        self.log(e2)
        e2.mock.tracked[3], e2.mock.tracked[1] = None, True
        e2.mock.fire("QUEST_LOG_UPDATE")
        e2.mock.advance(0.5)
        self.assertEqual(e2.mock.trackedList(), "2,3")
        self.assertIsNone(e2.db.questSaved)
        self.assertEqual(e2.errors(), [])

    def test_broken_saved_list(self):
        e = self.make(db="{ v = 2, questSaved = { 2, 'x', 3 } }")
        self.assertEqual(list(e.db.questSaved.values()) if e.db.questSaved else None, None)


class QuestOrder(unittest.TestCase):
    """The quest list sorted and thinned out: by distance, by group or not, in a recommended order."""

    GAME = """function(mock)
        mock.dist, mock.order, mock.tags, mock.done, mock.grey, mock.sorted = {}, {}, {}, {}, {}, 0
        local function drop(id)
            for i, v in ipairs(mock.order) do if v == id then table.remove(mock.order, i); return end end
        end
        C_QuestLog.AddQuestWatch = function(id)
            if not mock.tracked[id] then mock.tracked[id] = true; mock.order[#mock.order + 1] = id end
        end
        C_QuestLog.RemoveQuestWatch = function(id) mock.tracked[id] = nil; drop(id) end
        C_QuestLog.GetNumQuestWatches = function() return #mock.order end
        C_QuestLog.GetQuestIDForQuestWatchIndex = function(i) return mock.order[i] end
        C_QuestLog.GetDistanceSqToQuest = function(id)
            local d = mock.dist[id]
            if d then return d * d, true end
            return 0, false
        end
        C_QuestLog.GetQuestTagInfo = function(id) return mock.tags[id] end
        C_QuestLog.IsComplete = function(id) return mock.done[id] or false end
        C_QuestLog.IsQuestTrivial = function(id) return mock.grey[id] or false end
        function mock.listed() return table.concat(mock.order, ",") end
    end"""

    def make(self, track=(1, 2, 3), dist=None, game=True, **kw):
        def setup(e):
            T = e.lua.table
            if game:
                e.lua.eval(self.GAME)(e.mock)
            for i, row in enumerate([
                T(title="Arathi Highlands", isHeader=True),
                T(title="Raising Spirits", questID=1, level=30), T(title="Foul Magics", questID=2, level=31),
                T(title="Stranglethorn Vale", isHeader=True),
                T(title="Tiger Mastery", questID=3, level=30), T(title="The Captain's Chest", questID=4, level=32, suggestedGroup=3),
                T(title="Colonel Kurzen", questID=5, level=40), T(title="Welcome to the Jungle", questID=6, level=12),
            ], 1):
                e.mock.log[i] = row
            for id in track:
                e.lua.globals().C_QuestLog.AddQuestWatch(id)
            for id, d in (dist or {}).items():
                e.mock.dist[id] = d
        e = Env(setup=setup, **kw)
        e.mock.units.player.level = 30
        return e

    def settle(self, e, seconds=5):
        e.update(seconds, 0.5)
        e.mock.advance(0.5)

    def test_nearest_first_and_it_follows_you(self):
        e = self.make(dist={1: 500, 2: 100, 3: 300})
        self.assertEqual(e.mock.listed(), "1,2,3")
        e.cmd("questnearest on")
        self.assertEqual(e.mock.listed(), "2,3,1")
        self.assertIsNone(e.db.questSaved)                           # which quests are listed stays yours
        e.mock.dist[1] = 20                                          # you rode over to the first one
        self.settle(e)
        self.assertEqual(e.mock.listed(), "1,2,3")
        e.mock.dist[2], e.mock.dist[3] = 310, 300                    # about as far as each other: left as they are
        self.settle(e)
        self.assertEqual(e.mock.listed(), "1,2,3")
        e.mock.dist[3] = None                                        # a quest the game has no place for goes last
        e.mock.dist[2] = 800
        self.settle(e)
        self.assertEqual(e.mock.listed(), "1,2,3")
        e.g.C_QuestLog.AddQuestWatch(5)                              # you track another one yourself: it is sorted in
        e.mock.dist[5] = 100
        e.mock.fire("QUEST_LOG_UPDATE")
        e.mock.advance(0.5)
        self.assertEqual(e.mock.listed(), "1,5,2,3")
        e.cmd("questnearest off")
        e.mock.dist[1] = 5000
        self.settle(e)
        self.assertEqual(e.mock.listed(), "1,5,2,3")                 # off: the list is left as it is
        self.assertEqual(e.errors(), [])

    def test_not_while_you_fight(self):
        e = self.make(dist={1: 500, 2: 100, 3: 300})
        e.cmd("questnearest on")
        e.mock.state.combat = True
        e.mock.dist[1] = 20
        self.settle(e)
        self.assertEqual(e.mock.listed(), "2,3,1")
        e.mock.state.combat = False
        self.settle(e)
        self.assertEqual(e.mock.listed(), "1,2,3")

    def test_the_games_own_sort_is_used_for_nearest_first(self):
        e = self.make(dist={1: 500, 2: 100, 3: 300})
        e.lua.eval("""function(mock)
            C_QuestLog.SortQuestWatches = function()
                mock.sorted = mock.sorted + 1
                table.sort(mock.order, function(a, b) return (mock.dist[a] or 1e9) < (mock.dist[b] or 1e9) end)
            end
        end""")(e.mock)
        e.cmd("questnearest on")
        self.assertEqual((e.mock.listed(), e.mock.sorted), ("2,3,1", 1))
        self.settle(e, 12)                                           # nothing moved: nothing asked of the game
        self.assertEqual(e.mock.sorted, 1)

    def test_the_recommended_order(self):
        e = self.make(track=(1, 2, 3, 4, 5, 6), dist={1: 500, 2: 900, 3: 200, 4: 50, 5: 60, 6: 10})
        e.mock.done[2] = True
        e.mock.grey[6] = True
        e.cmd("questorder on")
        # ready to hand in; what you can do alone, nearest first; above your level; wants a group; grey
        self.assertEqual(e.mock.listed(), "2,3,1,5,4,6")
        e.mock.setUnit("party1", e.lua.table(name="Friend", health=10, healthMax=10))
        e.mock.advance(0.5)
        self.assertEqual(e.mock.listed(), "2,4,3,1,5,6")             # with company the group quest is worth doing
        e.mock.setUnit("party1", None)
        e.mock.advance(0.5)
        e.mock.tags[1] = e.lua.table(tagID=81, tagName="Dungeon")    # a dungeon quest by the game's tag
        self.settle(e)
        self.assertEqual(e.mock.listed(), "2,3,5,4,1,6")
        self.assertEqual(e.mock.trackedList(), "1,2,3,4,5,6")       # the order only: nothing left out
        self.assertEqual(e.errors(), [])

    def test_no_group_quests_while_alone(self):
        e = self.make(track=(1, 4, 5))
        e.cmd("questsolo on")
        self.assertEqual(e.mock.trackedList(), "1,5")
        self.assertEqual(list(e.db.questSaved.values()), [1, 4, 5])  # your own tracking is remembered
        e.mock.setUnit("party1", e.lua.table(name="Friend", health=10, healthMax=10))
        e.mock.advance(0.5)
        self.assertEqual(e.mock.trackedList(), "1,4,5")             # in a group it is back
        e.mock.setUnit("party1", None)
        e.mock.advance(0.5)
        self.assertEqual(e.mock.trackedList(), "1,5")
        e.mock.done[4] = True                                        # done: it stays, to be handed in
        e.mock.fire("QUEST_LOG_UPDATE")
        e.mock.advance(0.5)
        self.assertEqual(e.mock.trackedList(), "1,4,5")
        e.mock.done[4] = None
        e.cmd("questsolo off")
        self.assertEqual(e.mock.trackedList(), "1,4,5")
        self.assertIsNone(e.db.questSaved)
        self.assertEqual(e.ns.RunCheck(False)[0], 0)

    def test_only_the_nearest_few(self):
        e = self.make(track=(1, 2, 3, 5), dist={1: 500, 2: 100, 3: 300, 5: 50})
        self.assertIn("2", e.cmd("questnear 2"))
        self.assertEqual(e.mock.trackedList(), "2,5")
        e.mock.dist[1] = 10
        self.settle(e)
        self.assertEqual(e.mock.trackedList(), "1,5")
        e.cmd("questnearest on")
        self.assertEqual(e.mock.listed(), "1,5")
        e.cmd("questnear 0")
        self.assertEqual(e.mock.trackedList(), "1,2,3,5")
        self.assertEqual(e.mock.listed().split(",")[0], "1")        # all of them again, still nearest first
        self.assertEqual(e.errors(), [])

    def test_together_with_the_zone(self):
        e = self.make(track=(3,), dist={1: 400, 2: 100})
        e.cmd("questzone on")
        self.assertEqual(e.mock.trackedList(), "1,2")
        e.cmd("questnear 1")
        self.assertEqual(e.mock.trackedList(), "2")
        e.mock.zone = "Stranglethorn Vale"
        e.mock.fire("ZONE_CHANGED_NEW_AREA")
        e.mock.advance(0.5)
        e.cmd("questnear 0")
        e.cmd("questsolo on")
        self.assertEqual(e.mock.trackedList(), "3,5,6")             # the zone's quests, without the group one
        e.cmd("questzone off")
        e.cmd("questsolo off")
        self.assertEqual(e.mock.trackedList(), "3")

    def test_a_quest_you_just_took_stays_listed(self):
        e = self.make(track=(1, 4))
        e.cmd("questsolo on")
        e.mock.log[9] = e.lua.table(title="New Errand", questID=7, level=30)
        e.g.C_QuestLog.AddQuestWatch(7)                              # the game tracks what you accept
        e.mock.fire("QUEST_ACCEPTED", 9, 7)
        e.mock.advance(0.5)
        self.assertEqual(e.mock.trackedList(), "1,7")
        e.cmd("questsolo off")
        self.assertEqual(e.mock.trackedList(), "1,4,7")

    def test_the_plan_is_said_in_chat(self):
        e = self.make(track=(), dist={1: 500, 2: 900, 3: 200, 4: 50, 5: 60, 6: 10})
        e.mock.done[2] = True
        e.mock.grey[6] = True
        out = plain(e.cmd("questplan")).split("\n")
        self.assertIn("Recommended next:", out[0])
        self.assertIn("1. Foul Magics [31], 900 yd, ready to hand in", out[1])
        self.assertIn("2. Tiger Mastery [30], 200 yd", out[2])
        self.assertIn("3. Raising Spirits", out[3])
        self.assertIn("4. Colonel Kurzen [40], 60 yd, above your level", out[4])
        self.assertIn("5. The Captain's Chest [32], 50 yd, wants a group", out[5])
        self.assertIn("6. Welcome to the Jungle [12], 10 yd, low level", out[6])
        self.assertEqual(e.mock.trackedList(), "")                   # saying it changes nothing
        empty = Env()
        self.assertIn("empty", empty.cmd("questplan"))

    def test_a_game_that_says_less_is_left_alone(self):
        e = self.make(game=False, track=())                          # no distances, no order of the list
        e.mock.tracked[1], e.mock.tracked[4] = True, True
        e.cmd("questnearest on")
        e.cmd("questorder on")
        self.settle(e)
        self.assertEqual(e.mock.trackedList(), "1,4")
        e.cmd("questsolo on")                                        # the log's own word on group size is enough
        self.assertEqual(e.mock.trackedList(), "1")
        e.cmd("questnear 3")
        self.settle(e)
        self.assertEqual(e.mock.trackedList(), "1")
        self.assertIn("1. ", e.cmd("questplan"))
        self.assertEqual(e.errors(), [])


class PadIcons(unittest.TestCase):
    """The icons on the buttons are the game's own style for the controller in use: found, or chosen."""

    GAME = """function(mock)
        local function copy(t)
            local out = {}
            for k, v in pairs(t) do out[k] = v end
            return out
        end
        local function key(id) return (id and id.vendorID) and (id.vendorID .. ":" .. tostring(id.productID)) or "all" end
        mock.pad = { configs = { all = { name = "All Devices" } }, pending = {}, applied = 0, refuse = false }
        function mock.controller(name, maker, product, style)
            mock.pad.device = name and { name = name, vendorID = maker, productID = product } or nil
            if name and style then
                mock.pad.configs[maker .. ":" .. product] =
                    { labelStyle = style, configID = { vendorID = maker, productID = product } }
            end
        end
        function mock.padStyle(k) return mock.pad.configs[k or "all"] and mock.pad.configs[k or "all"].labelStyle end
        C_GamePad.GetActiveDeviceID = function() return mock.pad.device and 1 or nil end
        C_GamePad.GetDeviceRawState = function() return mock.pad.device end
        C_GamePad.GetConfig = function(id)
            local c = mock.pad.configs[key(id)]
            return c and copy(c) or nil
        end
        C_GamePad.SetConfig = function(c)
            if not mock.pad.refuse then mock.pad.pending[key(c.configID)] = copy(c) end
        end
        C_GamePad.ApplyConfigs = function()
            for k, c in pairs(mock.pad.pending) do mock.pad.configs[k] = c end
            mock.pad.pending = {}
            mock.pad.applied = mock.pad.applied + 1
        end
    end"""

    def make(self, name="DualSense Wireless Controller", maker=0x054C, product=0x0CE6, style="Generic", **kw):
        def setup(e):
            e.lua.eval(self.GAME)(e.mock)
            if name:
                e.mock.controller(name, maker, product, style)
        return Env(setup=setup, **kw)

    def test_found_by_itself(self):
        e = self.make()
        self.assertEqual(e.db.padIcons, "auto")
        self.assertEqual(e.mock.padStyle("1356:3302"), "Shapes")     # a PlayStation pad: shapes
        self.assertEqual(e.db.padIconsWas["1356:3302"], "Generic")   # what the game had is remembered
        self.assertEqual(e.mock.pad.applied, 1)
        e.mock.fire("GAME_PAD_CONFIGS_CHANGED")
        e.mock.advance(1)
        e.update(1)
        self.assertEqual(e.mock.pad.applied, 1)                      # done once, not again and again
        for name, maker, want in (("Steam Controller", 10462, "Letters"), ("Xbox Series X Controller", 0x045E, "Letters"),
                                  ("Controller", 0x057E, "Reverse"), ("Pro Controller (Switch)", 0x0F0D, "Reverse"),
                                  ("Wireless Controller", 0x054C, "Shapes")):
            e = self.make(name=name, maker=maker, product=7)
            self.assertEqual(e.mock.padStyle("%d:7" % maker), want, name)
            self.assertEqual(e.errors(), [])

    def test_a_controller_that_does_not_say_what_it_is_keeps_the_games_numbers(self):
        e = self.make(name="USB Gamepad", maker=0x0079, product=6)
        self.assertEqual(e.mock.padStyle("121:6"), "Generic")
        self.assertEqual(e.mock.pad.applied, 0)
        self.assertIn("does not say what it is", e.cmd("padicons auto"))
        self.assertEqual(e.mock.padStyle("121:6"), "Generic")

    def test_a_style_somebody_set_by_hand_is_left_alone(self):
        e = self.make(style="Letters")                               # letters on a PlayStation pad, on purpose
        self.assertEqual(e.mock.padStyle("1356:3302"), "Letters")
        self.assertEqual(e.mock.pad.applied, 0)
        e.cmd("padicons playstation")                                # asked for by name: done
        self.assertEqual(e.mock.padStyle("1356:3302"), "Shapes")
        self.assertEqual(e.db.padIconsWas["1356:3302"], "Letters")

    def test_the_kind_you_choose(self):
        e = self.make(name="USB Gamepad", maker=0x0079, product=6)
        for word, style in (("xbox", "Letters"), ("playstation", "Shapes"), ("switch", "Reverse"), ("steam", "Letters"),
                            ("generic", "Generic"), ("ps", "Shapes"), ("Nintendo", "Reverse")):
            out = e.cmd("padicons " + word)
            self.assertIn("Button icons:", out)
            self.assertEqual(e.mock.padStyle("121:6"), style, word)
        self.assertEqual(e.db.padIcons, "switch")
        self.assertIn("usage", e.cmd("padicons round"))
        self.assertEqual(e.db.padIcons, "switch")
        self.assertIn("Switch", e.cmd("padicons"))                   # asked: says what is chosen
        self.assertIn("Reverse", e.cmd("padicons"))
        self.assertEqual(e.db.padIconsWas["121:6"], "Generic")       # still what the game had at the very start
        kept = self.make(name="USB Gamepad", maker=0x0079, product=6,
                         db="{ v = 10, asked = true, enabled = true, padIcons = 'xbox' }")
        self.assertEqual(kept.mock.padStyle("121:6"), "Letters")
        bad = self.make(db="{ v = 10, asked = true, enabled = true, padIcons = 'triangles', padIconsWas = 'x' }")
        self.assertEqual(bad.db.padIcons, "auto")
        self.assertEqual(e.errors(), [])

    def test_the_games_own_comes_back_when_asked_and_when_the_hud_is_off(self):
        e = self.make()
        self.assertEqual(e.mock.padStyle("1356:3302"), "Shapes")
        e.cmd("padicons game")
        self.assertEqual(e.mock.padStyle("1356:3302"), "Generic")
        self.assertIsNone(e.db.padIconsWas["1356:3302"])
        e.mock.fire("GAME_PAD_CONFIGS_CHANGED")
        e.mock.advance(1)
        self.assertEqual(e.mock.padStyle("1356:3302"), "Generic")    # and it is left alone from then on
        e.cmd("padicons auto")
        self.assertEqual(e.mock.padStyle("1356:3302"), "Shapes")
        e.cmd("off")                                                 # the HUD off: as the game had it
        self.assertEqual(e.mock.padStyle("1356:3302"), "Generic")
        e.cmd("on")
        self.assertEqual(e.mock.padStyle("1356:3302"), "Shapes")
        self.assertEqual(e.errors(), [])

    def test_a_controller_plugged_in_later_and_never_in_a_fight(self):
        e = self.make(name=None)
        self.assertEqual(e.mock.pad.applied, 0)
        self.assertIn("No controller", e.cmd("padicons auto"))
        e.mock.state.combat = True
        e.mock.controller("Xbox Wireless Controller", 0x045E, 2, "Generic")
        e.mock.fire("GAME_PAD_CONNECTED")
        e.mock.advance(1)
        self.assertEqual(e.mock.padStyle("1118:2"), "Generic")       # the fight first
        e.mock.state.combat = False
        e.mock.fire("PLAYER_REGEN_ENABLED")
        e.mock.advance(1)
        self.assertEqual(e.mock.padStyle("1118:2"), "Letters")

    def test_a_controller_without_settings_of_its_own_uses_the_shared_ones(self):
        e = self.make(style=None)
        self.assertEqual(e.mock.padStyle("all"), "Shapes")
        self.assertEqual(e.db.padIconsWas["all"], "Generic")
        e.cmd("padicons game")
        self.assertEqual(e.mock.padStyle("all"), "Generic")

    def test_a_game_that_will_not_take_it_is_asked_once(self):
        e = self.make(name="USB Gamepad", maker=0x0079, product=6)
        e.mock.pad.refuse = True
        self.assertIn("did not take", e.cmd("padicons xbox"))
        applied = e.mock.pad.applied
        e.mock.fire("GAME_PAD_CONFIGS_CHANGED")
        e.mock.advance(1)
        e.cmd("textscale 100")                                       # anything that applies the settings again
        self.assertEqual(e.mock.pad.applied, applied)
        self.assertEqual(e.mock.padStyle("121:6"), "Generic")
        self.assertEqual(e.errors(), [])

    def test_a_game_without_icon_styles(self):
        e = Env()
        self.assertIn("No controller", e.cmd("padicons xbox"))
        self.assertEqual(e.db.padIcons, "xbox")
        self.assertEqual(e.errors(), [])

    def test_the_options_page_has_a_button_for_each(self):
        e = self.make(name="USB Gamepad", maker=0x0079, product=6)
        e.ns.BuildOptions()
        self.assertEqual(sorted(e.ns.padIconButtons.keys()), ["auto", "generic", "playstation", "steam", "switch", "xbox"])
        b = e.ns.padIconButtons["playstation"]
        self.assertEqual(b.text, "PlayStation")
        b.scripts.OnClick(b)
        self.assertEqual(e.mock.padStyle("121:6"), "Shapes")


class ScreenRests(unittest.TestCase):
    """One fade for the whole HUD: bars, minimap, quest list, damage meter and experience bar together."""

    def test_everything_rests_together_out_of_combat(self):
        e = Env(setup=lambda env: env.lua.execute(
            'DamageMeterSessionWindow1 = CreateFrame("Frame", "DamageMeterSessionWindow1", UIParent)'))
        parts = [e.g.GamepadMainActionBarFrame, e.g.MinimapCluster, e.g.ObjectiveTrackerFrame,
                 e.g.StatusTrackingBarManager, e.g.DamageMeterSessionWindow1]     # (the meter: found by its name)
        e.update(1)
        self.assertEqual(parts[0].alpha, 1)                         # it stays a moment after you log in
        e.update(6)
        for f in parts:
            self.assertAlmostEqual(f.alpha, 0.3)                    # on by default
        e.mock.state.combat = True
        e.update(0.3)
        for f in parts:
            self.assertEqual(f.alpha, 1)
        e.mock.state.combat = False
        e.update(2)
        self.assertEqual(parts[1].alpha, 1)                         # and lingers after the fight
        e.update(5)
        self.assertAlmostEqual(parts[1].alpha, 0.3)
        e.mock.keysDown.PADLTRIGGER = True                          # a pull of the trigger: a look at it all
        e.update(0.3)
        for f in parts:
            self.assertEqual(f.alpha, 1)
        e.mock.keysDown.PADLTRIGGER = False
        e.update(2)
        self.assertEqual(parts[2].alpha, 1)                         # for a few seconds after letting go
        e.update(5)
        self.assertAlmostEqual(parts[2].alpha, 0.3)
        e.target()                                                  # an enemy targeted
        e.update(1)
        self.assertEqual(parts[0].alpha, 1)
        self.assertEqual(e.ns.RunCheck(False)[0], 0)
        self.assertEqual(e.errors(), [])

    def test_the_games_own_alpha_changes_are_overruled_and_off_gives_it_back(self):
        e = Env()
        bars, cluster = e.g.GamepadMainActionBarFrame, e.g.MinimapCluster
        e.update(6)
        bars.SetAlpha(bars, 1)                                      # the game shows them again
        e.update(0.1)
        self.assertAlmostEqual(bars.alpha, 0.3)
        e.cmd("hudfade off")
        self.assertEqual(bars.alpha, 1)
        self.assertEqual(cluster.alpha, 1)
        e.cmd("hudfade on")
        e.cmd("hudidle 50")
        e.update(6)
        self.assertAlmostEqual(bars.alpha, 0.5)
        self.assertAlmostEqual(cluster.alpha, 0.5)

    def test_a_part_can_be_left_out(self):
        e = Env()
        e.cmd("restminimap off")
        e.update(6)
        self.assertEqual(e.g.MinimapCluster.alpha, 1)
        self.assertAlmostEqual(e.g.GamepadMainActionBarFrame.alpha, 0.3)
        e.cmd("restminimap on")
        e.update(6)
        self.assertAlmostEqual(e.g.MinimapCluster.alpha, 0.3)

    def test_what_you_chose_for_the_bars_carries_over(self):
        e = Env(db="{ v = 8, barsFade = false, barsIdle = 0.5 }")
        self.assertFalse(e.db.hudFade)
        self.assertEqual(e.db.hudIdle, 0.5)
        e.update(6)
        self.assertEqual(e.g.GamepadMainActionBarFrame.alpha, 1)

    def test_edit_mode_shows_everything(self):
        e = Env()
        e.update(6)
        e.mock.editMode(True)
        e.update(0.5)
        self.assertEqual(e.g.MinimapCluster.alpha, 1)


class DebugReports(unittest.TestCase):
    """While it is being finished, the HUD gathers its troubleshooting reports by itself."""

    def test_gathered_at_login_and_again_when_you_reload(self):
        e = Env(db="{ v = 10, debug = true }")
        self.assertTrue(e.db.debug)
        self.assertIsNone(e.db.debugReport)
        e.update(7)
        login = e.db.debugReport.login
        self.assertEqual(login.why, "login")
        for section in ("screen", "bindings", "pad", "rest", "fishing", "auction", "cast", "plates", "errors"):
            self.assertIsNotNone(login[section], section)
        self.assertIn("LeftClassAction", "\n".join(login.pad.values()))
        self.assertIn("GAMEPADLEFTMOD = PADLTRIGGER", list(login.bindings.values()))
        self.assertEqual(e.db.probe.v, e.ns.PROBE_VERSION)           # the probe too, once per game build
        self.assertIsNotNone(e.db.check)                              # and the self-check, quietly
        said = len(e.mock.printed)
        e.target()
        e.update(1)
        e.mock.fire("PLAYER_LOGOUT")                                 # the game writes the settings right after
        self.assertEqual(len(e.mock.printed), said)                  # nothing is said in chat
        report = e.db.debugReport
        self.assertEqual(report.logout.why, "logout")
        self.assertIsNotNone(report.login)                           # both are kept, side by side
        notes = "\n".join(report.notes.values())
        self.assertIn("rest: up for enemy", notes)                   # what the modules did on the way
        self.assertEqual(e.errors(), [])

    def test_a_wheel_cut_off_by_the_screen_is_noted(self):
        e = Env(setup=lambda env: env.lua.execute("""
            GamepadSpellFlyout = CreateFrame("Frame", "GamepadSpellFlyout", UIParent)
            GamepadSpellFlyout:Hide()
            GamepadSpellFlyout.GetRect = function() return 400, -60, 200, 200 end
            GamepadSpellFlyout.GetEffectiveScale = function() return 1 end
            UIParent.GetEffectiveScale = function() return 1 end
            UIParent.GetSize = function() return 1365, 768 end"""), db="{ v = 10, debug = true }")
        e.g.GamepadSpellFlyout.Show(e.g.GamepadSpellFlyout)
        e.update(0.5)
        e.mock.fire("PLAYER_LOGOUT")
        rows = list(e.db.debugReport.logout.flyouts.values())
        self.assertEqual(len(rows), 1)
        self.assertIn("bottom -60", rows[0])
        self.assertIn("CUT OFF", rows[0])

    def test_off_gathers_nothing(self):
        e = Env(db="{ v = 8, debug = false }")
        e.update(7)
        e.mock.fire("PLAYER_LOGOUT")
        self.assertIsNone(e.db.debugReport)
        self.assertIsNone(e.db.probe)
        self.assertEqual(len(list(e.ns.notes.values())), 0)
        e.cmd("debug on")
        self.assertEqual(e.db.debugReport.asked.why, "switched on")

    def test_a_published_build_has_it_off(self):
        fresh = Env()
        self.assertFalse(fresh.ns.Debug.DEFAULT, "Debug.DEFAULT stays off in what is published")
        self.assertFalse(fresh.db.debug)                            # a new install gathers nothing
        fresh.update(7)
        self.assertIsNone(fresh.db.debugReport)
        self.assertIsNone(fresh.db.probe)
        kept = Env(db="{ v = 10, debug = true }")                   # whoever switched it on keeps it on
        self.assertTrue(kept.db.debug)


class StanceAndPetButtons(unittest.TestCase):
    """The two round buttons under the clusters move up to where the targeting icons are."""

    SETUP = """
        local page = GamepadMainActionBarFramePageUnit
        page.cx, page.cy = 500, 100
        page.LeftClassAction.cx, page.LeftClassAction.cy = 362, 8                 -- by the bottom of the screen
        page.LeftClassAction:SetPoint("CENTER", page, "CENTER", -138, -92)
        page.LeftShoulderIcon = CreateFrame("Frame", nil, page)                           -- the green targeting icon
        page.LeftShoulderIcon.cx, page.LeftShoulderIcon.cy = 420, 150
        page.LeftInputPrompt = CreateFrame("Frame", nil, page)                    -- "LB + LT"
        page.LeftInputPrompt.cx, page.LeftInputPrompt.cy = 362, -14
        page.LeftInputPrompt:SetPoint("CENTER", page, "CENTER", -138, -114)
        page.RightClassAction = CreateFrame("CheckButton", "GamepadMainActionBarFramePageUnitRightClassAction", page)
        page.RightClassAction.NormalTexture = page.RightClassAction:CreateTexture()
        page.RightClassAction.cx, page.RightClassAction.cy = 638, 8               -- no icon above this one
        page.RightClassAction:SetPoint("CENTER", page, "CENTER", 138, -92)
    """

    def env(self, **kw):
        return Env(setup=lambda env: env.lua.execute(self.SETUP), **kw)

    def test_they_take_the_place_of_the_targeting_icons(self):
        e = self.env()
        page = e.g.GamepadMainActionBarFramePageUnit
        left, right = page.LeftClassAction, page.RightClassAction
        p = left.points[1]
        self.assertEqual(p[1], "CENTER")
        self.assertTrue(e.same(p[2], page))
        self.assertEqual((p[4], p[5]), (-80, 50))                   # where the green icon is
        self.assertEqual(page.LeftShoulderIcon.alpha, 0)                    # which is gone
        hint = page.LeftInputPrompt.points[1]
        self.assertTrue(e.same(hint[2], left))                      # its hint came along, as far below as it was
        self.assertEqual((hint[4], hint[5]), (0, -22))
        p = right.points[1]
        self.assertEqual((p[4], p[5]), (138, -92 + e.ns.PadButtons.RAISE))   # no icon: straight up
        self.assertEqual(e.ns.RunCheck(False)[0], 0)
        self.assertEqual(e.errors(), [])

    def test_the_wheel_opens_around_the_button_where_it_sits_now(self):
        e = self.env()
        e.lua.execute("""
            GamepadSpellFlyout = CreateFrame("Frame", "GamepadSpellFlyout", UIParent)
            GamepadSpellFlyout:Hide()""")
        page = e.g.GamepadMainActionBarFramePageUnit
        left, wheel = page.LeftClassAction, e.g.GamepadSpellFlyout
        e.update(0.2)
        self.assertEqual(left.points[1][5], 50)
        left.ClearAllPoints(left)                                   # a wheel opens: the game lays the bars out afresh
        left.SetPoint(left, "CENTER", page, "CENTER", -138, -92)
        wheel.cx, wheel.cy = 362, 8                                 # and the wheel opens around that spot,
        wheel.SetPoint(wheel, "CENTER", page, "CENTER", -138, -92)
        wheel.Show(wheel)
        e.update(0.1)
        self.assertEqual(left.points[1][5], 50)                     # the button is up again at once,
        self.assertTrue(e.same(wheel.points[1][2], left))           # and the wheel is around it where it is now
        self.assertEqual(wheel.points[1][1], "CENTER")
        self.assertEqual(e.ns.PadButtons.wheels, 1)
        e.update(0.5)                                               # (once it is there, it is left alone)
        self.assertEqual(e.ns.PadButtons.wheels, 1)
        self.assertEqual(e.errors(), [])

    def test_the_games_own_layout_is_answered_out_of_combat_only(self):
        e = self.env()
        page = e.g.GamepadMainActionBarFramePageUnit
        left = page.LeftClassAction
        e.mock.state.combat = True
        left.ClearAllPoints(left)                                   # the game laid its bars out again
        left.SetPoint(left, "CENTER", page, "CENTER", -138, -92)
        e.update(2)
        self.assertEqual(left.points[1][5], -92)                    # not in a fight
        e.mock.state.combat = False
        e.update(2)
        self.assertEqual((left.points[1][4], left.points[1][5]), (-80, 50))

    def test_off_and_edit_mode_put_everything_back(self):
        e = self.env()
        page = e.g.GamepadMainActionBarFramePageUnit
        left = page.LeftClassAction
        e.cmd("padraise off")
        self.assertEqual((left.points[1][4], left.points[1][5]), (-138, -92))
        self.assertEqual(page.LeftShoulderIcon.alpha, 1)
        self.assertTrue(e.same(page.LeftInputPrompt.points[1][2], page))
        e.cmd("padraise on")
        self.assertEqual(left.points[1][5], 50)
        e.mock.editMode(True)
        self.assertEqual(left.points[1][5], -92)
        e.mock.editMode(False)
        self.assertEqual(left.points[1][5], 50)
        self.assertIn("LeftClassAction", e.cmd("padinfo"))
        self.assertEqual(e.errors(), [])


class FishingMode(unittest.TestCase):
    """With a pole in your hands, the interact button casts the line and hooks the fish."""

    def env(self, pole=True, interact=None, db=None):
        e = Env(db=db)
        e.mock["items"][6256] = e.lua.table(name="Fishing Pole", **{"class": 2, "sub": 20})
        e.mock["items"][25] = e.lua.table(name="Worn Shortsword", **{"class": 2, "sub": 7})
        e.mock.state.mainHand = 6256 if pole else 25
        e.mock.spellNames = e.lua.table_from({7620: "Fishing"})
        if interact:
            e.mock.bindings.INTERACTTARGET = e.lua.table(interact)
        e.mock.fire("PLAYER_EQUIPMENT_CHANGED", 16)
        return e

    def line(self, e, out):
        now = e.mock.time
        e.mock.units.player.cast = out and e.lua.table(name="Fishing", start=now * 1000, stop=(now + 20) * 1000,
                                                       channel=True, spellId=7620) or None
        e.mock.fire("UNIT_SPELLCAST_CHANNEL_START" if out else "UNIT_SPELLCAST_CHANNEL_STOP", "player")

    def test_with_a_pole_in_hand_the_interact_button_casts_and_then_hooks(self):
        e = self.env()
        F = e.ns.Fishing
        self.assertEqual(e.mock.overrides.PAD3, "SPELL Fishing")   # Square / X: the Gamepad UI's interact button
        self.assertTrue(F.hint.shown)
        self.assertIn("casts your line", list(e.mock.printed.values())[-1])    # said once
        said = len(e.mock.printed)
        self.line(e, True)
        self.assertIsNone(e.mock.overrides.PAD3)                    # the float is out: the game's own interact
        self.assertFalse(F.hint.shown)
        self.line(e, False)
        self.assertEqual(e.mock.overrides.PAD3, "SPELL Fishing")   # and it casts again
        self.assertEqual(len(e.mock.printed), said)
        self.assertEqual(e.errors(), [])

    def test_the_button_stays_interact_when_there_is_something_to_interact_with(self):
        e = self.env()
        e.mock.units.softinteract = e.lua.table(name="Mailbox")
        e.mock.fire("PLAYER_SOFT_INTERACT_CHANGED")
        self.assertIsNone(e.mock.overrides.PAD3)
        e.mock.units.softinteract = None                            # walked past it (the game does not always say)
        e.update(0.5)
        self.assertEqual(e.mock.overrides.PAD3, "SPELL Fishing")

    def test_not_without_a_pole_not_in_a_fight_and_not_when_paused(self):
        e = self.env(pole=False)
        self.assertIsNone(e.mock.overrides.PAD3)
        e.cmd("fish")
        self.assertIn("fishing pole", e.cmd("fish"))
        e = self.env()
        e.mock.state.combat = True
        e.mock.fire("PLAYER_REGEN_DISABLED")
        self.assertIsNone(e.mock.overrides.PAD3)                    # the button is yours in a fight
        e.update(1)
        self.assertIsNone(e.mock.overrides.PAD3)
        e.mock.state.combat = False
        e.mock.fire("PLAYER_REGEN_ENABLED")
        self.assertEqual(e.mock.overrides.PAD3, "SPELL Fishing")
        self.assertIn("off", e.cmd("fish"))                         # paused: yours with a pole in hand too
        self.assertIsNone(e.mock.overrides.PAD3)
        e.update(1)
        self.assertIsNone(e.mock.overrides.PAD3)
        e.cmd("fish")
        self.assertEqual(e.mock.overrides.PAD3, "SPELL Fishing")
        e.mock.state.mainHand = 25                                  # the pole put away
        e.mock.fire("PLAYER_EQUIPMENT_CHANGED", 16)
        self.assertIsNone(e.mock.overrides.PAD3)
        e.mock.state.mainHand = 6256
        e.mock.fire("PLAYER_EQUIPMENT_CHANGED", 16)
        self.assertEqual(e.mock.overrides.PAD3, "SPELL Fishing")
        e.cmd("fishmode off")
        self.assertIsNone(e.mock.overrides.PAD3)
        self.assertEqual(e.errors(), [])

    def test_your_own_interact_key_or_a_button_you_name(self):
        e = self.env(interact="PAD2")                               # interact is a key binding here: that key
        self.assertEqual(e.mock.overrides.PAD2, "SPELL Fishing")
        self.assertIsNone(e.mock.overrides.PAD3)
        e = self.env()
        e.cmd("fishkey pad1")
        self.assertEqual(e.mock.overrides.PAD1, "SPELL Fishing")
        self.assertIsNone(e.mock.overrides.PAD3)
        self.assertEqual(e.db.fishKey, "PAD1")
        self.assertIn("usage", e.cmd("fishkey nonsense"))
        self.assertEqual(e.db.fishKey, "PAD1")
        kept = self.env(db="{ v = 8, fishKey = 'PAD4' }")
        self.assertEqual(kept.mock.overrides.PAD4, "SPELL Fishing")
        bad = self.env(db="{ v = 8, fishKey = 'SPACE; evil' }")     # only a pad button is taken from the saved file
        self.assertIsNone(bad.db.fishKey)
        self.assertEqual(bad.mock.overrides.PAD3, "SPELL Fishing")

    def test_a_trigger_can_be_the_fishing_button(self):
        e = self.env()
        self.assertIn("usage", e.cmd("fishkey"))
        e.cmd("fishkey rt")                                          # by the name on it
        self.assertEqual(e.db.fishKey, "PADRTRIGGER")
        self.assertEqual(e.mock.overrides.PADRTRIGGER, "SPELL Fishing")
        self.assertIsNone(e.mock.overrides.PAD3)                    # the interact button is the game's again
        e.mock.units.softinteract = e.lua.table(name="Mailbox")     # it was never your way of interacting:
        e.update(0.5)
        self.assertEqual(e.mock.overrides.PADRTRIGGER, "SPELL Fishing")    # it casts all the same
        e.mock.units.softinteract = None
        self.line(e, True)                                           # the float is out: the trigger hooks,
        self.assertEqual(e.mock.overrides.PADRTRIGGER, "INTERACTTARGET")   # by the game's own Interact
        self.line(e, False)
        self.assertEqual(e.mock.overrides.PADRTRIGGER, "SPELL Fishing")
        e.mock.state.combat = True
        e.mock.fire("PLAYER_REGEN_DISABLED")
        self.assertIsNone(e.mock.overrides.PADRTRIGGER)             # in a fight the trigger is the game's
        e.mock.state.combat = False
        e.mock.fire("PLAYER_REGEN_ENABLED")
        e.cmd("fishkey square")                                      # back to the interact button
        self.assertEqual(e.mock.overrides.PAD3, "SPELL Fishing")
        self.assertIsNone(e.mock.overrides.PADRTRIGGER)
        self.line(e, True)
        self.assertIsNone(e.mock.overrides.PAD3)                    # whose hook is the game's own
        self.assertEqual(e.errors(), [])

    def test_the_catch_is_taken_and_your_auto_loot_is_left_alone(self):
        e = self.env(pole=False)
        e.lua.execute("TAKEN = {}; function GetNumLootItems() return 2 end; function LootSlot(i) TAKEN[#TAKEN + 1] = i end")
        e.mock.fire("LOOT_OPENED")
        self.assertEqual(len(list(e.g.TAKEN.values())), 0)         # no pole: nothing of ours
        e.mock.state.mainHand = 6256
        e.mock.fire("PLAYER_EQUIPMENT_CHANGED", 16)
        e.mock.fire("LOOT_OPENED")
        self.assertEqual(list(e.g.TAKEN.values()), [2, 1])
        self.assertIsNone(e.mock.cvars.autoLootDefault)


class FishJournal(unittest.TestCase):
    """Catches are written down, with weights made up for fun; the fishing interface and the journal show them."""

    def env(self, pole=True, db=None, setup=None, zone="Durotar", area=1411):
        e = Env(db=db, setup=setup)
        e.mock["items"][6256] = e.lua.table(name="Fishing Pole", **{"class": 2, "sub": 20})
        e.mock["items"][6291] = e.lua.table(name="Raw Brilliant Smallfish", **{"class": 7})
        e.mock["items"][6303] = e.lua.table(name="Raw Slitherskin Mackerel", **{"class": 7})
        e.mock["items"][6309] = e.lua.table(name="17 Pound Catfish", **{"class": 7})
        e.mock["items"][6297] = e.lua.table(name="Old Skull", **{"class": 15})
        e.mock["items"][6529] = e.lua.table(name="Shiny Bauble", **{"class": 0})
        e.mock.state.mainHand = 6256 if pole else 25
        e.mock.spellNames = e.lua.table_from({7620: "Fishing"})
        e.mock.zone = zone
        e.g.C_Map.GetBestMapForUnit = lambda unit: area
        e.mock.fire("PLAYER_EQUIPMENT_CHANGED", 16)
        return e

    def line(self, e, out, seconds=20):
        now = e.mock.time
        e.mock.units.player.cast = out and e.lua.table(name="Fishing", start=now * 1000, stop=(now + seconds) * 1000,
                                                       channel=True, spellId=7620) or None
        e.mock.fire("UNIT_SPELLCAST_CHANNEL_START" if out else "UNIT_SPELLCAST_CHANNEL_STOP", "player")

    def land(self, e, *ids):
        self.line(e, True)
        e.update(3)
        e.mock.land(e.lua.table_from([e.lua.table(id=i, name=e.mock["items"][i].name, quality=1) for i in ids]))
        self.line(e, False)

    def test_a_catch_is_written_down_with_a_weight(self):
        e = self.env()
        J = e.ns.FishLog
        J.random = lambda: 0.5
        self.land(e, 6291)
        fish = e.db.fishLog.fish[6291]
        self.assertEqual((fish.n, fish.name, fish.firstAt, fish.fish), (1, "Raw Brilliant Smallfish", "Durotar", True))
        self.assertGreater(fish.best, 0)
        self.assertEqual(fish.bestAt, "Durotar")
        self.assertEqual((e.db.fishLog.total, J.session.caught), (1, 1))
        self.assertEqual(e.db.fishLog.zones["Durotar"].fish[6291], 1)
        self.assertEqual(e.db.fishLog.zones["Durotar"].map, 1411)
        said = list(e.mock.printed.values())[-1]
        self.assertIn("New in your fish journal: Raw Brilliant Smallfish", said)
        self.assertIn("lb", said)
        first = fish.best
        J.random = lambda: 1.0                                       # a big one
        self.land(e, 6291)
        self.assertGreater(fish.best, first)
        self.assertEqual(fish.n, 2)
        said = list(e.mock.printed.values())[-1]
        self.assertIn("heaviest Raw Brilliant Smallfish", said)
        count = len(e.mock.printed)
        J.random = lambda: 0.0                                       # a small one: nothing to say
        self.land(e, 6291)
        self.assertEqual(len(e.mock.printed), count)
        self.assertEqual(fish.best, e.db.fishLog.fish[6291].best)
        self.assertEqual(e.errors(), [])

    def test_weights_are_for_fish_and_a_fish_can_name_its_own(self):
        e = self.env()
        J = e.ns.FishLog
        self.land(e, 6309, 6297)                                     # two things on one line
        self.assertEqual(e.db.fishLog.fish[6309].best, 17)           # "17 Pound Catfish" weighs that
        self.assertFalse(e.db.fishLog.fish[6297].fish)               # an old skull is not a fish
        self.assertIsNone(e.db.fishLog.fish[6297].best)
        self.assertEqual(e.db.fishLog.total, 2)
        self.assertEqual(J.feed[1].id, 6297)                         # the latest first
        self.assertIsNone(J.feed[1].weight)
        for r in (0.0, 0.3, 0.9, 1.0):                               # a kind stays near its own usual weight
            J.random = (lambda v: lambda: v)(r)
            w = J.Weigh(6291, "Raw Brilliant Smallfish")
            base = J.Base(6291, "Raw Brilliant Smallfish")
            self.assertTrue(0.5 * base <= w <= 1.85 * base, (w, base))
        self.assertNotEqual(J.Base(6291, "a"), J.Base(6303, "b"))

    def test_only_what_was_fished_is_written_down(self):
        e = self.env()
        e.mock.loot = e.lua.table_from([e.lua.table(id=6291, name="Raw Brilliant Smallfish")])
        e.mock.fire("LOOT_READY")                                    # a corpse, not a catch
        e.mock.fire("LOOT_OPENED")
        e.mock.fire("LOOT_CLOSED")
        self.assertEqual(e.db.fishLog.total, 0)
        e.cmd("fishjournal off")
        self.land(e, 6291)
        self.assertEqual(e.db.fishLog.total, 0)
        e.cmd("fishjournal on")
        self.land(e, 6291)
        self.assertEqual(e.db.fishLog.total, 1)
        e.g.IsFishingLoot = None                                     # a game without that word: by the line just out
        e.mock.loot = e.lua.table_from([e.lua.table(id=6303, name="Raw Slitherskin Mackerel")])
        self.line(e, True)
        e.mock.fire("LOOT_READY")
        self.line(e, False)
        e.mock.fire("LOOT_CLOSED")
        self.assertEqual(e.db.fishLog.total, 2)
        e.update(10)
        e.mock.fire("LOOT_READY")                                    # long after: not a catch
        self.assertEqual(e.db.fishLog.total, 2)
        self.assertEqual(e.errors(), [])

    def test_the_ones_that_got_away_are_counted(self):
        e = self.env()
        J = e.ns.FishLog
        self.line(e, True)
        e.update(20)                                                 # the line ran its whole time, nothing landed
        self.line(e, False)
        self.assertEqual(J.session.away, 0)                          # (a catch may still arrive in this moment)
        e.update(1.2)
        self.assertEqual((J.session.away, e.db.fishLog.away), (1, 1))
        self.line(e, True)
        e.update(4)
        self.line(e, False)                                          # cast again early: nothing got away
        e.update(1.5)
        self.assertEqual(J.session.away, 1)
        self.line(e, True)
        e.update(19.8)
        e.mock.land(e.lua.table_from([e.lua.table(id=6291, name="Raw Brilliant Smallfish")]))
        self.line(e, False)                                          # hooked at the last moment: landed
        e.update(1.5)
        self.assertEqual((J.session.away, J.session.caught), (1, 1))
        self.line(e, True)
        e.update(6)
        e.mock.fire("UI_ERROR_MESSAGE", 50, "Your fish got away!")   # the game says so itself
        e.mock.fire("UI_ERROR_MESSAGE", 50, "Your fish got away!")
        self.line(e, False)
        e.update(1.5)
        self.assertEqual(J.session.away, 2)
        e.mock.fire("UI_ERROR_MESSAGE", 50, "Not enough rage")
        self.assertEqual(J.session.away, 2)
        self.assertEqual(e.errors(), [])

    def test_this_waters_fish_are_found_by_landing_them(self):
        e = self.env()
        J = e.ns.FishLog
        waters = list(J.Waters().values())
        self.assertEqual(len(waters), 4)                             # room for what has not been found
        self.assertFalse(any(w.known for w in waters))
        self.land(e, 6291, 6297)
        waters = list(J.Waters().values())
        self.assertEqual([bool(w.known) for w in waters], [True, False, False, False])   # the skull is not listed
        self.assertEqual(waters[0].id, 6291)
        e.mock.zone = "The Barrens"                                  # another water: nothing found there yet
        self.assertFalse(any(w.known for w in J.Waters().values()))

    def test_with_the_fishing_data_the_whole_water_is_listed_and_hidden_until_landed(self):
        e = self.env(setup=lambda env: env.lua.execute("""
            ImprovedForever = { FishingData = {
                items = { [6303] = "Raw Slitherskin Mackerel|1|fish", [6291] = "Raw Brilliant Smallfish|1|fish",
                          [6309] = "17 Pound Catfish|1|fish", [6307] = "Message in a Bottle|1|treasure" },
                zones = { [14] = "Durotar|6303:60:0,6291:38:0,6309:2:0,6307:0.5:0" }, areas = {} } }"""))
        J = e.ns.FishLog
        waters = list(J.Waters().values())
        self.assertEqual([w.id for w in waters], [6303, 6291, 6309])
        self.assertFalse(any(w.known for w in waters))
        self.land(e, 6291)
        self.assertEqual([bool(w.known) for w in J.Waters().values()], [False, True, False])

    def test_the_fishing_interface_shows_the_water_the_skill_and_the_catches(self):
        e = self.env()
        P, J = e.ns.FishPanel, e.ns.FishLog
        e.mock.skills = e.lua.table_from([e.lua.table(name="Cooking", rank=10, cap=75),
                                          e.lua.table(name="Fishing", rank=150, bonus=50, cap=225)])
        e.update(0.6)
        f = P.frame
        self.assertTrue(f.shown)
        self.assertEqual(f.points[1][1], "TOP")
        self.assertLess(f.points[1][5], 0)                           # under the middle of the screen
        self.assertEqual(sum(1 for s in P.slots.values() if s.back.shown), 4)
        self.assertTrue(all(s.q.shown for s in list(P.slots.values())[:4]))
        self.assertIn("Fishing 150", f.skill.text)
        self.assertIn("(+50)", f.skill.text)
        self.assertIn("/ 225", f.skill.text)
        self.assertAlmostEqual(f.fill.width, 180 * 150 / 225)
        self.assertEqual(f.scale, 1)                                 # low and wide: it has to fit above the bars
        self.assertLessEqual(f.height, 100)
        self.assertIn("Caught 0", f.stats.text)
        self.assertIn("Got away 0", f.stats.text)
        self.assertEqual(f.bait.text, "No bait")
        self.assertEqual(f.alpha, 0.6)                               # fainter between casts
        J.random = lambda: 1.0
        self.land(e, 6291)
        e.update(0.3)
        self.assertEqual(f.alpha, 1)
        self.assertIn("Caught 1", f.stats.text)
        slot = P.slots[1]
        self.assertTrue(slot.icon.shown)
        self.assertFalse(slot.q.shown)
        self.assertEqual(slot.icon.texture, 1000 + 6291)
        row = P.rows[1]
        self.assertIn("Raw Brilliant Smallfish", row.text.text)
        self.assertIn("lb", row.text.text)
        self.assertIn("new!", row.text.text)
        self.assertGreater(row.text.alpha, 0.9)
        self.land(e, 6291)                                           # no heavier than the last: just listed
        self.assertNotIn("new!", P.rows[1].text.text)
        self.assertIn("new!", P.rows[2].text.text)
        e.mock.enchant = 452                                         # bait on the pole
        e.update(0.3)
        self.assertEqual(f.bait.text, "Bait 7:32")
        e.mock.skills[2].bonus = 0
        e.mock.enchant = None
        e.update(2.5)
        self.assertNotIn("(+", f.skill.text)
        e.update(100)                                                # old catches leave the feed
        self.assertEqual(P.rows[1].text.alpha, 0)
        self.assertEqual(f.alpha, 0.6)
        e.mock.state.combat = True                                   # not in a fight
        e.update(0.3)
        self.assertFalse(f.shown)
        e.mock.state.combat = False
        e.update(0.3)
        self.assertTrue(f.shown)
        e.mock.state.mainHand = 25                                   # the pole put away
        e.update(0.3)
        self.assertFalse(f.shown)
        e.mock.state.mainHand = 6256
        e.cmd("fishpanel off")
        e.update(0.6)
        self.assertFalse(f.shown)
        self.assertEqual(e.errors(), [])

    def test_no_skill_known_no_skill_bar(self):
        e = self.env()
        e.update(0.6)
        f = e.ns.FishPanel.frame
        self.assertEqual(f.skill.text, "")
        self.assertFalse(f.track.shown)
        self.assertFalse(f.fill.shown)

    def test_a_double_press_puts_bait_on(self):
        e = self.env()
        F = e.ns.Fishing
        self.assertEqual(e.mock.overrides.PAD3, "SPELL Fishing")
        self.line(e, True)
        self.assertIsNone(e.mock.overrides.PAD3)                    # no bait in the bags: the game's own interact
        self.line(e, False)
        e.mock.put(0, 1, e.lua.table(id=6529, name="Shiny Bauble", count=3, **{"class": 0}))
        self.assertEqual(list(F.Bait()), [6529, "Shiny Bauble", 25])
        e.update(0.6)
        self.assertIn("press", e.ns.FishPanel.frame.bait.text)       # the interface says how
        self.assertIn("Shiny Bauble", e.ns.FishPanel.frame.bait.text)
        self.line(e, True)                                           # your cast began: a second press is for the bait
        self.assertEqual(e.mock.overrides.PAD3, "CLICK ControllerCamHUD_FishingBait:LeftButton")
        b = e.g.ControllerCamHUD_FishingBait
        self.assertEqual(b.template, "SecureActionButtonTemplate")
        self.assertEqual((b.attrs.type, b.attrs.item, b.attrs["target-slot"]), ("item", "item:6529", 16))
        e.update(0.7)                                                # no second press: the hook is the game's again
        self.assertIsNone(e.mock.overrides.PAD3)
        self.line(e, False)
        self.assertEqual(e.mock.overrides.PAD3, "SPELL Fishing")
        e.mock.enchant = 600                                         # bait on the pole already: nothing to add
        self.line(e, True)
        self.assertIsNone(e.mock.overrides.PAD3)
        self.line(e, False)
        e.mock.enchant = None
        e.cmd("fishbait off")
        self.line(e, True)
        self.assertIsNone(e.mock.overrides.PAD3)
        self.line(e, False)
        e.cmd("fishbait on")
        e.cmd("fishkey rt")                                          # a trigger: bait for a moment, then the hook
        self.line(e, True)
        self.assertEqual(e.mock.overrides.PADRTRIGGER, "CLICK ControllerCamHUD_FishingBait:LeftButton")
        e.update(0.7)
        self.assertEqual(e.mock.overrides.PADRTRIGGER, "INTERACTTARGET")
        self.line(e, False)
        e.mock.put(0, 2, e.lua.table(id=6533, name="Aquadynamic Fish Attractor", **{"class": 0}))
        self.assertEqual(F.Bait(), (6533, "Aquadynamic Fish Attractor", 100))    # the best in the bags
        e.g.IsUsableItem = lambda item: item != 6533                 # not at your skill yet: the next best
        self.assertEqual(F.Bait(), (6529, "Shiny Bauble", 25))
        self.line(e, True)
        e.mock.state.combat = True                                   # a fight in that moment: everything let go
        e.mock.fire("PLAYER_REGEN_DISABLED")
        self.assertIsNone(e.mock.overrides.PADRTRIGGER)
        self.assertEqual(e.errors(), [])

    def test_the_journal_window(self):
        e = self.env()
        W, J = e.ns.FishJournal, e.ns.FishLog
        e.lua.execute("UISpecialFrames = {}")
        e.cmd("journal")
        f = W.frame
        self.assertTrue(f.shown)
        self.assertTrue(f.empty.shown)                               # nothing landed yet
        J.random = lambda: 0.5
        self.land(e, 6291, 6303, 6297)
        self.assertFalse(f.empty.shown)                              # it follows along while open
        rows = [r for r in W.rows.values() if r.shown]
        self.assertEqual([r.name.text for r in rows],
                         ["Raw Brilliant Smallfish", "Raw Slitherskin Mackerel", "Old Skull"])   # fish first, by name
        self.assertTrue(rows[0].hl.shown)
        self.assertIn("lb", rows[0].sub.text)
        self.assertNotIn("lb", rows[2].sub.text)
        self.assertIn("3 landed, 3 kinds, 0 got away", f.summary.text)
        self.assertIn("Heaviest:", f.summary.text)
        self.assertEqual(f.name.text, "Raw Brilliant Smallfish")
        self.assertIn("Landed: 1", f.facts.text)
        self.assertIn("at Durotar", f.facts.text)
        self.assertIn("First landed: Durotar", f.facts.text)
        self.assertIn("first fish most anglers", f.lore.text)        # a few lines about the fish
        self.assertTrue(W.Pad(W, "PADDDOWN"))
        self.assertEqual(f.name.text, "Raw Slitherskin Mackerel")
        W.Pad(W, "PADDDOWN")
        W.Pad(W, "PADDDOWN")                                         # the end of the list is the end
        self.assertEqual(f.name.text, "Old Skull")
        self.assertEqual(f.lore.text, "")
        self.assertTrue(W.Pad(W, "PADRSHOULDER"))                    # the other page: waters
        self.assertEqual(W.page, "waters")
        self.assertEqual(f.name.text, "Durotar")
        self.assertIn("Landed here: 3", f.facts.text)
        self.assertIn("Kinds found here: 3", f.facts.text)
        self.assertIn("Raw Brilliant Smallfish", f.facts.text)
        self.assertIn("Echo Isles", f.lore.text)
        self.assertFalse(W.Pad(W, "PAD1"))                           # a button it has no use for
        self.assertIsNone(e.mock.overrides.PAD1)                     # is never taken from the game
        self.assertIsNone(e.mock.overrides.PADLSTICK)
        self.assertIsNone(f.scripts.OnGamePadButtonDown)             # and no press is caught and passed on
        self.assertEqual(e.mock.overrides.PADDUP, "CLICK ControllerCamHUD_Key_Journal_PADDUP:LeftButton")
        key = e.g.ControllerCamHUD_Key_Journal_PADLSHOULDER          # the buttons it does use are bound to it
        key.scripts.OnClick(key)
        self.assertEqual(W.page, "fish")
        key.scripts.OnClick(key)
        self.assertEqual(W.page, "waters")
        self.assertTrue(W.Pad(W, "PAD2"))
        self.assertFalse(f.shown)
        self.assertIsNone(e.mock.overrides.PADDUP)                   # closed: every button is the game's
        self.assertFalse(W.Pad(W, "PADDUP"))
        e.cmd("journal")
        e.mock.state.combat = True                                   # a fight closes it and gives the buttons back
        e.mock.fire("PLAYER_REGEN_DISABLED")
        self.assertFalse(f.shown)
        self.assertIsNone(e.mock.overrides.PADDUP)
        e.mock.state.combat = False
        e.mock.fire("PLAYER_REGEN_ENABLED")
        self.assertIsNone(e.mock.overrides.PADDUP)
        e.g.ControllerCamHUD_FishJournal()                           # its key binding
        self.assertTrue(f.shown)
        self.assertEqual(W.page, "waters")
        self.assertIn("ControllerCamHUD_FishJournalWindow", list(e.g.UISpecialFrames.values()))
        self.assertEqual(e.errors(), [])

    def test_a_long_journal_scrolls_with_the_choice(self):
        e = self.env()
        for i in range(12):
            e.mock["items"][7000 + i] = e.lua.table(name="Fish %02d" % i, **{"class": 7})
        self.land(e, *[7000 + i for i in range(12)])
        W = e.ns.FishJournal
        e.cmd("journal")
        for _ in range(9):
            W.Pad(W, "PADDDOWN")
        self.assertEqual(W.frame.name.text, "Fish 09")
        self.assertEqual(W.top, 3)
        self.assertEqual(W.rows[8].name.text, "Fish 09")
        self.assertIn("3 - 10 / 12", W.frame.count.text)

    def test_a_saved_journal_is_read_carefully(self):
        e = self.env(db="""{ v = 10, asked = true, enabled = true, fishLog = {
            total = 7, away = "2", fish = { [6291] = { n = 7, best = 2.5, name = "Raw Brilliant Smallfish", fish = true,
            firstAt = "Durotar", icon = {} }, bad = 5, [5] = "no" },
            zones = { Durotar = { n = 7, map = 1411, fish = { [6291] = 7, x = 1 } }, [3] = {} } } }""")
        log = e.db.fishLog
        self.assertEqual((log.total, log.away), (7, 2))
        self.assertEqual(sorted(log.fish.keys()), [6291])
        self.assertEqual((log.fish[6291].n, log.fish[6291].best), (7, 2.5))
        self.assertIsNone(log.fish[6291].icon)
        self.assertEqual(list(log.zones.keys()), ["Durotar"])
        self.assertEqual(dict(log.zones["Durotar"].fish), {6291: 7})
        self.assertTrue(e.ns.FishLog.Waters()[1].known)
        junk = self.env(db="{ v = 10, asked = true, enabled = true, fishLog = 'fish' }")
        self.assertEqual(junk.db.fishLog.total, 0)

    def test_the_bar_drops_its_word_and_a_loose_line_leads_up_from_the_float(self):
        e = self.env()
        cb = e.ns.CastBar
        self.line(e, True)
        e.update(0.2)
        self.assertEqual(cb.frame.label.text, "")                    # the float says what this is
        self.assertNotEqual(cb.frame.time.text, "")                  # the time stays
        dots = list(cb.bar.line.values())
        self.assertTrue(all(d.shown for d in dots))
        ys = [d.points[1][5] for d in dots]
        self.assertGreater(ys[-1], ys[0] + 20)                       # it climbs from the float
        mid = len(dots) // 2
        self.assertLess(ys[mid], (ys[0] + ys[-1]) / 2)               # and hangs slack on the way
        self.assertGreater(dots[0].alpha, dots[-1].alpha)            # fading out: it leads to nowhere
        x0 = dots[0].points[1][4]
        e.update(8)
        self.assertLess(dots[0].points[1][4], x0)                    # its low end rides with the float
        self.line(e, False)
        e.update(1)
        self.assertFalse(any(d.shown for d in dots))
        e.mock.units.player.cast = e.lua.table(name="Fireball", start=e.mock.time * 1000, stop=(e.mock.time + 2) * 1000)
        e.mock.fire("UNIT_SPELLCAST_START", "player")
        self.assertEqual(cb.frame.label.text, "Fireball")            # any other cast has its name
        self.assertFalse(any(d.shown for d in dots))

    def test_the_float_on_the_hint_is_large(self):
        e = self.env()
        F = e.ns.Fishing
        self.assertTrue(F.hint.shown)
        self.assertEqual((F.hint.icon.width, F.hint.icon.height), (40, 40))


class FishingGame(unittest.TestCase):
    """Something to do while the float is out; it never touches the fishing itself."""

    def env(self, on=True, db=None):
        e = Env(db=db)
        e.mock["items"][6256] = e.lua.table(name="Fishing Pole", **{"class": 2, "sub": 20})
        e.mock["items"][6291] = e.lua.table(name="Raw Brilliant Smallfish", **{"class": 7})
        e.mock.state.mainHand = 6256
        e.mock.spellNames = e.lua.table_from({7620: "Fishing"})
        e.mock.fire("PLAYER_EQUIPMENT_CHANGED", 16)
        if on:
            e.cmd("fishgame on")
        e.ns.FishGame.random = lambda: 0.5
        e.ns.FishLog.random = lambda: 0.5
        return e

    def line(self, e, out, seconds=30):
        now = e.mock.time
        e.mock.units.player.cast = out and e.lua.table(name="Fishing", start=now * 1000, stop=(now + seconds) * 1000,
                                                       channel=True, spellId=7620) or None
        e.mock.fire("UNIT_SPELLCAST_CHANNEL_START" if out else "UNIT_SPELLCAST_CHANNEL_STOP", "player")

    def land(self, e):
        e.mock.land(e.lua.table_from([e.lua.table(id=6291, name="Raw Brilliant Smallfish", quality=1)]))
        self.line(e, False)

    def test_off_unless_you_want_it(self):
        e = self.env(on=False)
        self.assertFalse(e.db.fishGame)
        self.line(e, True)
        e.update(2)
        self.assertIsNone(e.ns.FishGame.frame)
        self.assertEqual(e.ns.FishGame.Take(e.ns.FishGame), 0)

    def test_hold_the_trigger_to_sink_the_lure_and_stay_beside_the_shadow(self):
        e = self.env()
        G = e.ns.FishGame
        e.update(0.5)
        f = G.frame
        self.assertTrue(f.shown)
        self.assertEqual(f.alpha, 0.5)                               # between casts the water is still
        y = G.y
        e.update(1)
        self.assertEqual(G.y, y)
        self.assertIn("LTRIGGER", f.text.text)                       # it says which trigger
        self.line(e, True)
        e.update(1)
        self.assertEqual(f.alpha, 1)
        self.assertEqual(G.y, 0)                                     # let go: the lure floats up
        self.assertEqual(G.m, 0)                                     # the shadow is far below: the fish does not care
        e.mock.keysDown.PADLTRIGGER = True
        e.update(0.3)
        self.assertGreater(G.y, 0.2)                                 # held: it sinks
        lure = f.lure.points[1][5]
        e.update(0.2)
        self.assertLess(f.lure.points[1][5], lure)                   # drawn lower
        for _ in range(200):                                         # played well: hold when above, let go when below
            e.mock.keysDown.PADLTRIGGER = G.y < G.s
            e.update(0.05, 0.05)
        self.assertGreater(G.m, 0.6)
        self.assertAlmostEqual(f.fill.width, 150 * G.m, 1)
        self.assertEqual(e.errors(), [])

    def test_a_curious_fish_weighs_more_and_the_meter_starts_again(self):
        plain_env = self.env(on=False)
        self.line(plain_env, True)
        plain_env.update(3)
        self.land(plain_env)
        usual = plain_env.db.fishLog.fish[6291].best
        e = self.env()
        G = e.ns.FishGame
        self.line(e, True)
        e.update(1)
        G.m = 1
        self.land(e)
        fish = e.db.fishLog.fish[6291]
        self.assertAlmostEqual(fish.best, round(usual * 1.6, 1), 1)  # a full meter: that much heavier
        self.assertEqual(G.m, 0)
        self.assertEqual(G.streak, 1)
        e.update(0.5)
        self.assertIn("+60%", G.frame.text.text)                     # and it says so for a moment
        self.line(e, True)
        e.update(2)
        self.land(e)
        self.assertEqual((G.streak, e.db.fishLog.streak), (2, 2))
        e.update(5)
        self.assertIn("2 in a row", G.frame.text.text)

    def test_one_that_gets_away_costs_half_the_meter_and_the_row(self):
        e = self.env()
        G = e.ns.FishGame
        self.line(e, True)
        e.update(1)
        self.land(e)
        self.line(e, True, seconds=10)
        G.m = 0.8
        e.mock.keysDown.PADLTRIGGER = False
        e.update(10)
        G.m = 0.8
        self.line(e, False)                                          # the line ran out
        e.update(1.5)
        self.assertAlmostEqual(G.m, 0.4)
        self.assertEqual(G.streak, 0)
        self.assertEqual(e.db.fishLog.streak, 1)                     # the best row is kept

    def test_it_never_touches_the_fishing_itself(self):
        e = self.env()
        G = e.ns.FishGame
        self.assertEqual(e.mock.overrides.PAD3, "SPELL Fishing")    # one press casts, as ever
        self.line(e, True)
        e.mock.keysDown.PADLTRIGGER = True
        e.update(2)
        self.assertIsNone(e.mock.overrides.PAD3)                    # and the hook is the game's own interact
        self.assertIsNone(e.mock.overrides.PADLTRIGGER)             # the trigger is only looked at
        self.assertIsNone(G.frame.scripts.OnGamePadButtonDown)      # no press is taken
        self.assertIsNone(G.frame.scripts.OnKeyDown)
        self.assertIsNone(G.frame.mouse)
        self.land(e)
        self.assertEqual(e.mock.overrides.PAD3, "SPELL Fishing")
        e.cmd("fishkey lt")                                          # the left trigger fishes: the right one plays
        self.assertEqual(G.Key(), "PADRTRIGGER")
        self.line(e, True)
        e.update(0.6)
        self.assertEqual(e.mock.overrides.PADLTRIGGER, "INTERACTTARGET")
        self.assertIsNone(e.mock.overrides.PADRTRIGGER)
        e.mock.keysDown.PADLTRIGGER = False
        e.mock.keysDown.PADRTRIGGER = True
        y = G.y
        e.update(0.3)
        self.assertNotEqual(G.y, y)
        e.mock.state.combat = True                                   # put away in a fight, and with the pole
        e.update(0.5)
        self.assertFalse(G.frame.shown)
        e.mock.state.combat = False
        e.cmd("fishgame off")
        e.update(0.5)
        self.assertFalse(G.frame.shown)
        self.assertEqual(e.errors(), [])


class CastBarArt(unittest.TestCase):
    """A cast bar shows what is being cast."""

    def test_every_kind_has_its_show(self):
        e = Env()
        cb = e.ns.CastBar
        seen = {}
        self.assertIn("casttest", e.cmd("help").lower() + "casttest")
        e.cmd("casttest")
        for _ in range(700):
            e.update(0.1)
            if cb.demo is None and not cb.frame.shown:
                break
            if cb.art.kind and cb.casting:
                seen[cb.art.kind] = max(seen.get(cb.art.kind, 0), cb.art.Shown(cb.art))
        self.assertEqual(sorted(seen), sorted(["mining", "crafting", "herbs", "nature", "lightning", "roots", "heal",
                                               "arcane", "fire", "frost", "shadow", "holy", "physical", "fishing"]))
        for kind, n in seen.items():
            self.assertGreater(n, 0, kind)                          # something of it was on screen
        self.assertFalse(cb.frame.shown)
        self.assertEqual(cb.bar.height, 12)                         # the fishing line is a bar again
        self.assertEqual(e.errors(), [])

    def test_casts_are_sorted_by_what_they_do(self):
        e = Env()
        e.mock.spellNames = e.lua.table_from({403: "Lightning Bolt", 339: "Entangling Roots", 5176: "Wrath",
                                              5185: "Healing Touch", 635: "Holy Light"})
        K, A = e.ns.CastLook, e.ns.CastArt

        def show(name, spell):
            look = K.Look(name, spell)
            return look.kind, A.STYLE_OF[look.kind]

        self.assertEqual(show("Lightning Bolt", 403), ("lightning", "bolts"))      # the sky's own, in pale blue
        self.assertEqual(show("Lightning Bolt", 25449), ("lightning", "bolts"))    # a higher rank, by its name
        self.assertEqual(show("Wrath", 5176), ("nature", "bolts"))                 # nature strikes as green lightning
        self.assertEqual(show("Entangling Roots", 339), ("roots", "roots"))        # roots only where roots are cast
        self.assertEqual(show("Healing Touch", 5185), ("heal", "vines"))           # a heal flowers
        self.assertEqual(show("Holy Light", 635), ("heal", "vines"))
        self.assertNotEqual(K.Look("Lightning Bolt", 403).color[3], K.Look("Wrath", 5176).color[3])
        for school in ("physical", "holy", "fire", "nature", "frost", "shadow", "arcane"):   # every school there is
            look = K.LookOf(school)
            self.assertIsNotNone(look, school)
            self.assertIsNotNone(A.STYLES[A.STYLE_OF[look.kind]], school)
        plain = K.LookOf("physical")                                               # a physical cast: the plain bar
        self.assertIsNone(plain.every)
        self.assertEqual(list(plain.color.values()), list(e.ns.colors.cast.values()))

    def test_a_heal_is_learned_from_the_log(self):
        e = Env()
        K = e.ns.CastLook
        e.mock.logHit("SPELL_DAMAGE", "player", "target", 8)
        e.mock.logEntry[12] = 99004
        e.mock.fire("COMBAT_LOG_EVENT_UNFILTERED")
        self.assertEqual(K.Look("Odd Mend", 99004).kind, "nature")                 # known only as a nature spell
        e.mock.logEntry[2] = "SPELL_HEAL"
        e.mock.fire("COMBAT_LOG_EVENT_UNFILTERED")
        self.assertEqual(K.Look("Odd Mend", 99004).kind, "heal")                   # it healed: it flowers from now on
        self.assertEqual(e.errors(), [])

    def test_flowers_open_along_the_vine_and_lightning_comes_in_strokes(self):
        e = Env()
        art, K = e.ns.CastBar.art, e.ns.CastLook
        self.assertTrue(art.Start(art, K.LookOf("heal")))
        art.Update(art, 0.05, 0.05, 10.0)
        self.assertEqual(art.state.opened, 0)
        art.Update(art, 0.5, 0.5, 10.5)
        half = art.state.opened
        art.Update(art, 1.0, 1.0, 11.0)
        flowers = len(list(art.state.flowers.values()))
        self.assertTrue(0 < half < flowers)
        self.assertEqual(art.state.opened, flowers)
        self.assertLessEqual(flowers, 5)                                           # a few, not a hedge
        self.assertTrue(art.Start(art, K.LookOf("nature")))
        strokes = set()
        for i in range(60):
            art.Update(art, 0.8, 0.8, 20 + i * 0.05)
            strokes.add(art.state.strokes)
        self.assertIn(0, strokes)                                                  # dark between the strokes
        self.assertGreaterEqual(max(strokes), 1)
        art.Finish(art, True, 30.0)
        art.Update(art, None, None, 30.1)
        self.assertEqual(art.state.bolts[1].alpha, 1)                              # the last one runs the whole bar
        self.assertEqual(e.errors(), [])

    def test_a_holy_heal_sears_wounds_shut_instead_of_growing_flowers(self):
        e = Env()
        e.mock.spellNames = e.lua.table_from({635: "Holy Light", 5185: "Healing Touch"})
        art, K, A = e.ns.CastBar.art, e.ns.CastLook, e.ns.CastArt
        self.assertTrue(art.Start(art, K.Look("Holy Light", 635)))
        self.assertTrue(e.same(art.style, A.STYLES.sear))           # light, not leaves
        wounds = len(list(art.state.wounds.values()))
        art.Update(art, 0.05, 0.05, 10.0)
        self.assertEqual(art.state.closed, 0)
        self.assertGreater(art.state.wounds[wounds].cut.alpha, 0.5)  # the last wound gapes still
        art.Update(art, 0.6, 0.6, 10.5)
        self.assertTrue(0 < art.state.closed < wounds)
        art.Update(art, 1.0, 1.0, 11.0)
        self.assertEqual(art.state.closed, wounds)                   # every one seared shut,
        self.assertEqual(art.state.wounds[1].cut.alpha, 0)
        self.assertGreater(art.state.wounds[1].seam.alpha, 0.3)      # a warm seam where it was
        art.Finish(art, True, 11.0)
        art.Update(art, None, None, 11.1)
        self.assertEqual(art.state.blaze.alpha, 1)                   # and the bar blazes as it lands
        self.assertTrue(art.Start(art, K.Look("Healing Touch", 5185)))
        self.assertTrue(e.same(art.style, A.STYLES.vines))           # a nature heal still flowers
        self.assertEqual(e.errors(), [])

    def test_fire_kindles_catches_and_leaps(self):
        e = Env()
        art, K, A = e.ns.CastBar.art, e.ns.CastLook, e.ns.CastArt
        self.assertLess(A.Heat(0.1), A.Heat(0.3))
        self.assertLess(A.Heat(0.3) * 1.5, A.Heat(0.5))             # it catches: a jump, not a creep
        self.assertLess(A.Heat(0.5), A.Heat(1))
        art.Start(art, K.LookOf("fire"))
        art.Update(art, 0.1, 0.1, 5.0)
        kindling = art.state.lit
        art.Update(art, 0.9, 0.9, 5.5)
        self.assertGreater(art.state.lit, kindling)                  # more of them burn as it builds
        tall = art.state.flames[1][1].height
        art.Finish(art, True, 6.0)
        art.Update(art, None, None, 6.2)
        self.assertGreater(art.state.flames[1][1].height, tall)      # when it lands they leap,
        self.assertEqual(art.state.flash.alpha, 1)                   # in a flash
        art.Start(art, K.LookOf("nature"))                           # lightning ends in a flash too
        art.Update(art, 1.0, 1.0, 7.0)
        art.Finish(art, True, 7.0)
        art.Update(art, None, None, 7.1)
        self.assertEqual(art.state.flash.alpha, 1)
        self.assertEqual(e.errors(), [])

    def test_runes_take_shape_as_the_cast_reaches_them(self):
        e = Env()
        cb = e.ns.CastBar
        cb.art.Start(cb.art, e.ns.CastLook.LookOf("arcane"))
        cb.art.Update(cb.art, 0.1, 0.1, 5)
        early = cb.art.state.shaped
        cb.art.Update(cb.art, 0.95, 0.95, 6)
        self.assertGreater(cb.art.state.shaped, early)
        cb.art.Start(cb.art, e.ns.CastLook.LookOf("frost"))
        cb.art.Update(cb.art, 0.5, 0.5, 7)
        half = cb.art.state.frozen
        cb.art.Update(cb.art, 1, 1, 8)
        self.assertGreater(cb.art.state.frozen, half)               # ice, crystal by crystal
        cb.art.Finish(cb.art, True, 8)
        cb.art.Update(cb.art, None, None, 8.2)                      # it shatters and fades
        self.assertLess(cb.art.layer.alpha, 1)
        cb.art.Update(cb.art, None, None, 9)
        self.assertIsNone(cb.art.kind)
        self.assertEqual(cb.art.Shown(cb.art), 0)

    def test_off_means_a_plain_bar_and_nameplates_get_a_lighter_show(self):
        e = Env()
        cb = e.ns.CastBar
        light = e.ns.CastArt.Attach(cb.bar, 0.65, True)
        light.Start(light, e.ns.CastLook.LookOf("fire"))
        cb.art.Start(cb.art, e.ns.CastLook.LookOf("fire"))
        self.assertLess(light.n, cb.art.n)                          # fewer pieces on a nameplate
        self.assertFalse(cb.art.Start(cb.art, e.ns.CastLook.LookOf("mount")))   # no show for this kind
        e.cmd("castart off")
        self.assertFalse(cb.art.Start(cb.art, e.ns.CastLook.LookOf("fire")))
        self.assertEqual(cb.art.Shown(cb.art), 0)


class Chat(unittest.TestCase):
    """Who is talking, and a quieter chat."""

    GUID = "Player-1-0000ABCD"

    def env(self):
        e = Env(setup=lambda env: env.lua.execute("ChatFrame1.AddMessage = function(self, text) GOT = text end"))
        e.mock.guids[self.GUID] = e.lua.table_from({"class": "MAGE", "name": "Uther"})
        return e

    LINE = "12:00 |Hchannel:SAY|h[S]|h |Hplayer:%s:%d:SAY|h[|cff3fc7eb%s|r]|h says: %s"

    def test_class_icon_and_level_in_brackets_before_the_name(self):
        e = self.env()
        C = e.ns.Chat
        self.assertEqual(e.mock.chat("CHAT_MSG_SAY", "hello there", "Uther-Forever", self.GUID), "hello there")
        self.assertEqual(e.mock.lastArgs[12], self.GUID)            # what is said, and all else, passed on as it was
        line = self.LINE % ("Uther-Forever", e.mock.lineID, "Uther", "hello there")
        self.assertRegex(C.Dress(line),                             # [icon] Name: the brackets moved to the badge
                         r"^12:00 \|Hchannel:SAY\|h\[S\]\|h \[\|T[^|]*UI-CHARACTERCREATE-CLASSES[^|]*\|t\] "
                         r"\|Hplayer:Uther-Forever:\d+:SAY\|h\|cff3fc7ebUther\|r\|h says: hello there$")
        C.levels[self.GUID] = 60                                    # a level we have seen
        self.assertRegex(C.Dress(line), r"\|t\|cff[0-9a-f]{6}60\|r\] \|Hplayer:")    # the icon right against the level
        e.g.ChatFrame1.AddMessage(e.g.ChatFrame1, line)             # the same on its way into the chat window
        self.assertEqual(e.g.GOT, C.Dress(line))
        # someone known by name only (your guild's list, a /who): the level alone
        C.byName["Jaina"] = 33
        e.mock.chat("CHAT_MSG_GUILD", "hi", "Jaina-Forever", "Player-1-77777777")
        jaina = self.LINE % ("Jaina-Forever", e.mock.lineID, "Jaina", "hi")
        self.assertRegex(C.Dress(jaina), r"\[\|cff[0-9a-f]{6}33\|r\] \|Hplayer:Jaina-Forever")
        # nothing known, another kind of line, and not a player's line at all: untouched
        e.mock.chat("CHAT_MSG_SAY", "plain", "Someone", "Creature-0-1")
        nobody = self.LINE % ("Someone", e.mock.lineID, "Someone", "plain")
        self.assertEqual(C.Dress(nobody), nobody)
        earned = "|Hplayer:Uther-Forever:99999:ACHIEVEMENT|h[Uther]|h has earned the achievement"
        self.assertEqual(C.Dress(earned), earned)
        self.assertEqual(C.Dress("The door is locked."), "The door is locked.")
        e.cmd("chatinfo off")                                       # off: the window's own way in is given back
        e.g.ChatFrame1.AddMessage(e.g.ChatFrame1, line)
        self.assertEqual(e.g.GOT, line)
        self.assertEqual(C.Dress(line), line)
        e.cmd("chatinfo on")
        e.g.ChatFrame1.AddMessage(e.g.ChatFrame1, line)
        self.assertNotEqual(e.g.GOT, line)
        self.assertEqual(e.errors(), [])

    def test_levels_come_from_friends_guild_and_who(self):
        e = Env(setup=lambda env: env.lua.execute("""
            C_FriendList = C_FriendList or {}
            C_FriendList.GetNumFriends = function() return 1 end
            C_FriendList.GetFriendInfoByIndex = function(i) return { name = "Thrall", level = 60 } end
            C_FriendList.GetNumWhoResults = function() return 1 end
            C_FriendList.GetWhoInfo = function(i) return { fullName = "Vol-Forever", level = 41 } end
            function GetNumGuildMembers() return 2 end
            function GetGuildRosterInfo(i) return (i == 1 and "Cairne-Forever" or "Rexxar-Forever"), "Rank", 1, 50 + i end"""))
        names = e.ns.Chat.byName
        self.assertEqual((names.Thrall, names.Vol, names.Cairne, names.Rexxar), (60, 41, 51, 52))
        self.assertEqual(e.errors(), [])

    def test_gold_sellers_are_hidden(self):
        e = self.env()
        for ad in ("WTS cheap GOLD fast delivery at www.g0ldshop.com",
                   "Best price boost, visit g o l d s h o p (dot) com",
                   "Cheap gold > W W W . GOLDZ . NET <"):
            self.assertIsNone(e.mock.chat("CHAT_MSG_CHANNEL", ad, "Spammer", "Player-1-1"), ad)
        for fine in ("LFG Deadmines, need healer", "selling Linen Cloth, 5g a stack",
                     "check wowhead.com for the quest"):
            self.assertIsNotNone(e.mock.chat("CHAT_MSG_CHANNEL", fine, "Friendly", "Player-1-2"), fine)
        self.assertEqual(e.ns.Chat.hidden, 3)
        self.assertIn("3 messages hidden", e.cmd("spam"))

    def test_repeats_are_hidden_for_a_while(self):
        e = self.env()
        msg = "LFM Scarlet Monastery, all welcome"
        self.assertIsNotNone(e.mock.chat("CHAT_MSG_CHANNEL", msg, "Leader", "Player-1-3"))
        self.assertIsNone(e.mock.chat("CHAT_MSG_CHANNEL", msg, "Leader", "Player-1-3"))
        self.assertIsNotNone(e.mock.chat("CHAT_MSG_CHANNEL", msg, "Other", "Player-1-4"))   # someone else may
        e.mock.advance(130)
        self.assertIsNotNone(e.mock.chat("CHAT_MSG_CHANNEL", msg, "Leader", "Player-1-3"))
        self.assertIsNotNone(e.mock.chat("CHAT_MSG_PARTY", msg, "Leader", "Player-1-3"))   # never your group
        e.cmd("chatspam off")
        self.assertIsNotNone(e.mock.chat("CHAT_MSG_CHANNEL", msg, "Leader", "Player-1-3"))

    def test_class_colours_are_the_games_own_setting(self):
        e = self.env()
        self.assertFalse(e.ns.GetNative("chatclass"))
        e.cmd("chatclass on")
        self.assertTrue(e.g.ChatTypeInfo.SAY.colorNameByClass)
        self.assertTrue(e.g.ChatTypeInfo.CHANNEL1.colorNameByClass)
        self.assertTrue(e.ns.GetNative("chatclass"))
        self.assertIsNone(e.db.chatclass)                           # nothing kept of ours

    def test_mouse_ui_untouched(self):
        e = Env(style="0")
        self.assertEqual(e.mock.chat("CHAT_MSG_CHANNEL", "WTS gold www.x.com", "Spammer", "Player-1-1"),
                         "WTS gold www.x.com")


class Repair(unittest.TestCase):
    def test_repairs_when_a_vendor_opens(self):
        e = Env()
        e.mock.repairCost = 500
        out_before = len(e.mock.printed)
        e.mock.openMerchant(True)
        self.assertEqual(e.mock.repaired, "own")
        self.assertEqual(e.mock.money, 12345 - 500)
        self.assertIn("Repaired for 5s", "\n".join(list(e.mock.printed.values())[out_before:]))

    def test_from_the_guild_bank_when_allowed(self):
        e = Env()
        e.cmd("repairguild on")
        e.mock.repairCost, e.mock.guildRepair = 500, True
        e.mock.openMerchant(True)
        self.assertEqual(e.mock.repaired, "guild")
        self.assertEqual(e.mock.money, 12345)

    def test_not_enough_gold_and_off(self):
        e = Env()
        e.mock.repairCost = 99999
        e.mock.openMerchant(True)
        self.assertIsNone(e.mock.repaired)
        e.mock.openMerchant(False)
        e.cmd("autorepair off")
        e.mock.repairCost = 10
        e.mock.openMerchant(True)
        self.assertIsNone(e.mock.repaired)


class HoverNPC(unittest.TestCase):
    """Friendly NPC plates only while you point at them (off by default)."""

    def test_off_by_default(self):
        e = Env()
        npc = e.lua.table(name="Innkeeper", level=30, health=5, healthMax=5, attackable=False, reaction=5)
        o = e.ns.Nameplates.byPlate[e.mock.addPlate("nameplate1", npc)]
        self.assertGreater(o.alpha, 0)

    def test_shows_while_pointed_at(self):
        e = Env()
        e.cmd("platehovernpc on")
        npc = e.lua.table(name="Innkeeper", level=30, health=5, healthMax=5, attackable=False, reaction=5)
        o = e.ns.Nameplates.byPlate[e.mock.addPlate("nameplate1", npc)]
        self.assertEqual(o.alpha, 0)
        e.mock.units["mouseover"] = npc                              # the cursor (or soft targeting) on it
        e.mock.fire("UPDATE_MOUSEOVER_UNIT")
        self.assertGreater(o.alpha, 0)
        e.mock.units["mouseover"] = None                             # pointing away has no event: noticed soon
        e.update(0.5)
        self.assertEqual(o.alpha, 0)
        e.mock.setUnit("target", npc)                                # your target always shows
        e.mock.fire("PLAYER_TARGET_CHANGED")
        self.assertGreater(o.alpha, 0)

    def test_things_you_can_interact_with_stay_bare(self):
        e = Env()
        ore = e.lua.table(name="Iron Deposit", level=1, health=0, healthMax=0, attackable=False, reaction=4,
                          guid="GameObject-0-4521-0-12-1735-00006F3A12")
        o = e.ns.Nameplates.byPlate[e.mock.addPlate("nameplate1", ore)]
        self.assertEqual(o.alpha, 0)                                 # no name over a node, a chest, a plaque
        e.mock.units["softinteract"] = ore                           # even while you face it
        e.update(0.5)
        self.assertEqual(o.alpha, 0)
        npc = e.lua.table(name="Innkeeper", level=30, health=5, healthMax=5, attackable=False, reaction=5,
                          guid="Creature-0-4521-0-12-6741-00006F3A13")
        o2 = e.ns.Nameplates.byPlate[e.mock.addPlate("nameplate2", npc)]
        self.assertGreater(o2.alpha, 0)                              # someone, not something: as before
        e.cmd("plateobjects on")                                     # unless you ask for them
        e.update(0.5)
        self.assertGreater(o.alpha, 0)
        self.assertEqual(e.errors(), [])

    def test_enemies_and_players_always_show(self):
        e = Env()
        e.cmd("platehovernpc on")
        enemy = e.lua.table(name="Raptor", level=30, health=5, healthMax=5, attackable=True, reaction=2)
        player = e.lua.table(name="Jaina", level=60, health=5, healthMax=5, attackable=False, reaction=5,
                             isPlayer=True)
        o1 = e.ns.Nameplates.byPlate[e.mock.addPlate("nameplate1", enemy)]
        o2 = e.ns.Nameplates.byPlate[e.mock.addPlate("nameplate2", player)]
        self.assertGreater(o1.alpha, 0)
        self.assertGreater(o2.alpha, 0)


class Family(unittest.TestCase):
    """The HUD belongs to ControllerCam: its options sit under the camera addon's, its parts switch on and off."""

    def test_options_nest_under_controllercam(self):
        def setup(env):
            env.lua.execute('ControllerCamSettings = { category = { name = "ControllerCam" } }')
        e = Env(setup=setup)
        subs = {s.name: s for s in e.mock.subcategories.values()}
        self.assertEqual(subs["HUD"].parent.name, "ControllerCam")      # ControllerCam > HUD
        self.assertTrue(e.same(subs["Nameplates"].parent, subs["HUD"]))  # ... > HUD > Nameplates
        self.assertTrue(e.same(subs["Frames"].parent, subs["HUD"]))
        self.assertTrue(e.ns.nested)

    def test_on_its_own_without_the_camera_addon(self):
        e = Env()
        self.assertFalse(e.ns.nested)
        self.assertEqual(e.mock.category.name, "ControllerCam HUD")

    def test_every_module_has_its_switch(self):
        e = Env()
        keys = {d.key for d in e.ns.settings.values() if d.label}
        for key in e.ns.MODULES.values():
            self.assertIn(key, keys)
        e.ns.BuildOptions()                                           # the page builds with them
        self.assertEqual(e.errors(), [])

    def test_cursor_tooltips_flip_quickly(self):
        e = Env()
        self.assertTrue(e.db.tooltipCursor)
        self.assertIn("tooltipCursor", list(e.ns.STYLE.values()))          # in the quick switches
        e.g.ControllerCamHUD_ToggleTooltipCursor()                          # the key binding
        self.assertFalse(e.db.tooltipCursor)
        self.assertFalse(e.ns.Tooltip.active)
        e.g.ControllerCamHUD_ToggleTooltipCursor()
        self.assertTrue(e.ns.Tooltip.active)
        e.cmd("tooltipcursor off")
        self.assertFalse(e.ns.Tooltip.active)

    def test_the_addon_list_groups_it_with_controllercam(self):
        toc = open(os.path.join(HUD, "ControllerCam_HUD.toc"), encoding="utf-8").read()
        self.assertIn("## Group: ControllerCam", toc)
        self.assertIn("## OptionalDeps: ControllerCam", toc)


class ServiceIcons(unittest.TestCase):
    def test_vendors_and_smiths_wear_their_icon(self):
        e = Env()
        T = e.lua.table
        smith = T(name="Smith", level=30, health=5, healthMax=5, attackable=False, reaction=5, cursor="Repair")
        townie = T(name="Townie", level=30, health=5, healthMax=5, attackable=False, reaction=5)
        enemy = T(name="Raptor", level=30, health=5, healthMax=5, attackable=True, reaction=2, cursor="Attack")
        o1 = e.ns.Nameplates.byPlate[e.mock.addPlate("nameplate1", smith)]
        o2 = e.ns.Nameplates.byPlate[e.mock.addPlate("nameplate2", townie)]
        o3 = e.ns.Nameplates.byPlate[e.mock.addPlate("nameplate3", enemy)]
        self.assertTrue(o1.service.shown)
        self.assertEqual(o1.service.icon.texture, "Repair")
        self.assertFalse(o2.service.shown)                          # nothing to offer: no icon
        self.assertFalse(o3.service.shown)                          # enemies: no
        e.cmd("platehovernpc on")
        e.cmd("nameplates off")
        e.cmd("nameplates on")
        o1 = e.ns.Nameplates.byPlate[e.mock.plates.nameplate1]
        self.assertEqual(o1.alpha, 0)                               # the plate waits to be pointed at...
        self.assertTrue(o1.service.shown)                           # ...the icon still says what it is
        e.update(0.5)
        self.assertEqual(o1.service.alpha, 1)                       # (never hidden with the game's plate)
        e.mock.removePlate("nameplate1")
        self.assertFalse(o1.service.shown)
        e.cmd("plateserviceicons off")
        self.assertFalse(e.ns.Nameplates.byPlate[e.mock.plates.nameplate2].service.shown)


class Rumble(unittest.TestCase):
    def motors(self, e):
        return [r.motor for r in e.mock.rumble.values()]

    def test_hits_rumble_heavier_when_big(self):
        e = Env()
        e.mock.fire("UNIT_COMBAT", "player", "WOUND", "", 30, 1)        # 3% of your health
        e.update(0.5)
        self.assertEqual(e.ns.Rumble.last, "hit")
        self.assertIn("Low", self.motors(e))
        self.assertEqual(self.motors(e)[-1], "stop")                  # always let go
        e.mock.fire("UNIT_COMBAT", "player", "WOUND", "", 300, 1)       # 30%
        self.assertEqual(e.ns.Rumble.last, "bighit")

    def test_a_weaker_pattern_never_cuts_a_stronger_one(self):
        e = Env()
        R = e.ns.Rumble
        R.Play(R, "death")
        self.assertFalse(R.Play(R, "whisper"))
        e.update(1)
        self.assertTrue(R.Play(R, "whisper"))

    def test_crits_tick_in_the_right_trigger(self):
        e = Env()
        e.target()
        e.mock.logHit("SPELL_DAMAGE", "player", "target", 4, True)
        self.assertEqual(e.ns.Rumble.last, "crit")
        e.update(0.2)
        self.assertIn("RTrigger", self.motors(e))

    def test_alerts_interrupts_level_and_heartbeat(self):
        e = Env()
        R = e.ns.Rumble
        for event, args, pattern in (("READY_CHECK", (), "alert"), ("PLAYER_LEVEL_UP", (), "level"),
                                     ("UNIT_SPELLCAST_INTERRUPTED", ("target",), "interrupt")):
            e.update(3)
            e.mock.fire(event, *args)
            self.assertEqual(R.last, pattern, event)
        e.update(3)
        e.mock.state.combat = True
        e.mock.units.player.health = 200                                # 20% in a fight
        e.update(0.3)
        self.assertEqual(R.last, "heartbeat")

    def test_a_seal_charges_up(self):
        e = Env()
        e.mock.spellNames = e.lua.table_from({20154: "Seal of Righteousness", 99100: "Seal of Righteousness",
                                              635: "Holy Light"})
        e.mock.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 99100)    # another rank: known by its name
        self.assertEqual(e.ns.Rumble.last, "charge")
        e.update(0.5)
        motors = self.motors(e)
        self.assertIn("RTrigger", motors)                               # it snaps in the trigger
        ks = [r.k for r in e.mock.rumble.values() if r.motor == "Low"]
        self.assertEqual(ks, sorted(ks))                                # rising
        e.mock.rumble = e.lua.table()
        e.update(1)
        e.mock.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 635)      # not a seal
        self.assertEqual(len(e.mock.rumble), 0)
        e.cmd("rumbleseals off")
        e.mock.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-3", 20154)
        e.update(0.5)
        self.assertEqual(len(e.mock.rumble), 0)

    def test_casts_build_up_when_asked(self):
        e = Env()
        now = e.mock.time
        e.mock.units.player.cast = e.lua.table(name="Holy Light", start=now * 1000, stop=(now + 2) * 1000)
        e.mock.fire("UNIT_SPELLCAST_START", "player")
        e.update(1.5)
        self.assertEqual(len(e.mock.rumble), 0)                         # off by default
        e.mock.units.player.cast = None
        e.mock.fire("UNIT_SPELLCAST_STOP", "player")
        e.update(1)
        e.cmd("rumblecasts on")
        now = e.mock.time
        e.mock.units.player.cast = e.lua.table(name="Holy Light", start=now * 1000, stop=(now + 2) * 1000)
        e.mock.fire("UNIT_SPELLCAST_START", "player")
        e.update(1.9)
        ks = [r.k for r in e.mock.rumble.values() if r.motor == "Low"]
        self.assertGreaterEqual(len(ks), 3)
        self.assertEqual(ks, sorted(ks))                                # it builds
        self.assertLessEqual(len(ks), 6)                                # in steps, not every frame
        e.update(0.5)
        self.assertEqual(e.ns.Rumble.last, "snap")                      # and snaps when it lands

    def test_the_games_vibration_setting_comes_first(self):
        def setup(env):
            env.mock.cvars["GamePadVibrationStrength"] = "0"
        e = Env(setup=setup)
        e.mock.fire("UNIT_COMBAT", "player", "WOUND", "", 300, 1)
        self.assertEqual(len(e.mock.rumble), 0)
        self.assertIn("vibration is off", e.cmd("rumbletest"))

    def test_off_and_mouse_ui(self):
        e = Env()
        e.cmd("rumble off")
        e.mock.fire("UNIT_COMBAT", "player", "WOUND", "", 300, 1)
        self.assertEqual(len(e.mock.rumble), 0)
        e2 = Env(style="0")
        e2.mock.fire("UNIT_COMBAT", "player", "WOUND", "", 300, 1)
        self.assertEqual(len(e2.mock.rumble), 0)

    def test_the_light_bar_shows_your_health(self):
        e = Env()
        e.update(0.3)
        self.assertGreater(e.mock.led.g, 0.9)                           # full: green
        e.mock.units.player.health = 100
        e.update(0.3)
        self.assertGreater(e.mock.led.r, 0.9)                           # low: red
        self.assertLess(e.mock.led.g, 0.3)
        e.cmd("lightbar off")
        e.update(0.3)
        self.assertEqual(e.mock.led, "cleared")                         # the game's colour back


class MinorPlates(unittest.TestCase):
    def test_minor_units_get_a_small_plate_with_just_the_name(self):
        e = Env()
        T = e.lua.table
        e.mock.units.player.level = 40
        grey = T(name="Kobold", level=10, health=5, healthMax=5, attackable=True, reaction=2,
                 classification="elite")
        minion = T(name="Imp", level=40, health=5, healthMax=5, attackable=True, reaction=2, classification="minus")
        normal = T(name="Raptor", level=40, health=5, healthMax=5, attackable=True, reaction=2)
        e.cmd("platepercent on")
        o1 = e.ns.Nameplates.byPlate[e.mock.addPlate("nameplate1", grey)]
        o2 = e.ns.Nameplates.byPlate[e.mock.addPlate("nameplate2", minion)]
        o3 = e.ns.Nameplates.byPlate[e.mock.addPlate("nameplate3", normal)]
        self.assertTrue(o1.mini)                                     # grey: no experience, minor
        self.assertTrue(o2.mini)
        self.assertFalse(o3.mini)
        self.assertEqual(o1.name.text, "Kobold")                     # no level in front
        self.assertFalse(o1.wingL.shown)                             # no rank flourish
        self.assertFalse(o1.percent.shown)                           # no health text
        self.assertIn("40", o3.name.text)
        self.assertTrue(o3.percent.shown)

    def test_full_size_again_once(self):
        e = Env(db="{ v = 7, plateCompact = true, targetCompact = true }")
        self.assertFalse(e.db.plateCompact)
        self.assertFalse(e.db.targetCompact)


class Bloom(unittest.TestCase):
    def friend(self, e, **kw):
        return e.target(attackable=False, reaction=5, isPlayer=True, health=400, healthMax=800, guid="Player-5", **kw)

    def test_a_heal_over_time_grows_and_withers(self):
        e = Env()
        self.friend(e)
        e.mock.spellNames = e.lua.table_from({774: "Rejuvenation"})
        e.mock.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 774)
        e.update(0.3)
        v = e.ns.Bloom.frames[e.frames.target]
        self.assertTrue(v.top.shown and v.bottom.shown)
        self.assertLess(v.g, 1)                                       # growing...
        e.update(1)
        self.assertEqual(v.g, 1)                                      # ...grown
        nature = e.ns.Bloom.LOOK.nature.color
        self.assertEqual(round(v.top.vcolor[2], 2), round(nature[2], 2))
        e.update(12)                                                  # Rejuvenation's usual length
        self.assertEqual(v.g, 0)                                      # withered away
        self.assertFalse(v.top.shown)

    def test_renew_is_golden_and_enemies_get_none(self):
        e = Env()
        self.friend(e)
        e.mock.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 139)
        e.update(1.2)
        v = e.ns.Bloom.frames[e.frames.target]
        self.assertEqual(v.school, "holy")
        e.target(name="Raptor", guid="Creature-1")                    # an enemy targeted: the heal went on you
        e.mock.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 774)
        self.assertIsNotNone(e.ns.Bloom.HotOn("player"))
        self.assertIsNone(e.ns.Bloom.HotOn("target"))

    def test_the_heal_on_its_way_shows_its_school(self):
        e = Env()
        self.friend(e, incoming=200)
        now = e.mock.time
        e.mock.spellNames = e.lua.table_from({635: "Holy Light"})
        e.mock.units.player.cast = e.lua.table(name="Holy Light", spellId=635, start=now * 1000, stop=(now + 2) * 1000)
        e.mock.fire("UNIT_SPELLCAST_START", "player")
        e.mock.fire("UNIT_HEAL_PREDICTION", "target")
        heal = e.frames.target.health.healBar
        holy = e.ns.Impact.PROFILES.holy.color
        self.assertEqual(round(heal.color[1], 2), round(holy[1], 2))
        self.assertEqual(round(heal.color[3], 2), round(holy[3], 2))
        e.cmd("healcolors off")
        e.mock.fire("UNIT_HEAL_PREDICTION", "target")
        self.assertEqual(round(heal.color[2], 2), 1)                  # the plain heal green

    def test_off(self):
        e = Env()
        self.friend(e)
        e.cmd("hotvines off")
        e.mock.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 774)
        e.update(1)
        v = e.ns.Bloom.frames[e.frames.target]
        self.assertTrue(v is None or not v.top.shown)


class TooltipGlass(unittest.TestCase):
    """How solid a tooltip's background and border are is yours to set."""

    def back(self, e):
        return e.ns.Skin.added[e.g.GameTooltip].panel

    def alpha(self, tex):
        return round(tex.color[4], 3) if getattr(tex, "color", None) else None

    def setUp(self):
        self.lua_patch = """
            local make = CreateFrame
        """

    def env(self, **kw):
        def setup(env):                                              # textures remember the colour they are given
            env.lua.execute("""
                local base = CreateFrame
                local function watch(t)
                    t.SetColorTexture = function(self, r, g, b, a) self.color = { r, g, b, a } end
                    return t
                end
                local tip = GameTooltip
                local old = tip.CreateTexture
                tip.CreateTexture = function(self, ...) return watch(old(self, ...)) end
            """)
        return Env(setup=setup, **kw)

    def test_mostly_see_through_to_begin_with_and_adjustable(self):
        e = self.env()
        S = e.ns.Skin
        p = self.back(e)
        self.assertAlmostEqual(e.db.tooltipGlass, 0.4)
        self.assertAlmostEqual(p.back.color[4], 0.82 * 0.4)          # the glass: mostly see-through
        self.assertAlmostEqual(p.edges[1].color[4], S.EDGE[4] * 0.4) # and its border with it
        self.assertIn("100", e.cmd("tooltipglass 100"))
        self.assertAlmostEqual(p.back.color[4], 0.82)                # the full dark glass
        self.assertAlmostEqual(p.edges[1].color[4], S.EDGE[4])
        e.cmd("tooltipglass 0")
        self.assertEqual(p.back.color[4], 0)                         # only the text is left
        self.assertEqual(p.edges[1].color[4], 0)
        self.assertEqual(p.shine.color[4], 0)
        e.cmd("tooltipglass 50")
        S.EdgeColor(p, e.lua.table_from([1, 0, 0, 0.9]))             # a tooltip opens: its edge takes a colour
        self.assertAlmostEqual(p.edges[2].color[4], 0.45)            # at the level asked for
        self.assertEqual(p.edges[2].color[1], 1)
        e.cmd("textscale 100")                                       # the look is put on again: still at that level
        self.assertAlmostEqual(self.back(e).back.color[4], 0.41)
        self.assertEqual(e.g.GameTooltip.NineSlice.alpha, 0)         # (the game's own background stays put away)
        self.assertEqual(e.errors(), [])

    def test_without_our_look_the_games_own_background_is_faded(self):
        e = self.env()
        nine = e.g.GameTooltip.NineSlice
        e.cmd("skintooltips off")
        e.update(0.3)
        self.assertAlmostEqual(nine.alpha, 0.4)
        e.cmd("tooltipglass 75")
        e.update(0.3)
        self.assertAlmostEqual(nine.alpha, 0.75)
        nine.alpha = 1                                               # the game sets it again by itself
        e.update(0.3)
        self.assertAlmostEqual(nine.alpha, 0.75)                     # ours again
        e.cmd("tooltipglass 100")
        e.update(0.3)
        self.assertEqual(nine.alpha, 1)
        e.cmd("tooltipglass 30")
        e.cmd("skintooltips on")                                     # our look again: its glass at that level
        self.assertEqual(nine.alpha, 0)
        self.assertAlmostEqual(self.back(e).back.color[4], 0.82 * 0.3)
        e.cmd("off")                                                 # the HUD off: exactly as the game had it
        e.update(0.3)
        self.assertEqual(nine.alpha, 1)
        self.assertFalse(self.back(e).back.shown)
        e.cmd("on")
        e.cmd("skintooltips off")
        e.update(0.3)
        self.assertAlmostEqual(nine.alpha, 0.3)
        e.cmd("off")
        e.update(0.3)
        self.assertEqual(nine.alpha, 1)
        self.assertEqual(e.errors(), [])


class BuffsRest(unittest.TestCase):
    def test_buffs_fade_with_the_rest_of_the_screen(self):
        e = Env(setup=lambda env: env.lua.execute("BuffFrame = CreateFrame('Frame', 'BuffFrame', UIParent)"))
        R = e.ns.Rest
        e.update(12)
        self.assertLess(e.g.BuffFrame.alpha, 0.5)                    # nothing going on: they rest
        self.assertAlmostEqual(e.g.BuffFrame.alpha, e.g.MinimapCluster.alpha)
        e.mock.state.combat = True
        e.mock.fire("PLAYER_REGEN_DISABLED")
        e.update(2)
        self.assertEqual(e.g.BuffFrame.alpha, 1)                     # a fight: back in full
        e.mock.state.combat = False
        e.mock.fire("PLAYER_REGEN_ENABLED")
        e.cmd("restbuffs off")
        e.update(12)
        self.assertEqual(e.g.BuffFrame.alpha, 1)                     # left out of it
        self.assertLess(e.g.MinimapCluster.alpha, 0.5)
        self.assertEqual(e.errors(), [])


class TaintLog(unittest.TestCase):
    def test_the_games_own_record_is_kept_while_reports_are_on(self):
        def known(env):
            env.mock.cvars.taintLog = "0"
            env.mock.knownCVars.taintLog = True
        e = Env(setup=known)
        self.assertEqual(e.mock.cvars.taintLog, "0")                 # reports off: the game's setting is the game's
        e.cmd("debug on")
        self.assertEqual((e.mock.cvars.taintLog, e.db.taintLogWas), ("1", "0"))
        e.cmd("debug off")
        self.assertEqual(e.mock.cvars.taintLog, "0")
        self.assertIsNone(e.db.taintLogWas)
        yours = Env(setup=lambda env: (known(env), env.mock.cvars.__setitem__("taintLog", "2")))
        yours.cmd("debug on")
        self.assertEqual(yours.mock.cvars.taintLog, "2")             # set by you already: left as it is
        yours.cmd("debug off")
        self.assertEqual(yours.mock.cvars.taintLog, "2")
        self.assertEqual(Env().errors(), [])                         # a client without it: nothing happens


class FriendsInside(unittest.TestCase):
    """In a dungeon the game draws friendly nameplates itself: its own options make them look like ours there."""

    ONLY, COLOR, SHOW = ("nameplateShowOnlyNameForFriendlyPlayerUnits", "nameplateUseClassColorForFriendlyPlayerUnitNames",
                         "nameplateShowFriendlyPlayers")

    def enter(self, e, kind="party"):
        e.mock.state.instance = kind
        e.mock.fire("PLAYER_ENTERING_WORLD")

    def leave(self, e):
        e.mock.state.instance = None
        e.mock.fire("PLAYER_ENTERING_WORLD")

    def now(self, e):
        c = e.mock.cvars
        return (c[self.ONLY], c[self.COLOR], c[self.SHOW])

    def test_names_only_inside_and_back_outside(self):
        e = Env()
        self.assertEqual(self.now(e), ("0", "0", "1"))               # outside: the game's settings are yours
        for kind in ("party", "raid", "scenario"):                   # dungeons and raids
            self.enter(e, kind)
            self.assertEqual(self.now(e), ("1", "1", "1"), kind)     # names alone, in the class colour, still shown
            self.assertEqual(e.db.plateInsideWas[self.ONLY].was, "0")
            self.leave(e)
            self.assertEqual(self.now(e), ("0", "0", "1"), kind)
            self.assertEqual(len(list(e.db.plateInsideWas.keys())), 0)
        for kind in ("pvp", "arena"):                                # a battleground: the plates there are ours
            self.enter(e, kind)
            self.assertEqual(self.now(e), ("0", "0", "1"), kind)
            self.leave(e)
        self.assertEqual(e.errors(), [])

    def test_wherever_the_game_says_it_keeps_a_plate_to_itself(self):
        e = Env()
        self.enter(e, "pvp")
        self.assertEqual(self.now(e), ("0", "0", "1"))
        e.mock.fire("FORBIDDEN_NAME_PLATE_UNIT_ADDED", "nameplate3") # the game says so, here
        self.assertEqual(self.now(e), ("1", "1", "1"))
        e.mock.fire("FORBIDDEN_NAME_PLATE_UNIT_ADDED", "nameplate4")
        self.assertEqual(self.now(e), ("1", "1", "1"))
        self.leave(e)                                                # somewhere new: back, and not assumed again
        self.assertEqual(self.now(e), ("0", "0", "1"))
        self.assertFalse(e.ns.Nameplates.kept)

    def test_their_bars_come_back_for_a_fight(self):
        e = Env()
        self.enter(e)
        self.assertEqual(self.now(e), ("1", "1", "1"))
        e.mock.state.combat = True
        e.mock.fire("PLAYER_REGEN_DISABLED")                         # a fight: the game's bars, as on our own plates
        self.assertEqual(self.now(e), ("0", "1", "1"))
        e.cmd("textscale 100")                                       # nothing is changed during the fight
        self.assertEqual(self.now(e), ("0", "1", "1"))
        e.mock.state.combat = False
        e.mock.fire("PLAYER_REGEN_ENABLED")
        self.assertEqual(self.now(e), ("1", "1", "1"))               # quiet again: names alone
        e.cmd("platefriendbars off")                                 # no bars for friends in a fight: names all along
        e.mock.state.combat = True
        e.mock.fire("PLAYER_REGEN_DISABLED")
        self.assertEqual(self.now(e), ("1", "1", "1"))
        e.mock.state.combat = False
        e.mock.fire("PLAYER_REGEN_ENABLED")
        e.cmd("platefriendbars on")
        e.mock.state.combat = True
        e.mock.fire("PLAYER_REGEN_DISABLED")
        self.assertEqual(self.now(e), ("0", "1", "1"))
        e.mock.state.combat = False                                  # wiped and walked out: as you had it
        e.mock.fire("PLAYER_REGEN_ENABLED")
        self.leave(e)
        self.assertEqual(self.now(e), ("0", "0", "1"))
        self.assertEqual(len(list(e.db.plateInsideWas.keys())), 0)
        own = Env()                                                  # names only is how you play anyway:
        own.mock.cvars[self.ONLY] = "1"
        self.enter(own)
        own.mock.state.combat = True
        own.mock.fire("PLAYER_REGEN_DISABLED")
        self.assertEqual(own.mock.cvars[self.ONLY], "0")             # bars for the fight all the same
        own.mock.state.combat = False
        own.mock.fire("PLAYER_REGEN_ENABLED")
        self.leave(own)
        self.assertEqual(own.mock.cvars[self.ONLY], "1")             # and yours again outside
        self.assertEqual(e.errors() + own.errors(), [])

    def test_hidden_altogether_if_you_would_rather(self):
        e = Env()
        e.cmd("platefriendshide on")
        self.assertEqual(self.now(e), ("0", "0", "1"))               # not out here
        self.enter(e)
        self.assertEqual(self.now(e), ("1", "1", "0"))
        e.cmd("platefriendsinside off")                              # only hidden: the look is put back at once
        self.assertEqual(self.now(e), ("0", "0", "0"))
        e.cmd("platefriendshide off")
        self.assertEqual(self.now(e), ("0", "0", "1"))
        e.cmd("platefriendsinside on")
        self.assertEqual(self.now(e), ("1", "1", "1"))
        self.leave(e)
        self.assertEqual(self.now(e), ("0", "0", "1"))

    def test_what_you_set_yourself_is_left_alone(self):
        e = Env()
        e.mock.cvars[self.ONLY] = "1"                                # you play with names only anyway
        self.enter(e)
        self.assertIsNone(e.db.plateInsideWas[self.ONLY])
        self.assertEqual(e.db.plateInsideWas[self.COLOR].was, "0")
        self.leave(e)
        self.assertEqual(self.now(e), ("1", "0", "1"))               # and it stays as you had it
        self.enter(e)
        e.mock.cvars[self.COLOR] = "0"                               # switched back by hand in there
        e.cmd("textscale 100")                                       # (anything that applies the settings again)
        self.assertEqual(e.mock.cvars[self.COLOR], "0")              # left as you set it
        self.leave(e)
        self.assertEqual(e.mock.cvars[self.COLOR], "0")
        self.assertEqual(len(list(e.db.plateInsideWas.keys())), 0)

    def test_never_in_a_fight(self):
        e = Env()
        e.mock.state.combat = True                                   # pulled in still fighting
        self.enter(e)
        self.assertEqual(self.now(e), ("0", "0", "1"))
        e.mock.state.combat = False
        e.mock.fire("PLAYER_REGEN_ENABLED")
        self.assertEqual(self.now(e), ("1", "1", "1"))

    def test_the_other_option_and_the_hud_itself(self):
        e = Env()
        self.enter(e)
        e.cmd("platefriendsgame on")                                 # friends left to the game's look: then in here too
        self.assertEqual(self.now(e), ("0", "0", "1"))
        e.cmd("platefriendsgame off")
        self.assertEqual(self.now(e), ("1", "1", "1"))
        e.cmd("off")                                                 # the HUD off: as you had it
        self.assertEqual(self.now(e), ("0", "0", "1"))
        self.assertEqual(len(list(e.db.plateInsideWas.keys())), 0)

    def test_a_reload_inside_still_puts_it_back_on_the_way_out(self):
        def inside(env):
            env.mock.state.instance = "party"
            env.mock.cvars[self.ONLY] = "1"
        e = Env(db="""{ v = 11, asked = true, enabled = true, plateInsideWas = {
            nameplateShowOnlyNameForFriendlyPlayerUnits = { was = "0", set = "1" }, junk = 5, [3] = {} } }""", setup=inside)
        self.assertEqual(sorted(e.db.plateInsideWas.keys()), sorted([self.COLOR, self.ONLY]))
        self.leave(e)
        self.assertEqual(self.now(e), ("0", "0", "1"))

        def hidden(env):                                             # switched off by the first try at this
            env.mock.cvars[self.SHOW] = "0"
        e = Env(db="{ v = 11, asked = true, enabled = true, plateFriendsWas = '1' }", setup=hidden)
        self.assertEqual(e.mock.cvars[self.SHOW], "1")               # put back, and forgotten
        self.assertIsNone(e.db.plateFriendsWas)

    def test_a_game_without_those_options_is_left_alone(self):
        def none(env):
            for name in (self.ONLY, self.COLOR, self.SHOW):
                env.mock.cvars[name] = None
                env.mock.knownCVars[name] = None
        e = Env(setup=none)
        self.assertIsNone(e.ns.Nameplates.FriendsCVar())
        e.cmd("platefriendshide on")
        self.enter(e)
        self.assertEqual(len(list(e.db.plateInsideWas.keys())), 0)
        e.lua.execute("""C_Console = { GetAllCommands = function() return {
            { command = "nameplateShowEnemies" }, { command = "nameplateFriendlyThing" }, { command = "cameraZoom" } } end }""")
        out = e.cmd("plates")
        self.assertIn("nameplateShowEnemies", out)                   # the report says which settings there are
        self.assertIn("nameplateFriendlyThing", out)
        self.assertNotIn("cameraZoom", out)
        self.assertEqual(e.errors(), [])


class HeldStill(unittest.TestCase):
    """A frame the game will not let addons move in a fight is asked about once, not every frame."""

    def hit(self, e):
        e.mock.logHit("SWING_DAMAGE", "player", "target", 1, True)

    def test_a_protected_frame_is_not_moved_in_a_fight(self):
        e = Env()
        e.target()
        v = e.frames.target.visual
        IM = e.ns.Impact
        e.mock.state.combat = True
        v.IsProtected = lambda *_: True                              # something of the game's hangs on it
        before = len(v.points)
        e.lua.execute("CALLS = 0")
        clear = v.ClearAllPoints
        v.ClearAllPoints = lambda self: (e.lua.execute("CALLS = CALLS + 1"), clear(self))[1]
        self.hit(e)
        e.update(0.5)
        self.assertEqual(e.g.CALLS, 0)                               # not once
        self.assertTrue(IM.held[v])
        e.mock.state.combat = False
        e.mock.fire("PLAYER_REGEN_ENABLED")
        self.assertIsNone(IM.held[v])
        self.hit(e)
        e.update(0.1)
        self.assertGreater(e.g.CALLS, 0)                             # out of a fight it shakes again
        self.assertEqual(e.errors(), [])

    def test_a_frame_the_game_refuses_is_left_for_the_rest_of_the_fight(self):
        e = Env()
        e.target()
        v = e.frames.target.visual
        IM = e.ns.Impact
        e.mock.state.combat = True
        self.hit(e)
        e.update(0.05)
        self.assertIsNotNone(IM.shaking[v])
        e.mock.fire("ADDON_ACTION_BLOCKED", "ControllerCam_HUD", "Frame:SetPoint()")
        self.assertTrue(IM.held[v])
        e.lua.execute("CALLS = 0")
        clear = v.ClearAllPoints
        v.ClearAllPoints = lambda self: (e.lua.execute("CALLS = CALLS + 1"), clear(self))[1]
        e.update(0.5)
        self.hit(e)
        e.update(0.3)
        self.assertEqual(e.g.CALLS, 0)                               # asked once: not again in this fight
        e.mock.fire("ADDON_ACTION_BLOCKED", "SomeOtherAddon", "Frame:SetPoint()")
        e.mock.state.combat = False
        e.mock.fire("PLAYER_REGEN_ENABLED")
        self.assertIsNone(IM.held[v])
        self.assertEqual(e.errors(), [])

    def test_bars_following_the_camera_wait_out_the_fight(self):
        e = Env()
        e.cmd("vertical on")
        f = e.frames.vertical
        v = f.visual
        e.update(0.5)
        e.mock.state.combat = True
        v.IsProtected = lambda *_: True
        v.baseX, v.baseY = 0, 0
        e.db.followRef = 10
        e.lua.execute("function GetCameraZoom() return 4 end")
        e.update(1)
        self.assertEqual((v.baseX, v.baseY), (0, 0))                 # held: nothing pretended
        self.assertEqual(e.errors(), [])


class Wards(unittest.TestCase):
    """A shield shows as a ward round the bar of whoever has it."""

    def friend(self, e, **kw):
        return e.target(attackable=False, reaction=5, isPlayer=True, health=400, healthMax=800, guid="Player-5", **kw)

    def log(self, e, sub, dest, spell):
        e.mock.logEntry = e.lua.table_from([e.mock.time, sub, False, "Player-9", "src", 0, 0, dest, "dst", 0, 0, spell,
                                            "Spell", 2])
        e.mock.fire("COMBAT_LOG_EVENT_UNFILTERED")

    def test_a_holy_shield_flares_holds_and_fades(self):
        e = Env()
        self.friend(e)
        e.mock.spellNames = e.lua.table_from({17: "Power Word: Shield"})
        e.mock.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 17)
        e.update(0.1)
        v = e.ns.Ward.frames[e.frames.target]
        self.assertTrue(v.glow.shown and v.top.shown and v.bottom.shown)
        self.assertEqual(v.school, "holy")
        gold = e.ns.Ward.COLOR.holy
        self.assertEqual([round(x, 2) for x in list(v.glow.vcolor.values())[:3]], [round(x, 2) for x in gold.values()])
        flare = v.glow.alpha
        self.assertGreater(v.flare, 0.5)                             # it flares as it lands
        e.update(1.5)
        self.assertEqual(v.flare, 0)
        self.assertEqual(v.a, 1)
        self.assertLess(v.glow.alpha, flare)                         # and settles to a quiet glow
        self.assertGreater(v.glow.alpha, 0.15)
        e.update(30)                                                 # its usual length
        self.assertEqual(v.a, 0)
        self.assertFalse(v.glow.shown or v.top.shown)
        self.assertEqual(e.errors(), [])

    def test_a_shield_of_ones_own_sits_on_its_caster(self):
        e = Env()
        self.friend(e)                                               # a friend targeted all the same
        e.mock.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 11426)   # Ice Barrier
        e.update(0.5)
        W = e.ns.Ward
        self.assertIsNone(W.On("target"))
        self.assertEqual(W.On("player").school, "frost")
        v = W.frames[e.frames.player]
        self.assertTrue(v.glow.shown)
        self.assertEqual(round(v.glow.vcolor[3], 2), 1)              # pale blue
        e.target(name="Raptor", guid="Creature-1")                   # an enemy targeted: a shield for a friend
        e.mock.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 17)      # lands on you
        self.assertEqual(W.On("player").school, "holy")
        self.assertIsNone(W.On("target"))

    def test_the_combat_log_says_when_it_lands_and_when_it_breaks(self):
        e = Env()
        e.target(name="Dark Priest", guid="Creature-7")
        self.log(e, "SPELL_AURA_APPLIED", "Creature-7", 17)          # an enemy shields itself: seen as well
        e.update(1)
        v = e.ns.Ward.frames[e.frames.target]
        self.assertEqual(v.a, 1)
        self.log(e, "SPELL_AURA_REMOVED", "Creature-7", 17)          # broken long before its time
        e.update(0.2)
        self.assertLess(v.a, 1)
        e.update(0.5)
        self.assertFalse(v.glow.shown)
        self.log(e, "SPELL_AURA_APPLIED", "Creature-7", 774)         # not a shield
        e.update(0.5)
        self.assertFalse(v.glow.shown)
        self.log(e, "SPELL_AURA_APPLIED", "Creature-8", 17)          # somebody else's
        e.update(0.5)
        self.assertFalse(v.glow.shown)
        e.target(name="Other", guid="Creature-8")                    # looked at later: the ward is there, no flare
        e.update(0.5)
        self.assertTrue(v.glow.shown)
        self.assertEqual(v.flare, 0)

    def test_other_ranks_go_by_the_name(self):
        e = Env()
        self.friend(e)
        e.mock.spellNames = e.lua.table_from({17: "Power Word: Shield", 10901: "Power Word: Shield"})
        e.mock.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 10901)
        self.assertEqual(e.ns.Ward.On("target").school, "holy")

    def test_off(self):
        e = Env()
        self.friend(e)
        e.mock.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 17)
        e.update(1)
        v = e.ns.Ward.frames[e.frames.target]
        self.assertTrue(v.glow.shown)
        e.cmd("wards off")
        self.assertFalse(v.glow.shown)
        e.mock.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 17)
        e.update(1)
        self.assertFalse(v.glow.shown)
        self.assertEqual(e.errors(), [])


class PartySecrets(unittest.TestCase):
    def test_secret_range_and_status_do_not_break_the_party_frames(self):
        e = Env()
        e.lua.execute("""
            UnitInRange = function() return { secret = true }, { secret = true } end
            UnitIsDeadOrGhost = function() return { secret = true } end
        """)
        e.mock.units.party1 = e.lua.table(name="Sel", health=50, healthMax=100, isPlayer=True, reaction=5)
        e.mock.fire("GROUP_ROSTER_UPDATE")
        e.update(1)
        self.assertEqual(e.errors(), [])


class Moments(unittest.TestCase):
    def env(self):
        def setup(env):
            env.mock.units.player["class"] = "PALADIN"
        e = Env(setup=setup)
        e.target()
        e.mock.spellNames = e.lua.table_from({20271: "Judgement", 679: "Holy Strike"})
        e.mock.fire("PLAYER_REGEN_DISABLED")
        return e

    def land(self, e, spell, amount=300, crit=False):
        e.mock.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", spell)
        e.mock.fire("UNIT_COMBAT", "target", "WOUND", "CRITICAL" if crit else "", amount, 2)

    def test_each_key_ability_has_its_feel(self):
        e = self.env()
        R = e.ns.Rumble
        self.land(e, 20271)
        self.assertEqual(R.last, "splash")                          # Judgement splashes
        e.update(2)
        self.land(e, 679)
        self.assertEqual(R.last, "strike")                          # Holy Strike snaps
        e.update(2)
        e.mock.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 635)    # not a key ability
        e.mock.fire("UNIT_COMBAT", "target", "WOUND", "", 100, 2)
        self.assertNotEqual(R.last, "splash")

    def test_back_to_back_crits_make_a_big_moment_rarely(self):
        e = self.env()
        M = e.ns.Moments
        self.land(e, 20271, 500, True)
        self.assertIsNone(M.live)                                   # one crit: felt, not pinned
        e.update(2)
        self.land(e, 679, 450, True)                                # back to back: the moment
        self.assertIsNotNone(M.live)
        self.assertEqual(M.frame.number.text, "450")
        self.assertEqual(M.frame.label.text, "Holy Strike")
        self.assertEqual(e.ns.Rumble.last, "moment")
        e.update(3)
        self.assertIsNone(M.live)                                   # slammed, held, gone
        self.land(e, 20271, 500, True)                              # again too soon: no
        self.assertIsNone(M.live)
        for _ in range(3):                                          # never more than twice a fight
            e.update(9)
            self.land(e, 20271, 500, True)
            self.land(e, 679, 500, True)
        self.assertEqual(M.fight.moments, 2)
        e.mock.fire("PLAYER_REGEN_DISABLED")                        # a new fight
        self.assertEqual(M.fight.moments, 0)

    def test_a_windfury_crit_from_the_log(self):
        e = self.env()
        e.mock.spellNames[25504] = "Windfury Attack"
        pg = e.g.UnitGUID("player")
        e.mock.logEntry = e.lua.table(e.mock.time, "SPELL_EXTRA_ATTACKS", False, pg, "me", 0, 0, "x", "x", 0, 0,
                                      25504, "Windfury Attack", 1, 1)
        e.mock.fire("COMBAT_LOG_EVENT_UNFILTERED")
        e.mock.logHit("SWING_DAMAGE", "player", "target", 1, True)
        self.assertIsNotNone(e.ns.Moments.live)
        self.assertEqual(e.ns.Moments.frame.label.text, "Windfury Attack")

    def test_big_moments_can_be_switched_off(self):
        e = self.env()
        e.cmd("bigmoments off")
        self.land(e, 20271, 500, True)
        e.update(1)
        self.land(e, 679, 450, True)
        self.assertIsNone(e.ns.Moments.live)
        self.assertEqual(e.ns.Rumble.last, "strike")                # still felt

    def test_moment_test(self):
        e = self.env()
        e.cmd("momenttest")
        self.assertIsNotNone(e.ns.Moments.live)
        self.assertEqual(e.errors(), [])


class StatValues(unittest.TestCase):
    def env(self, cls, level=60):
        def setup(env):
            env.mock.units.player["class"] = cls
            env.mock.units.player.level = level
        return Env(setup=setup)

    def test_what_stats_are_worth_by_class(self):
        e = self.env("HUNTER")
        A = e.ns.Stats.Annotate
        self.assertEqual(plain(A("+10 Agility")), "+10 Agility (+10 AP, +20 RAP, +0.19% crit, +0.38% dodge)")
        self.assertIn("|cffff9a4d+10 AP|r", A("+10 Agility"))           # each value in its own colour
        self.assertIn("|cff8fdc5a+20 RAP|r", A("+10 Agility"))
        self.assertEqual(plain(A("+10 Stamina")), "+10 Stamina (+100 health)")
        self.assertEqual(plain(A("+10 Intellect")), "+10 Intellect (+150 mana, +0.17% spell crit)")
        self.assertIsNone(A("Equip: Increases your chance to hit by 1%."))
        p = self.env("PALADIN")
        self.assertEqual(plain(p.ns.Stats.Annotate("+10 Strength")), "+10 Strength (+20 AP)")
        self.assertIn("+0.34% spell crit", p.ns.Stats.Annotate("+10 Intellect"))
        self.assertIn("+0.5% crit", p.ns.Stats.Annotate("+10 Agility"))
        w = self.env("WARRIOR")
        self.assertIsNone(w.ns.Stats.Annotate("+10 Intellect"))             # no mana: nothing to say
        self.assertIn("-20 AP", w.ns.Stats.Annotate("-10 Strength"))

    def test_lower_levels_need_fewer_points(self):
        e = self.env("PALADIN", level=30)
        self.assertIn("+1% crit", e.ns.Stats.Annotate("+10 Agility"))        # twice the share at level 30

    def test_the_tooltip_lines_get_their_worth_once(self):
        e = self.env("PALADIN")
        e.lua.execute("""
            local tip = CreateFrame("GameTooltip", "StatTip", UIParent)
            tip.NumLines = function() return 3 end
            for i = 1, 3 do _G["StatTipTextLeft" .. i] = tip:CreateFontString() end
            StatTipTextLeft1:SetText("Sword of Testing")
            StatTipTextLeft2:SetText("+12 Strength")
            StatTipTextLeft3:SetText("+5 Stamina")
            STAT_TIP = tip
        """)
        tip = e.g.STAT_TIP
        for fn in e.mock.tipCalls[e.g.Enum.TooltipDataType.Item].values():
            fn(tip, e.lua.table(id=1))
            fn(tip, e.lua.table(id=1))                               # twice: still once
        self.assertEqual(plain(e.g.StatTipTextLeft2.text), "+12 Strength (+24 AP)")
        self.assertEqual(plain(e.g.StatTipTextLeft3.text), "+5 Stamina (+50 health)")
        self.assertEqual(e.g.StatTipTextLeft1.text, "Sword of Testing")
        e.cmd("statvalues off")


class ClassIcons(unittest.TestCase):
    def test_players_wear_their_class_on_plates_friend_or_enemy(self):
        e = Env()
        T = e.lua.table
        friend = e.lua.table_from({"name": "Jaina", "level": 60, "health": 5, "healthMax": 5, "isPlayer": True,
                                   "attackable": False, "reaction": 5, "class": "MAGE"})
        foe = e.lua.table_from({"name": "Rexxar", "level": 60, "health": 5, "healthMax": 5, "isPlayer": True,
                                "attackable": True, "reaction": 2, "class": "HUNTER"})
        npc = T(name="Raptor", level=30, health=5, healthMax=5, attackable=True, reaction=2)
        o1 = e.ns.Nameplates.byPlate[e.mock.addPlate("nameplate1", friend)]
        o2 = e.ns.Nameplates.byPlate[e.mock.addPlate("nameplate2", foe)]
        o3 = e.ns.Nameplates.byPlate[e.mock.addPlate("nameplate3", npc)]
        self.assertTrue(o1.classIcon.shown)
        self.assertTrue(o2.classIcon.shown)
        self.assertEqual(o2.classIcon.texCoord[1], 0)               # the hunter's corner of the sheet
        self.assertTrue(o3.classIcon is None or not o3.classIcon.shown)
        e.cmd("plateclassicons off")
        self.assertFalse(o1.classIcon.shown)

    def test_on_again_once_and_no_preset_takes_them_away(self):
        e = Env(db="{ v = 6, classIcons = false }")
        self.assertTrue(e.db.classIcons)
        for name in ("minimal", "openworld", "adventure", "compass"):
            e.cmd("preset " + name)
            self.assertTrue(e.db.classIcons, name)
        e2 = Env(db="{ v = 7, classIcons = false }")
        self.assertFalse(e2.db.classIcons)                          # your own choice since: kept


class Inventory(unittest.TestCase):
    """Sorting with the game's own sort, and item counts across bags, bank and your other characters."""

    def env(self, db=None):
        e = Env(db=db)
        e.mock.put(0, 1, e.lua.table(id=2589, name="Linen Cloth", quality=1, price=13, count=20))
        e.mock.put(1, 3, e.lua.table(id=2589, name="Linen Cloth", quality=1, price=13, count=6))
        e.mock.fire("BAG_UPDATE_DELAYED")
        e.update(0.5)
        return e

    def test_your_bags_are_counted(self):
        e = self.env()
        rec = e.db.inventory["Ghostlight-Forever"]
        self.assertEqual(rec.bags[2589], 26)
        self.assertEqual(rec.money, 12345)
        self.assertEqual([plain(v) for v in e.mock.itemTooltip(2589)[1].values()], ["You", "Bag x26"])

    def test_the_bank_is_counted_while_it_is_open(self):
        e = self.env()
        e.mock.bags[-1] = e.lua.table()
        e.mock.put(-1, 1, e.lua.table(id=2589, name="Linen Cloth", quality=1, price=13, count=40))
        e.mock.openBank(True)
        e.update(0.5)
        e.mock.openBank(False)
        e.mock.bags[-1] = None                                       # closed: the game shows us nothing there
        e.mock.fire("BAG_UPDATE_DELAYED")
        e.update(0.5)
        self.assertEqual(e.db.inventory["Ghostlight-Forever"].bank[2589], 40)   # still remembered
        self.assertEqual([plain(v) for v in e.mock.itemTooltip(2589)[1].values()], ["You", "Bag x26  Bank x40"])

    def test_other_characters_and_the_total(self):
        e = self.env(db='{ v = 5, inventory = { ["Thrall-Forever"] = { class = "SHAMAN", money = 500, '
                        'bags = { [2589] = 4 }, bank = { [2589] = 10 } }, ["Empty-Forever"] = { bags = {}, bank = {} } } }')
        lines = [list(l.values()) for l in e.mock.itemTooltip(2589).values()]
        lines = [[plain(x) for x in l] for l in lines if l[0] not in ("Vendor", "Auction", "Best")]
        self.assertEqual(lines[0], ["You", "Bag x26  (x40)"])         # the total across your characters
        self.assertIn("Thrall", lines[1][0])                         # in the class colour
        self.assertEqual(lines[1][1], "Bag x4  Bank x10")
        self.assertEqual(len(lines), 2)                              # a character without any: not listed
        self.assertEqual(len(e.mock.itemTooltip(9999)), 0)
        out = e.cmd("gold")
        self.assertIn("Thrall", out)
        self.assertIn("1g 23s 45c".split()[0], out)                  # yours, and the total

    def test_counts_off_and_in_the_mouse_ui(self):
        e = self.env()
        e.cmd("invtotals off")
        self.assertNotIn("You", [list(l.values())[0] for l in e.mock.itemTooltip(2589).values()])
        e2 = Env(style="0")
        e2.mock.put(0, 1, e2.lua.table(id=2589, name="Linen Cloth", quality=1, price=13, count=2))
        e2.mock.fire("BAG_UPDATE_DELAYED")
        e2.update(0.5)
        self.assertEqual(e2.db.inventory["Ghostlight-Forever"].bags[2589], 2)    # still noted
        self.assertEqual(len(e2.mock.itemTooltip(2589)), 0)                      # but shown only in the HUD

    def test_sort(self):
        e = self.env()
        e.cmd("sort")
        self.assertEqual(list(e.mock.sorted.values()), ["bags"])
        self.assertIn("Bags sorted.", "\n".join(e.mock.printed.values()))
        e.mock.openBank(True)
        e.mock.printed = e.lua.table()
        e.g.ControllerCamHUD_Sort()                                  # the key binding, cursor nowhere: the bank
        self.assertEqual(list(e.mock.sorted.values()), ["bags", "bank"])
        self.assertIn("Press again to sort your bags", "\n".join(e.mock.printed.values()))
        e.g.ControllerCamHUD_Sort()                                  # pressed again soon: the bags
        self.assertEqual(list(e.mock.sorted.values()), ["bags", "bank", "bags"])
        e.mock.advance(5)
        e.g.ControllerCamHUD_Sort()                                  # later: the bank again
        self.assertEqual(list(e.mock.sorted.values())[-1], "bank")
        e.mock.advance(5)
        e.mock.focus = e.lua.eval('CreateFrame("Button", "BankFrameItem3", UIParent)')
        e.g.ControllerCamHUD_Sort()                                  # pointing into the bank: the bank
        e.g.ControllerCamHUD_Sort()                                  # and again (it says so: the bank)
        self.assertEqual(list(e.mock.sorted.values())[-2:], ["bank", "bank"])
        e.mock.focus = e.lua.eval('CreateFrame("Button", "ContainerFrame1Item2", UIParent)')
        e.g.ControllerCamHUD_Sort()                                  # in the bags: the bags
        self.assertEqual(list(e.mock.sorted.values())[-1], "bags")
        e.lua.execute("C_Container.SortBags = nil")
        self.assertIn("no bag sorting", e.cmd("sort"))

    def test_the_bank_sorts_the_current_way(self):
        e = self.env()
        e.lua.execute("""
            BANKSORTED = {}
            Enum.BankType = { Character = 0, Account = 2 }
            C_Container.SortBank = function(kind) table.insert(BANKSORTED, kind) end
            C_Container.SortBankBags = nil
            BankPanel = CreateFrame("Frame", "BankPanel", UIParent)
            BankPanel.GetActiveBankType = function() return 2 end
        """)
        e.mock.openBank(True)
        e.mock.focus = e.lua.eval('CreateFrame("Button", nil, BankPanel)')     # an unnamed slot in the bank
        e.g.ControllerCamHUD_Sort()
        self.assertEqual(list(e.g.BANKSORTED.values()), [2])                     # the tab you are on
        e.lua.execute("C_Container.SortBank = nil")
        self.assertIn("cannot be sorted", e.cmd("sort"))


class AuctionHouse(unittest.TestCase):
    def env(self):
        e = Env()
        e.mock.put(0, 1, e.lua.table(id=2589, name="Linen Cloth", quality=1, price=13, count=20, stack=20,
                                     **{"class": 7}))
        e.mock.put(0, 2, e.lua.table(id=2592, name="Wool Cloth", quality=1, price=33, count=5, stack=20,
                                     **{"class": 7}))
        return e

    def test_reads_the_whole_house_once_in_a_while(self):
        e = self.env()
        T = e.lua.table
        e.lua.execute("CanSendAuctionQuery = function() return true, true end; "
                      "QueryAuctionItems = function(...) QUERIED = {...} end")
        e.mock.auctions = T(*[T(id=2589, count=20, buyout=2000 + i) for i in range(900)])
        e.mock.fire("AUCTION_HOUSE_SHOW")
        e.update(1.2)
        self.assertTrue(e.g.QUERIED[7])                              # the "all at once" query
        e.mock.fire("AUCTION_ITEM_LIST_UPDATE")
        e.update(0.5)                                                # read a slice at a time
        self.assertEqual(e.db.auction[2589].p, 100)
        self.assertIn("again in", e.cmd("scan"))                     # not before the game allows it

    def test_the_best_use_of_an_item(self):
        e = self.env()
        M = e.ns.Market
        self.assertEqual(M.Verdict(2589), "vendor")                  # nothing seen at the auction house
        e.db.auction[2589] = e.lua.table(p=150, t=e.g.time())
        verdict, more = M.Verdict(2589)
        self.assertEqual(verdict, "auction")
        self.assertEqual(more, int(150 * 0.95 - 13 + 0.5))           # after the auction house's cut
        e.db.auction[2592] = e.lua.table(p=35, t=e.g.time())          # barely more than the vendor gives
        self.assertEqual(M.Verdict(2592), "vendor")
        e.db.sell.keep[2592] = True
        self.assertEqual(M.Verdict(2592), "keep")
        lines = [list(l.values()) for l in e.mock.itemTooltip(2589).values()]
        best = [l for l in lines if l[0] == "Best"][0]
        self.assertIn("Auction house", best[1])


class MarketPanel(unittest.TestCase):
    """The market beside the auction house: what to sell, for how much, where prices go, and posting."""

    def env(self):
        e = Env()
        T = e.lua.table
        e.mock.put(0, 1, T(id=2589, name="Linen Cloth", quality=1, price=13, count=20, stack=20, **{"class": 7}))
        e.mock.put(0, 2, T(id=2592, name="Wool Cloth", quality=1, price=33, count=5, stack=20, **{"class": 7}))
        e.mock.put(1, 1, T(id=2770, name="Copper Ore", quality=1, price=5, count=10, stack=20, **{"class": 7}))
        now, day = e.g.time(), e.ns.Market.Today()
        for i in range(1, 8):                                        # a week of history: usual 120 each
            e.db.auctionHistory[2589] = e.db.auctionHistory[2589] or T()
            e.db.auctionHistory[2589][i] = T(d=day - 8 + i, p=120)
        e.db.auction[2589] = T(p=150, t=now, n=3, q=60)            # today: higher than usual, few up
        e.db.auction[2592] = T(p=400, t=now, n=40, q=400)          # many up
        return e

    HOUSE = """
        AuctionHouseFrame = CreateFrame("Frame", "AuctionHouseFrame", UIParent)
        AuctionHouseFrame:SetSize(800, 538)
        AuctionHouseFrameTab1 = CreateFrame("Button", "AuctionHouseFrameTab1", AuctionHouseFrame)
        AuctionHouseFrameTab2 = CreateFrame("Button", "AuctionHouseFrameTab2", AuctionHouseFrame)
    """

    def house(self, e):
        e.lua.execute(self.HOUSE)
        e.mock.fire("AUCTION_HOUSE_SHOW")
        return e.ns.AuctionPanel

    def test_it_is_a_tab_of_the_auction_house(self):
        e = self.env()
        P = self.house(e)
        self.assertTrue(e.same(P.tab.parent, e.g.AuctionHouseFrame))
        self.assertTrue(e.same(P.tab.points[1][2], e.g.AuctionHouseFrameTab2))     # after the house's own tabs
        self.assertIsNone(P.view)                                    # the house opens as it always did
        self.assertEqual(len(list(e.mock.overrides.keys())), 0)      # no button is taken for it: L3 is your auto-run
        e.g.ControllerCamHUD_Market()
        self.assertTrue(P.view.shown)
        self.assertEqual(e.mock.overrides.PADDDOWN, "CLICK ControllerCamHUD_Key_Market_PADDDOWN:LeftButton")
        self.assertIsNone(e.mock.overrides.PADLSTICK)
        self.assertIsNone(e.mock.overrides.PADLTRIGGER)              # what it has no use for stays the game's
        self.assertIsNone(P.view.scripts.OnGamePadButtonDown)        # no press is caught and passed on
        down = e.g.ControllerCamHUD_Key_Market_PADDDOWN
        down.scripts.OnClick(down)
        self.assertEqual(P.index, 2)
        up = e.g.ControllerCamHUD_Key_Market_PADDUP
        up.scripts.OnClick(up)
        self.assertEqual(P.index, 1)
        self.assertTrue(e.same(P.view.parent, e.g.AuctionHouseFrame))
        self.assertEqual(P.perPage, 10)
        names = [plain(r.name.text) for r in P.rows.values() if r.shown]
        self.assertEqual(names, ["Linen Cloth x20", "Wool Cloth x5", "Copper Ore x10"])
        self.assertTrue(P.panel.shown)                               # the pane beside it, showing the first item
        self.assertTrue(e.same(P.panel.points[1][2], P.view))
        self.assertEqual(P.panel.title.text, "Linen Cloth")
        tab1 = e.g.AuctionHouseFrameTab1
        tab1.scripts.OnClick(tab1)                                   # one of the house's own tabs: the house again
        self.assertFalse(P.view.shown)
        self.assertFalse(P.panel.shown)
        self.assertEqual(len(list(e.mock.overrides.keys())), 0)      # and every button the game's again
        e.g.ControllerCamHUD_Market()
        e.mock.state.combat = True                                   # a fight: the buttons are yours at once
        e.mock.fire("PLAYER_REGEN_DISABLED")
        self.assertEqual(len(list(e.mock.overrides.keys())), 0)
        self.assertFalse(P.view.shown)
        e.mock.state.combat = False
        e.mock.fire("PLAYER_REGEN_ENABLED")
        self.assertEqual(len(list(e.mock.overrides.keys())), 0)
        e.g.ControllerCamHUD_Market()
        e.mock.fire("AUCTION_HOUSE_CLOSED")
        self.assertFalse(P.view.shown)
        self.assertEqual(len(list(e.mock.overrides.keys())), 0)
        self.assertEqual(e.errors(), [])

    def test_it_says_what_is_worth_selling_and_why(self):
        e = self.env()
        e.db.auction[2770] = e.lua.table(p=5, t=e.g.time(), n=9, q=90)    # copper ore: a vendor pays as much
        P = self.house(e)
        e.g.ControllerCamHUD_Market()
        rows = [r for r in P.rows.values() if r.shown]
        self.assertTrue(rows[0].mark.shown)                          # worth selling here
        self.assertIn("over a vendor", plain(rows[0].why.text))
        self.assertIn("few are up", plain(rows[0].why.text))         # and why this price
        self.assertFalse(rows[2].mark.shown)
        self.assertIn("a vendor pays as much", plain(rows[2].why.text))
        self.assertIn("2 worth selling here, 1 more", plain(P.view.status.text))
        self.assertIn("Auction house", plain(P.panel.best.text))
        self.assertIn("few are up", P.panel.why.text)

    def test_the_controller_chooses_and_posts(self):
        e = self.env()
        e.lua.execute("""
            POSTED = nil
            ClickAuctionSellItemButton = function() end
            PostAuction = function(bid, buyout, dur, stack, n) POSTED = { bid, buyout, dur, stack, n } end
            ClearCursor = function() end
            C_Container.PickupContainerItem = function() end
        """)
        P = self.house(e)
        e.g.ControllerCamHUD_Market()
        self.assertTrue(P.Pad(P, "PADDDOWN"))
        self.assertEqual(P.panel.title.text, "Wool Cloth")           # the pane follows
        self.assertTrue(P.rows[2].hl.shown)
        P.Pad(P, "PADDUP"); P.Pad(P, "PADDUP")
        self.assertEqual(P.index, 1)                                 # it stops at the ends
        self.assertTrue(P.Pad(P, "PAD3"))
        self.assertTrue(e.db.ahStrategy)                             # X: quick sale
        self.assertEqual(plain(P.view.strategy.text), "Quick sale")
        P.Pad(P, "PAD3")
        self.assertTrue(P.Pad(P, "PAD4"))
        self.assertEqual(e.db.ahDuration, 3)                         # Y: how long
        self.assertFalse(P.Pad(P, "PADLTRIGGER"))                    # not ours: the game's
        self.assertTrue(P.Pad(P, "PAD1"))                            # A: post
        self.assertEqual(list(e.g.POSTED.values())[1], 149 * 20)
        self.assertTrue(P.Pad(P, "PAD2"))                            # B: back to the house
        self.assertFalse(P.view.shown)
        self.assertFalse(P.Pad(P, "PAD1"))
        self.assertEqual(e.errors(), [])

    def test_pointing_at_a_row_chooses_it_and_pressing_it_posts(self):
        e = self.env()
        P = self.house(e)
        e.g.ControllerCamHUD_Market()
        row = P.rows[2]
        row.scripts.OnEnter(row)
        self.assertEqual(P.selected, 2592)
        self.assertEqual(P.panel.title.text, "Wool Cloth")

    def test_patient_and_quick_prices(self):
        e = self.env()
        M = e.ns.Market
        price, why = M.Suggest(2589, False)
        self.assertEqual(price, 149)                                  # just under the lowest: few are up
        price, _ = M.Suggest(2592, False)
        self.assertEqual(price, 396)                                  # a touch under: many are up
        price, _ = M.Suggest(2589, True)
        self.assertEqual(price, int(150 * 0.95))                      # quick sale: 5% under
        self.assertAlmostEqual(M.Trend(2589), 0.25)                   # 25% above its usual week
        e.db.auction[2589].p = 60                                     # the market dumped today
        price, why = M.Suggest(2589, False)
        self.assertEqual(price, 108)                                  # wait for buyers near the usual
        self.assertIn("unusually low", why)

    def test_never_below_what_a_vendor_pays(self):
        e = self.env()
        e.db.auction[2589].p = 10
        e.db.auctionHistory[2589] = None
        price, why = e.ns.Market.Suggest(2589, True)
        self.assertGreaterEqual(price * 0.95, 13)
        self.assertIn("vendor", why)

    def test_the_chart_and_the_trend(self):
        e = self.env()
        P = self.house(e)
        e.g.ControllerCamHUD_Market()
        bars = [b for b in P.panel.chart.bars.values() if b.shown]
        self.assertEqual(len(bars), 7)                                # a week of days
        self.assertTrue(P.panel.chart.usual.shown)                    # the usual price drawn across
        self.assertIn("^ 25%", plain(P.rows[1].trend.text))
        self.assertIn("^ 25%", plain(P.panel.facts.text))

    def test_posting_on_the_older_auction_house(self):
        e = self.env()
        e.lua.execute("""
            POSTED = nil
            ClickAuctionSellItemButton = function() end
            PostAuction = function(bid, buyout, dur, stack, n) POSTED = { bid, buyout, dur, stack, n } end
            ClearCursor = function() end
            C_Container.PickupContainerItem = function() end
        """)
        P = self.house(e)
        e.g.ControllerCamHUD_Market()
        self.assertIn("Post 20 for", plain(P.view.post.text))
        self.assertTrue(P.Post(P))
        posted = list(e.g.POSTED.values())
        self.assertEqual(posted[1], 149 * 20)                         # the buyout for the stack
        self.assertEqual(posted[2], 2)                                # 24 hours by default
        self.assertEqual(posted[3], 20)

    def test_history_is_kept_a_day_at_a_time(self):
        e = self.env()
        M = e.ns.Market
        M.Note(2770, 50)
        M.Note(2770, 40)                                              # lower the same day: kept
        M.Note(2770, 70)
        h = list(M.History(2770).values())
        self.assertEqual(len(h), 1)
        self.assertEqual(h[0].p, 40)


class ServiceKinds(unittest.TestCase):
    def test_the_job_in_the_name_counts_too(self):
        e = Env()
        npc = e.lua.table(name="Auctioneer Tricket", level=50, health=5, healthMax=5, attackable=False, reaction=5)
        o = e.ns.Nameplates.byPlate[e.mock.addPlate("nameplate1", npc)]
        self.assertEqual(o.serviceKind, "auction")
        self.assertTrue(o.service.shown)

    def test_each_kind_of_npc_has_its_icon(self):
        e = Env()
        K = e.ns.Nameplates.ServiceKind
        self.assertEqual(K("Banker")[0], "bank")
        self.assertEqual(K("<Guild Banker>")[0], "guildbank")
        self.assertEqual(K("Reagent Vendor")[0], "reagent")
        self.assertEqual(K("Flight Master")[0], "flight")
        self.assertEqual(K("Innkeeper")[0], "inn")
        self.assertEqual(K("Weaponsmith")[0], "repair")
        self.assertEqual(K("Mining Trainer")[0], "trainer")
        self.assertIsNone(K("Hand of Lordaeron"))
        self.assertTrue(K("Banker")[1].endswith("Tracking\Banker"))


class MarketAndItems(unittest.TestCase):
    """What things are worth, everything about an item, the stick buttons at the bags, sharing settings."""

    def env(self):
        e = Env()
        e.mock.put(0, 1, e.lua.table(id=2589, name="Linen Cloth", quality=1, price=13, count=20, stack=20,
                                     ilvl=5, **{"class": 7}))
        e.mock.fire("BAG_UPDATE_DELAYED")
        e.update(0.5)
        return e

    def lines(self, e, id):
        return [list(l.values()) for l in e.mock.itemTooltip(id).values()]

    def test_vendor_price_each_and_for_a_stack(self):
        e = self.env()
        self.assertIn(["Vendor", "13c   2s 60c x20"], [[plain(x) for x in l] for l in self.lines(e, 2589)])
        e.cmd("vendorprice off")
        self.assertNotIn("Vendor", [l[0] for l in self.lines(e, 2589)])

    def test_auction_prices_are_noted_from_what_you_browse(self):
        e = self.env()
        T = e.lua.table
        e.mock.auctions = T(T(id=2589, count=20, buyout=4000), T(id=2589, count=5, buyout=750),
                            T(id=2589, count=1, buyout=0))                       # no buyout: left out
        e.mock.fire("AUCTION_ITEM_LIST_UPDATE")
        self.assertEqual(e.db.auction[2589].p, 150)                              # the lowest each: 1s 50c
        line = [l for l in self.lines(e, 2589) if l[0] == "Auction"][0]
        self.assertIn("1s 50c   30s x20", plain(line[1]))
        self.assertIn("just now", line[1])
        e2 = Env(db=e.mock.serialize(e.g.ControllerCamHUDDB))                    # remembered
        self.assertEqual(e2.db.auction[2589].p, 150)

    def test_the_item_details_window(self):
        e = self.env()
        e.mock.pointAt(0, 1)
        e.g.ControllerCamHUD_ItemInfo()                                           # the key binding
        IN = e.ns.ItemInfo
        self.assertTrue(IN.frame.shown)
        self.assertEqual(IN.shown, 2589)
        rows = [(r.left.text, r.right.text) for r in IN.frame.rows.values() if r.left.shown]
        self.assertIn(("Item ID", "2589"), rows)
        self.assertIn(("Stacks to", "20"), rows)
        self.assertIn(("You", "Bag x20"), [(plain(a), plain(b)) for a, b in rows])
        self.assertIn(("Auction", "not seen yet"), rows)
        self.assertIn(("Your mark", "none"), rows)
        e.g.ControllerCamHUD_ItemInfo()                                           # again: closes
        self.assertFalse(IN.frame.shown)
        e.cmd("item 2589")
        self.assertTrue(IN.frame.shown)
        self.assertEqual(e.errors(), [])

    def test_stick_buttons_only_while_the_windows_are_open(self):
        e = self.env()
        e.update(0.5)
        self.assertEqual(len(list(e.mock.overrides.keys())), 0)                  # R3 and L3 are yours
        e.g.ContainerFrame1.Show(e.g.ContainerFrame1)
        e.update(0.5)
        self.assertEqual(e.mock.overrides.PADRSTICK, "CCHUD_SORT")
        self.assertIsNone(e.mock.overrides.PADLSTICK)
        e.mock.openBank(True)
        e.update(0.5)
        self.assertEqual(e.mock.overrides.PADRSTICK, "CLICK ControllerCamHUD_StickKey:LeftButton")
        self.assertIsNone(e.mock.overrides.PADLSTICK)                             # L3 is never taken: your auto-run
        stick = e.g.ControllerCamHUD_StickKey
        said = len(e.mock.printed)
        stick.scripts.OnClick(stick)                                              # pointing at nothing: it sorts
        self.assertIn("sorted", list(e.mock.printed.values())[-1])
        self.assertIsNone(e.mock.usedItem)
        e.mock.pointAt(0, 1)
        stick.scripts.OnClick(stick)                                              # pointing at an item: it moves
        self.assertEqual(list(e.mock.moved.values()), [2589])
        e.mock.pointAt(None)
        e.cmd("padsort off")                                                      # no sorting: it asks for an item
        e.update(0.5)
        stick.scripts.OnClick(stick)
        self.assertIn("Point at an item", list(e.mock.printed.values())[-1])
        e.cmd("padsort on")
        e.mock.openBank(False)
        e.g.ContainerFrame1.Hide(e.g.ContainerFrame1)
        e.update(0.5)
        self.assertEqual(len(list(e.mock.overrides.keys())), 0)                  # given back
        e.cmd("padsort off")
        e.g.ContainerFrame1.Show(e.g.ContainerFrame1)
        e.update(0.5)
        self.assertIsNone(e.mock.overrides.PADRSTICK)

    def test_quick_move_hands_items_over_in_a_trade_and_at_the_mailbox(self):
        e = self.env()
        e.mock.pointAt(0, 1)
        e.g.ControllerCamHUD_QuickMove()
        self.assertIsNone(e.mock.usedItem)                                        # nowhere to move it to
        for opened, closed in (("TRADE_SHOW", "TRADE_CLOSED"), ("MAIL_SHOW", "MAIL_CLOSED")):
            e.mock.usedItem = None
            e.mock.fire(opened)
            e.update(0.5)
            self.assertEqual(e.mock.overrides.PADRSTICK, "CLICK ControllerCamHUD_StickKey:LeftButton")
            self.assertIsNone(e.mock.overrides.PADLSTICK)
            e.g.ControllerCamHUD_QuickMove()
            self.assertEqual(e.mock.usedItem, 2589, opened)                       # the game puts it in
            e.mock.fire(closed)
            e.update(0.5)
            self.assertIsNone(e.mock.overrides.PADRSTICK)

    def test_settings_go_out_and_come_back(self):
        e = Env()
        e.cmd("preset arpg")
        e.db.sell.junk[1234] = True
        text = e.ns.Share.Export()
        self.assertTrue(text.startswith("CCHUD1:"))
        e2 = Env()
        taken, skipped = e2.ns.Share.Import(text)
        self.assertGreater(taken, 50)
        self.assertEqual(skipped, 0)
        for key in ("plateMini", "plateSubtitles", "plateTitles", "presetZoom", "xpScale", "idle"):
            self.assertEqual(e2.db[key], e.db[key], key)
        self.assertEqual(e2.db.pos.player.x, e.db.pos.player.x)
        self.assertTrue(e2.db.sell.junk[1234])

    @staticmethod
    def game(layouts, camera=True):
        """The game's Edit Mode with these layouts of your own, and (or not) the camera addon."""
        def setup(env):
            env.lua.globals().MOCK = env.mock
            env.lua.execute("""
                MOCK.layouts = %s
                Enum.EditModeLayoutType = { Preset = 0, Account = 1, Character = 2 }
                C_EditMode = {
                    GetLayouts = function() return MOCK.layouts end,
                    SaveLayouts = function(all) MOCK.layouts = all; MOCK.layoutsWritten = (MOCK.layoutsWritten or 0) + 1 end,
                    SetActiveLayout = function(index) MOCK.layoutChosen = index end,
                    ConvertLayoutInfoToString = function(info) return info.text end,
                    ConvertStringToLayoutInfo = function(text)
                        if text:find("broken") then error("not a layout") end
                        return { text = text }
                    end,
                }""" % layouts)
            if camera:
                env.lua.execute("""ControllerCam = {
                    ExportSetup = function() return "CCS1:camera setup|100%" end,
                    ImportSetup = function(text)
                        if MOCK.cameraRefuses then return nil, "No." end
                        MOCK.cameraGot = text
                        return true
                    end }""")
        return setup

    MINE = '{ activeLayout = 3, layouts = { { layoutName = "Mine", layoutType = 1, text = "1 39 0 UIParent 0.0 45.0 |x~y%" } } }'
    NONE = "{ activeLayout = 1, layouts = {} }"

    def import_all(self, e, text):
        r = e.lua.eval("function(sh, s) local got, why = sh.ImportAll(s); return { got = got, why = why } end")(
            e.ns.Share, text)
        return r["got"], r["why"]

    def test_the_whole_setup_is_one_line(self):
        e = Env(setup=self.game(self.MINE))
        e.cmd("preset arpg")
        text = e.ns.Share.ExportAll()
        self.assertRegex(text, r"^CCUI1:[0-9a-f]{8}:hud=CCHUD1:")
        self.assertNotRegex(text, r"\s")                                           # nothing a paste could break
        self.assertNotIn("debug=", text)                                          # debug mode stays on your machine
        for part in ("|cam=", "|layname=Mine|", "|lay=1~39~0~UIParent"):
            self.assertIn(part, text)

        other = Env(setup=self.game(self.NONE), db="{ v = 8, debug = false }")
        got, why = self.import_all(other, text[:60] + "\n  " + text[60:] + "\r\n")
        self.assertIsNone(why)
        self.assertGreater(got.taken, 50)
        self.assertEqual(got.skipped, 0)
        self.assertTrue(other.db.plateMini)                                       # the HUD's settings
        self.assertEqual(other.db.pos.player.x, e.db.pos.player.x)
        self.assertFalse(other.db.debug)
        self.assertTrue(got.camera)                                               # the camera's, as it wrote them
        self.assertEqual(other.mock.cameraGot, "CCS1:camera setup|100%")
        self.assertEqual(got.layout, "Mine")                                      # and the game's layout
        saved = other.mock.layouts
        self.assertEqual(saved.layouts[1].text, "1 39 0 UIParent 0.0 45.0 |x~y%")
        self.assertEqual((saved.layouts[1].layoutName, saved.layouts[1].layoutType), ("Mine", 1))
        self.assertEqual((saved.activeLayout, other.mock.layoutChosen), (1, None))   # added; choosing it is yours
        self.import_all(other, text)                                              # again: yours of that name is replaced
        self.assertEqual(len(list(other.mock.layouts.layouts.values())), 1)
        self.assertEqual(other.errors(), [])

    def test_a_built_in_layout_is_chosen_by_name(self):
        e = Env(setup=self.game("{ activeLayout = 2, layouts = {} }", camera=False))
        text = e.ns.Share.ExportAll()
        self.assertIn("|game=classic", text)
        self.assertNotIn("cam=", text)                                            # no camera addon: no such part
        other = Env(setup=self.game(self.MINE, camera=False))
        got, _ = self.import_all(other, text)
        self.assertEqual(got.layout, False)                                       # a built-in one is yours to choose
        self.assertIsNone(other.mock.layoutSelected)                              # (the game refuses it to addons)
        self.assertIsNone(got.camera)
        self.assertIsNone(other.mock.layoutsWritten)                              # your own layouts are not touched

    def test_a_line_that_is_cut_or_changed_changes_nothing(self):
        e = Env(setup=self.game(self.MINE))
        text = e.ns.Share.ExportAll()
        other = Env(setup=self.game(self.NONE))
        before = other.ns.Share.Export()
        for bad, reason in ((text[:-3], "damaged"), (text.replace("b1", "b0", 1), "damaged"),
                            (text.replace("CCUI1", "CCUI2", 1), "newer"), ("CCUI1:zz", None), ("hello", None),
                            ("CCUI1:%s:cam=x" % e.ns.Share.Sum("cam=x"), None)):
            got, why = self.import_all(other, bad)
            self.assertIsNone(got, bad[:40])
            self.assertEqual(why, reason, bad[:40])
        self.assertEqual(other.ns.Share.Export(), before)
        self.assertIsNone(other.mock.cameraGot)
        self.assertIsNone(other.mock.layoutsWritten)
        got, _ = self.import_all(other, e.ns.Share.Export())                      # the HUD's settings alone still work
        self.assertGreater(got.taken, 50)
        self.assertIsNone(got.camera)
        self.assertIsNone(got.layout)

    def test_what_could_not_be_taken_is_said(self):
        five = ", ".join('{ layoutName = "L%d", layoutType = 1, text = "t" }' % i for i in range(5))
        e = Env(setup=self.game(self.MINE))
        text = e.ns.Share.ExportAll()
        other = Env(setup=self.game("{ activeLayout = 1, layouts = { %s } }" % five))
        other.mock.cameraRefuses = True
        other.ns.Share.text = text
        box = other.lua.eval("function(sh) return { GetText = function() return sh.text end } end")(other.ns.Share)
        said = len(other.mock.printed)
        other.ns.Share.FromBox(box)
        heard = "\n".join(list(other.mock.printed.values())[said:])
        self.assertIn("Settings imported", heard)
        self.assertIn("The camera setup was left as it is. No.", heard)
        self.assertIn("The game's layout was left as it is.", heard)              # the game keeps five of yours
        self.assertEqual(len(list(other.mock.layouts.layouts.values())), 5)
        self.assertIsNone(other.mock.layoutsWritten)

        fine = Env(setup=self.game(self.NONE))
        fine.ns.Share.text = text
        said = len(fine.mock.printed)
        fine.ns.Share.FromBox(fine.lua.eval("function(sh) return { GetText = function() return sh.text end } end")(
            fine.ns.Share))
        heard = "\n".join(list(fine.mock.printed.values())[said:])
        self.assertIn("The camera setup came along.", heard)
        self.assertIn("A layout named 'Mine' was added to the game's Edit Mode", heard)
        fine.ns.Share.text = text[:-2]
        fine.ns.Share.FromBox(fine.lua.eval("function(sh) return { GetText = function() return sh.text end } end")(
            fine.ns.Share))
        self.assertIn("damaged", list(fine.mock.printed.values())[-1])

    def test_the_games_layout_is_left_alone_in_combat_or_when_it_refuses(self):
        e = Env(setup=self.game(self.NONE))
        self.assertEqual(e.ns.Share.SetLayout("Mine", "a broken layout"), False)  # the game does not accept it
        self.assertEqual(e.ns.Share.SetLayout("Mine", "line\nbreak"), False)
        e.mock.state.combat = True
        self.assertEqual(e.ns.Share.SetLayout("Mine", "1 2 3"), False)
        self.assertIsNone(e.mock.layoutsWritten)
        e.mock.state.combat = False
        mixed = Env(setup=self.game('{ activeLayout = 1, layouts = { { layoutName = "A", layoutType = 1, text = "a" },'
                                    ' { layoutName = "Hunter", layoutType = 2, text = "c" } } }'))
        ok, name, switched = mixed.ns.Share.SetLayout("|cffff0000Red", "1 2 3")
        self.assertTrue(ok)
        self.assertFalse(switched)                                                # added, not chosen
        self.assertNotIn("|", name)
        names = [l.layoutName for l in mixed.mock.layouts.layouts.values()]
        self.assertEqual(names, ["A", name, "Hunter"])                            # with the account's, before a character's
        self.assertIsNone(mixed.mock.layoutChosen)
        bare = Env()                                                              # a client without these functions
        self.assertIsNone(bare.ns.Share.Layout())
        self.assertEqual(bare.ns.Share.SetLayout("Mine", "1 2 3"), False)
        self.assertRegex(bare.ns.Share.ExportAll(), r"^CCUI1:[0-9a-f]{8}:hud=CCHUD1:[^|]+$")

    def test_import_takes_only_what_it_knows(self):
        e = Env()
        taken, skipped = e.ns.Share.Import("CCHUD1:plateTitles=b0;xpScale=n99;nonsense=b1;units.vertical=n3;"
                                           "pos.player.x=n10;sell.junk.77=b1")
        self.assertEqual((taken, skipped), (4, 2))
        self.assertFalse(e.db.plateTitles)
        self.assertEqual(e.db.xpScale, 1.2)                                       # held to its range
        self.assertIsNone(e.db.nonsense)
        self.assertIsNone(e.db.pos.player)                                        # half a position: dropped
        self.assertIsNone(e.ns.Share.Import("hello"))
        self.assertIn("export", e.cmd("help"))


class Skin(unittest.TestCase):
    """The game's own frames in the HUD's look, and back exactly as they were."""

    BUTTON = "GamepadMainActionBarFramePageUnitTopCenteredAnchorTopBarActionButton1"

    def test_dressed_while_the_hud_runs(self):
        e = Env()
        g, S = e.g, e.ns.Skin
        self.assertTrue(S.active)
        self.assertGreater(S.dressed, 0)
        b = g[self.BUTTON]
        self.assertEqual(b.NormalTexture.alpha, 0)                          # the gold art goes
        self.assertTrue(S.added[b].ring.shown)                              # a slim ring
        self.assertTrue(S.added[b].disc.shown)                              # on a dark backing
        self.assertEqual(b.Name.fontFlags, "OUTLINE")
        bar = g.GamepadMainActionBarFramePageUnitTopCenteredAnchorTopBar
        self.assertEqual(bar.BackgroundWatermark.alpha, 0)
        self.assertEqual(bar.BackgroundFocus.alpha, 1)                      # the mark of the active set stays
        self.assertEqual(g.GameTooltip.NineSlice.alpha, 0)                  # tooltips: our glass instead
        self.assertTrue(S.added[g.GameTooltip].panel.back.shown)
        self.assertEqual(g.GameTooltipText.fontFlags, "OUTLINE")
        self.assertEqual(g.MinimapCompassTexture.alpha, 0)
        self.assertTrue(S.added[g.Minimap].ring.shown)
        self.assertTrue(S.added[g.Minimap].ring.texture.endswith("mapring"))   # the large, clean ring
        self.assertEqual(S.added[b].ring.texture, e.ns.media.ring)              # buttons keep the small one
        self.assertEqual(g.ObjectiveTrackerFrame.Header.Background.alpha, 0)
        self.assertEqual(g.ObjectiveTrackerHeaderFont.fontFlags, "OUTLINE")
        self.assertEqual(g.ChatFrame1EditBoxLeft.alpha, 0)
        self.assertEqual(e.errors(), [])

    def test_new_buffs_are_dressed_as_they_come(self):
        e = Env()
        b = e.mock.addBuff()
        self.assertNotIn(b, list(e.ns.Skin.added.keys()))
        e.update(0.6)
        self.assertEqual(b.Icon.texCoord[1], 0.08)                          # cropped
        self.assertEqual(b.Duration.fontFlags, "OUTLINE")
        self.assertTrue(e.ns.Skin.added[b].panel.edges[1].shown)            # edged

    def test_everything_goes_back(self):
        e = Env()
        g = e.g
        b = g[self.BUTTON]
        for cmd in ("skin off", "skin on", "off"):                          # off, again, and the HUD stopping
            e.cmd(cmd)
            if cmd == "skin on":
                self.assertEqual(b.NormalTexture.alpha, 0)
                continue
            e.update(0.3)
            self.assertEqual(b.NormalTexture.alpha, 1, cmd)
            self.assertFalse(e.ns.Skin.added[b].ring.shown)
            # the game's own tooltip background is back: as see-through as tooltips are set to be while the HUD
            # runs, and exactly the game's when it stops
            self.assertAlmostEqual(g.GameTooltip.NineSlice.alpha, 1 if cmd == "off" else 0.4)
            self.assertEqual(g.GameTooltipText.fontFlags, "")
            self.assertEqual(g.GameTooltipText.fontSize, 12)
            self.assertEqual(g.MinimapCompassTexture.alpha, 1)
            self.assertEqual(g.GamepadMainActionBarFramePageUnitTopCenteredAnchorTopBar.BackgroundWatermark.alpha, 1)
            self.assertEqual(e.errors(), [])

    def test_mouse_ui_keeps_the_games_look(self):
        e = Env(style="0")
        self.assertFalse(e.ns.Skin.active)
        self.assertEqual(e.g[self.BUTTON].NormalTexture.alpha, 1)

    def test_one_area_off(self):
        e = Env()
        e.cmd("skinminimap off")
        self.assertEqual(e.g.MinimapCompassTexture.alpha, 1)
        self.assertEqual(e.g[self.BUTTON].NormalTexture.alpha, 0)          # the rest stays dressed

    def test_with_slim_bars_the_art_comes_back_only_when_both_let_go(self):
        e = Env()
        watermark = e.g.GamepadMainActionBarFramePageUnitTopCenteredAnchorTopBar.BackgroundWatermark
        e.cmd("bars on")
        e.cmd("skin off")
        e.update(0.6)
        self.assertEqual(watermark.alpha, 0)                                # slim bars still hide it
        e.cmd("bars off")
        self.assertEqual(watermark.alpha, 1)

    def test_a_missing_area_is_skipped(self):
        def setup(env):
            env.lua.execute("Minimap = nil; BuffFrame = nil; ObjectiveTrackerFrame = nil")
        e = Env(setup=setup)
        self.assertEqual(e.ns.Skin.found.minimap, 0)
        self.assertGreater(e.ns.Skin.dressed, 0)
        self.assertEqual(e.errors(), [])


class SlimBars(unittest.TestCase):
    def art(self, e):
        bar = e.g.GamepadMainActionBarFramePageUnitTopCenteredAnchorTopBar
        return bar.BackgroundWatermark, bar.BackgroundFocus, e.g.GamepadMainActionBarFramePageUnit.LeftShoulderBackground

    def test_off_by_default(self):
        e = Env(db="{ skin = false }")                 # the slim bars alone (no restyle)
        self.assertEqual([t.alpha for t in self.art(e)], [1, 1, 1])
        self.assertEqual(e.g.GamepadMainActionBarFrame.scale, 1)

    def test_art_goes_and_the_cluster_shrinks(self):
        e = Env(db="{ skin = false }")                 # the slim bars alone (no restyle)
        e.cmd("bars on")
        watermark, focus, shoulder = self.art(e)
        self.assertEqual((watermark.alpha, shoulder.alpha), (0, 0))
        self.assertEqual(focus.alpha, 1)                            # the mark of the active set stays
        self.assertEqual(e.g.GamepadMainActionBarFrame.scale, 0.85)
        self.assertIn("70%", e.cmd("barscale 70"))
        self.assertAlmostEqual(e.g.GamepadMainActionBarFrame.scale, 0.7)
        watermark.alpha = 1                                         # the game showed it again
        e.update(0.6)
        self.assertEqual(watermark.alpha, 0)
        self.assertEqual(e.ns.RunCheck(False)[0], 0)

    def test_off_and_edit_mode_put_it_all_back(self):
        e = Env(db="{ skin = false }")                 # the slim bars alone (no restyle)
        e.g.GamepadMainActionBarFrame.scale = 1.1                   # the player's own size
        e.cmd("bars on")
        self.assertAlmostEqual(e.g.GamepadMainActionBarFrame.scale, 1.1 * 0.85)
        e.mock.editMode(True)
        self.assertEqual([t.alpha for t in self.art(e)], [1, 1, 1])
        self.assertAlmostEqual(e.g.GamepadMainActionBarFrame.scale, 1.1)
        e.mock.editMode(False)
        self.assertEqual(self.art(e)[0].alpha, 0)
        e.cmd("off")
        self.assertEqual([t.alpha for t in self.art(e)], [1, 1, 1])
        self.assertAlmostEqual(e.g.GamepadMainActionBarFrame.scale, 1.1)

    def test_a_client_without_the_bars(self):
        e = Env(setup=lambda env: env.lua.execute("GamepadMainActionBarFrame = nil"))
        e.cmd("bars on")
        self.assertFalse(e.ns.Bars.active)
        self.assertEqual(e.errors(), [])


class OptionsPanel(unittest.TestCase):
    def rows(self, e):
        e.ns.BuildOptions()
        return {r["def"].label: r for r in e.ns.optionRows.values()}

    def click(self, e, row, checked):
        w = row.widget
        w.checked = checked
        w.scripts.OnClick(w)

    def test_every_setting_has_a_row(self):
        e = Env()
        rows = self.rows(e)
        labels = [d.label for d in e.ns.settings.values() if d.label]
        self.assertEqual(len(rows), len(labels))
        self.assertEqual(len(set(labels)), len(labels))            # no two rows with the same name
        for name in ("Enabled", "Player frame", "Party and raid frames", "Cast bar", "Nameplates",
                     "Quest list: current zone only", "Slim gamepad bars", "Sell junk when a vendor opens",
                     "Cooldown Manager", "Text size"):
            self.assertIn(name, rows)
        self.assertEqual(e.mock.category.name, "ControllerCam HUD")
        self.assertEqual(e.errors(), [])

    def test_rows_do_what_the_commands_do(self):
        e = Env()
        rows = self.rows(e)
        self.assertTrue(rows["Party and raid frames"].widget.checked)
        self.click(e, rows["Party and raid frames"], False)
        self.assertFalse(e.db.group)
        self.assertEqual(e.g.PartyFrame.alpha, 1)
        self.click(e, rows["Player frame"], False)
        self.assertFalse(e.frames.player.button.shown)
        self.assertEqual(e.aside("PlayerFrame"), False)
        self.click(e, rows["Sell junk when a vendor opens"], True)
        self.assertTrue(e.db.sell.auto)
        s = rows["Player bar when idle"].widget
        s.scripts.OnValueChanged(s, 60)
        self.assertAlmostEqual(e.db.idle, 0.6)
        self.assertIn("60%", rows["Player bar when idle"].label.text)
        s = rows["Text size"].widget
        s.scripts.OnValueChanged(s, 140)
        self.assertAlmostEqual(e.frames.target.name.fontSize, 13 * 1.4)

    def test_game_options_are_the_games(self):
        e = Env()
        rows = self.rows(e)
        self.assertFalse(rows["Personal Resource Display"].widget.checked)
        self.click(e, rows["Personal Resource Display"], True)
        self.assertEqual(e.mock.cvars.nameplateShowSelf, "1")
        self.click(e, rows["Target of target"], False)
        self.assertEqual(e.mock.cvars.showTargetOfTarget, "0")
        e.mock.cvars.cooldownViewerEnabled = "0"                    # changed in the game's own menu
        e.ns.RefreshOptions()
        self.assertFalse(rows["Cooldown Manager"].widget.checked)

    def test_the_panel_follows_changes_made_elsewhere(self):
        e = Env()
        rows = self.rows(e)
        e.cmd("castbar off")
        e.cmd("scale 150")
        e.ns.RefreshOptions()
        self.assertFalse(rows["Cast bar"].widget.checked)
        self.assertEqual(rows["Frame size"].widget.value, 150)

    def test_a_missing_game_option_is_greyed_out(self):
        e = Env()
        e.mock.cvars.nameplateShowSelf = None
        rows = self.rows(e)
        self.assertFalse(rows["Personal Resource Display"].widget.enabled)
        self.assertTrue(rows["Target of target"].widget.enabled)

    def test_config_command_and_help(self):
        e = Env()
        e.cmd("config")
        self.assertEqual(e.mock.opened, 42)
        out = e.cmd("help")
        for word in ("/cchud group", "/cchud castbar", "/cchud nameplates", "/cchud questzone", "/cchud bars",
                     "/cchud barscale <60-120>", "/cchud config"):
            self.assertIn(word, out)


class TooltipAtCursor(unittest.TestCase):
    def test_tooltips_follow_the_cursor_while_the_hud_runs(self):
        e = Env()
        e.g.GameTooltip_SetDefaultAnchor(e.g.GameTooltip, e.g.UIParent)
        self.assertEqual(e.g.GameTooltip.anchor, "ANCHOR_CURSOR_RIGHT")
        e.mock.state.combat = True                                         # in a fight: the corner
        e.g.GameTooltip_SetDefaultAnchor(e.g.GameTooltip, e.g.UIParent)
        self.assertEqual(e.g.GameTooltip.anchor, "ANCHOR_NONE")
        e.mock.state.combat = False
        e.cmd("tooltipcursor off")
        e.g.GameTooltip_SetDefaultAnchor(e.g.GameTooltip, e.g.UIParent)
        self.assertEqual(e.g.GameTooltip.anchor, "ANCHOR_NONE")          # the game's corner again
        e.cmd("tooltipcursor on")
        e.cmd("off")
        e.g.GameTooltip_SetDefaultAnchor(e.g.GameTooltip, e.g.UIParent)
        self.assertEqual(e.g.GameTooltip.anchor, "ANCHOR_NONE")
        e2 = Env(style="0")                                                # mouse & keyboard UI: the game's way
        e2.g.GameTooltip_SetDefaultAnchor(e2.g.GameTooltip, e2.g.UIParent)
        self.assertEqual(e2.g.GameTooltip.anchor, "ANCHOR_NONE")


class SizedForTheScreen(unittest.TestCase):
    """Text you can read from the couch, or at a desk."""

    def test_chat_text_is_bigger_and_given_back(self):
        e = Env()
        frames = [e.g["ChatFrame%d" % i] for i in (1, 2, 3)]
        self.assertTrue(all(f.fontSize == 18 for f in frames))      # 150% of the game's 12
        self.assertIn("200", e.cmd("chatsize 200"))
        self.assertEqual(frames[0].fontSize, 24)
        frames[0].SetFont(frames[0], "Fonts\\FRIZQT__.TTF", 14, "")  # you change the game's own setting
        e.mock.fire("UPDATE_CHAT_WINDOWS")
        self.assertEqual(frames[0].fontSize, 28)                    # ours goes by the new one
        e.cmd("off")
        self.assertEqual((frames[0].fontSize, frames[1].fontSize), (14, 12))    # off: exactly what the game had
        e.cmd("on")
        self.assertEqual(frames[1].fontSize, 24)
        mouse = Env(style="0")                                      # not while the HUD is not running
        self.assertIn(mouse.g.ChatFrame1.fontSize, (None, 12))
        self.assertIsNone(mouse.ns.Chat.sized[mouse.g.ChatFrame1])
        placed = Env(db="{ v = 8, pos = { vertical = { x = -460, y = -20 }, target = { x = -460, y = 5 } } }")
        self.assertEqual(placed.db.pos.vertical.x, -280)            # the bars' old starting spot comes in once
        newer = Env(db="{ v = 10, pos = { vertical = { x = -320, y = -30 } } }")
        self.assertEqual(newer.db.pos.vertical.x, -280)             # and the one after it, once more
        own = Env(db="{ v = 10, pos = { vertical = { x = -333, y = -30 } } }")
        self.assertEqual(own.db.pos.vertical.x, -333)               # bars you placed yourself stay
        self.assertEqual(placed.db.pos.target.x, -460)              # (nothing else is touched)
        self.assertEqual(e.errors(), [])

    def test_sized_for_a_tv_or_a_monitor(self):
        e = Env()
        self.assertEqual((e.db.textScale, e.db.chatScale, e.db.castScale), (1.5, 1.5, 1.35))   # a TV to begin with
        self.assertEqual(e.ns.CastBar.frame.scale, 1.35)                        # the cast bar, large enough to read
        self.assertIn("monitor", e.cmd("sizefor monitor"))
        self.assertEqual((e.db.textScale, e.db.chatScale, e.db.castScale, e.db.sizedFor), (1, 1, 1, "monitor"))
        self.assertEqual(e.ns.CastBar.frame.scale, 1)
        self.assertIn("150", e.cmd("castsize 150"))
        self.assertEqual(e.ns.CastBar.frame.scale, 1.5)
        self.assertEqual(e.g.ChatFrame1.fontSize, 12)
        self.assertIn("TV", e.cmd("sizefor tv"))
        self.assertEqual((e.db.textScale, e.db.chatScale), (1.5, 1.5))
        self.assertEqual(e.g.ChatFrame1.fontSize, 18)
        self.assertIn("usage", e.cmd("sizefor cinema"))
        self.assertIn("sizefor", e.cmd("help"))
        self.assertEqual(e.errors(), [])

    SCALED = """
        for _, name in ipairs({ "MinimapCluster", "ObjectiveTrackerFrame", "EssentialCooldownViewer", "UtilityCooldownViewer" }) do
            local f = _G[name] or CreateFrame("Frame", name, UIParent)
            f.scale = 1
            f.GetScale = function(self) return self.scale end
            f.SetScale = function(self, s) self.scale = s end
        end
        EssentialCooldownViewer:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 120)     -- on top of the gamepad buttons
        UtilityCooldownViewer:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 80)
    """

    def sized(self, layouts="{ activeLayout = 2, layouts = {} }", **kw):
        return Env(setup=lambda env: (MarketAndItems.game(layouts, camera=False)(env), env.lua.execute(self.SCALED)), **kw)

    def test_the_minimap_and_quest_list_keep_the_games_own_size(self):
        e = self.sized(db="{ v = 8, screenAsked = true, nativeScale = 1.25 }")     # (an earlier version made them bigger)
        e.update(2)
        self.assertEqual((e.g.MinimapCluster.scale, e.g.ObjectiveTrackerFrame.scale), (1, 1))
        self.assertIsNone(e.db.nativeScale)

    def test_the_cooldown_rows_sit_beside_the_gamepad_buttons(self):
        e = self.sized(db="{ v = 8, screenAsked = true }")
        rows = e.g.EssentialCooldownViewer, e.g.UtilityCooldownViewer
        for row in rows:
            p = row.points[1]
            self.assertEqual(p[1], "BOTTOM")
            self.assertEqual(p[4], 0)                                # in the middle,
            self.assertGreater(p[5] * row.scale, 550)                # high up under the target
            self.assertEqual(row.scale, 0.8)                         # and a little smaller
        self.assertGreater(rows[0].points[1][5], rows[1].points[1][5])     # one above the other
        rows[0].ClearAllPoints(rows[0])                              # the game puts one back (a layout applied)
        rows[0].SetPoint(rows[0], "BOTTOM", e.g.UIParent, "BOTTOM", 0, 120)
        e.update(1.5)
        self.assertGreater(rows[0].points[1][5] * rows[0].scale, 550)
        e.mock.editMode(True)                                        # in Edit Mode they are the game's again
        self.assertEqual((rows[0].points[1][4], rows[0].points[1][5], rows[0].scale), (0, 120, 1))
        e.mock.editMode(False)
        self.assertEqual(rows[0].scale, 0.8)
        e.cmd("cooldownrows off")
        self.assertEqual((rows[1].points[1][4], rows[1].points[1][5], rows[1].scale), (0, 80, 1))
        own = self.sized(layouts=MarketAndItems.MINE, db="{ v = 8 }")       # on a layout of your own: where you put them
        self.assertEqual((own.g.EssentialCooldownViewer.points[1][4], own.g.EssentialCooldownViewer.scale), (0, 1))
        bare = Env()                                                 # a client that does not say: left alone
        self.assertFalse(bare.ns.Sizes.BuiltinLayout())
        self.assertEqual(e.errors(), [])

    def test_the_games_built_in_layouts_go_by_their_names(self):
        e = Env(setup=lambda env: (MarketAndItems.game("{ activeLayout = 3, layouts = {} }", camera=False)(env),
                                   env.lua.execute("Enum.EditModePresetLayouts = { Modern = 0, Classic = 1, Gamepad = 2 }")))
        self.assertEqual(e.ns.Share.Layout().builtin, "gamepad")    # three of them on this client
        self.assertEqual(e.ns.Share.BuiltinLayouts(), 3)
        self.assertIn("|game=gamepad", e.ns.Share.ExportAll())


class ChatAndMap(unittest.TestCase):
    def test_chat_fades_and_is_put_back(self):
        e = Env()
        frames = [e.g["ChatFrame%d" % i] for i in (1, 2, 3)]
        self.assertTrue(all(f.fading and f.timeVisible == 15 for f in frames))
        self.assertIn("30", e.cmd("chattime 30"))
        self.assertEqual(frames[1].timeVisible, 30)
        e.cmd("chatfade off")
        self.assertTrue(all(f.fading is False and f.timeVisible == 120 for f in frames))
        e.cmd("chatfade on")
        e.cmd("off")
        self.assertTrue(all(f.fading is False and f.timeVisible == 120 for f in frames))
        e2 = Env(style="0")
        self.assertFalse(e2.g.ChatFrame1.fading)

    def test_a_player_who_already_fades_chat_keeps_their_setting(self):
        e = Env(setup=lambda env: env.lua.execute("ChatFrame2.fading = true; ChatFrame2.timeVisible = 40"))
        e.cmd("chatfade off")
        self.assertEqual((e.g.ChatFrame2.fading, e.g.ChatFrame2.timeVisible), (True, 40))

    def test_map_coordinates(self):
        e = Env()
        coords = e.ns.World.coords
        self.assertTrue(e.same(coords.parent, e.g.WorldMapFrame))     # only works while the map is open
        e.update(0.3)
        self.assertEqual(coords.text.text, "73.8, 32.8")
        e.mock.playerPos = None                                        # an instance that hides it
        e.update(0.3)
        self.assertEqual(coords.text.text, "")
        e.cmd("mapcoords off")
        self.assertFalse(coords.shown)
        self.assertIsNone(coords.scripts.OnUpdate)
        self.assertEqual(e.ns.RunCheck(False)[0], 0)
        self.assertEqual(e.errors(), [])


class Fade(unittest.TestCase):
    def test_faded_unless_hurt_in_a_fight(self):
        e = Env()
        visual = e.frames.player.visual
        e.update(1)
        self.assertEqual(visual.alpha, 1)                 # not yet: it waits a moment first
        e.update(3)
        self.assertAlmostEqual(visual.alpha, 0.3)         # full health, no fight
        self.assertAlmostEqual(e.frames.pet.visual.alpha, 0.3)
        e.target()
        e.update(2)
        self.assertAlmostEqual(visual.alpha, 0.3)         # a target alone changes nothing
        e.mock.units.player.health = 600
        e.mock.fire("UNIT_HEALTH", "player")
        e.update(4)
        self.assertAlmostEqual(visual.alpha, 0.3)         # hurt, but out of combat
        e.mock.state.combat = True
        e.update(0.5)
        self.assertAlmostEqual(visual.alpha, 0.7)         # in a fight: the combat level ...
        e.mock.units.player.health = 400
        e.mock.fire("UNIT_HEALTH", "player")
        e.update(0.5)
        self.assertEqual(visual.alpha, 1)                 # ... and in full below half health
        e.mock.units.player.health = 1000
        e.mock.units.player.power = 200                   # low mana is a call to action too
        e.mock.fire("UNIT_HEALTH", "player")
        e.mock.fire("UNIT_POWER_UPDATE", "player")
        e.update(0.5)
        self.assertEqual(visual.alpha, 1)
        e.mock.units.player.power = 500
        e.mock.fire("UNIT_POWER_UPDATE", "player")
        e.update(4)
        self.assertAlmostEqual(visual.alpha, 0.7)         # all good again, still fighting
        e.ns.db.combatAlpha, e.ns.db.alertHealth = 0.2, 0.9
        e.update(2)
        self.assertAlmostEqual(visual.alpha, 0.2)         # the player's own levels
        e.mock.units.player.health = 850
        e.mock.fire("UNIT_HEALTH", "player")
        e.update(0.5)
        self.assertEqual(visual.alpha, 1)

    def test_idle_setting(self):
        e = Env()
        self.assertIn("0%", e.cmd("idle 0"))
        e.update(5)
        self.assertEqual(e.frames.player.visual.alpha, 0)
        e.cmd("idle 250")
        self.assertEqual(e.db.idle, 1)
        self.assertIn("usage", e.cmd("idle lots"))

    def test_secret_health_in_a_fight_keeps_the_bar_visible(self):
        e = Env()
        e.mock.units.player.health = e.mock.secret()
        e.mock.fire("UNIT_HEALTH", "player")
        e.update(5)
        self.assertAlmostEqual(e.frames.player.visual.alpha, 0.3)     # out of combat: steps back
        e.mock.state.combat = True
        e.update(1)
        self.assertEqual(e.frames.player.visual.alpha, 1)


class Moving(unittest.TestCase):
    def test_drag_saves_and_reset_restores(self):
        e = Env()
        self.assertIn("Drag", e.cmd("unlock"))
        mover = e.frames.player.mover
        self.assertTrue(mover.movable)
        self.assertTrue(mover.overlay.shown)
        mover.cx, mover.cy = 200, 100
        mover.scripts.OnDragStop(mover)
        self.assertEqual((e.db.pos.player.x, e.db.pos.player.y), (200 - 512, 100 - 384))
        self.assertEqual(mover.points[1][1], "CENTER")
        e.cmd("lock")
        self.assertFalse(mover.movable)
        self.assertFalse(mover.overlay.shown)
        e.cmd("reset")
        self.assertIsNone(e.db.pos.player)
        self.assertEqual(mover.points[1][1], "TOPLEFT")

    def test_saved_position_is_used_after_a_reload(self):
        e = Env(db="{ pos = { target = { x = 10, y = -20 }, junk = { x = 1, y = 2 }, pet = 'no' } }")
        p = e.frames.target.mover.points[1]
        self.assertEqual((p[1], p[4], p[5]), ("CENTER", 10, -20))
        self.assertIsNone(e.db.pos.junk)
        self.assertIsNone(e.db.pos.pet)

    def test_no_unlocking_in_combat_and_combat_locks(self):
        e = Env()
        e.mock.state.combat = True
        self.assertIn("Not in combat", e.cmd("unlock"))
        self.assertFalse(e.ns.UnitFrames.unlocked)
        e.mock.state.combat = False
        e.cmd("unlock")
        e.mock.state.combat = True
        e.mock.fire("PLAYER_REGEN_DISABLED")
        self.assertFalse(e.ns.UnitFrames.unlocked)
        self.assertFalse(e.frames.player.mover.movable)

    def test_scale(self):
        e = Env()
        self.assertIn("150%", e.cmd("scale 150"))
        self.assertEqual(e.frames.player.mover.scale, 1.5)
        self.assertEqual(e.frames.player.button.scale, 1.5)
        e.cmd("scale 9999")
        self.assertEqual(e.db.scale, 2)

    def test_unlock_needs_the_hud_running(self):
        e = Env(style="0")
        self.assertIn("not running", e.cmd("unlock"))


class Commands(unittest.TestCase):
    def test_status_help_and_unknown(self):
        e = Env()
        self.assertIn("running", e.cmd(""))
        out = e.cmd("help")
        for word in ("/cchud unlock", "/cchud idle", "/cchud blizzard", "/cchud chat"):
            self.assertIn(word, out)
        self.assertIn("unknown command", e.cmd("dance"))

    def test_frames_can_be_turned_off_one_by_one(self):
        e = Env()
        e.cmd("player off")
        self.assertFalse(e.frames.player.button.shown)
        self.assertEqual(e.aside("PlayerFrame"), False)                 # the game's own is back
        self.assertEqual(e.aside("TargetFrame"), True)   # the target is still ours
        e.cmd("player")
        self.assertTrue(e.frames.player.button.shown)

    def test_blizzard_frames_can_stay(self):
        e = Env()
        e.cmd("blizzard on")
        self.assertFalse(e.db.hideBlizzard)
        self.assertEqual(e.aside("PlayerFrame"), False)
        self.assertTrue(e.frames.player.button.shown)
        e.cmd("blizzard off")
        self.assertEqual(e.aside("PlayerFrame"), True)

    def test_settings_survive_a_reload(self):
        e = Env()
        e.cmd("idle 60")
        e.cmd("pet off")
        e.cmd("chat on")
        e.cmd("classcolor off")
        saved = e.mock.serialize(e.g.ControllerCamHUDDB)
        e2 = Env(db=saved)
        self.assertAlmostEqual(e2.db.idle, 0.6)
        self.assertFalse(e2.db.units.pet)
        self.assertFalse(e2.db.classColors)
        self.assertEqual(e2.g.ChatFrame1.points[1][1], "TOPLEFT")

    def test_broken_saved_data_is_repaired(self):
        e = Env(db="{ enabled = 'yes', idle = 'x', scale = -3, units = 5, pos = 7, chat = {} }")
        self.assertTrue(e.db.enabled)
        self.assertAlmostEqual(e.db.idle, 0.3)
        self.assertEqual(e.db.scale, 0.5)
        self.assertTrue(e.db.units.player)
        self.assertFalse(e.db.chat)
        self.assertEqual(e.errors(), [])

    def test_probe_runs(self):
        e = Env()
        out = e.cmd("probe")
        self.assertIn("probe saved", out)
        self.assertIsNotNone(e.db.probe)
        self.assertEqual(e.db.probe.cvars.InputDeviceInterfaceStyle, "1")


class Reactions(unittest.TestCase):
    def hit(self, e, hp):
        e.mock.units.player.health = hp
        e.mock.fire("UNIT_HEALTH", "player")

    def test_a_hit_flashes_the_bar(self):
        e = Env()
        f = e.frames.player
        self.assertEqual(f.flash.alpha, 0)
        self.hit(e, 950)
        self.assertGreater(f.flash.alpha, 0.4)
        self.assertFalse(e.ns.Impact.IsShaking(e.ns.Impact, f.visual))     # too light to shake
        e.update(1)
        self.assertEqual(f.flash.alpha, 0)

    def test_a_heavy_hit_shakes_and_settles(self):
        e = Env()
        f = e.frames.player
        self.hit(e, 600)
        self.assertTrue(e.ns.Impact.IsShaking(e.ns.Impact, f.visual))
        e.update(0.1)
        p = f.visual.points[1]
        self.assertNotEqual((p[4], p[5]), (0, 0))
        e.update(0.5)
        p = f.visual.points[1]
        self.assertEqual((p[4], p[5]), (0, 0))
        self.assertFalse(e.ns.Impact.IsShaking(e.ns.Impact, f.visual))

    def test_healing_and_target_switches_do_not_flash(self):
        e = Env()
        self.hit(e, 500)
        e.update(2)
        self.hit(e, 900)
        self.assertEqual(e.frames.player.flash.alpha, 0)
        e.target()
        e.target(health=100, healthMax=1000)
        self.assertEqual(e.frames.target.flash.alpha, 0)

    def test_your_hits_flash_the_target(self):
        e = Env()
        t = e.target()
        t.health = 700
        e.mock.fire("UNIT_HEALTH", "target")
        self.assertGreater(e.frames.target.health.flashA, 0.1)       # no hit event from the game: the drop is the hit
        self.assertTrue(e.ns.Impact.IsShaking(e.ns.Impact, e.frames.target.visual))

    def test_low_health_pulses(self):
        e = Env()
        self.hit(e, 200)
        seen = set()
        for _ in range(12):
            e.update(0.05)
            seen.add(round(e.frames.player.glow.alpha, 2))
        self.assertGreater(len(seen), 4)
        self.assertTrue(all(0.2 <= a <= 0.96 for a in seen), seen)

    def test_combat_warms_the_bar_and_pops_it(self):
        e = Env()
        f = e.frames.player
        e.update(0.5)
        self.assertEqual(f.combatGlow.alpha, 0)
        e.mock.state.combat = True
        e.mock.fire("PLAYER_REGEN_DISABLED")
        e.update(0.1)
        self.assertGreater(f.visual.scale, 1)             # a short swell as combat starts
        e.update(1)
        self.assertEqual(f.visual.scale, 1)
        self.assertGreater(f.combatGlow.alpha, 0.3)
        e.mock.state.combat = False
        e.update(2)
        self.assertEqual(f.combatGlow.alpha, 0)


class Demo(unittest.TestCase):
    def test_demo_plays_a_fight_and_gives_the_frames_back(self):
        e = Env()
        self.assertFalse(e.frames.target.button.shown)
        self.assertIn("Demo running", e.cmd("demo"))
        self.assertTrue(e.frames.target.button.shown)
        self.assertTrue(e.frames.pet.button.shown)
        self.assertEqual(e.color(e.frames.target.health), e.theme("hostile"))
        e.update(3)
        self.assertTrue(e.frames.target.cast.shown)       # the dummy is casting
        e.update(3.5)
        self.assertTrue(e.frames.player.glow.shown)       # player is low by now
        self.assertEqual(e.color(e.frames.player.health), e.theme("danger"))
        e.update(2.5)
        self.assertEqual(e.color(e.frames.target.health), (0.25, 0.78, 0.92))    # a friendly mage, class coloured
        e.update(20)                                      # loops without trouble
        self.assertEqual(e.errors(), [])
        self.assertIn("stopped", e.cmd("demo"))
        self.assertFalse(e.frames.target.button.shown)
        self.assertFalse(e.frames.pet.button.shown)
        self.assertEqual(e.frames.player.health.fill.value, 1000)
        self.assertFalse(e.frames.player.glow.shown)
        self.assertEqual(e.ns.RunCheck(False)[0], 0)

    def test_real_events_wait_while_the_demo_draws(self):
        e = Env()
        e.cmd("demo")
        e.update(3.2)
        shown = e.frames.player.health.goal
        e.mock.fire("UNIT_HEALTH", "player")
        self.assertEqual(e.frames.player.health.goal, shown)

    def test_combat_ends_the_demo(self):
        e = Env()
        e.mock.state.combat = True
        self.assertIn("Not in combat", e.cmd("demo"))
        e.mock.state.combat = False
        e.cmd("demo")
        e.mock.fire("PLAYER_REGEN_DISABLED")
        self.assertIsNone(e.ns.UnitFrames.fake)
        self.assertFalse(e.frames.target.button.shown)
        self.assertTrue(e.mock.watched[e.frames.target.button])

    def test_demo_needs_the_hud_running(self):
        e = Env(style="0")
        self.assertIn("not running", e.cmd("demo"))

    def test_turning_the_hud_off_ends_the_demo(self):
        e = Env()
        e.cmd("demo")
        e.cmd("off")
        self.assertIsNone(e.ns.UnitFrames.fake)
        self.assertFalse(e.frames.target.button.shown)


class Grid(unittest.TestCase):
    """Every combination of the switches, end to end: what is on screen must match the settings, the in-game
    self-check must agree, and turning the HUD off must leave the game exactly as it was."""

    FLAGS = ("enabled", "always", "hideBlizzard", "chat", "player", "target", "pet")

    def combos(self):
        import itertools
        for style in ("0", "1"):
            for bits in itertools.product((True, False), repeat=len(self.FLAGS)):
                yield style, dict(zip(self.FLAGS, bits))

    def make(self, style, o, **kw):
        b = lambda v: "true" if v else "false"
        db = ("{ v = 2, enabled = %s, always = %s, hideBlizzard = %s, chat = %s, units = { player = %s, target = %s, "
              "pet = %s } }" % tuple(b(o[k]) for k in self.FLAGS))
        return Env(db=db, style=style, **kw)

    def verify(self, e, style, o, label):
        run = o["enabled"] and (o["always"] or style == "1")
        aside = run and o["hideBlizzard"]
        self.assertEqual(e.aside("PlayerFrame"), bool(aside and o["player"]), label)
        self.assertEqual(e.aside("TargetFrame"), bool(aside and o["target"]), label)
        self.assertEqual(e.aside("FocusFrame"), bool(aside), label)
        self.assertEqual(e.g.ChatFrame1.points[1][1], "TOPLEFT" if run and o["chat"] else "CENTER", label)
        for key, has_unit in (("player", True), ("target", True), ("pet", False)):
            f = e.frames[key]
            shown = bool(f and f.button.shown)
            self.assertEqual(shown, bool(run and o[key] and has_unit), "%s %s" % (label, key))
        failed, rows = e.ns.RunCheck(False)
        bad = [r.name for r in rows.values() if not r.ok]
        self.assertEqual(failed, 0, "%s: %s" % (label, bad))
        self.assertEqual(e.errors(), [], label)

    def pristine(self, e, label):
        for name in e.mock.cooldownFrames.values():
            self.assertEqual(e.g[name].alpha, 1, label)
        self.assertEqual(e.mock.cvars.cooldownViewerEnabled, "1", label)
        self.assertEqual(e.aside("PlayerFrame"), False, label)
        self.assertEqual(e.aside("TargetFrame"), False, label)
        self.assertEqual(e.aside("FocusFrame"), False, label)
        self.assertEqual(e.g.ChatFrame1.points[1][1], "CENTER", label)
        self.assertTrue(e.same(e.g.MerchantSellAllJunkButton.scripts.OnClick, e.mock.nativeJunkClick), label)
        self.assertEqual((e.g.PartyFrame.alpha, e.g.CompactRaidFrameContainer.alpha), (1, 1), label)
        self.assertEqual(e.parent("PlayerCastingBarFrame"), "UIParent", label)
        self.assertEqual(e.g.GamepadMainActionBarFrame.scale, 1, label)
        self.assertEqual((e.g.ChatFrame1.fading, e.g.ChatFrame1.timeVisible), (False, 120), label)
        for key in ("player", "target", "pet", "tot", "focus"):
            f = e.frames[key]
            self.assertFalse(bool(f and f.button.shown), label)

    def test_every_combination(self):
        n = 0
        for style, o in self.combos():
            label = "style %s %s" % (style, o)
            e = self.make(style, o)
            e.target()
            self.verify(e, style, o, label)
            e.update(0.5)
            e.cmd("off")
            self.pristine(e, label + " after off")
            n += 1
        self.assertEqual(n, 256)

    def test_every_combination_when_logging_in_during_combat(self):
        for style, o in self.combos():
            label = "combat login, style %s %s" % (style, o)
            e = self.make(style, o, combat=True)
            self.pristine(e, label)                        # nothing may be touched yet
            e.mock.state.combat = False
            e.mock.fire("PLAYER_REGEN_ENABLED")
            e.target()
            self.verify(e, style, o, label)

    def test_switching_everything_back_and_forth_ends_where_it_started(self):
        e = Env()
        e.target()
        for c in ("chat on", "player off", "blizzard on", "always on", "target off", "pet off", "scale 150",
                  "unlock", "lock", "demo", "demo", "player on", "target on", "blizzard off", "chat off", "pet on"):
            e.cmd(c)
            self.assertEqual(e.ns.RunCheck(False)[0], 0, c)
        self.assertEqual(e.errors(), [])
        e.cmd("off")
        self.pristine(e, "after the tour")

    def test_the_check_notices_when_something_is_wrong(self):
        e = Env()
        self.assertEqual(e.ns.RunCheck(False)[0], 0)
        e.g.PlayerFrame.alpha = 1                          # the game's frame showed through
        e.frames.player.button.shown = False               # and ours vanished
        out = e.cmd("check")
        self.assertIn("FAIL", out)
        self.assertEqual(e.db.check.failed, 2)
        self.assertIn("ok", e.cmd("check all"))


if __name__ == "__main__":
    unittest.main()
