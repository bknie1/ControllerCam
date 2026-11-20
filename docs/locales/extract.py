import re, sys, os
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
STR = r'"((?:[^"\\]|\\.)*)"'
keys = []
def add(k):
    if k not in keys:
        keys.append(k)
for f in ["Schema.lua", "Presets.lua", "Core.lua", "Share.lua", "Slash.lua", "Options.lua"]:
    t = open(f, encoding="utf-8").read()
    if f == "Schema.lua":
        for m in re.finditer(r'label = ' + STR, t): add(m.group(1))
        for m in re.finditer(r'group = ' + STR, t): add(m.group(1))
        for m in re.finditer(r'values = \{([^}]*)\}', t):
            for q in re.finditer(STR, m.group(1)): add(q.group(1))
    if f == "Presets.lua":
        for m in re.finditer(r'\n\s+(?:name|desc) = ' + STR, t): add(m.group(1))
    if f == "Slash.lua":
        for m in re.finditer(r'\{ "(/ccam[^"]*)",\s+' + STR + r' \}', t): add(m.group(2))
    for m in re.finditer(r'\bL\[' + STR + r'\]', t): add(m.group(1))
for i, k in enumerate(keys, 1):
    print(i, k)
print(len(keys), file=sys.stderr)
