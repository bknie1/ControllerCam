"""Lists every English text of ControllerCam Gather that players see, in a stable order (one per line, numbered).

    python docs/locales/extract_gather.py
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "ControllerCam_Gather")
STR = r'"((?:[^"\\]|\\.)*)"'


def toc_files():
    out = []
    with open(os.path.join(ROOT, "ControllerCam_Gather.toc"), encoding="utf-8") as f:
        lines = f.read().splitlines()
    for line in lines:
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
        with open(os.path.join(ROOT, name), encoding="utf-8") as f:
            t = f.read()
        for m in re.finditer(r"\bL\[" + STR + r"\]", t):
            add(m.group(1))
        for m in re.finditer(r"\b(?:label|tip) = " + STR, t):                       # registered settings
            add(m.group(1))
        for m in re.finditer(r'\{ "(/ccgather[^"]*)",\s+' + STR + r" \}", t):       # help rows
            add(m.group(2))
        for m in re.finditer(r'"/ccgather [^"]*",\s*' + STR + r"\)", t):            # RegisterCommand(..., usage, text)
            add(m.group(1))
        if name == "Core.lua":                                                      # the kinds of node
            m = re.search(r"ns\.KIND_LABEL = \{(.*?)\}", t, re.S)
            for q in re.finditer(r"= " + STR, m.group(1)):
                add(q.group(1))
    return found


if __name__ == "__main__":
    ks = keys()
    for i, k in enumerate(ks, 1):
        print(i, k)
    print(len(ks), file=sys.stderr)
