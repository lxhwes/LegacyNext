#!/usr/bin/env python3
"""Check that every `path:line` citation in a markdown file still points where it claims.

Line-number citations into the vendored source are pin-relative: a one-line insertion
upstream silently shifts everything below it, and a stale citation is worse than none
because it reads as verified. This re-resolves each one against the checkout on disk.

Run it after any pin bump, against docs/legacy-internals.md and anything else carrying
citations. Exit status is 1 if a citation broke, so it can gate a bump.

Usage:
    scripts/verify_citations.py docs/legacy-internals.md [more.md ...]
    scripts/verify_citations.py --expect-symbol docs/legacy-internals.md

--expect-symbol also checks that a cited `Name = "Foo"` doc line still names Foo, which
catches the shift-by-one case that a non-empty-line check alone would pass.
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[4]
BASE = ROOT / "vendor/wow-ui-source/Interface/AddOns"

CITE = re.compile(r"`?([A-Za-z_][A-Za-z0-9_/]*\.lua):(\d+)")


def resolve(relpath):
    """Find a cited file. Honour the directory when given one.

    Matching on basename alone is a trap: Blizzard_AchievementUI.lua exists under both
    Mainline/ and Cata/, the copies are different lengths, and picking the wrong one
    reports valid citations as broken. This is the same flavour hazard SKILL.md covers.
    """
    exact = BASE / relpath
    if exact.exists():
        return exact
    if "/" in relpath:
        matches = [p for p in BASE.rglob("*") if str(p).endswith("/" + relpath)]
        if matches:
            return matches[0]
        return None
    # A bare filename is only safe if it is unambiguous in the tree.
    matches = list(BASE.rglob(relpath))
    return matches[0] if len(matches) == 1 else None


def check(path, expect_symbol):
    text = path.read_text(errors="replace")
    seen, ok, broken, outside, ambiguous = set(), 0, [], set(), set()

    for relpath, lineno in CITE.findall(text):
        if (relpath, lineno) in seen:
            continue
        seen.add((relpath, lineno))

        target = resolve(relpath)
        if target is None:
            if "/" in relpath and not (BASE / relpath.split("/")[0]).exists():
                outside.add(relpath)      # file lives outside the sparse checkout
            else:
                ambiguous.add(relpath)
            continue

        lines = target.read_text(errors="replace").splitlines()
        n = int(lineno)
        if not (1 <= n <= len(lines)) or not lines[n - 1].strip():
            broken.append(f"{relpath}:{lineno}  (file has {len(lines)} lines)")
            continue

        if expect_symbol:
            # If the citation sits near prose naming a symbol, the cited line should
            # mention it. Cheap heuristic, only applied to doc-table Name = "..." lines.
            m = re.match(r'\s*Name = "([A-Za-z0-9_]+)"', lines[n - 1])
            if m and m.group(1) not in text:
                broken.append(f"{relpath}:{lineno}  names {m.group(1)}, unmentioned in {path.name}")
                continue
        ok += 1

    return seen, ok, broken, outside, ambiguous


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    expect_symbol = "--expect-symbol" in sys.argv
    if not args:
        print(__doc__, file=sys.stderr)
        return 64
    if not BASE.exists():
        print(f"FATAL: vendored source missing at {BASE}", file=sys.stderr)
        print("Recreate it with the recipe in vendor/PINS.md.", file=sys.stderr)
        return 69

    pin = (ROOT / "vendor/wow-ui-source/version.txt").read_text().strip()
    print(f"checkout: {BASE.parent.parent.name} @ {pin}\n")

    failed = False
    for arg in args:
        path = pathlib.Path(arg)
        if not path.exists():
            print(f"{arg}: not found")
            failed = True
            continue
        seen, ok, broken, outside, ambiguous = check(path, expect_symbol)
        print(f"{arg}: {len(seen)} citations, {ok} resolve, {len(broken)} broken")
        for b in broken:
            print(f"   BROKEN  {b}")
        if outside:
            print(f"   outside the sparse checkout, not checkable here ({len(outside)}):")
            for o in sorted(outside):
                print(f"           {o}")
        if ambiguous:
            print(f"   ambiguous filename, could not resolve ({len(ambiguous)}):")
            for a in sorted(ambiguous):
                print(f"           {a}")
        if broken:
            failed = True
        print()

    if failed:
        print("Citations broke. They are pin-relative, so this is expected after a bump —")
        print("re-derive each one with api_lookup.sh rather than nudging the line number.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
