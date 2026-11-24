"""Lists every English text of the HUD that players see, in a stable order (one per line, numbered).

    python docs/locales/extract_hud.py
"""
import os
import re
import sys

REPO = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
ROOT = os.path.join(REPO, "ControllerCam_HUD")
STR = r'"((?:[^"\\]|\\.)*)"'

# The HUD's modules (load-on-demand addons beside it, Modules.lua): their texts are the HUD's, in one Locales.lua
MODULES = sorted(d for d in os.listdir(REPO)
                 if d.startswith("ControllerCam_HUD_") and os.path.isfile(os.path.join(REPO, d, d + ".toc")))


def toc_files():
    """Every file of the HUD with texts, the core's first and then each module's (paths from the HUD's folder)."""
    out = []
    for folder in ["ControllerCam_HUD"] + MODULES:
        for line in open(os.path.join(REPO, folder, folder + ".toc"), encoding="utf-8").read().splitlines():
            line = line.strip()
            if line.endswith(".lua") and line != "Locales.lua":
                out.append(line if folder == "ControllerCam_HUD" else os.path.join("..", folder, line))
    return out


def keys():
    found = []

    def add(k):
        if k and k not in found:
            found.append(k)

    for name in toc_files():
        t = open(os.path.join(ROOT, name), encoding="utf-8").read()
        name = os.path.basename(name)
        for m in re.finditer(r"\bL\[" + STR + r"\]", t):
            add(m.group(1))
        for m in re.finditer(r"\b(?:label|tip) = " + STR, t):                       # registered settings
            add(m.group(1))
        for m in re.finditer(r"\b(?:Unit|Sell|Native)\(" + STR + r",\s*" + STR + r",\s*" + STR + r"\)", t):
            add(m.group(2))
            add(m.group(3))
        for m in re.finditer(r"\b(?:Setting|Area)\(" + STR + r",\s*" + STR + r",\s*" + STR, t):   # Setting(key, label, tip, ...)
            add(m.group(2))
            add(m.group(3))
        for m in re.finditer(r'\{ "(/cchud[^"]*)",\s+' + STR + r" \}", t):          # help rows
            add(m.group(2))
        for m in re.finditer(r'"/cchud [^"]*",\s*' + STR + r"\)", t):               # RegisterCommand(..., usage, text)
            add(m.group(1))
        if name == "Options.lua":
            add("General")
            m = re.search(r"local PAGES = \{(.*?)\}", t, re.S)
            for q in re.finditer(STR, m.group(1)):
                add(q.group(1))
            m = re.search(r"local LAYOUT = \{(.*?)\n\}", t, re.S)
            for q in re.finditer(r"\b(?:page|head) = " + STR, m.group(1)):          # pages and their headings
                add(q.group(1))
        if name == "UnitFrames.lua":
            m = re.search(r"local LABEL = \{(.*?)\}", t, re.S)
            for q in re.finditer(r"= " + STR, m.group(1)):
                add(q.group(1))
    return found


if __name__ == "__main__":
    ks = keys()
    for i, k in enumerate(ks, 1):
        print(i, k)
    print(len(ks), file=sys.stderr)
