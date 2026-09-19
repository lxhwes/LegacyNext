---
name: fixture-intake
description: Turn output pasted back from the live Forever client into committed fixtures, stubs and un-pended tests, and write the finding into the docs. Use this the moment Alex pastes anything from the game — a dump, semicolon rows, an /etrace list, a single /dump value, even one line in chat — and whenever you are about to create or edit a file in spec/fixtures/ or spec/stubs/, flip a pending test to a real one, or define what Debug/ should emit. Also use it when a claim needs re-tagging from [unverified] to [verified in game], since the paste is the evidence that licenses the tag. Captured data is the only fixture source this project permits: a fabricated fixture is worse than a missing one, because achievement, category and criteria IDs churn through beta and a fixture with no provenance cannot later be told apart from an invention.
---

# Fixture intake

A paste from the client is the most expensive data on this project — it cost Alex a context
switch and us a wait. It is also the only kind of data that licenses anything: fixtures come
from captures, never from a shape we reasoned our way to. CLAUDE.md is blunt about it, and
`spec/fixtures/README.md` repeats it, because the temptation is real and the failure is quiet.
An invented fixture makes a green test suite that proves nothing, in a client nobody can run.

So the job here is to get the evidence into the repo without editing it, and to spend it fully
— a paste that unblocks three pending tests and only gets used for one wasted two thirds of a
round trip.

## Order of work

1. **Preserve before you interpret.** Save the paste verbatim first. Every later step can be
   redone from the raw text; nothing can be recovered from a paste you paraphrased.
2. **Generate the fixture** with the script below, which keeps the raw block inside the file.
3. **Wire the stub** in `spec/stubs/` so `Api/` specs read the fixture.
4. **Spend it** — every pending test the capture actually covers, not just the one you came for.
5. **Write the finding down** in `docs/legacy-internals.md`, and in `CLAUDE.md` if it changes a
   client fact. Mark the queue entry in `docs/ingame-commands.md` done with the date, and
   update `docs/status.md`. A finding left in chat is a finding we pay for twice.

## Generating the fixture

```sh
.claude/skills/fixture-intake/scripts/dump_to_fixture.py paste.txt \
  --out spec/fixtures/criteria_shapes.lua \
  --source "script 1, docs/ingame-commands.md" \
  --date 2026-09-18 --build 1.60.1.69913 --pin 70ef1b2 \
  --character "fresh level 1, no points spent" \
  --string-col quantityString --string-col name
```

It parses the `== SECTION ==` / header-row / semicolon-row shape the in-game scripts emit,
types each field, and writes a Lua table with the paste kept verbatim at the bottom. Run
`--stdout` first if you want to look before writing.

**It refuses to run without provenance**, and that refusal is the point. `--source`, `--date`,
`--build` and `--character` are required because a fixture missing any of them cannot be
interpreted later: a criteria row captured on a fresh level 1 says something different from the
same row on a played character, and neither can be distinguished from a guess once the origin
is lost. Fill `--pin` too where you know it — the vendored pin decides which doc the shape was
checked against.

Three things about the output to understand before trusting it:

- **`nil` becomes an absent key.** The client prints missing values as the literal `nil`, and
  the fixture omits the field, which is what the API would have handed us. So test for
  `row.charName == nil`, and do not read an absent key as "the capture was incomplete".
- **The paste cannot tell `0` from `"0"`.** Semicolon rows are text, so a numeric-looking
  string arrives indistinguishable from a number. Pass `--string-col` for fields the API
  documents as strings — `quantityString`, `charName`, `name` — or a spec will assert a number
  where the client returns `"0 / 150"`. The script records which columns you coerced.
- **`|` came back as `!`.** The capture scripts escape it to survive display, and that is
  lossy on purpose. Do not reverse it: a `!` in fixture text may have been a colour code or a
  real exclamation mark, and guessing which is editing evidence.

Then **check the generated file against the raw block at the bottom of it** and confirm it
loads (`./tools/lua51/bin/busted`, or `luac -p` on the fixture). The raw block exists so that
a transcription mistake stays findable; it only does that job if somebody looks.

`references/dump-format.md` is the contract: what the in-game scripts emit, what the parser
accepts, and therefore what `Debug/` must produce when it replaces the ad-hoc dumpers. Read it
before changing either side, because drift between them silently makes captured data unusable.

## Data already in the docs

`docs/legacy-internals.md` holds captured rows in prose — the two criteria samples around
"Two captured samples, which are the first real fixtures" are real client output pasted into a
document. They are legitimate evidence, and they should become fixture files.

But re-stamp them rather than copying them blind: the doc is a write-up, not the paste, so
confirm what it says about character state and build, and mark the fixture's `--source` as the
doc rather than the script. A fixture whose provenance says "script 1" when it actually came
out of a markdown table is a small lie that gets load-bearing later.

## Stubs, and the arity rule

`spec/stubs/` is the fake WoW environment `Api/` specs run against. Stubs return fixture data
and nothing else — no computed values, no filled gaps.

Where a fixture covers only part of a function's returns, the stub returns that part and the
spec asserts nothing about the tail. `GetAchievementCriteriaInfo` is the live example: we have
9 returns from a Mainline call site and no evidence about anything past them, so 9 is a lower
bound, not the arity. A stub that returns a tenth value is inventing an API shape just as much
as a fabricated fixture would — it is just harder to spot, because it looks like plumbing.

Keep the stub's argument order identical to the real function even where the fixture makes an
argument irrelevant. The stub's job is to be wrong in no way the spec could detect.

## Spending the capture, and what stays pending

Un-pend exactly what the fixture covers. A capture from a fresh character supports "a
progress-bar criterion at zero" and does not support "a criterion mid-progress" — those are
different tests and `docs/status.md` tracks the second as outstanding (C3).

So a pending test stays pending, and says why, naming the command that unblocks it:

```lua
-- Pending: needs a criterion with non-zero quantity. Section C3 of docs/ingame-commands.md.
pending("ranks a part-done progress-bar criterion above an untouched one")
```

That comment is what makes the test a queue entry rather than a shrug. Resist the alternative
of asserting on a plausible-looking value you constructed by scaling the captured one — that
is the fabricated fixture again, wearing a test's clothes.

## Writing the finding down

The tag decides how much later readers may lean on it, so use the conventions already in the
tree rather than inventing a phrasing:

- `[verified in game <date>]` — this paste. The strongest evidence available on this project:
  it outranks the generated docs, and it outranks anything inferred from the vendored source,
  including where they disagree. If the capture contradicts the docs, that is a finding worth
  stating plainly, not a discrepancy to smooth over by picking the tidier answer.
- `[unverified]` — still waiting on a capture. Keep the tag until one lands.

Where the finding changes a **client fact** — a constant's value, an interface number, a
struct's real field list, whether an event fires — it belongs in `CLAUDE.md` too, in the
section that already owns that fact. Detail and citations go in `docs/legacy-internals.md`;
`CLAUDE.md` gets the short form. Leave `[unverified]` claims, Scope and Non-goals alone; those
are Alex's.

And say what the capture cost bought, including the parts that came back surprising. A value
that disagrees with what "What I'm reading it for" predicted is the most valuable thing in a
paste, and the easiest to skim past while transcribing rows.
