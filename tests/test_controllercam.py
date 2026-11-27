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

    # movement: what the player answered when asked whether the profiles may set movement and the stick (True:
    # they may, as every test before the question assumes; None: not answered yet, the question still to come)
    def __init__(self, db=None, cvars=None, locale="enUS", addons=(), state=None, login=True, movement=True):
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
            d = self.ns.GetDB()
            if movement is not None and d is not None and d.movement is None:
                d.movement = movement
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
                used.update(m.group(1) for m in re.finditer(r"help = " + STR, t))
                used.update(m.group(1) for m in re.finditer(r"\bname = " + STR + r",\s+from", t))
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
        self.assertEqual(ids[:2], ["action", "hybrid"])               # the recommended setup's camera first
        self.assertEqual(ids[-1], "classic")                           # the game's own camera last
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
        self.bad(self.make("n=Test;shoulderCurve=" + ",".join("%d:1" % i for i in range(13))))   # too many points
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

    def setup_string(self, body):
        return self.env.run('return "CCS1:" .. NS.ShareChecksum(%r) .. ":" .. %r' % (body, body))

    def import_setup(self, env, text):
        env.lua.globals().NS = env.ns
        r = env.lua.eval("function(s) local ok, e = NS.ImportSetup(s); return { ok = ok, e = e } end")(text)
        return r["ok"], r["e"]

    def test_the_whole_setup_goes_out_and_comes_back(self):
        e, ns = self.env, self.env.ns
        mine, _ = e.importing(ns.ExportById("hybrid"))                  # a profile of your own
        self.assertTrue(ns.Assign("mounted", mine))
        self.assertTrue(ns.Assign("combat", "shooter"))
        ns.SetExitDelay(3)
        ns.SetFlipShoulder(True)
        ns.SetAdvanced(True)
        self.assertTrue(ns.SetValue("action", "shoulder", 1.5))         # and a built-in one you edited
        text = ns.ExportSetup()
        self.assertTrue(text.startswith("CCS1:"))
        self.assertNotRegex(text, r"\s")
        self.assertEqual(e.lua.globals().ControllerCam.ExportSetup(), text)     # what the HUD asks for

        other = Env()
        ok, err = self.import_setup(other, text[:30] + "\n " + text[30:])
        self.assertTrue(ok, err)
        self.assertEqual(other.ns.ExportSetup(), text)                  # the same setup, to the letter
        db = other.db()
        self.assertEqual(db["assign"]["combat"], "shooter")
        self.assertEqual(db["exitDelay"], 3)
        self.assertTrue(db["flipShoulder"])
        self.assertEqual(db["overrides"]["action"]["shoulder"], 1.5)
        theirs = db["assign"]["mounted"]
        self.assertFalse(other.ns.IsBuiltin(theirs))
        self.assertEqual(other.ns.ExportById(theirs), ns.ExportById(mine))
        self.assertTrue(other.lua.globals().ControllerCam.ImportSetup(text))    # again: nothing is doubled
        self.assertEqual(len(list(db["profiles"].keys())), 1)
        self.assertEqual(other.ns.ExportSetup(), text)

    def test_a_bad_setup_changes_nothing(self):
        e = self.env
        e.importing(e.ns.ExportById("hybrid"))
        text = e.ns.ExportSetup()
        before = e.saved()
        bad = ["junk", "", text[:-4], text.replace("CCS1", "CCS2", 1), "CCS1:" + "0" * 8 + ":" + "a" * 40000,
               self.setup_string("a=default>nosuch"),                   # a profile that does not exist
               self.setup_string("a=default>#2&p=" + e.ns.ExportById("hybrid")),    # ... or did not come along
               self.setup_string("a=nowhere>action"),                   # a situation that does not exist
               self.setup_string("a=default>action&d=99"),
               self.setup_string("a=default>action&f=2"),
               self.setup_string("a=default>action&s=1>9"),
               self.setup_string("a=default>action&x=1"),
               self.setup_string("a=default>action&o=nosuch>" + e.ns.ExportById("hybrid")),
               self.setup_string("a=default>action&p=CC1:00000000:n=Evil;shoulder=1")]
        for s in bad:
            ok, err = self.import_setup(e, s)
            self.assertIsNone(ok, s[:60])
            self.assertTrue(err, s[:60])
        self.assertEqual(e.saved(), before)
        self.assertIn("newer", self.import_setup(e, text.replace("CCS1", "CCS2", 1))[1])
        self.assertIn("checksum", self.import_setup(e, text[:-4])[1])

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


class Movement(unittest.TestCase):
    """How you move and the stick's speeds are yours: the profiles set them only once you said they may."""

    MINE = {"GamePadFaceMovementMaxAngle": "90", "GamePadTurnWithCamera": "2", "GamePadCameraYawSpeed": "1.5"}

    def test_asked_once_and_nothing_of_yours_changed_before_you_answer(self):
        env = Env(cvars=dict(self.MINE), movement=None)
        env.advance(4)                                               # (asked a few seconds in)
        ask = env.lua.globals().ControllerCamMovementAsk
        self.assertTrue(ask.shown)
        self.assertEqual(env.mock.overrides.PAD1, "CLICK ControllerCamMovementYes:LeftButton")   # A: let them
        self.assertEqual(env.mock.overrides.PAD2, "CLICK ControllerCamMovementNo:LeftButton")    # B: keep mine
        for cvar, v in self.MINE.items():
            self.assertEqual(env.cv(cvar), v, cvar)                  # yours, untouched while asked
        self.assertEqual(env.cv("test_cameraDynamicPitch"), "1")     # (the camera itself is the profile's)
        no = env.lua.globals().ControllerCamMovementNo
        no.scripts.OnClick(no)
        self.assertFalse(ask.shown)
        self.assertIsNone(env.mock.overrides.PAD1)                   # the game's buttons again
        self.assertIs(env.db().movement, False)
        for cvar, v in self.MINE.items():
            self.assertEqual(env.cv(cvar), v, cvar)
        env2 = reload_env(env, movement=None)                        # not asked again
        env2.advance(4)
        ask2 = env2.lua.globals().ControllerCamMovementAsk
        self.assertTrue(ask2 is None or not ask2.shown)

    def test_keep_mine_puts_back_what_a_profile_had_changed(self):
        env = Env(cvars=dict(self.MINE))                             # (an old install: the profiles set them)
        self.assertEqual(env.cv("GamePadFaceMovementMaxAngle"), "0")
        self.assertEqual(env.cv("GamePadCameraYawSpeed"), "1.25")
        env.cmd("movement")                                          # /ccam movement: yours again
        self.assertIs(env.db().movement, False)
        for cvar, v in self.MINE.items():
            self.assertEqual(env.cv(cvar), v, cvar)                  # as you had them
        env.ns.Evaluate(True)
        self.assertEqual(env.cv("GamePadFaceMovementMaxAngle"), "90")   # and left alone after
        env.cmd("movement")                                          # and back to the profiles'
        self.assertEqual(env.cv("GamePadFaceMovementMaxAngle"), "0")

    def test_let_them_sets_them_as_before(self):
        env = Env(cvars=dict(self.MINE), movement=None)
        env.advance(4)
        yes = env.lua.globals().ControllerCamMovementYes
        yes.scripts.OnClick(yes)
        self.assertIs(env.db().movement, True)
        self.assertEqual(env.cv("GamePadFaceMovementMaxAngle"), "0")
        self.assertEqual(env.cv("GamePadCameraYawSpeed"), "1.25")


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
        self.assertEqual(cv("test_cameraTargetFocusEnemyEnable"), "1")
        self.assertEqual(cv("test_cameraTargetFocusEnemyStrengthYaw"), "0.6")   # whole body in view: 60% of 1
        self.assertEqual(cv("test_cameraTargetFocusEnemyStrengthPitch"), "0.45")  # ... and of 0.75
        self.assertEqual(cv("cameraSmoothStyle"), "0")
        self.assertEqual(env.mock.state.zoom, 7)
        self.assertEqual(cv("test_cameraOverShoulder"), "1")                  # whole body in view, on the zoom curve
        self.assertEqual(env.ns.Status().profile, "Action")

    def test_shoulder_offset_follows_the_zoom_curve(self):
        env = Env()
        frame = env.ns.frame
        for zoom, expect in [(8, "1"), (3, "1.5"), (5, "1.5"), (6.5, "1.25"), (10, "1"), (11.5, "0.5"), (13, "0"),
                             (30, "0"), (2, "1.5"), (1.5, "0.75"), (0, "0"), (7, "1")]:
            env.state(zoom=zoom)
            frame.scripts.OnUpdate(frame, 0.2)
            self.assertEqual(env.cv("test_cameraOverShoulder"), expect, zoom)

    def test_a_scene_of_the_huds_holds_the_camera_in_the_middle(self):
        """The HUD's camp fire scene turns the camera round the character: the offset rests at the middle while it
        plays, the curve and the profile's distance stay out of it, and letting go puts the profile back."""
        env = Env()
        frame, cam = env.ns.frame, env.lua.globals().ControllerCam
        env.state(zoom=8)
        frame.scripts.OnUpdate(frame, 0.2)
        self.assertEqual(env.cv("test_cameraOverShoulder"), "1")
        env.mock.cvars.cameraSmoothStyle = "4"                         # the game's auto-follow, on
        cam.Hold(True)
        self.assertTrue(cam.IsHeld())
        self.assertEqual(env.cv("test_cameraOverShoulder"), "0")
        self.assertEqual(env.cv("cameraSmoothStyle"), "0")             # resting: it pulled a flight's camera back
        self.assertEqual(env.ns.db.heldWas.cameraSmoothStyle, "4")     # (kept, in case the game closes now)
        env.state(zoom=11)                                             # the scene eases the camera out
        frame.scripts.OnUpdate(frame, 0.2)
        env.ns.Evaluate(True)
        self.assertEqual(env.cv("test_cameraOverShoulder"), "0")       # neither the curve nor a profile moves it
        self.assertEqual(env.mock.state.zoom, 11)
        cam.Hold(False)
        self.assertEqual(env.cv("cameraSmoothStyle"), "0")             # auto-follow as the profile has it
        self.assertIsNone(env.ns.db.heldWas)
        self.assertNotEqual(env.cv("test_cameraOverShoulder"), "0")     # back on the curve at once
        self.assertEqual(env.cv("test_cameraOverShoulder"),
                         env.ns.FormatNumber(env.run("return NS.EvalCurve(NS.BUILTIN.action.values.shoulderCurve, 11)")))

    def test_a_scene_cut_off_by_the_game_closing_is_put_back_on_load(self):
        env = Env(db='{ heldWas = { cameraSmoothStyle = "4", bogus = "1" } }', cvars={"cameraSmoothStyle": "0"},
                  login=False)
        env.mock.fire("ADDON_LOADED", "ControllerCam")
        self.assertEqual(env.cv("cameraSmoothStyle"), "4")             # what the scene held, given back
        self.assertIsNone(env.ns.db.heldWas)

    def test_close_zoom_keeps_the_character_on_screen(self):
        """A sideways offset in yards covers more screen the closer the camera is: keep it a fraction of the view.
        (Not Action: its offsets are the player's own choice per zoom view, tested by value in ZoomViews. Town
        stroll has more at its closest steps by the same choice, so it is held to this from 4 yards out.)"""
        env = Env()
        ns = env.ns
        for i in range(1, len(ns.BUILTIN_LIST) + 1):
            prof = ns.BUILTIN_LIST[i]
            curve = prof["values"]["shoulderCurve"]
            if curve is None or prof.id == "action":
                continue
            for zoom in [x / 2 for x in range(8 if prof.id == "stroll" else 1, 41)]:
                offset = env.run("return NS.EvalCurve(NS.BUILTIN['%s'].values.shoulderCurve, %s)" % (prof.id, zoom))
                self.assertLessEqual(abs(offset) / (1.78 * zoom), 0.25, "%s at zoom %s: offset %s" % (prof.id, zoom, offset))

    def test_the_middle_zoom_band_keeps_the_character_where_close_zoom_puts_it(self):
        """Up to `hold` the offset grows with the distance, so the character stays at the same place on screen as
        at the closest zoom; it used to stop growing at `ramp`, and the character drifted toward the middle."""
        env = Env()
        ns = env.ns
        for i in range(1, len(ns.BUILTIN_LIST) + 1):
            prof = ns.BUILTIN_LIST[i]
            curve = prof["values"]["shoulderCurve"]
            if curve is None or len(curve) < 4 or prof.id == "action":
                continue
            n = len(curve)                                                           # ... ramp, hold, fade
            (ramp, near), (hold, mid) = (curve[n - 2][1], curve[n - 2][2]), (curve[n - 1][1], curve[n - 1][2])
            self.assertGreater(mid, near, prof.id)                                   # further out in the middle,
            self.assertAlmostEqual(mid / hold, near / ramp, delta=0.01, msg=prof.id)  # by the same share of the view
            self.assertEqual(curve[1][2], 0, prof.id)                                # (the close end as it was)

    def test_in_town_the_closest_steps_move_your_character_out_of_the_view(self):
        env = Env()
        env.state(resting=True)
        env.tick()
        self.assertEqual(env.ns.Status().profile, "Town stroll")
        frame = env.ns.frame
        # (the old curve was zoom / 4 up to 4 yards: half a yard more from 0.5 to 2, nothing new from 4 out)
        for zoom, offset in [(0, 0), (1, 0.733), (1.5, 0.867), (2, 1), (3, 1), (4, 1), (6, 1.5), (9, 0.75), (12, 0)]:
            env.state(zoom=zoom)
            frame.scripts.OnUpdate(frame, 0.2)
            self.assertAlmostEqual(float(env.cv("test_cameraOverShoulder")), offset, places=2, msg=zoom)

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
        self.assertEqual(env.cv("test_cameraOverShoulder"), "-1")
        env.state(zoom=3)
        frame = env.ns.frame
        frame.scripts.OnUpdate(frame, 0.2)
        self.assertEqual(env.cv("test_cameraOverShoulder"), "-1.5")
        self.assertEqual(env.cv("test_cameraTargetFocusEnemyStrengthYaw"), "1")     # only the offset is mirrored
        env.ns.SetFlipShoulder(False)
        self.assertEqual(env.cv("test_cameraOverShoulder"), "1.5")           # zoom 3 is kept: edits do not move the camera

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
        env.ns.GetDB().movement = True                               # (the profiles may set the stick's speeds)
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
        env.state(flying=False, mounted=False, swimming=True); env.tick(2); self.assertEqual(name(), "Action")
        env.state(swimming=False, vehicle=True); env.tick(2); self.assertEqual(name(), "Hybrid")
        env.state(vehicle=False, instance="raid"); env.tick(2); self.assertEqual(name(), "Raid view")
        env.state(instance="party"); env.tick(2); self.assertEqual(name(), "Action")
        env.state(instance=None); env.tick(2); self.assertEqual(name(), "Action")

    def test_closer_on_an_enemy_target_and_back_out_after(self):
        env = Env()
        env.run("""
            ENEMY = false
            function UnitExists(u) return u == "target" and ENEMY end
            function UnitCanAttack() return ENEMY end
            function UnitIsDead() return false end
        """)
        g = env.lua.globals()
        self.assertEqual(env.db().targetZoom, 0)                     # off to begin with
        env.state(zoom=14)
        g.ENEMY = True
        env.mock.fire("PLAYER_TARGET_CHANGED")
        self.assertEqual(env.mock.state.zoom, 14)                    # off: nothing
        self.assertIn("6.0", " ".join(env.cmd("targetzoom 6")))
        self.assertAlmostEqual(env.mock.state.zoom, 6)               # an enemy target: in close
        g.ENEMY = False
        env.mock.fire("PLAYER_TARGET_CHANGED")
        env.tick(0.6)
        self.assertAlmostEqual(env.mock.state.zoom, 6)               # (a moment: the next one may come)
        env.tick(2.5)
        self.assertAlmostEqual(env.mock.state.zoom, 14)              # gone: back out where you had it
        g.ENEMY = True
        env.mock.fire("PLAYER_TARGET_CHANGED")
        env.state(zoom=9)                                            # you zoom yourself meanwhile
        g.ENEMY = False
        env.mock.fire("PLAYER_TARGET_CHANGED")
        env.tick(3)
        self.assertAlmostEqual(env.mock.state.zoom, 9)               # yours stays
        env.state(mounted=True, zoom=20)
        g.ENEMY = True
        env.mock.fire("PLAYER_TARGET_CHANGED")
        self.assertAlmostEqual(env.mock.state.zoom, 20)              # mounted: left alone

    def test_indoors_does_nothing_until_assigned_and_a_pole_alone_changes_nothing(self):
        env = Env()
        name = lambda: env.ns.Status().profile
        env.state(indoors=True, mainHand=6256); env.tick(2)
        self.assertEqual(name(), "Action")
        self.assertIsNone(env.ns.db.assign.indoors)
        self.assertEqual(env.ns.db.assign.fishing, "shooter")       # fishing has its view from the start

    def test_indoors(self):
        env = Env()
        name = lambda: env.ns.Status().profile
        self.assertIn("Indoors", " ".join(env.cmd("set indoors shooter")))
        env.state(indoors=True); env.tick(); self.assertEqual(name(), "Shooter")
        env.state(resting=True); env.tick(); self.assertEqual(name(), "Shooter")        # an inn: indoors wins over city
        env.state(instance="party"); env.tick(2); self.assertEqual(name(), "Action")    # a dungeon keeps its own camera
        env.state(instance=None, resting=False, mounted=True); env.tick(2); self.assertEqual(name(), "Mounted cruise")
        env.state(mounted=False, indoors=False); env.tick(2); self.assertEqual(name(), "Action")

    def test_fishing(self):
        env = Env()
        name = lambda: env.ns.Status().profile
        env.state(mainHand=6256); env.tick(2); self.assertEqual(name(), "Action")       # a pole in hand: nothing yet
        env.state(channel=131474); env.tick(); self.assertEqual(name(), "Shooter")      # you cast: over the shoulder
        env.state(channel=None); env.tick(5); self.assertEqual(name(), "Shooter")       # between casts the view holds
        env.state(channel=131474); env.tick(); env.state(channel=None); env.tick(5)
        self.assertEqual(name(), "Shooter")
        env.tick(14); self.assertEqual(name(), "Action")                                # until you have stopped a while
        env.state(channel=131474); env.tick()
        env.state(channel=None, mainHand=25); env.tick(3); self.assertEqual(name(), "Action")    # the pole put away
        env.state(channel=1234); env.tick(2); self.assertEqual(name(), "Action")        # another channel is not fishing
        env.cmd("set fishing cinematic")
        env.state(channel=131474); env.tick(); self.assertEqual(name(), "Cinematic")    # the cast itself, no pole
        env.cmd("set combat tactical")
        env.state(combat=True); env.tick(); self.assertEqual(name(), "Tactical")        # a fight comes first
        env.state(combat=False); env.cmd("set fishing none"); env.tick(3)
        self.assertEqual(name(), "Action")                                              # and it can be left empty

    def test_an_install_from_before_gets_the_fishing_view_once(self):
        old = Env(db="{ v = 1, assign = { default = 'hybrid' } }")
        self.assertEqual(old.ns.db.assign.fishing, "shooter")
        self.assertEqual(old.ns.db.assign.default, "hybrid")
        own = Env(db="{ v = 1, assign = { default = 'hybrid', fishing = 'cinematic' } }")
        self.assertEqual(own.ns.db.assign.fishing, "cinematic")                         # yours is kept
        later = Env(db="{ v = 2, assign = { default = 'hybrid' } }")
        self.assertIsNone(later.ns.db.assign.fishing)                                   # emptied since: stays empty

    def test_head_tracking_rests_in_the_water_and_the_way_in_is_noted(self):
        env = Env()
        head = lambda: float(env.cv("test_cameraHeadMovementStrength"))
        self.assertEqual(head(), 1)
        shoulder = env.cv("test_cameraOverShoulder")
        pitch = lambda: float(env.cv("test_cameraDynamicPitch"))
        self.assertEqual(pitch(), 1)
        env.state(swimming=True); env.tick(2)
        self.assertEqual(head(), 0)                                    # the stroke does not drag the camera
        self.assertEqual(pitch(), 0)                                   # nor does the sea bed tilt it
        self.assertEqual(float(env.cv("cameraTerrainTilt")), 0)
        self.assertEqual(env.cv("test_cameraOverShoulder"), shoulder)  # the offset is left as it was
        self.assertEqual(env.ns.Status().profile, "Action")
        env.state(swimming=False); env.tick(2)
        self.assertEqual(head(), 1)                                    # out of the water: as the profile has it
        self.assertEqual(pitch(), 1)
        trace = list(env.ns.GetDB().trace.values())
        self.assertTrue(any("into the water: " in l and "test_cameraOverShoulder=" in l and "facing=" in l
                            for l in trace))
        self.assertTrue(any("a second later: " in l for l in trace))
        self.assertTrue(any("out of the water: " in l for l in trace))

    def test_in_the_water_you_face_the_way_you_do_on_land(self):
        env = Env()
        for id in ("action", "hybrid", "stroll", "cruise", "skies", "shooter"):
            env.ns.UseEverywhere(id)
            env.tick(1)
            self.assertEqual(float(env.cv("GamePadFaceMovementSwimming")), 0, id)   # no turning to the stick

    def test_the_water_keeps_the_camera_you_have(self):
        env = Env()
        self.assertIsNone(env.ns.db.assign.swimming)                  # a fresh install: no swap in the water
        before = {k: env.mock.cvars[k] for k in ("test_cameraOverShoulder", "GamePadFaceMovementMaxAngle")}
        env.state(swimming=True); env.tick(2)
        self.assertEqual(env.ns.Status().profile, "Action")
        after = {k: env.mock.cvars[k] for k in before}
        self.assertEqual(before, after)                                # nothing moves sideways, nothing turns you
        old = Env(db="{ v = 2, assign = { default = 'action', swimming = 'hybrid' } }")
        self.assertIsNone(old.ns.db.assign.swimming)                   # the old starter's swap goes
        mine = Env(db="{ v = 3, assign = { default = 'action', swimming = 'hybrid' } }")
        self.assertEqual(mine.ns.db.assign.swimming, "hybrid")         # chosen since: yours
        other = Env(db="{ v = 2, assign = { default = 'action', swimming = 'cruise' } }")
        self.assertEqual(other.ns.db.assign.swimming, "cruise")        # one you picked yourself: kept

    def test_a_preset_for_everywhere_tells_the_hud(self):
        env = Env()
        env.lua.execute("HUDHEARD = {}; ControllerCamHUD = { CameraPreset = function(id) table.insert(HUDHEARD, id) end }")
        env.cmd("use shooter")
        env.cmd("set combat classic")                         # one situation only: the HUD is not told
        env.cmd("starter")
        heard = list(env.lua.globals().HUDHEARD.values())
        self.assertEqual(heard, ["shooter", "action"])
        env.lua.execute("ControllerCamHUD = nil")
        env.cmd("use hybrid")                                 # without the HUD: nothing to tell, nothing breaks

    def test_shapeshift_forms_scale_the_shoulder_offset(self):
        env = Env()
        env.cmd("use shooter")
        env.mock.state.zoom = 5
        env.tick(1)
        normal = float(env.cv("test_cameraOverShoulder"))
        self.assertGreater(normal, 0)
        env.state(form=1)                                     # cat form
        env.mock.fire("UPDATE_SHAPESHIFT_FORM")
        env.tick(0.2)
        self.assertAlmostEqual(float(env.cv("test_cameraOverShoulder")), normal * 0.6, places=2)
        self.assertIn("60%", " ".join(env.cmd("formoffset")))
        env.cmd("formoffset 40")
        self.assertAlmostEqual(float(env.cv("test_cameraOverShoulder")), normal * 0.4, places=2)
        env.state(form=0)
        env.mock.fire("UPDATE_SHAPESHIFT_FORM")
        env.tick(0.2)
        self.assertAlmostEqual(float(env.cv("test_cameraOverShoulder")), normal, places=2)
        self.assertIn("not in a form", " ".join(env.cmd("formoffset")))
        saved = env.mock.serialize(env.lua.globals().ControllerCamDB)
        env2 = Env(db=saved)
        self.assertAlmostEqual(env2.ns.db.formOffset[1], 0.4)

    def test_unknown_situation_lists_them_all(self):
        env = Env()
        out = " ".join(env.cmd("set nowhere action"))
        for word in ("vehicle", "fishing", "indoors", "default"):
            self.assertIn(word, out)

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
        self.assertIn("test_cameraOverShoulder = 1", text)
        self.assertIn("zoom view: body", text)
        self.assertIn("this game has none", text)                              # no field of view in this mock
        self.assertIn("CameraKeepCharacterCentered = 0", text)

    def test_describe_command_and_descriptions(self):
        plain = lambda t: re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "", t)
        text = plain(self.said("describe action"))
        self.assertIn("Action", text)
        self.assertIn("out-of-the-box", text)                                 # the description
        self.assertIn("Camera distance (yards): 7", text)
        self.assertIn("Head tracking strength: 1", text)
        self.assertIn("1:0 2:1.5 6:1.5 7:1 10:1 13:0", text)                   # the shoulder curve
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


class ExperimentalNotice(unittest.TestCase):
    """The game's notice about its experimental camera settings: answered once, then not asked again."""

    def env(self, db=None):
        e = Env(db=db)
        e.lua.execute("""
            POPUP = false
            function StaticPopup_Visible(which) return POPUP and which == "EXPERIMENTAL_CVAR_WARNING" and "StaticPopup1" or nil end""")
        e.g = e.lua.globals()
        e.g.UIParent.RegisterEvent(e.g.UIParent, "EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")   # the game's own
        return e

    def ask(self, e, answer):
        e.g.POPUP = True
        e.mock.fire("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
        e.advance(1)
        e.g.POPUP = False
        if answer == "disable":                                     # the game puts its test settings back
            for k in list(e.mock.cvars.keys()):
                if k.startswith("test_"):
                    e.mock.cvars[k] = e.mock.defaults[k]
        e.advance(1)

    def test_accepted_once_it_is_not_asked_again(self):
        e = self.env()
        self.assertTrue(e.ns.TestCvarsOn())                        # the Action camera's shoulder offset
        self.assertFalse(e.db().noticeAccepted)
        self.ask(e, "accept")
        self.assertTrue(e.db().noticeAccepted)
        self.assertIsNone(e.g.UIParent.events["EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED"])   # the game is not told to ask
        saved = e.lua.eval("function(t) local o = {} for k, v in pairs(t) do if type(v) ~= 'table' then o[#o + 1] = k .. '=' .. tostring(v) end end return table.concat(o, ',') end")(e.db())
        self.assertIn("noticeAccepted=true", saved)
        e2 = Env(db="{ v = 3, noticeAccepted = true }")             # the next login
        self.assertIsNone(e2.lua.globals().UIParent.events["EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED"])
        self.assertTrue(e2.ns.notice.quieted)
        self.assertIn("ask about its experimental camera settings again", " ".join(e2.cmd("notice")))
        self.assertFalse(e2.db().noticeAccepted)
        self.assertTrue(e2.lua.globals().UIParent.events["EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED"])

    def test_every_listener_of_the_game_is_quieted_not_only_uiparent(self):
        e = Env(db="{ v = 3, noticeAccepted = true }", login=False)
        g = e.lua.globals()
        e.lua.execute("""
            OtherAsker = CreateFrame("Frame", "OtherAsker")
            OtherAsker:RegisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
            function GetFramesRegisteredForEvent(event)
                local out = {}
                for _, f in ipairs(ALL_FRAMES) do if f.events[event] then out[#out + 1] = f end end
                return unpack(out)
            end""".replace("ALL_FRAMES", "WOW_MOCK_FRAMES"))
        g.WOW_MOCK_FRAMES = e.mock.frames
        e.mock.fire("ADDON_LOADED", "ControllerCam")
        e.mock.fire("PLAYER_LOGIN")
        self.assertIsNone(g.OtherAsker.events["EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED"])
        self.assertIn("OtherAsker", e.ns.notice.quietedFrom)

    def test_disable_is_respected_and_nothing_is_remembered(self):
        e = self.env()
        self.ask(e, "disable")
        self.assertFalse(e.db().noticeAccepted)
        self.assertTrue(e.g.UIParent.events["EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED"])

    def test_a_request_the_game_never_shows_is_not_taken_for_a_yes(self):
        e = self.env()
        e.mock.fire("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")        # no dialog appears
        e.advance(7)
        self.assertFalse(e.db().noticeAccepted)


class ZoomViews(unittest.TestCase):
    """The recommended camera by zoom view: offset and target focus hold across a view and ease between them."""

    def setUp(self):
        self.env = Env()

    def at(self, zoom, env=None):
        env = env or self.env
        env.state(zoom=zoom)
        env.ns.frame.scripts.OnUpdate(env.ns.frame, 0.2)

    def shoulder(self, env=None):
        return float((env or self.env).cv("test_cameraOverShoulder"))

    def focus(self):
        return (float(self.env.cv("test_cameraTargetFocusEnemyStrengthYaw")),
                float(self.env.cv("test_cameraTargetFocusEnemyStrengthPitch")))

    def values(self, pid="action"):
        return self.env.ns.GetProfile(pid)["values"]

    def table(self, key, pid="action"):
        self.env.lua.globals().NS = self.env.ns
        got = self.env.run("return NS.ViewValues(NS.GetProfile('%s').values.%s)" % (pid, key))
        return [got[i] for i in range(1, 7)]

    def test_a_little_offset_stays_until_you_are_really_in_first_person(self):
        for zoom, offset in ((0, 0), (0.1, 0.125), (0.2, 0.25), (0.4, 0.5), (0.5, 0.5), (1, 0.5), (1.2, 0.5),
                             (1.5, 0.75), (2, 1.5), (3, 1.5), (16, 0), (30, 0)):
            self.at(zoom)
            self.assertAlmostEqual(self.shoulder(), offset, 3, "at %s yards" % zoom)
        ns = self.env.ns
        lua = self.env.lua
        curve = lambda *points: lua.table_from([lua.table_from(list(p)) for p in points])
        self.assertAlmostEqual(ns.OffsetAt(curve((0, 0), (2, -1)), 0.5), -0.5)    # the other shoulder: that side
        self.assertAlmostEqual(ns.OffsetAt(curve((0, 0), (2, 0.1)), 0.5), 0.1)    # never more than over the shoulder
        self.assertEqual(ns.OffsetAt(curve((0, 0), (39, 0)), 0.5), 0)             # a centred camera stays centred

    def test_recommended_offset_and_focus_in_each_view(self):
        self.assertEqual(self.table("shoulderCurve"), [0, 1.5, 1.5, 1, 0, 0])
        self.assertEqual(self.table("focusCurve"), [0, 1, 1, 0.6, 0.3, 0])
        views = [(0, 0, 0), (2.75, 1.5, 1), (5.25, 1.5, 1), (8.5, 1, 0.6), (16, 0, 0.3), (33, 0, 0)]
        for zoom, offset, share in views:
            self.at(zoom)
            self.assertAlmostEqual(self.shoulder(), offset, places=3, msg=zoom)
            yaw, pitch = self.focus()
            self.assertAlmostEqual(yaw, share, places=3, msg=zoom)
            self.assertAlmostEqual(pitch, 0.75 * share, places=3, msg=zoom)
        self.assertEqual(self.env.cv("cameraDistanceMaxZoomFactor"), "2.2")     # as far out as before

    def test_nothing_snaps_between_the_views(self):
        last = None
        for step in range(0, 331):
            self.at(step / 10)
            now = (self.shoulder(),) + self.focus()
            if last:
                for a, b in zip(last, now):
                    self.assertLessEqual(abs(a - b), 0.16, step / 10)
            last = now

    def test_the_camera_rests_within_a_view(self):
        self.at(8)
        n = len(self.env.mock.setLog)
        for zoom in (7, 7.5, 9, 10):
            self.at(zoom)
        self.assertEqual(len(self.env.mock.setLog), n)

    def test_your_own_values_come_back_after_the_by_zoom_ones(self):
        self.at(16)
        self.env.ns.UseEverywhere("classic")
        self.assertEqual(self.env.cv("test_cameraTargetFocusEnemyStrengthYaw"), "0.5")
        self.assertEqual(self.env.cv("test_cameraTargetFocusEnemyEnable"), "0")
        env = Env(cvars={"test_cameraTargetFocusEnemyStrengthYaw": "0.2"})
        env.ns.SetEnabled(False)
        self.assertEqual(env.cv("test_cameraTargetFocusEnemyStrengthYaw"), "0.2")
        self.assertEqual(env.cv("test_cameraOverShoulder"), "0")

    def test_target_focus_off_stays_off(self):
        self.env.cmd("advanced on")
        self.env.cmd("edit action focusEnemy off")
        for zoom in (3, 16):
            self.at(zoom)
            self.assertEqual(self.env.cv("test_cameraTargetFocusEnemyEnable"), "0")
            self.assertEqual(self.env.cv("test_cameraTargetFocusEnemyStrengthYaw"), "1")   # the plain strength

    def test_the_switches_need_advanced_on_a_built_in_profile(self):
        self.assertFalse(self.env.ns.SetByZoom("action", "focusCurve", False)[0])
        self.assertIsNotNone(self.values()["focusCurve"])
        self.assertIsNone(self.env.db()["overrides"]["action"])

    def test_target_focus_by_zoom_switched_off_and_on(self):
        self.env.ns.SetAdvanced(True)
        self.env.ns.SetByZoom("action", "focusCurve", False)
        self.assertIsNone(self.values()["focusCurve"])
        for zoom in (3, 8, 30):
            self.at(zoom)
            self.assertEqual(self.focus(), (1, 0.75))                      # full strength at every distance
        self.env.ns.SetByZoom("action", "focusCurve", True)
        self.assertEqual(self.table("focusCurve"), [0, 1, 1, 0.6, 0.3, 0])

    def test_offset_by_zoom_switched_off_keeps_what_you_see_and_on_gives_the_points_back(self):
        self.env.ns.SetAdvanced(True)
        self.env.cmd("curve action 0:0 3:2 20:0")
        self.at(3)
        self.env.ns.SetByZoom("action", "shoulderCurve", False)
        self.assertEqual(self.values()["shoulder"], 2)
        self.assertIsNone(self.values()["shoulderCurve"])
        self.at(30)
        self.assertEqual(self.shoulder(), 2)
        self.env.ns.SetByZoom("action", "shoulderCurve", True)
        self.assertIsNone(self.values()["shoulder"])
        self.assertEqual(self.values()["shoulderCurve"][2][2], 2)          # the points you had, not the preset's

    def test_one_view_can_be_set_without_moving_the_others(self):
        self.env.ns.SetAdvanced(True)
        self.env.ns.SetViewValue("action", "shoulderCurve", 4, 1.2)
        self.assertEqual(self.table("shoulderCurve"), [0, 1.5, 1.5, 1.2, 0, 0])
        self.at(8.5)
        self.assertEqual(self.shoulder(), 1.2)
        self.env.cmd("reset action")
        self.assertEqual(self.table("shoulderCurve"), [0, 1.5, 1.5, 1, 0, 0])

    def test_six_different_values_still_make_a_curve_that_can_be_shared(self):
        r = self.env.run("""
            local c = NS.CurveFromViews({ 0.1, 0.2, 0.3, 0.4, 0.5, 0.6 })
            local clean = NS.ValidateValue(NS.SETTING_BY_KEY.shoulderCurve, c)
            local v = NS.ViewValues(clean)
            local values = {}
            for k, x in pairs(NS.BUILTIN.action.values) do values[k] = x end
            values.shoulderCurve, values.focusCurve, values.fovCurve = clean, clean, NS.CurveFromViews({1,0.9,0.95,1,1.05,1.1})
            local text = NS.ExportProfile({ name = "Everything by zoom", values = values })
            local p = NS.ParseProfile(text)
            return { n = #clean, v = table.concat(v, " "), same = p and NS.ExportProfile(p) == text, len = #text,
                     flat = #NS.CurveFromViews({ 1, 1, 1, 1, 1, 1 }) }""")
        self.assertEqual(r["n"], 10)                                       # the flat ends need one point each
        self.assertEqual(r["v"], "0.1 0.2 0.3 0.4 0.5 0.6")
        self.assertTrue(r["same"])
        self.assertLess(r["len"], 1500)
        self.assertEqual(r["flat"], 1)

    def test_every_view_has_a_place(self):
        got = [self.env.run("return NS.ViewAt(%s)" % z) for z in (0, 1.4, 1.6, 3.9, 4.1, 6.4, 6.6, 11.4, 11.6, 22.1, 39)]
        self.assertEqual(got, [1, 1, 2, 2, 3, 3, 4, 4, 5, 6, 6])

    def test_offset_strength_scales_every_profile_and_is_kept(self):
        self.assertIn("80%", " ".join(self.env.cmd("offset 80")))
        self.at(3)
        self.assertAlmostEqual(self.shoulder(), 1.2)
        self.assertEqual(self.focus(), (1, 0.75))                          # only the offset
        self.env.ns.UseEverywhere("shooter")
        self.at(5)
        self.assertAlmostEqual(self.shoulder(), 1.6)                       # shooter's 2, at 80%
        env2 = reload_env(self.env)
        self.assertEqual(env2.db().offsetScale, 0.8)
        text = env2.ns.ExportSetup()
        self.assertIn("&k=0.8", text)
        other = Env()
        self.assertTrue(other.lua.globals().ControllerCam.ImportSetup(text))
        self.assertEqual(other.db().offsetScale, 0.8)
        self.assertIn("usage", " ".join(self.env.cmd("offset 500")))
        self.assertEqual(self.env.db().offsetScale, 0.8)
        self.env.cmd("offset 100")
        self.assertNotIn("&k=", self.env.ns.ExportSetup())                 # a setup without it reads as before

    def test_recommended_comes_first(self):
        out = self.env.cmd("list")
        self.assertIn("Recommended setup", out[0])
        self.assertIn("Action", out[1])
        self.assertIn("Classic", out[-1])
        self.env.cmd("use classic")
        self.assertIn("Recommended setup applied", " ".join(self.env.cmd("use recommended")))
        self.assertEqual(self.env.db().assign.default, "action")
        self.assertEqual(self.env.db().assign.mounted, "cruise")


class FieldOfView(unittest.TestCase):
    """No field of view CVar is confirmed in the client: it is only used if the game turns out to have one."""

    PROFILE = """{ v = 3, assign = { default = 'u_fov' }, profiles = { u_fov = { name = 'Wide', values = {
        fovCurve = { {2,0.9}, {10,1}, {24,1.1} } } } } }"""

    def env(self, own="80", takes=True, setup="", db=None):
        e = Env(db=db or self.PROFILE, login=False)
        e.mock.cvars.cameraFov = own
        e.mock.defaults.cameraFov = "90"
        if takes:
            e.mock.knownCVars.cameraFov = True
        if setup:
            e.run(setup)
        e.mock.fire("ADDON_LOADED", "ControllerCam")
        e.ns.GetDB().movement = True
        e.state(zoom=2)
        e.mock.fire("PLAYER_LOGIN")
        e.mock.fire("PLAYER_ENTERING_WORLD")
        e.advance(1.2)
        return e

    def at(self, e, zoom):
        e.state(zoom=zoom)
        e.ns.frame.scripts.OnUpdate(e.ns.frame, 0.2)

    def test_a_game_without_one_is_left_alone(self):
        e = Env(db=self.PROFILE)
        self.assertIsNone(e.ns.FovCVar())
        self.assertIsNone(e.cv("cameraFov"))
        self.assertNotIn("cameraFov", e.setlog_names())

    def test_it_follows_the_zoom_as_a_share_of_your_own(self):
        e = self.env()
        self.assertEqual(e.ns.FovCVar(), "cameraFov")
        self.assertEqual(float(e.cv("cameraFov")), 72)                  # 90% of your 80, not of the default
        self.at(e, 10)
        self.assertEqual(float(e.cv("cameraFov")), 80)
        self.at(e, 30)
        self.assertEqual(float(e.cv("cameraFov")), 88)

    def test_yours_comes_back_with_another_profile_or_the_addon_off(self):
        e = self.env()
        e.ns.UseEverywhere("classic")
        self.assertEqual(float(e.cv("cameraFov")), 80)
        self.assertIsNone(e.db().originals.cameraFov)
        e.mock.cvars.cameraFov = "70"                                   # changed by you meanwhile
        e.ns.Evaluate(True)
        self.assertEqual(e.cv("cameraFov"), "70")                       # and left alone
        e2 = self.env()
        e2.ns.SetEnabled(False)
        self.assertEqual(float(e2.cv("cameraFov")), 80)

    def test_changing_it_in_the_games_settings_makes_that_your_own(self):
        e = self.env()
        e.mock.cvars.cameraFov = "100"
        self.at(e, 2)
        self.assertEqual(float(e.cv("cameraFov")), 90)
        e.ns.SetEnabled(False)
        self.assertEqual(float(e.cv("cameraFov")), 100)

    def test_it_survives_a_reload_without_compounding(self):
        e = self.env()
        e2 = self.env(own=e.cv("cameraFov"), db=e.saved())
        self.assertEqual(float(e2.cv("cameraFov")), 72)
        self.assertEqual(float(e2.db().originals.cameraFov), 80)

    def test_a_game_that_takes_no_change_is_not_asked_again(self):
        e = self.env(takes=False)
        self.assertIsNone(e.ns.FovCVar())
        self.assertEqual(e.cv("cameraFov"), "80")
        self.assertIsNone(e.db().originals.cameraFov)

    def test_a_read_only_one_is_never_written(self):
        e = self.env(setup="C_CVar.GetCVarInfo = function() return '80', '90', false, false, false, false, true end")
        self.assertIsNone(e.ns.FovCVar())
        self.assertNotIn("cameraFov", e.setlog_names())

    def test_no_built_in_profile_sets_it(self):
        e = Env(login=False)
        for i in range(1, len(e.ns.BUILTIN_LIST) + 1):
            self.assertIsNone(e.ns.BUILTIN_LIST[i]["values"]["fovCurve"], e.ns.BUILTIN_LIST[i].id)


class OptionsPanel(unittest.TestCase):
    def areas(self, env):
        return env.ns.editorAreas

    def test_settings_are_grouped_in_areas_with_every_setting_explained(self):
        env = Env()
        env.ns.SetAdvanced(True)
        env.ns.RefreshOptions()
        areas = self.areas(env)
        groups = {env.ns.GROUPS[i].id for i in range(1, len(env.ns.GROUPS) + 1)}
        for i in range(1, len(env.ns.SETTINGS) + 1):
            s = env.ns.SETTINGS[i]
            self.assertIn(s.group, groups, s.key)
            self.assertTrue(s.help, s.key)
        self.assertEqual(len(list(areas.keys())), len(groups))
        for gid in groups:
            areas[gid].button.scripts.OnClick(areas[gid].button, "LeftButton")
            shown = [g for g in groups if areas[g].frame.shown]
            self.assertEqual(shown, [gid])

    def test_a_locked_preset_shows_no_wall_of_settings(self):
        env = Env()
        scroll = env.lua.globals().ControllerCamEditorScroll
        env.ns.SelectProfile("action"); env.ns.RefreshOptions()
        self.assertFalse(scroll.shown)
        env.ns.SetAdvanced(True); env.ns.RefreshOptions()
        self.assertTrue(scroll.shown)
        env.ns.SetAdvanced(False)
        env.ns.SelectProfile(env.ns.DuplicateProfile("action", "Mine")); env.ns.RefreshOptions()
        self.assertTrue(scroll.shown)                                  # your own profiles are always editable

    def test_the_field_of_view_table_says_when_the_game_has_none(self):
        env = Env()
        env.ns.SetAdvanced(True); env.ns.RefreshOptions()
        probe = self.areas(env)["Zoom"].probe
        self.assertFalse(probe.box.shown)
        self.assertTrue(probe.missing.shown)
        env.mock.cvars.cameraFov = "90"; env.mock.defaults.cameraFov = "90"
        env.ns.RefreshOptions()
        self.assertTrue(probe.box.shown)

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
        self.said("curve action 0:0 5:1.25 20:0")
        v = self.env.ns.GetProfile("action")["values"]
        self.assertEqual(v["shoulderCurve"][2][2], 1.25)
        self.assertEqual(self.env.ns.BUILTIN.action["values"]["shoulderCurve"][2][2], 1.5)

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
