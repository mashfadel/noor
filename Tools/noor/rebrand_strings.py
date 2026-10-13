"""Rename user-facing 'NOOP' -> 'Noor' inside Swift string literals and String Catalogs.
Comments, identifiers (NOOPWidget, noopDeviceId, ...) and storage keys are left alone.
Re-run after pulling upstream changes: python3 -I Tools/noor/rebrand_strings.py"""
import json, pathlib, re, sys
ROOTS = ["Strand", "StrandiOS", "StrandiOSShared", "StrandiOSWidgets", "NOOPWatch", "NOOPWatchComplications", "Packages"]
WORD = re.compile(r"\bNOOP\b")
LIT = re.compile(r'"(?:[^"\\\n]|\\.)*"')
root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
changed = 0
for r in ROOTS:
    for p in (root / r).rglob("*.swift"):
        if "/Tests/" in str(p): continue
        lines = p.read_text().split("\n"); out = []
        for ln in lines:
            if ln.lstrip().startswith("//"):
                out.append(ln); continue
            new = LIT.sub(lambda m: WORD.sub("Noor", m.group(0)), ln)
            out.append(new)
        s = "\n".join(out)
        if s != p.read_text(): p.write_text(s); changed += 1
    for p in (root / r).rglob("*.xcstrings"):
        # Hand-formatted JSON: substitute textually (every NOOP in a catalog is display text).
        old = p.read_text(); new = WORD.sub("Noor", old)
        if new != old: p.write_text(new); changed += 1
print(f"files changed: {changed}")
