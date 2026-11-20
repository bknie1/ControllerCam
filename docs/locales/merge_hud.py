"""Brings the translation files up to date after the HUD's texts changed.

Keeps every translation whose English text is still used, drops the ones that are not, and adds the
translations of new texts from hud/new_<locale>.txt (line by line, in the order of hud/new_enUS.txt), then
rewrites hud/enUS.txt in the code's order. Run gen_hud_locales.py afterwards.

    python docs/locales/merge_hud.py
"""
import os

import extract_hud

HUD = os.path.join(os.path.dirname(os.path.abspath(__file__)), "hud")
LOCALES = ["deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW"]


def lines(name):
    path = os.path.join(HUD, name + ".txt")
    if not os.path.isfile(path):
        return []
    text = open(path, encoding="utf-8").read()
    return text[:-1].split("\n") if text.endswith("\n") else text.split("\n")


def main():
    english = extract_hud.keys()
    old_english, new_english = lines("enUS"), lines("new_enUS")
    for loc in LOCALES:
        known = dict(zip(old_english, lines(loc)))
        known.update(zip(new_english, lines("new_" + loc)))
        missing = [k for k in english if k not in known]
        if missing:
            raise SystemExit("%s: no translation for %d texts, first: %s" % (loc, len(missing), missing[0]))
        out = [known[k] for k in english]
        open(os.path.join(HUD, loc + ".txt"), "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
    open(os.path.join(HUD, "enUS.txt"), "w", encoding="utf-8", newline="\n").write("\n".join(english) + "\n")
    for name in ["new_enUS"] + ["new_" + loc for loc in LOCALES]:
        path = os.path.join(HUD, name + ".txt")
        if os.path.isfile(path):
            os.remove(path)
    print("merged: %d texts in %d languages" % (len(english), len(LOCALES)))


if __name__ == "__main__":
    main()
