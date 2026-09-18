---
name: beta-build-bump
description: Re-pin the vendored Blizzard forever-branch source to a newer Forever beta build, diff the Legacy addons and generated API docs against the old pin, and report what it breaks in LegacyNext. Use this whenever Blizzard pushes a new beta build, whenever the forever branch has moved, or whenever the user mentions re-pinning, bumping the pin, updating vendor/, a new build number, checking for API changes, or asks some version of "did anything change?" about the client — even if they don't name this skill or say "vendor". Also use it before trusting any claim in CLAUDE.md's "Client facts" or Legacy constants table, since that table is only as current as the pin.
---

# beta-build-bump

Blizzard pushes Forever beta builds every few days through beta (2026-09-17) and up to
launch (2026-11-04). Each one can silently change a constant value, add a return to a
function, or delete a documentation file out from under us. `vendor/wow-ui-source` is our
only ground truth for the Forever API, so a stale pin means every `[verified]` claim in
CLAUDE.md is really "verified as of some build ago."

This skill moves the pin forward and tells you what it cost.

## The shape of the job

Most bumps are boring, and that is the point. Across the five builds on the mirror so far,
**not one** touched the four vendored directories — only `version.txt` moved. Recognising a
boring bump quickly and saying so plainly is a success, not a non-answer. Do not manufacture
findings to justify the run.

The bump is two phases. `check` never touches the working tree, so you can read the diff and
walk away with nothing to undo. `--apply` is the only thing that moves the checkout, and it
refuses to run without check artifacts for that SHA.

## Workflow

### 1. Check

```sh
bash .claude/skills/beta-build-bump/scripts/bump.sh
```

Read the summary it prints. It is also written to `summary.txt` in the artifacts directory.
The markers that matter:

| Marker | What it means | What you do |
|---|---|---|
| `NO_NEW_BUILD` (exit 3) | Already at the newest commit | Say so in one line. Stop. Do not edit anything. |
| `VENDORED_DIRS_UNCHANGED` | Build moved, our four dirs did not | The boring case. Go to step 3, skip the diff reading. |
| `WATCHLIST_HIT` | A symbol LegacyNext calls appears in the diff | Go to step 2. This is the whole reason the skill exists. |
| `CONSTANTS_CHANGED` | `LegacyConstantsDocumentation.lua` moved | Highest severity. Read `constants.diff` in full, always. |
| `TOC_INTERFACE_STALE` | Build implies a different `## Interface:` than the .toc has | Fix the .toc in step 3. |
| `BUILD_WENT_BACKWARDS` | New build number is lower than the pinned one | Stop and ask Alex. The mirror re-pushes out of order; this has really happened. |
| `PINS_DRIFT` | `PINS.md` and the actual checkout disagree | A previous bump half-applied. Reconcile before trusting anything downstream. |

### 2. Read the diff, if there is one worth reading

Start with `watchlist.txt` — that is the triaged view, and on a real build bump it is a
handful of lines. `full.diff` can be five figures of lines; open it only when a watchlist hit
needs surrounding context, and read the specific hunk rather than the file.

For each hit, decide which of these it is, because they have very different costs:

- **A constant's value changed.** Worst case. Our fallback literals in CLAUDE.md become
  silently wrong rather than erroring, so nothing crashes and the addon just shows the wrong
  thing. Always report the old and new value explicitly.
- **A function's signature changed** — an argument added, a return added or reordered.
  Breaks `Api/` at the point of use. Name the function and quote the before/after.
- **A documentation file was added or removed.** A removed file means a namespace went away.
  An added file may be a new API worth knowing about, but is not a break.
- **A Blizzard call site changed.** Weakest signal. It tells you how Blizzard uses an API,
  not that the API changed. Useful colour, not a finding.

Anything in the diff that does not touch a watched symbol is noise. Say how much of it there
was and move on; do not summarise Blizzard's UI refactors.

### 3. Apply and record

```sh
bash .claude/skills/beta-build-bump/scripts/bump.sh --apply <sha>
```

Then update, in this order:

**`vendor/PINS.md`** — always. Commit, `version.txt`, and "Pinned on" date. If a sparse-checkout
directory stopped existing at the new commit, say so under the recreate recipe; the current
file claims "All four directories were present at this commit" and that claim has to stay true.

**`LegacyNext/LegacyNext.toc`** — only on `TOC_INTERFACE_STALE`. Set `## Interface:` to the
number the script computed.

**`CLAUDE.md`** — only for facts the vendored source mechanically decides:

- the "Interface 16001, build 1.60.1" line under Client facts
- values in the Legacy constants table
- the pinned-SHA citation attached to `Constants.LegacyConsts`
- removing a function from the Legacy API surface list when its doc entry is gone

Everything else in CLAUDE.md stays put, and you propose rather than edit. In particular do
not touch anything marked `[unverified]` (the "Resourcefulness" public name is a guess that a
source diff cannot settle), the SavedVariables bug note, the Blizzard quote, or Scope and
Non-goals. If a build makes you think a non-goal should change, that is a conversation, not
an edit.

**`docs/beta-builds.md`** — always, even for a boring bump. Prepend a new section; newest
first, so the file reads top-down as "what has happened lately".

```markdown
## 1.60.2.70114 — 2026-10-02

Pin: `70ef1b2` → `a91c3d4`

**Touches us**
- `LEGACY_TREE_PROGRESSION_ID` 1189 → 1190 — CLAUDE.md table updated, Api/ has no
  reference yet so nothing to fix in code
- `C_Traits.GetTraitCurrencyForAchievement` gained a second return (`spent`)

**Does not touch us**
- 41 files changed across Blizzard_AchievementUI, all frame layout

**Needs in-game confirmation**
- Whether the new second return is populated outside a Legacy tree context —
  `/dump C_Traits.GetTraitCurrencyForAchievement(12345)`
```

Drop the "Touches us" or "Needs in-game confirmation" heading when it would be empty rather
than writing "none"; a boring bump should look boring at a glance.

### 4. Commit

Invoke the `safe-commit` skill. Suggested subject:

```
chore(vendor): re-pin forever branch to <build>
```

The vendored checkout itself is gitignored, so the commit is `vendor/PINS.md`,
`docs/beta-builds.md`, and whichever of `CLAUDE.md` / `LegacyNext.toc` you changed. Nothing
from the artifacts directory ever gets committed — it lives in `$TMPDIR` for exactly that
reason.

## Rules that survive contact with a weird build

**Cite, don't recall.** Every claim in the report names the file and line it came from, in
the artifacts directory or the vendored tree. If you catch yourself writing what an API
"normally" does on retail, delete it — CLAUDE.md is explicit that Forever's docs already
differ from live retail by ~6k lines, so retail intuition is actively misleading here.

**A signature change is not a fixture.** The docs give you argument names and types. They do
not give you real values, and inventing a response shape to write a test against is the one
thing CLAUDE.md forbids outright. If a change means a test needs new shape data, say the test
stays `pending` and write Alex the exact `/run` or `/dump` line, then stop.

**Never widen the sparse checkout on your own.** If the diff makes you want a fifth directory,
propose it — that changes `PINS.md`, the recreate recipe, and every future run of this skill.

**Read-only, still.** Nothing here calls a game API, but the same instinct applies: the
vendored tree is reference material. `--apply` is the only write to it, and `reset --hard` is
safe there precisely because nobody edits it by hand.

**When the script and the source disagree, the source wins.** The script's triage is grep. It
finds symbol mentions, not semantics, and it can miss a rename that changes behaviour without
mentioning the old name. A clean watchlist is weak evidence on a large diff, not proof.

## Keeping the watchlist honest

`references/watchlist.txt` is the triage filter. The script unions it with every
`C_Namespace.Function` reference it finds under `LegacyNext/`, so namespaced calls added to
`Api/` get watched automatically. Bare FrameXML globals (`GetAchievementInfo`) and constant
names cannot be auto-discovered and have to be added by hand.

If you add a symbol to `Api/` during other work and notice it is neither namespaced nor
listed, add the line. A symbol missing from the watchlist is not hidden — it still appears in
`full.diff` — but it stops being surfaced, which is how a break gets through.
