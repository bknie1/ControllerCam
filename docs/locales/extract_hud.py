"""Lists every English text of the HUD that players see, in a stable order (one per line, numbered).

    python docs/locales/extract_hud.py
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "ControllerCam_HUD")
STR = r'"((?:[^"\\]|\\.)*)"'


def toc_files():
    out = []
    for line in open(os.path.join(ROOT, "ControllerCam_HUD.toc"), encoding="utf-8").read().splitlines():
        line = line.strip()
        if line.endswith(".lua") and line != "Locales.lua":
            out.append(line)
    return out


def keys():
    found = []

    def add(k):
        if k and k not in found:
            found.append(k)

    for name in toc_files():
        t = open(os.path.join(ROOT, name), encoding="utf-8").read()
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
