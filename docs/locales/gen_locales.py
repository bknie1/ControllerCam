"""Builds Locales.lua from the English texts found in the code (extract.py) and translations.txt.

    python docs/locales/gen_locales.py
"""
import re, subprocess, sys, os
SP = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(SP, "..", "..")
out = subprocess.run([sys.executable, "-I", os.path.join(SP, "extract.py")], capture_output=True, text=True, encoding="utf-8").stdout
extracted = []
for line in out.splitlines():
    m = re.match(r"^(\d+) (.*)$", line)
    if m:
        extracted.append(m.group(2).replace('\\"', '"'))
rows = []
for line in open(os.path.join(SP, "translations.txt"), encoding="utf-8").read().splitlines():
    if not line.strip():
        continue
    parts = [p.strip() for p in line.split(" ;; ")]
    assert len(parts) == 10, (len(parts), line[:60])
    rows.append(parts)
LOCS = ["deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW"]
ph = re.compile(r"%[-.\d]*[sd]|%\.\df")
problems = 0
for r in rows:
    if r[0] not in extracted:
        print("NOT USED IN CODE:", r[0]); problems += 1
    base = ph.findall(r[0])
    for loc, t in zip(LOCS, r[1:]):
        if ph.findall(t) != base:
            print("PLACEHOLDER MISMATCH", loc, r[0]); problems += 1
translated = [r[0] for r in rows]
rest = [k for k in extracted if k not in translated]
english = translated + rest
def lua(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
lines = []
lines.append('''-- ControllerCam localization.
--
-- The English text is the lookup key (L["Some text"]). Translations are listed in the SAME ORDER as the
-- ENGLISH list below, one table per game locale. Anything missing falls back to English, so a new text can be
-- added at the end of ENGLISH before it is translated. Keep %s / %d / %.1f placeholders in the same order when
-- adding or fixing a language.

local ADDON, ns = ...

local ENGLISH = {''')
for i, k in enumerate(english, 1):
    lines.append(f"    {lua(k)},  -- {i}")
lines.append("}\n")
lines.append("local TRANSLATIONS = {")
for j, loc in enumerate(LOCS):
    lines.append(f"    {loc} = {{")
    for i, r in enumerate(rows, 1):
        lines.append(f"        {lua(r[j + 1])},  -- {i}")
    lines.append("    },")
lines.append("}")
lines.append('TRANSLATIONS.esMX = TRANSLATIONS.esES      -- Latin American Spanish uses the same text')
lines.append('''
-- Lookup table: L["English text"] -> translated text, or the English text itself when there is none.
local L = setmetatable({}, { __index = function(_, key) return key end })

local translated = TRANSLATIONS[GetLocale()]
if translated then
    for i, english in ipairs(ENGLISH) do
        if translated[i] then L[english] = translated[i] end
    end
end

ns.L = L
ns.localeData = { english = ENGLISH, translations = TRANSLATIONS }   -- used by the automated tests''')
open(os.path.join(ROOT, "Locales.lua"), "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
print("rows", len(rows), "english", len(english), "problems", problems)
