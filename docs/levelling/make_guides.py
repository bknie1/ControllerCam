"""Writes ControllerCam_HUD_Mentor/LevelGuides.lua from the guide data in docs/levelling/<profession>.json, and
ControllerCam_HUD/RecipeData.lua from docs/levelling/recipes.json.

Each JSON file holds, for one profession, the steps the well-known levelling guides take (Wowhead's main path,
with its alternatives and Icy Veins' differences as alternatives): facts only, recipe and item IDs, skill
ranges, craft counts and reagents. The Lua file is what The Mentor (Levelling.lua) follows.

recipes.json is every Cooking and First Aid recipe: what it makes, the skill it needs, the ranks it turns
yellow, green and grey at, its reagents and where it is learned; with the vendors (zone, town, side), the skill
books, which materials a vendor sells and which a gathering profession brings. It is in the core, as item advice
needs it whether The Mentor is loaded or not.

    python docs/levelling/make_guides.py            write the Lua files
    python docs/levelling/make_guides.py --check    only report problems (and a Lua file that is out of date)
"""
import glob
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "ControllerCam_HUD_Mentor", "LevelGuides.lua")
RECIPES = os.path.join(HERE, "recipes.json")
RECIPES_OUT = os.path.join(HERE, "..", "..", "ControllerCam_HUD", "RecipeData.lua")
SIDES = {"A", "H", "B"}
KINDS = ["alchemy", "blacksmithing", "enchanting", "engineering", "leatherworking", "tailoring", "cooking",
         "firstaid", "mining"]
WHY = {"cheap", "vendor", "gathered", "sells", "useful", "fewer", "recipe", "other"}
LEARN = {"trainer", "vendor", "drop", "quest"}
CAP = 300


def num(v):
    return v if isinstance(v, int) and not isinstance(v, bool) and v > 0 else None


def lua_str(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


def recipe(o, where, problems):
    """One recipe as Lua fields, or None when it has no ID to match the game's list by."""
    p, s = num(o.get("item")), num(o.get("spell"))
    if not (p or s):
        problems.append("%s: %r has no item or spell ID" % (where, o.get("name")))
        return None
    f = []
    if p:
        f.append("p = %d" % p)
    if s:
        f.append("s = %d" % s)
    if num(o.get("crafts")):
        f.append("n = %d" % o["crafts"])
    if num(o.get("made")) and o["made"] > 1:
        f.append("m = %d" % o["made"])
    if num(o.get("learnAt")):
        f.append("at = %d" % o["learnAt"])
    learn = o.get("learn") or "trainer"
    if learn not in LEARN:
        problems.append("%s: unknown learn %r" % (where, learn))
        learn = "trainer"
    if learn != "trainer":
        f.append("learn = %s" % lua_str(learn))
    r = []
    for pair in o.get("reagents") or []:
        if isinstance(pair, list) and len(pair) == 2 and num(pair[0]) and num(pair[1]):
            r += [pair[0], pair[1]]
        else:
            problems.append("%s: %r: a reagent without an ID or count: %r" % (where, o.get("name"), pair))
    if r:
        f.append("r = { %s }" % ", ".join(str(x) for x in r))
    if o.get("name"):
        f.append("name = %s" % lua_str(o["name"]))
    return f


def profession(kind, data, problems):
    lines = ["    %s = {" % kind]
    at = 1
    for i, st in enumerate(data.get("steps") or []):
        where = "%s step %d" % (kind, i + 1)
        lo, hi = st.get("from"), st.get("to")
        if not (isinstance(lo, int) and isinstance(hi, int) and lo < hi):
            problems.append("%s: bad range %r-%r" % (where, lo, hi))
            continue
        if lo == at + 1 and i > 0:
            lo = at                          # (a guide's "1-30, 31-45": the next stretch starts where one ends)
        if lo > at:
            problems.append("%s: a gap from %d to %d" % (where, at, lo))
        at = max(at, hi)
        if num(st.get("gather")):
            f = ["gather = %d" % st["gather"]]
            if st.get("name"):
                f.append("name = " + lua_str(st["name"]))
        else:
            f = recipe(st, where, problems)
            if f is None:
                continue
        alts = []
        for k, a in enumerate(st.get("alts") or []):
            if num(a.get("gather")):                     # another vein or herb to gather instead
                alts.append("{ gather = %d%s }" % (a["gather"], (", name = " + lua_str(a["name"])) if a.get("name") else ""))
                continue
            af = recipe(a, "%s alt %d" % (where, k + 1), problems)
            if af is None:
                continue
            span = a.get("range") or ([a["from"], a["to"]] if isinstance(a.get("from"), int) and isinstance(a.get("to"), int) else None)
            if span and isinstance(span, list) and len(span) == 2 and span[0] < span[1]:
                af.append("lo = %d, hi = %d" % (span[0], span[1]))   # (its own stretch, for its count)
            why = [w for w in (a.get("why") or []) if w in WHY]
            bad = [w for w in (a.get("why") or []) if w not in WHY]
            if bad:
                problems.append("%s alt %d: unknown why %r" % (where, k + 1, bad))
            af.append("why = { %s }" % ", ".join(lua_str(w) for w in (why or ["other"])))
            alts.append("{ " + ", ".join(af) + " }")
        if alts:
            f.append("alts = {\n            " + ",\n            ".join(alts) + " }")
        lines.append("        { %d, %d, %s }," % (lo, hi, ", ".join(f)))
    if at < CAP:
        problems.append("%s: the steps stop at %d, short of %d" % (kind, at, CAP))
    lines.append("    },")
    return lines


def lua_list(values):
    return "{ %s }" % ", ".join(values)


def recipe_data(data, problems):
    """RecipeData.lua's lines from recipes.json."""
    zones = {int(k): v for k, v in data["zones"].items()}
    names = sorted(data["vendors"])
    index = {n: i + 1 for i, n in enumerate(names)}

    def vendor_refs(where, wanted):
        out = []
        for n in wanted:
            if n not in index:
                problems.append("%s: unknown vendor %r" % (where, n))
            else:
                out.append(str(index[n]))
        return out

    lines = ["ns.RecipeData = {", "    -- [area ID] = the zone's name, for a client that cannot say it", "    zones = {"]
    lines += ["        [%d] = %s," % (z, lua_str(zones[z])) for z in sorted(zones)]
    lines += ["    },", "    -- { name, zone (area ID), town, side: A Alliance, H Horde, B both }", "    vendors = {"]
    for n in names:
        zone, town, side = data["vendors"][n]
        if zone not in zones:
            problems.append("vendor %s: unknown zone %r" % (n, zone))
        if side not in SIDES:
            problems.append("vendor %s: unknown side %r" % (n, side))
        lines.append("        { %s, %d, %s, %s }," % (lua_str(n), zone, lua_str(town), lua_str(side)))
    lines.append("    },")
    for kind in ("cooking", "firstaid"):
        lines.append("    %s = {" % kind)
        seen = set()
        for r in data[kind]:
            where = "%s %s" % (kind, r.get("name"))
            if r["item"] in seen:
                problems.append("%s: listed twice" % where)
            seen.add(r["item"])
            colors = r["colors"]
            if len(colors) != 4 or colors != sorted(colors):
                problems.append("%s: bad colours %r" % (where, colors))
            f = ["name = " + lua_str(r["name"]), "s = %d" % r["spell"], "p = %d" % r["item"],
                 "at = %d" % r["skill"], "c = " + lua_list(str(x) for x in colors)]
            reagents = []
            for pair in r["reagents"]:
                reagents += [str(pair[0]), str(pair[1])]
            f.append("r = " + lua_list(reagents))
            if r.get("made"):
                f.append("m = %d" % r["made"])
            if r.get("book"):
                f.append("book = %d" % r["book"])
            if r.get("trainer"):
                f.append("trainer = true")
            if r.get("vendors"):
                f.append("v = " + lua_list(vendor_refs(where, r["vendors"])))
            if r.get("quests"):
                quests = []
                for name, zone, side in r["quests"]:
                    if zone not in zones or side not in SIDES:
                        problems.append("%s: bad quest %r" % (where, name))
                    quests.append("{ %s, %d, %s }" % (lua_str(name), zone, lua_str(side)))
                f.append("q = " + lua_list(quests))
            if r.get("drop"):
                zone, who = r["drop"]
                if zone and zone not in zones:
                    problems.append("%s: unknown zone %r" % (where, zone))
                f.append("drop = { %d, %s }" % (zone, lua_str(who)))
            if r.get("season"):
                f.append("season = " + lua_str(r["season"]))
            if r.get("class"):
                f.append("class = " + lua_str(r["class"]))
            if r.get("raid"):
                f.append("raid = true")
            if not any(r.get(k) for k in ("trainer", "vendors", "quests", "drop", "season")):
                problems.append("%s: nowhere to learn it" % where)
            lines.append("        { %s }," % ", ".join(f))
        lines.append("    },")
    lines += ["    -- skill books: [item] = what it raises, to which cap, who sells it", "    books = {"]
    for b in data["books"]:
        lines.append("        [%d] = { kind = %s, cap = %d, name = %s, v = %s }," % (
            b["item"], lua_str(b["kind"]), b["cap"], lua_str(b["name"]),
            lua_list(vendor_refs(b["name"], b["vendors"]))))
    lines += ["    },", "    -- materials a vendor sells without running out", "    vendorItems = {"]
    for group, ids in data["vendorItems"].items():
        lines.append("        -- " + group)
        lines.append("        " + " ".join("[%d] = true," % i for i in ids))
    lines += ["    },", "    seasonItems = { %s }," % " ".join("[%d] = true," % i for i in data["seasonItems"]),
              "    -- what a gathering profession brings", "    gather = {"]
    for kind, ids in data["gather"].items():
        lines.append("        " + " ".join("[%d] = %s," % (i, lua_str(kind)) for i in ids))
    lines += ["    },", "}", ""]
    header = [
        "-- ControllerCam HUD: every Cooking and First Aid recipe, and where it is learned (Recipes.lua reads it).",
        "-- Made by docs/levelling/make_guides.py from docs/levelling/recipes.json; change that, not this file.",
        "-- For each recipe: what it makes (p) and its spell (s), the skill it needs (at), the ranks it is orange,",
        "-- yellow, green and grey from (c), its reagents (r: item, count, ...), how many a craft makes (m), the item",
        "-- that teaches it (book), and where it is learned: a trainer, vendors (v: indexes into vendors), quests",
        "-- (q: name, zone, side), a drop (zone, who), a season; class: only that class learns it.",
        "",
        "local ADDON, ns = ...",
        "",
    ]
    return header + lines


def write(path, lines):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print("wrote " + os.path.relpath(path))


def current(path):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read().replace("\r\n", "\n")
    except OSError:
        return None


def main():
    check = "--check" in sys.argv
    problems, body, sources = [], [], []
    for kind in KINDS:
        path = os.path.join(HERE, kind + ".json")
        if not os.path.isfile(path):
            problems.append("%s: no data (%s)" % (kind, os.path.basename(path)))
            continue
        data = json.load(open(path, encoding="utf-8"))
        sources += data.get("sources") or []
        body += profession(kind, data, problems)
    with open(RECIPES, encoding="utf-8") as f:
        recipes = recipe_data(json.load(f), problems)
    out = [
        "-- ControllerCam HUD: the steps the well-known profession levelling guides take, for The Mentor (Levelling.lua).",
        "-- Made by docs/levelling/make_guides.py from docs/levelling/<profession>.json; change those, not this file.",
        "-- For each profession, by skill: the recipe the guides use (p: what it makes, s: its spell), how many crafts",
        "-- (n), how many one makes (m), the skill it needs (at), where it is learned when not at a trainer, its",
        "-- reagents (r: item, count, ...), and the guides' alternatives, each with why you might pick it. Where the",
        "-- guides level by gathering: { from, to, gather = what to gather }.",
        "",
        "local ADDON = ...",
        "local ns = ControllerCamHUD.ns            -- the HUD's own namespace: this file is one of its modules (Modules.lua)",
        "",
        "ns.LevelGuides = {",
    ] + body + ["}", ""]
    files = ((OUT, out), (RECIPES_OUT, recipes))
    if check:
        for path, lines in files:
            if current(path) != "\n".join(lines):
                problems.append("%s is out of date: run make_guides.py" % os.path.basename(path))
    for p in problems:
        print("  " + p)
    print("%d professions, %d problems" % (len([k for k in KINDS if os.path.isfile(os.path.join(HERE, k + ".json"))]),
                                         len(problems)))
    if check:
        return 1 if problems else 0
    for path, lines in files:
        write(path, lines)
    return 0


if __name__ == "__main__":
    sys.exit(main())
