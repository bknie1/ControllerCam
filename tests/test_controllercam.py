"""Automated tests for ControllerCam.

They run the real addon Lua files inside a Lua 5.1 interpreter (the game's version) against a small mock of
the WoW API (tests/wow_mock.lua). Nothing here talks to the game.

    pip install lupa
    python tests/test_controllercam.py          (or: python -m unittest discover -s tests)
"""
import os
import re
import sys
import unittest

from lupa.lua51 import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TOC = os.path.join(ROOT, "ControllerCam.toc")
LOCALES = ["deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW"]


def toc_files():
    files = []
    for line in open(TOC, encoding="utf-8").read().splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            files.append(line)
    return files


def lua_path(p):
    return p.replace("\\", "/")


class Env:
    """One fresh game session: new Lua state, addon loaded in TOC order, login events fired."""

    def __init__(self, db=None, cvars=None, locale="enUS", addons=(), state=None, login=True):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        lua = self.lua
        self.mock = lua.execute("return dofile('%s')" % lua_path(os.path.join(HERE, "wow_mock.lua")))
        self.mock.locale = locale
        for name in addons:
            self.mock.addons[name] = True
        if cvars:
            for k, v in cvars.items():
                self.mock.cvars[k] = v
        for k, v in (state or {}).items():
            self.mock.state[k] = v
        if db is not None:
            lua.execute("ControllerCamDB = " + db)
        self.ns = lua.table()
        for f in toc_files():
            self.mock.loadFile(lua_path(os.path.join(ROOT, f)), self.ns)
        if login:
            self.mock.fire("ADDON_LOADED", "ControllerCam")
            self.mock.fire("PLAYER_LOGIN")
            self.mock.fire("PLAYER_ENTERING_WORLD")
            self.advance(1.2)           # the delayed first apply

    # -- helpers -----------------------------------------------------------
    def advance(self, sec):
        self.mock.advance(sec)

    def cv(self, name):
        return self.mock.cvars[name]

    def state(self, **kw):
        for k, v in kw.items():
            self.mock.state[k] = v

    def tick(self, sec=0.6):
        self.advance(sec)

    def cmd(self, text):
        n = len(self.mock.printed)
        self.ns.Command(text)
        return [self.mock.printed[i] for i in range(n + 1, len(self.mock.printed) + 1)]

    def printed(self):
        return [self.mock.printed[i] for i in range(1, len(self.mock.printed) + 1)]

    def db(self):
        return self.ns.GetDB()

    def run(self, code):
        """Run Lua with the namespace available as NS and the mock as MOCK."""
        self.lua.globals().NS = self.ns
        self.lua.globals().MOCK = self.mock
        return self.lua.execute(code)

    def parse(self, text):
        """ParseProfile -> (profile table or None, error message or None)."""
        self.lua.globals().NS = self.ns
        f = self.lua.eval("function(s) local p, e = NS.ParseProfile(s); return { p = p, e = e } end")
        r = f(text)
        return r["p"], r["e"]

    def importing(self, text):
        self.lua.globals().NS = self.ns
        f = self.lua.eval("function(s) local id, e = NS.ImportString(s); return { id = id, e = e } end")
        r = f(text)
        return r["id"], r["e"]

    def values(self, pid):
        return self.db()["profiles"][pid]["values"]

    def saved(self):
        """The saved variables as Lua source (what the game writes to disk)."""
        return self.mock.serialize(self.lua.globals().ControllerCamDB)

    def cvars(self):
        return {k: v for k, v in self.mock.cvars.items()}

    def setlog_names(self):
        return [self.mock.setLog[i][1] for i in range(1, len(self.mock.setLog) + 1)]


def reload_env(env, **kw):
    """Simulate a UI reload: new Lua state, saved variables and CVars carried over."""
    return Env(db=env.saved(), cvars=env.cvars(), **kw)


class TocAndFiles(unittest.TestCase):
    def test_toc_lists_existing_files_and_metadata(self):
        text = open(TOC, encoding="utf-8").read()
        self.assertIn("## Interface: 16001", text)
        self.assertIn("## SavedVariables: ControllerCamDB", text)
        self.assertIn("## Author: bknie1", text)
        for f in toc_files():
            self.assertTrue(os.path.isfile(os.path.join(ROOT, f)), f)
        for loc in LOCALES:
            self.assertIn("## Notes-%s:" % loc, text)

    def test_toc_version_matches_changelog(self):
        ver = re.search(r"^## Version: (.+)$", open(TOC, encoding="utf-8").read(), re.M).group(1).strip()
        first = re.search(r"^## (\S+)", open(os.path.join(ROOT, "CHANGELOG.md"), encoding="utf-8").read(), re.M).group(1)
        self.assertEqual(ver, first)

    def test_workflow_and_pkgmeta_mention_every_toc_file(self):
        wf = open(os.path.join(ROOT, ".github", "workflows", "release.yml"), encoding="utf-8").read()
        for f in toc_files():
            self.assertIn(f, wf, "release.yml does not copy " + f)
        self.assertIn("package-as: ControllerCam", open(os.path.join(ROOT, ".pkgmeta"), encoding="utf-8").read())

    def test_icon_exists_and_ships(self):
        text = open(TOC, encoding="utf-8").read()
        path = re.search(r"^## IconTexture: (.+)$", text, re.M).group(1).strip()
        self.assertTrue(path.startswith("Interface\AddOns\ControllerCam\\"), path)
        icon = os.path.join(ROOT, path.split("\\", 3)[3].replace("\\", os.sep) + ".tga")
        data = open(icon, "rb").read()
        self.assertIn(len(data), (18 + 64 * 64 * 4, 18 + 64 * 64 * 4 + 26))        # 64x64, 32 bits, uncompressed (+ optional TGA footer)
        self.assertEqual(list(data[:3]), [0, 0, 2])
        self.assertEqual((data[12] + data[13] * 256, data[14] + data[15] * 256, data[16]), (64, 64, 32))
        wf = open(os.path.join(ROOT, ".github", "workflows", "release.yml"), encoding="utf-8").read()
        self.assertIn("cp -r Media dist/ControllerCam/Media", wf)

    def test_no_forbidden_words_anywhere(self):
        bad = re.compile("claude|anthropic|co-authored|generated with", re.I)
        for base, dirs, files in os.walk(ROOT):
            dirs[:] = [d for d in dirs if d not in (".git", "__pycache__")]
            for f in files:
                if f.endswith((".lua", ".md", ".toc", ".yml", ".py", ".txt", ".pkgmeta")) or f in ("LICENSE", ".pkgmeta"):
                    p = os.path.join(base, f)
                    if os.path.abspath(p) == os.path.abspath(__file__):
                        continue
                    self.assertIsNone(bad.search(open(p, encoding="utf-8").read()), p)


class Cvars(unittest.TestCase):
    def schema_cvars(self):
        src = open(os.path.join(ROOT, "Schema.lua"), encoding="utf-8").read()
        names = set()
        for m in re.finditer(r"cvars = \{([^}]*)\}", src):
            names.update(re.findall(r'"([^"]+)"', m.group(1)))
        names.update(["CameraKeepCharacterCentered", "CameraReduceUnexpectedMovement"])
        return names

    def verified(self):
        lines = open(os.path.join(HERE, "verified_cvars.txt"), encoding="utf-8").read().splitlines()
        return {l.strip() for l in lines if l.strip() and not l.startswith("#")}

    def test_schema_only_uses_verified_cvars(self):
        self.assertEqual(self.schema_cvars() - self.verified(), set())

    def test_verified_names_exist_in_the_client(self):
        exe = os.environ.get("CONTROLLERCAM_WOW_EXE", r"D:\World of Warcraft\_forever_\Wow.exe")
        if not os.path.isfile(exe):
            self.skipTest("Forever client not installed here")
        data = open(exe, "rb").read()
        for name in self.verified():
            self.assertIn(name.encode(), data, name)

    def test_mock_knows_every_cvar(self):
        env = Env(login=False)
        for name in self.schema_cvars():
            self.assertIsNotNone(env.mock.defaults[name], name)


class Locales(unittest.TestCase):
    def test_every_localized_text_has_a_key(self):
        env = Env(login=False)
        english = {env.ns.localeData.english[i] for i in range(1, len(env.ns.localeData.english) + 1)}
        STR = r'"((?:[^"\\]|\\.)*)"'
        used = set()
        for f in toc_files():
            if f == "Locales.lua":
                continue
            t = open(os.path.join(ROOT, f), encoding="utf-8").read()
            used.update(m.group(1).replace('\\"', '"') for m in re.finditer(r"\bL\[" + STR + r"\]", t))
            if f == "Schema.lua":
                used.update(m.group(1) for m in re.finditer(r"label = " + STR, t))
                used.update(m.group(1) for m in re.finditer(r"group = " + STR, t))
                for m in re.finditer(r"values = \{([^}]*)\}", t):
                    used.update(re.findall(STR, m.group(1)))
            if f == "Presets.lua":
                used.update(m.group(1) for m in re.finditer(r"\n\s+(?:name|desc) = " + STR, t))
            if f == "Slash.lua":
                used.update(m.group(2) for m in re.finditer(r'\{ "(/ccam[^"]*)",\s+' + STR + r" \}", t))
        self.assertEqual(sorted(used - english), [], "texts used in code but missing from Locales.lua")

    def test_translation_tables_are_well_formed(self):
        env = Env(login=False)
        data = env.ns.localeData
        n_english = len(data.english)
        english = [data.english[i] for i in range(1, n_english + 1)]
        self.assertEqual(len(set(english)), n_english, "duplicate English keys")
        ph = re.compile(r"%[-.\d]*[sd]|%\.\df")
        for loc in LOCALES:
            tr = data.translations[loc]
            self.assertIsNotNone(tr, loc)
            n = len(tr)
            self.assertEqual(n, n_english, "%s is missing %d translations" % (loc, n_english - n))
            for i in range(1, n + 1):
                self.assertEqual(ph.findall(tr[i]), ph.findall(english[i - 1]), "%s #%d %s" % (loc, i, english[i - 1]))
                self.assertTrue(tr[i].strip(), "%s #%d is empty" % (loc, i))

    def test_game_language_is_used_and_missing_text_falls_back(self):
        for loc in LOCALES:
            env = Env(locale=loc)
            self.assertNotEqual(env.ns.L["In combat"], "In combat", loc)
            self.assertEqual(env.ns.L["something with no translation"], "something with no translation")
        self.assertEqual(Env(locale="enUS").ns.L["In combat"], "In combat")
        # profile descriptions are translated too
        for loc in LOCALES:
            env = Env(locale=loc)
            self.assertNotEqual(env.ns.ProfileDescription("action"), Env(locale="enUS").ns.ProfileDescription("action"), loc)


class Schema(unittest.TestCase):
    def setUp(self):
        self.env = Env(login=False)

    def test_every_builtin_profile_is_valid(self):
        ns = self.env.ns
        for i in range(1, len(ns.BUILTIN_LIST) + 1):
            p = ns.BUILTIN_LIST[i]
            r = self.env.run("local p = NS.BUILTIN_LIST[%d]; local c, why, key = NS.ValidateProfile({ name = p.name, values = p.values }); return { c = c, why = why, key = key }" % i)
            self.assertIsNotNone(r["c"], "%s: %s %s" % (p.id, r["why"], r["key"]))

    def test_expected_builtin_profiles_exist(self):
        ns = self.env.ns
        ids = [ns.BUILTIN_LIST[i].id for i in range(1, len(ns.BUILTIN_LIST) + 1)]
        self.assertEqual(ids[:3], ["action", "hybrid", "classic"])
        self.assertIn("shooter", ids)
        self.assertEqual(ns.STARTER.default, "action")

    def test_validate_value(self):
        v = self.env.run("""
            local s = NS.SETTING_BY_KEY
            local function ok(key, val) return (NS.ValidateValue(s[key], val)) end
            local function why(key, val) local _, w = NS.ValidateValue(s[key], val); return w end
            return {
              ok("shoulder", 2), ok("shoulder", "1.5"), ok("followOnStick", 1), ok("yawSpeed", "x1.25"), ok("yawSpeed", "d"),
              ok("zoom", 7), ok("turnWithCamera", 3),
              ok("shoulder", 99), ok("shoulder", 0/0), ok("shoulder", math.huge), ok("shoulder", "abc"), ok("shoulder", {}),
              ok("followOnStick", 2), ok("turnWithCamera", 1.5), ok("yawSpeed", 2), ok("yawSpeed", "x99"), ok("yawSpeed", "x-1"),
              ok("zoom", "d"), ok("shoulderCurve", {}), ok("shoulderCurve", {{0,1},{0,2}}), ok("shoulderCurve", {{0,99}}),
              why("shoulder", 99), why("shoulder", "abc"),
            }""")
        got = [v[i] for i in range(1, 24)]
        self.assertEqual(got[0], 2); self.assertEqual(got[1], 1.5); self.assertEqual(got[2], 1)
        self.assertEqual(got[3], "x1.25"); self.assertEqual(got[4], "d"); self.assertEqual(got[5], 7); self.assertEqual(got[6], 3)
        for i in range(7, 21):
            self.assertIsNone(got[i], "case %d should be rejected" % i)
        self.assertEqual(got[21], "range"); self.assertEqual(got[22], "type")

    def test_curve_is_sorted_and_interpolated(self):
        r = self.env.run("""
            local c = NS.ValidateValue(NS.SETTING_BY_KEY.shoulderCurve, {{20,0},{0,2},{8,2}})
            return { c[1][1], c[2][1], c[3][1], NS.EvalCurve(c, 0), NS.EvalCurve(c, 14), NS.EvalCurve(c, 30), NS.EvalCurve(c, -3) }""")
        self.assertEqual([r[i] for i in range(1, 8)], [0, 8, 20, 2, 1, 0, 2])

    def test_names_are_cleaned(self):
        r = self.env.run("""return { NS.CleanName("  Hello|cffff0000   World\\n"), NS.CleanName("|||"), NS.CleanName(5), NS.CleanName(string.rep("a", 80)) }""")
        self.assertEqual(r[1], "Hellocffff0000 World")
        self.assertIsNone(r[2]); self.assertIsNone(r[3]); self.assertEqual(len(r[4]), 32)


class Sharing(unittest.TestCase):
    def setUp(self):
        self.env = Env()

    def make(self, body):
        return self.env.run('return "CC1:" .. NS.ShareChecksum(%r) .. ":" .. %r' % (body, body))

    def test_round_trip_of_every_builtin(self):
        ns = self.env.ns
        for i in range(1, len(ns.BUILTIN_LIST) + 1):
            pid = ns.BUILTIN_LIST[i].id
            s = ns.ExportById(pid)
            self.assertTrue(s.startswith("CC1:"))
            self.assertLess(len(s), 1500)
            parsed, err = self.env.parse(s)
            self.assertIsNotNone(parsed, "%s: %s" % (pid, err))
            self.assertEqual(ns.ExportProfile(parsed), s, pid)

    def test_exports_are_stable(self):
        self.assertEqual(self.env.ns.ExportById("action"), self.env.ns.ExportById("action"))

    def test_pasted_whitespace_is_ignored(self):
        s = self.env.ns.ExportById("hybrid")
        spaced = s[:20] + "\n  " + s[20:] + "  \r\n"
        self.assertIsNotNone(self.env.parse(spaced)[0])

    def bad(self, s, contains=None):
        parsed, err = self.env.parse(s)
        self.assertIsNone(parsed, s)
        self.assertTrue(err)
        if contains:
            self.assertIn(contains, err)

    def test_rejects_garbage(self):
        for s in ["", "hello", "CC1", "CC1:zzzz:n=a", "CC1:00000000:", "<script>", "CC1:" + "0" * 8 + ":" + "x" * 2000]:
            self.bad(s)
        self.assertEqual(self.env.run("local p, e = NS.ParseProfile(nil); return e"), self.env.ns.L["That is not a ControllerCam profile string."])
        self.assertIsNone(self.env.run("local p, e = NS.ParseProfile(42); return p"))

    def test_rejects_changed_or_truncated_strings(self):
        s = self.env.ns.ExportById("action")
        self.bad(s[:-5], "checksum")
        self.bad(s.replace("x1.25", "x1.26"), "checksum")
        self.bad(s[:4] + ("0" if s[4] != "0" else "1") + s[5:], "checksum")

    def test_rejects_newer_version(self):
        s = self.env.ns.ExportById("action").replace("CC1:", "CC2:", 1)
        self.bad(s, "newer")

    def test_rejects_bad_content_even_with_a_correct_checksum(self):
        self.bad(self.make("n=Test;evil=1"), "evil")                    # unknown setting
        self.bad(self.make("n=Test;shoulder=99"), "shoulder")           # out of range
        self.bad(self.make("n=Test;shoulder=abc"), "shoulder")
        self.bad(self.make("n=Test;shoulder=1;shoulder=2"))             # duplicate
        self.bad(self.make("n=Test;yawSpeed=2"))                        # multiplier without x
        self.bad(self.make("n=Test;yawSpeed=x0"))
        self.bad(self.make("n=Test;followOnStick=5"))
        self.bad(self.make("n=Test;shoulderCurve=0:1,5"))               # broken curve
        self.bad(self.make("n=Test;shoulderCurve=0:1,0:2"))             # same zoom twice
        self.bad(self.make("n=Test;shoulderCurve=" + ",".join("%d:1" % i for i in range(12))))   # too many points
        self.bad(self.make("shoulder=1"), "name")                       # no name
        self.bad(self.make("n=%7C%7C;shoulder=1"), "name")              # name empty after cleaning
        self.bad(self.make("n=Test;zoom=d"))                            # zoom has no game default
        self.bad(self.make("n=Test;" + ";".join("k%d=1" % i for i in range(50))))   # too many fields

    def test_valid_minimal_strings(self):
        p, err = self.env.parse(self.make("n=Mine;shoulder=1.5;yawSpeed=x2;shoulderCurve=0:2,10:0;faceAngle=d"))
        self.assertIsNotNone(p, err)
        v = p["values"]
        self.assertEqual(v["shoulder"], 1.5)
        self.assertEqual(v["yawSpeed"], "x2")
        self.assertEqual(v["faceAngle"], "d")
        self.assertEqual(v["shoulderCurve"][2][2], 0)
        self.assertEqual(p["name"], "Mine")
        empty, err = self.env.parse(self.make("n=Empty"))                # an empty profile is allowed: it means "classic"
        self.assertIsNotNone(empty, err)
        lenient, err = self.env.parse(self.make("n=Test;shoulder=1;;"))  # stray separators are harmless
        self.assertIsNotNone(lenient, err)

    def test_name_cannot_inject_color_codes(self):
        p, err = self.env.parse(self.make("n=%7Ccffff0000Evil%7Cr;shoulder=1"))
        self.assertIsNotNone(p, err)
        self.assertNotIn("|", p["name"])

    def test_failed_import_changes_nothing(self):
        before = self.env.saved()
        for s in ["junk", self.make("n=Test;shoulder=99"), self.make("n=Test;evil=1")]:
            id_, err = self.env.importing(s)
            self.assertIsNone(id_)
        self.assertEqual(self.env.saved(), before)

    def test_import_creates_unique_custom_profile(self):
        ns = self.env.ns
        s = ns.ExportById("hybrid")
        id1, _ = self.env.importing(s)
        id2, _ = self.env.importing(s)
        self.assertNotEqual(id1, id2)
        self.assertNotIn(id1, ["action", "hybrid", "classic"])
        self.assertFalse(ns.IsBuiltin(id1))
        self.assertNotEqual(ns.ProfileName(id1), ns.ProfileName(id2))


class SavedData(unittest.TestCase):
    def test_fresh_install_gets_the_starter_setup(self):
        env = Env()
        a = env.db().assign
        self.assertEqual(a.default, "action")
        self.assertEqual(a.mounted, "cruise")
        self.assertEqual(a.raid, "raid")
        self.assertIsNone(a.combat)

    def test_welcome_message_once(self):
        env = Env()
        env.advance(4)
        self.assertTrue(any("Action camera is on" in p for p in env.printed()))
        env2 = reload_env(env)
        env2.advance(4)
        self.assertFalse(any("Action camera is on" in p for p in env2.printed()))

    def test_bad_saved_data_is_cleaned(self):
        bad = """{
            v = 1, enabled = "yes", exitDelay = 9999,
            profiles = {
                u_ok = { name = "Fine", values = { shoulder = 1 } },
                u_bad = { name = "Bad", values = { shoulder = 500 } },
                u_unknown = { name = "Odd", values = { evil = 1 } },
                u_noname = { values = {} },
                action = { name = "Hijack", values = { shoulder = 1 } },
                [5] = { name = "x", values = {} },
            },
            assign = { default = "u_ok", combat = "does_not_exist", raid = "u_bad", nonsense = "action" },
            force = "ghost",
            originals = { test_cameraOverShoulder = "0.5", evilcvar = "1", cameraFov = "10", GamePadCameraYawSpeed = 7 },
            motion = { CameraKeepCharacterCentered = "1", SomethingElse = "1" },
        }"""
        env = Env(db=bad)
        db = env.db()
        self.assertEqual(db.exitDelay, 10)
        self.assertTrue(db.enabled)
        self.assertIsNotNone(db.profiles.u_ok)
        for k in ["u_bad", "u_unknown", "u_noname", "action"]:
            self.assertIsNone(db.profiles[k], k)
        self.assertEqual(db.assign.default, "u_ok")
        self.assertIsNone(db.assign.combat); self.assertIsNone(db.assign.raid); self.assertIsNone(db.assign.nonsense)
        self.assertIsNone(db.force)
        self.assertEqual(db.originals.test_cameraOverShoulder, "0.5")
        self.assertIsNone(db.originals.evilcvar); self.assertIsNone(db.originals.cameraFov)
        self.assertIsNone(db.originals.GamePadCameraYawSpeed)
        self.assertEqual(db.motion.CameraKeepCharacterCentered, "1")
        self.assertIsNone(db.motion.SomethingElse)

    def test_survives_a_reload_with_originals_intact(self):
        env = Env()
        self.assertEqual(env.cv("GamePadCameraYawSpeed"), "1.25")
        self.assertEqual(env.db().originals.GamePadCameraYawSpeed, "1")
        env2 = reload_env(env)
        self.assertEqual(env2.db().originals.GamePadCameraYawSpeed, "1")           # still the user's own value
        self.assertEqual(env2.cv("GamePadCameraYawSpeed"), "1.25")
        env2.ns.SetEnabled(False)
        self.assertEqual(env2.cv("GamePadCameraYawSpeed"), "1")                    # restored from the saved copy
        self.assertEqual(env2.cv("test_cameraOverShoulder"), "0")


class Applying(unittest.TestCase):
    def test_action_is_applied_out_of_the_box(self):
        env = Env()
        cv = env.cv
        self.assertEqual(cv("GamePadCameraYawSpeed"), "1.25")                 # default 1 x1.25
        self.assertEqual(cv("GamePadCameraPitchSpeed"), "1.15")
        self.assertEqual(cv("CameraFollowYawSpeed"), "108")                   # default 90 x1.2
        self.assertEqual(cv("CameraFollowGamepadAdjustDelay"), "1.6")         # default 2 x0.8
        self.assertEqual(cv("GamepadCameraFollowOnStick"), "1")
        self.assertEqual(cv("CameraFollowOnStick"), "1")                      # both twins
        self.assertEqual(cv("GamePadFaceMovementMaxAngle"), "0")
        self.assertEqual(cv("GamePadFaceMovementMaxAngleCombat"), "180")
        self.assertEqual(cv("cameraDistanceMaxZoomFactor"), "2.2")
        self.assertEqual(cv("test_cameraHeadMovementStrength"), "1")
        self.assertEqual(cv("test_cameraDynamicPitch"), "1")
        self.assertEqual(cv("test_cameraTargetFocusInteractEnable"), "1")
        self.assertEqual(cv("test_cameraTargetFocusEnemyEnable"), "0")        # not in the profile: game default
        self.assertEqual(cv("cameraSmoothStyle"), "0")
        self.assertEqual(env.mock.state.zoom, 7)
        self.assertEqual(cv("test_cameraOverShoulder"), "2")                  # +2 close up (the zoom curve)
        self.assertEqual(env.ns.Status().profile, "Action")

    def test_shoulder_offset_follows_the_zoom_curve(self):
        env = Env()
        frame = env.ns.frame
        for zoom, expect in [(7, "2"), (8, "2"), (14, "1"), (20, "0"), (30, "0"), (3, "1"), (0, "0")]:
            env.state(zoom=zoom)
            frame.scripts.OnUpdate(frame, 0.2)
            self.assertEqual(env.cv("test_cameraOverShoulder"), expect, zoom)

    def test_close_zoom_keeps_the_character_on_screen(self):
        """A sideways offset in yards covers more screen the closer the camera is: keep it a fraction of the view."""
        env = Env()
        ns = env.ns
        for i in range(1, len(ns.BUILTIN_LIST) + 1):
            prof = ns.BUILTIN_LIST[i]
            curve = prof["values"]["shoulderCurve"]
            if curve is None:
                continue
            for zoom in [x / 2 for x in range(1, 41)]:
                offset = env.run("return NS.EvalCurve(NS.BUILTIN['%s'].values.shoulderCurve, %s)" % (prof.id, zoom))
                self.assertLessEqual(abs(offset) / (1.78 * zoom), 0.25, "%s at zoom %s: offset %s" % (prof.id, zoom, offset))

    def test_curve_only_writes_when_the_value_changes(self):
        env = Env()
        env.state(zoom=14)
        frame = env.ns.frame
        frame.scripts.OnUpdate(frame, 0.2)
        n = len(env.mock.setLog)
        for _ in range(20):
            frame.scripts.OnUpdate(frame, 0.2)
        self.assertEqual(len(env.mock.setLog), n)

    def test_mirror_shoulder(self):
        env = Env()
        env.ns.SetFlipShoulder(True)
        self.assertEqual(env.cv("test_cameraOverShoulder"), "-2")
        env.state(zoom=14)
        frame = env.ns.frame
        frame.scripts.OnUpdate(frame, 0.2)
        self.assertEqual(env.cv("test_cameraOverShoulder"), "-1")
        env.ns.SetFlipShoulder(False)
        self.assertEqual(env.cv("test_cameraOverShoulder"), "1")             # zoom 14 is kept: edits do not move the camera

    def test_classic_goes_back_to_game_defaults_and_keeps_zoom(self):
        env = Env()
        self.assertTrue(env.ns.UseEverywhere("classic"))
        for name, default in list(env.mock.defaults.items()):
            if name in ("CameraKeepCharacterCentered", "CameraReduceUnexpectedMovement"):
                continue
            self.assertEqual(env.cv(name), default, name)
        self.assertEqual(env.mock.state.zoom, 7)                              # classic leaves the camera distance alone

    def test_terrain_following_is_off_in_builtins_and_otherwise_yours(self):
        env = Env()
        self.assertEqual(env.cv("cameraTerrainTilt"), "0")                    # Action switches it off
        self.assertEqual(env.db()["originals"]["cameraTerrainTilt"], "1")     # and remembers the user's own value
        env.ns.UseEverywhere("classic")
        self.assertEqual(env.cv("cameraTerrainTilt"), "1")                    # Classic gives it back
        env.ns.UseEverywhere("raid")
        self.assertEqual(env.cv("cameraTerrainTilt"), "0")
        env.run("""NS.GetDB().profiles.u_plain = { name = "Plain", values = { zoom = 8 } }""")
        env.ns.UseEverywhere("u_plain")                                       # a profile that does not mention it
        self.assertEqual(env.cv("cameraTerrainTilt"), "1")
        env.ns.SetValue("u_plain", "followTerrain", 1)
        self.assertEqual(env.cv("cameraTerrainTilt"), "1")
        self.assertEqual(env.ns.ProfileName("u_plain"), "Plain")

    def test_a_user_who_already_has_it_off_is_left_alone(self):
        env = Env(cvars={"cameraTerrainTilt": "0"})
        self.assertEqual(env.cv("cameraTerrainTilt"), "0")
        env.ns.UseEverywhere("classic")
        self.assertEqual(env.cv("cameraTerrainTilt"), "0")
        self.assertNotIn("cameraTerrainTilt", env.setlog_names())

    def test_every_builtin_but_classic_switches_terrain_following_off(self):
        env = Env(login=False)
        ns = env.ns
        for i in range(1, len(ns.BUILTIN_LIST) + 1):
            prof = ns.BUILTIN_LIST[i]
            expected = None if prof.id == "classic" else 0
            self.assertEqual(prof["values"]["followTerrain"], expected, prof.id)

    def test_switching_profiles_leaves_nothing_behind(self):
        env = Env()
        env.ns.UseEverywhere("targetlock")
        self.assertEqual(env.cv("test_cameraTargetFocusEnemyEnable"), "1")
        env.ns.UseEverywhere("raid")
        self.assertEqual(env.cv("test_cameraTargetFocusEnemyEnable"), "0")
        self.assertEqual(env.cv("test_cameraHeadMovementStrength"), "0")      # action's head tracking is gone
        self.assertEqual(env.cv("test_cameraOverShoulder"), "0")

    def test_unknown_cvar_in_this_client_is_skipped(self):
        env = Env(login=False)
        env.run("MOCK.cvars.GamePadCameraYawSpeed = nil; MOCK.knownCVars.GamePadCameraYawSpeed = nil")
        env.mock.fire("ADDON_LOADED", "ControllerCam")
        env.mock.fire("PLAYER_ENTERING_WORLD")
        env.advance(1.2)
        self.assertEqual(env.cv("GamePadCameraPitchSpeed"), "1.15")           # the rest still applied

    def test_every_builtin_applies_without_error_and_changes_something_sensible(self):
        env = Env()
        ns = env.ns
        for i in range(1, len(ns.BUILTIN_LIST) + 1):
            pid = ns.BUILTIN_LIST[i].id
            self.assertTrue(ns.UseEverywhere(pid), pid)
            self.assertEqual(ns.Status().id, pid)
            self.assertLessEqual(env.mock.state.zoom, 39)
            self.assertGreaterEqual(env.mock.state.zoom, 1)

    def test_zoom_never_goes_past_the_allowed_maximum(self):
        env = Env()
        env.run("""NS.GetDB().profiles.u_far = { name = "Far", values = { zoom = 39, zoomMax = 1 } }""")
        env.ns.UseEverywhere("u_far")
        self.assertEqual(env.mock.state.zoom, 15)


class Situations(unittest.TestCase):
    def test_priorities(self):
        env = Env()
        name = lambda: env.ns.Status().profile
        self.assertEqual(name(), "Action")
        env.state(resting=True); env.tick(); self.assertEqual(name(), "Town stroll")
        env.state(resting=False); env.tick(2); self.assertEqual(name(), "Action")
        env.state(mounted=True); env.tick(); self.assertEqual(name(), "Mounted cruise")
        env.state(flying=True); env.tick(); self.assertEqual(name(), "Flying")
        env.state(flying=False, mounted=False, swimming=True); env.tick(2); self.assertEqual(name(), "Hybrid")
        env.state(swimming=False, vehicle=True); env.tick(2); self.assertEqual(name(), "Hybrid")
        env.state(vehicle=False, instance="raid"); env.tick(2); self.assertEqual(name(), "Raid view")
        env.state(instance="party"); env.tick(2); self.assertEqual(name(), "Action")
        env.state(instance=None); env.tick(2); self.assertEqual(name(), "Action")

    def test_combat_only_applies_when_assigned(self):
        env = Env()
        env.state(combat=True); env.tick()
        self.assertEqual(env.ns.Status().profile, "Action")                    # starter leaves combat alone
        env.state(combat=False); env.tick(2)
        env.ns.Assign("combat", "shooter")
        env.state(combat=True); env.mock.fire("PLAYER_REGEN_DISABLED")
        self.assertEqual(env.ns.Status().profile, "Shooter")
        self.assertEqual(env.cv("GamePadCameraYawSpeed"), "1.4")
        env.state(combat=False); env.mock.fire("PLAYER_REGEN_ENABLED")
        self.assertEqual(env.ns.Status().profile, "Shooter")                   # kept for the exit delay
        env.tick(2)
        self.assertEqual(env.ns.Status().profile, "Action")

    def test_exit_delay_prevents_flicker(self):
        env = Env()
        env.state(mounted=True); env.tick()
        self.assertEqual(env.ns.Status().profile, "Mounted cruise")
        env.state(mounted=False); env.tick(0.6)
        self.assertEqual(env.ns.Status().profile, "Mounted cruise")
        env.state(mounted=True); env.tick(0.6)
        self.assertEqual(env.ns.Status().profile, "Mounted cruise")
        env.state(mounted=False); env.tick(3)
        self.assertEqual(env.ns.Status().profile, "Action")
        env.ns.SetExitDelay(0)
        env.state(mounted=True); env.tick()
        env.state(mounted=False); env.tick(0.6)
        self.assertEqual(env.ns.Status().profile, "Action")

    def test_force_and_auto(self):
        env = Env()
        env.ns.Force("tactical")
        env.state(mounted=True); env.tick(2)
        self.assertEqual(env.ns.Status().profile, "Tactical")
        env.ns.Force(None); env.tick()
        self.assertEqual(env.ns.Status().profile, "Mounted cruise")
        self.assertFalse(env.ns.Force("no_such_profile"))

    def test_unassigned_default_changes_nothing(self):
        env = Env()
        env.ns.Assign("default", None)
        env.ns.UseEverywhere("classic")
        env.ns.Assign("default", None)
        before = env.cvars()
        env.tick(5)
        self.assertEqual(env.cvars(), before)

    def test_disabled_addon_does_not_touch_the_camera(self):
        env = Env()
        env.ns.SetEnabled(False)
        before = env.cvars()
        env.state(mounted=True); env.tick(3)
        self.assertEqual(env.cvars(), before)
        env.ns.SetEnabled(True)
        self.assertEqual(env.ns.Status().profile, "Mounted cruise")

    def test_dynamiccam_warning(self):
        env = Env(addons=["DynamicCam"])
        env.advance(4)
        self.assertTrue(any("DynamicCam is also loaded" in p for p in env.printed()))
        env = Env()
        env.advance(4)
        self.assertFalse(any("DynamicCam" in p for p in env.printed()))


class Combat(unittest.TestCase):
    def test_blocked_cvars_are_retried_after_combat(self):
        env = Env()
        env.run("MOCK.protected.GamePadCameraYawSpeed = true; MOCK.protected.GamePadFaceMovementMaxAngle = true")
        env.state(combat=True)
        env.ns.Force("tactical")
        self.assertEqual(env.cv("GamePadCameraYawSpeed"), "1.25")             # refused in combat: unchanged
        self.assertEqual(env.cv("GamePadCameraPitchSpeed"), "1.4")            # allowed ones went through
        env.state(combat=False)
        env.mock.fire("PLAYER_REGEN_ENABLED")
        self.assertEqual(env.cv("GamePadCameraYawSpeed"), "1.6")
        self.assertEqual(env.cv("GamePadFaceMovementMaxAngle"), "90")

    def test_an_erroring_setcvar_does_not_break_the_addon(self):
        env = Env()
        env.run("local real = SetCVar; SetCVar = function(n, v) if n == 'GamePadCameraYawSpeed' then error('blocked') end return real(n, v) end")
        env.ns.UseEverywhere("shooter")
        self.assertEqual(env.cv("GamePadCameraPitchSpeed"), "1.3")


class MotionSickness(unittest.TestCase):
    def test_mouse_and_keyboard_ui(self):
        env = Env()
        self.assertEqual(env.cv("CameraKeepCharacterCentered"), "0")
        self.assertEqual(env.cv("CameraReduceUnexpectedMovement"), "0")
        self.assertEqual(env.db().motion.CameraKeepCharacterCentered, "1")     # the user's own value is kept
        env.ns.UseEverywhere("classic")
        self.assertEqual(env.cv("CameraKeepCharacterCentered"), "1")
        self.assertEqual(env.cv("CameraReduceUnexpectedMovement"), "1")
        self.assertIsNone(env.db().motion.CameraKeepCharacterCentered)

    def test_a_profile_without_camera_features_leaves_the_setting_alone(self):
        env = Env(login=False)
        env.mock.fire("ADDON_LOADED", "ControllerCam")
        env.ns.UseEverywhere("raid")
        env.advance(1.2)
        self.assertEqual(env.cv("CameraKeepCharacterCentered"), "1")
        self.assertEqual(env.cv("test_cameraOverShoulder"), "0")

    def test_saved_value_survives_a_reload_while_overridden(self):
        env = Env()
        env2 = reload_env(env)
        self.assertEqual(env2.db().motion.CameraKeepCharacterCentered, "1")
        env2.ns.UseEverywhere("classic")
        self.assertEqual(env2.cv("CameraKeepCharacterCentered"), "1")

    def test_turning_the_addon_off_restores_it(self):
        env = Env()
        env.ns.SetEnabled(False)
        self.assertEqual(env.cv("CameraKeepCharacterCentered"), "1")
        self.assertEqual(env.cv("CameraReduceUnexpectedMovement"), "1")

    def test_gamepad_ui_overrides_the_temporary_value_not_the_stored_one(self):
        env = Env(state={"gamepadUI": True})
        temp = [(env.mock.tempLog[i][1], env.mock.tempLog[i][2]) for i in range(1, len(env.mock.tempLog) + 1)]
        self.assertIn(("CameraKeepCharacterCentered", "0"), temp)
        self.assertIn(("CameraReduceUnexpectedMovement", "0"), temp)
        self.assertNotIn("CameraKeepCharacterCentered", env.setlog_names())
        self.assertIsNone(env.db().motion.CameraKeepCharacterCentered)
        env.ns.UseEverywhere("classic")
        temp = [(env.mock.tempLog[i][1], env.mock.tempLog[i][2]) for i in range(1, len(env.mock.tempLog) + 1)]
        self.assertIn(("CameraKeepCharacterCentered", "1"), temp)             # the game's value handed back

    def test_game_setting_its_own_temp_value_later_is_overridden_again(self):
        env = Env(state={"gamepadUI": True})
        env.run("C_CVar.SetTempCVar('CameraKeepCharacterCentered', '1')")
        env.advance(0.1)
        self.assertEqual(env.cv("CameraKeepCharacterCentered"), "0")


class SlashCommands(unittest.TestCase):
    def setUp(self):
        self.env = Env()

    def said(self, text):
        return " ".join(self.env.cmd(text))

    def test_help_status_and_list(self):
        self.assertIn("/ccam use", self.said("help"))
        self.assertIn("Action", self.said(""))
        self.assertIn("Town stroll", self.said("list"))
        self.assertIn("shoulder", self.said("settings"))

    def test_use_set_force_auto(self):
        self.assertIn("Hybrid", self.said("use hybrid"))
        self.assertEqual(self.env.ns.Status().profile, "Hybrid")
        self.said("use cla")                                                  # unique start of a name
        self.assertEqual(self.env.ns.Status().profile, "Classic")
        self.assertIn("No profile", self.said("use nonsense"))
        self.assertIn("more than one", self.said("use s"))                    # Shooter / Skies? "Flying" -> id skies
        self.said("set combat shooter")
        self.assertEqual(self.env.db().assign.combat, "shooter")
        self.said("set combat none")
        self.assertIsNone(self.env.db().assign.combat)
        self.assertIn("Unknown situation", self.said("set nowhere hybrid"))
        self.said('force "Town stroll"')
        self.assertEqual(self.env.ns.Status().profile, "Town stroll")
        self.said("auto")
        self.said("starter")
        self.assertEqual(self.env.db().assign.mounted, "cruise")

    def test_on_off(self):
        self.said("off")
        self.assertFalse(self.env.db().enabled)
        self.assertEqual(self.env.cv("GamePadCameraYawSpeed"), "1")
        self.said("on")
        self.assertEqual(self.env.cv("GamePadCameraYawSpeed"), "1.25")

    def test_copy_edit_curve_delete(self):
        self.said('copy action "My Action"')
        mine = self.env.ns.FindProfile("My Action")
        self.assertIsNotNone(mine)
        self.assertEqual(self.env.values(mine)['yawSpeed'], "x1.25")
        self.assertIn("Built-in", self.said("edit action yawSpeed 2"))
        self.assertIn("Done", self.said('edit "My Action" yawSpeed 2'))
        self.assertEqual(self.env.values(mine)['yawSpeed'], "x2")
        self.assertIn("outside", self.said('edit "My Action" yawSpeed 50'))
        self.assertIn("not valid", self.said('edit "My Action" yawSpeed abc'))
        self.assertIn("Unknown setting", self.said('edit "My Action" nonsense 1'))
        self.said('edit "My Action" followOnStick off')
        self.assertEqual(self.env.values(mine)['followOnStick'], 0)
        self.said('edit "My Action" followOnStick default')
        self.assertIsNone(self.env.values(mine)['followOnStick'])
        self.said('edit "My Action" shoulder 3')                              # a fixed offset replaces the curve
        self.assertIsNone(self.env.values(mine)['shoulderCurve'])
        self.assertIn("Done", self.said('curve "My Action" 0:3 10:1 30:0'))
        v = self.env.values(mine)
        self.assertIsNone(v["shoulder"]); self.assertEqual(v["shoulderCurve"][1][2], 3)
        self.assertIn("outside", self.said('curve "My Action" 0:99'))
        self.said('use "My Action"')
        self.assertEqual(self.env.cv("GamePadCameraYawSpeed"), "2")
        self.said('delete "My Action"')
        self.assertIsNone(self.env.ns.FindProfile("My Action"))
        self.assertIsNone(self.env.db().assign.default)                       # assignments to it are removed
        self.assertIn("Built-in", self.said("delete action"))

    def test_save_current_camera(self):
        self.env.ns.UseEverywhere("classic")
        self.env.run("MOCK.cvars.test_cameraOverShoulder = '1.5'; MOCK.cvars.GamePadCameraYawSpeed = '2'; MOCK.cvars.GamepadCameraFollowOnStick = '1'")
        self.said("save Snapshot")
        sid = self.env.ns.FindProfile("Snapshot")
        v = self.env.values(sid)
        self.assertEqual(v.shoulder, 1.5); self.assertEqual(v.yawSpeed, "x2"); self.assertEqual(v.followOnStick, 1)
        self.assertEqual(v.zoom, 7)

    def test_export_import_through_commands(self):
        self.said("export hybrid")
        box = self.env.lua.globals().ControllerCamTextBoxEdit
        s = box.text
        self.assertTrue(s.startswith("CC1:"))
        self.assertIn("Imported", self.said("import " + s))
        self.assertIsNotNone(self.env.ns.FindProfile("Hybrid (2)"))
        self.assertIn("checksum", self.said("import " + s[:-3]))
        self.assertIn("Nothing to import", self.said("import"))

    def test_info_command(self):
        text = self.said("info")
        self.assertIn("zoom 7", text)
        self.assertIn("test_cameraOverShoulder = 2", text)
        self.assertIn("CameraKeepCharacterCentered = 0", text)

    def test_describe_command_and_descriptions(self):
        plain = lambda t: re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "", t)
        text = plain(self.said("describe action"))
        self.assertIn("Action", text)
        self.assertIn("out-of-the-box", text)                                 # the description
        self.assertIn("Camera distance (yards): 7", text)
        self.assertIn("Head tracking strength: 1", text)
        self.assertIn("0:0 6:2 8:2 20:0", text)                              # the shoulder curve
        self.assertIn("game default", text)
        classic = plain(self.said("describe classic"))
        self.assertIn("game's own camera", classic)
        self.assertNotIn("Camera distance", classic)                          # Classic changes nothing itself
        self.assertIn("No profile", self.said("describe nonsense"))
        for i in range(1, len(self.env.ns.BUILTIN_LIST) + 1):                 # every built-in has a real description
            pid = self.env.ns.BUILTIN_LIST[i].id
            self.assertGreater(len(self.env.ns.ProfileDescription(pid)), 40, pid)

    def test_other_commands(self):
        self.said("flip"); self.assertTrue(self.env.db().flipShoulder)
        self.said("flip"); self.assertFalse(self.env.db().flipShoulder)
        self.said("delay 3"); self.assertEqual(self.env.db().exitDelay, 3)
        self.assertIn("usage", self.said("delay x"))
        self.said("config"); self.assertEqual(self.env.mock.opened, 42)
        self.said("debug"); self.said("debug")
        self.assertIn("unknown command", self.said("frobnicate"))
        self.assertEqual(self.env.lua.globals().SLASH_CONTROLLERCAM1, "/ccam")

    def test_tokenizer(self):
        t = self.env.run("return NS.Tokenize('a \"b c\" d  \"e')")
        self.assertEqual([t[i] for i in range(1, 5)], ["a", "b c", "d", "e"])


class OptionsPanel(unittest.TestCase):
    def test_panel_is_registered_and_every_control_works(self):
        env = Env()
        self.assertEqual(env.mock.category.name, "ControllerCam")
        self.assertEqual(env.mock.subcategory.name, "Profiles")
        env.ns.RefreshOptions()
        clicks = 0
        for i in range(1, len(env.mock.frames) + 1):
            f = env.mock.frames[i]
            fn = f.scripts.OnClick
            if fn and f.template in ("UIPanelButtonTemplate", "UICheckButtonTemplate"):
                for mouse in ("LeftButton", "RightButton"):
                    fn(f, mouse)
                    clicks += 1
                env.ns.RefreshOptions()
        self.assertGreater(clicks, 30)
        env.ns.Evaluate(True)
        for i in range(1, len(env.mock.frames) + 1):                          # hover every control: tooltips build
            f = env.mock.frames[i]
            if f.scripts.OnEnter:
                f.scripts.OnEnter(f)
                f.scripts.OnLeave(f)
        # sliders and the curve box
        for i in range(1, len(env.mock.frames) + 1):
            f = env.mock.frames[i]
            if f.template == "OptionsSliderTemplate" and f.scripts.OnValueChanged:
                f.scripts.OnValueChanged(f, 1)
        env.ns.RefreshOptions()

    def test_editor_edits_custom_profiles_only(self):
        env = Env()
        env.ns.SelectProfile("action")
        env.ns.RefreshOptions()
        env.run("""NS.SelectProfile(NS.DuplicateProfile('action', 'Panel test'))""")
        env.ns.RefreshOptions()
        sliders = [f for f in (env.mock.frames[i] for i in range(1, len(env.mock.frames) + 1)) if f.template == "OptionsSliderTemplate" and f.scripts.OnValueChanged]
        self.assertGreater(len(sliders), 10)
        pid = env.ns.FindProfile("Panel test")
        self.assertIsNotNone(pid)
        self.assertEqual(env.values(pid)['yawSpeed'], "x1.25")
        for f in sliders:
            f.scripts.OnValueChanged(f, 1)
        self.assertEqual(env.values(pid)['yawSpeed'], "x1")                   # the custom copy changed
        self.assertEqual(env.ns.BUILTIN.action["values"]["yawSpeed"], "x1.25")
        env.ns.SelectProfile("action")
        env.ns.RefreshOptions()
        for f in sliders:
            f.scripts.OnValueChanged(f, 2)
        self.assertEqual(env.ns.BUILTIN.action["values"]["yawSpeed"], "x1.25")   # built-in profiles stay read-only


class AdvancedEditing(unittest.TestCase):
    def setUp(self):
        self.env = Env()

    def said(self, text):
        return " ".join(self.env.cmd(text))

    def yaw(self, pid="action"):
        return self.env.ns.GetProfile(pid)["values"]["yawSpeed"]

    def test_built_in_profiles_are_locked_by_default(self):
        self.assertFalse(self.env.ns.IsEditable("action"))
        self.assertIn("locked", self.said("edit action yawSpeed 2"))
        self.assertEqual(self.yaw(), "x1.25")
        self.assertIsNone(self.env.db()["overrides"]["action"])
        r = self.env.run("local ok, why = NS.SetValue('action', 'yawSpeed', 'x2'); return { ok = ok, why = why }")
        self.assertFalse(r["ok"]); self.assertEqual(r["why"], "builtin")

    def test_advanced_unlocks_edits_and_the_original_stays_intact(self):
        self.said("advanced on")
        self.assertTrue(self.env.ns.IsEditable("action"))
        self.assertIn("Done", self.said("edit action yawSpeed 2"))
        self.assertEqual(self.yaw(), "x2")
        self.assertEqual(self.env.ns.BUILTIN.action["values"]["yawSpeed"], "x1.25")   # original untouched
        self.assertEqual(self.env.cv("GamePadCameraYawSpeed"), "2")                  # and it is in use right away
        self.assertTrue(self.env.ns.IsEdited("action"))
        self.assertEqual(self.env.ns.ProfileName("action"), "Action")
        self.assertIn("(edited)", self.said("list"))
        self.assertIn("(edited)", self.said("describe action"))
        self.assertIn("Stick turn speed (left/right): x2", re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "", self.said("describe action")))

    def test_bad_edits_do_not_create_an_override(self):
        self.said("advanced on")
        self.said("edit action yawSpeed 99")
        self.said("edit action nonsense 1")
        self.assertIsNone(self.env.db()["overrides"]["action"])
        self.assertFalse(self.env.ns.IsEdited("action"))

    def test_curve_edit_on_a_built_in(self):
        self.said("advanced on")
        self.said("curve action 0:0 5:1.5 20:0")
        v = self.env.ns.GetProfile("action")["values"]
        self.assertEqual(v["shoulderCurve"][2][2], 1.5)
        self.assertEqual(self.env.ns.BUILTIN.action["values"]["shoulderCurve"][2][2], 2)

    def test_reset_brings_the_original_back(self):
        self.said("advanced on")
        self.said("edit action yawSpeed 2")
        self.assertIn("original", self.said("reset action"))
        self.assertEqual(self.yaw(), "x1.25")
        self.assertEqual(self.env.cv("GamePadCameraYawSpeed"), "1.25")
        self.assertFalse(self.env.ns.IsEdited("action"))
        self.assertIn("Nothing to reset", self.said("reset action"))
        self.assertNotIn("(edited)", self.said("list"))

    def test_edits_survive_a_reload_and_advanced_off_only_locks(self):
        self.said("advanced on")
        self.said("edit hybrid zoom 12")
        env2 = reload_env(self.env)
        self.assertTrue(env2.db()["advanced"])
        self.assertEqual(env2.ns.GetProfile("hybrid")["values"]["zoom"], 12)
        env2.cmd("advanced off")
        self.assertFalse(env2.ns.IsEditable("hybrid"))
        self.assertEqual(env2.ns.GetProfile("hybrid")["values"]["zoom"], 12)        # kept, just locked
        self.assertIn("locked", " ".join(env2.cmd("edit hybrid zoom 5")))

    def test_edited_profiles_export_and_copy_with_their_new_values(self):
        self.said("advanced on")
        self.said("edit action yawSpeed 2")
        parsed, err = self.env.parse(self.env.ns.ExportById("action"))
        self.assertEqual(parsed["values"]["yawSpeed"], "x2")
        self.said('copy action "Mine"')
        self.assertEqual(self.env.values(self.env.ns.FindProfile("Mine"))["yawSpeed"], "x2")

    def test_built_in_profiles_still_cannot_be_deleted(self):
        self.said("advanced on")
        self.assertIn("cannot be deleted", self.said("delete action"))

    def test_bad_saved_overrides_are_cleaned(self):
        bad = "{ v = 1, overrides = { action = { yawSpeed = 'x2', shoulder = 500 }, ghost = { yawSpeed = 'x2' }, hybrid = { zoom = 9, evil = 1 }, raid = { zoom = 20 } } }"
        env = Env(db=bad)
        o = env.db()["overrides"]
        self.assertIsNone(o["action"]); self.assertIsNone(o["ghost"]); self.assertIsNone(o["hybrid"])
        self.assertEqual(o["raid"]["zoom"], 20)

    def test_options_panel_follows_the_advanced_switch(self):
        env = self.env
        env.ns.SelectProfile("action"); env.ns.RefreshOptions()
        sliders = [f for f in (env.mock.frames[i] for i in range(1, len(env.mock.frames) + 1)) if f.template == "OptionsSliderTemplate" and f.scripts.OnValueChanged]
        for f in sliders:
            f.scripts.OnValueChanged(f, 2)
        self.assertEqual(self.yaw(), "x1.25")                                   # locked: nothing changed
        env.ns.SetAdvanced(True); env.ns.RefreshOptions()
        for f in sliders:
            f.scripts.OnValueChanged(f, 2)
        self.assertTrue(env.ns.IsEdited("action"))
        self.assertEqual(self.yaw(), "x2")
        # unticking every checkbox (the Advanced one among them) turns advanced editing off again
        for i in range(1, len(env.mock.frames) + 1):
            f = env.mock.frames[i]
            if f.template == "UICheckButtonTemplate" and f.scripts.OnClick:
                f.checked = False
                f.scripts.OnClick(f, "LeftButton")
        self.assertFalse(env.db()["advanced"])


class Loading(unittest.TestCase):
    def test_an_event_the_client_does_not_know_does_not_break_loading(self):
        env = Env(login=False)
        # a second session where one event name is refused when registering
        env2 = Env.__new__(Env)
        env2.lua = LuaRuntime(unpack_returned_tuples=True)
        env2.mock = env2.lua.execute("return dofile('%s')" % lua_path(os.path.join(HERE, "wow_mock.lua")))
        env2.mock.badEvents["UPDATE_SHAPESHIFT_FORM"] = True
        env2.ns = env2.lua.table()
        for f in toc_files():
            env2.mock.loadFile(lua_path(os.path.join(ROOT, f)), env2.ns)
        env2.mock.fire("ADDON_LOADED", "ControllerCam")
        env2.mock.fire("PLAYER_ENTERING_WORLD")
        env2.advance(1.2)
        self.assertEqual(env2.ns.Status().profile, "Action")


    def test_every_language_loads_and_runs(self):
        for loc in LOCALES + ["enUS", "enGB"]:
            env = Env(locale=loc)
            env.state(mounted=True); env.tick()
            self.assertEqual(env.ns.Status().id, "cruise", loc)
            env.cmd("help"); env.cmd("list"); env.cmd("")

    def test_missing_optional_apis_do_not_break_loading(self):
        env = Env(login=False)
        env.run("C_InputInterfaceStyle = nil; Enum = nil; C_CVar = nil")
        env.mock.fire("ADDON_LOADED", "ControllerCam")
        env.mock.fire("PLAYER_ENTERING_WORLD")
        env.advance(1.2)
        self.assertEqual(env.ns.Status().profile, "Action")


if __name__ == "__main__":
    unittest.main(verbosity=2)
