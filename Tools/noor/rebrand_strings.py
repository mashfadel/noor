"""Noor rebrand of user-facing text. Re-run after pulling upstream: python3 -I Tools/noor/rebrand_strings.py

Only touches Swift string literals and String Catalogs (display text). Comments, identifiers
(NOOPWidget, noopDeviceId, restColor ...) and storage keys are left alone.
  NOOP   -> Noor
  Charge -> Recovery   (not "Charge it ..." = battery)
  Effort -> Strain
  Rest   -> Sleep      (not interval-timer rest, "Rest HR", "Rest up", "Rest period", "Rest (seconds)")
"""
import pathlib, re, sys

ROOTS = ["Strand", "StrandiOS", "StrandiOSShared", "StrandiOSWidgets", "NOOPWatch", "NOOPWatchComplications", "Packages"]
SKIP_FILES = {"IntervalTimerView.swift"}  # work/rest intervals, not the sleep score
LIT = re.compile(r'"(?:[^"\\\n]|\\.)*"')
RULES = [
    (re.compile(r"\bNOOP\b"), "Noor"),
    (re.compile(r"\bCharge\b(?! it\b)"), "Recovery"),
    (re.compile(r"\bEffort\b"), "Strain"),
    (re.compile(r"\bRest\b(?! (?:HR|up|period|\(seconds\))\b| \(seconds\))"), "Sleep"),
    # Collapse doubles created by Rest -> Sleep next to an existing "Sleep".
    (re.compile(r"\bSleep(,| &| /| \+| and| or) Sleep\b"), "Sleep"),
    (re.compile(r"\bSleep ↔ Sleep\b"), "Sleep"),
]

def fix(text):
    for rx, rep in RULES:
        text = rx.sub(rep, text)
    return text

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
changed = 0
for r in ROOTS:
    for p in (root / r).rglob("*.swift"):
        if "/Tests/" in str(p) or p.name in SKIP_FILES:
            continue
        old = p.read_text()
        out = []
        for ln in old.split("\n"):
            out.append(ln if ln.lstrip().startswith("//") else LIT.sub(lambda m: fix(m.group(0)), ln))
        new = "\n".join(out)
        if new != old:
            p.write_text(new); changed += 1
    for p in (root / r).rglob("*.xcstrings"):
        # Hand-formatted JSON: substitute textually (catalog entries are all display text).
        old = p.read_text(); new = fix(old)
        if new != old:
            p.write_text(new); changed += 1
print(f"files changed: {changed}")
