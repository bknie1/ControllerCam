"""Writes ControllerCam_HUD/LevelGuides.lua from the guide data in docs/levelling/<profession>.json.

Each JSON file holds, for one profession, the steps the well-known levelling guides take (Wowhead's main path,
with its alternatives and Icy Veins' differences as alternatives): facts only, recipe and item IDs, skill
ranges, craft counts and reagents. The Lua file is what The Mentor (Levelling.lua) follows.

    python docs/levelling/make_guides.py            write the Lua file
    python docs/levelling/make_guides.py --check    only report problems
"""
import glob
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "ControllerCam_HUD", "LevelGuides.lua")
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
    for p in problems:
        print("  " + p)
    print("%d professions, %d problems" % (len([k for k in KINDS if os.path.isfile(os.path.join(HERE, k + ".json"))]),
                                         len(problems)))
    if check:
        return 1 if problems else 0
    out = [
        "-- ControllerCam HUD: the steps the well-known profession levelling guides take, for The Mentor (Levelling.lua).",
        "-- Made by docs/levelling/make_guides.py from docs/levelling/<profession>.json; change those, not this file.",
        "-- For each profession, by skill: the recipe the guides use (p: what it makes, s: its spell), how many crafts",
        "-- (n), how many one makes (m), the skill it needs (at), where it is learned when not at a trainer, its",
        "-- reagents (r: item, count, ...), and the guides' alternatives, each with why you might pick it. Where the",
        "-- guides level by gathering: { from, to, gather = what to gather }.",
        "",
        "local ADDON, ns = ...",
        "",
        "ns.LevelGuides = {",
    ] + body + ["}", ""]
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out))
    print("wrote " + os.path.relpath(OUT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
