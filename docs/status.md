# Status

Last updated 2026-09-30.

**Where we are, 2026-09-30: Phase 4 (v1 roster) has started on the report that SavedVariables
now load back. That report is untested here, and S1 tests it. Store, per-character snapshots,
the roster and tradeskill-candidate model, and `/lgn roster` are built, tested and merged
(PR #2: 158 tests, 2 pending on S1). No roster frame yet, and none of it has run in game.
Later the same day the client's own data tables (DB2) backed the tradeskill join, and another
addon's uploads closed the CurseForge check. S1 gained a fallback step. The vendor pin is still
`1.60.1.70009`, and wago.tools lists `1.60.1.70124`. Phase 3 is as below.**

**As of 2026-09-26: Phase 3 is built and the frame has been drawn by the client. A review pass on
2026-09-26 changed the ranking to three tiers, hid other classes' challenges, slowed the
`CRITERIA_UPDATE` refresh to 5 s and hardened the read path. All of it is tested here and
none of it has been seen in game yet. 3c is done except the CurseForge check and the TOC
version line. Phase 4 has not started. The vendor pin is at `1.60.1.70009`.**

`Api/` and `Debug/` work on two characters. Enumeration confirmed three times by separate code
paths — 111 challenges, 65 points. **No secrets on our surface**, and that is a tested negative
rather than an assumption: `issecretvalue` exists and the guard is active.

`Model/` ranks, groups and summarises against the fixtures (38 tests, run under an environment
that errors on any non-stdlib global). `UI/` renders through a widget double (10 tests).
`/lgn` opens the window; `/lgn uidump` prints what it rendered as text and matches
`spec/golden/uidump_combined.txt`. 90 tests, nothing pending.

Open in the queue, in order: **S1** (v1 rests on it), **U3**, **U1** and **U2** (under five
minutes together), then **C3**, with **D4**, **C2** and the second half of S1 in the same
Alchemy session. C3 is the first real data for the
"in progress" tier. See `docs/ingame-commands.md`.

## Legacy Forever and the client data (DB2) — 2026-09-30

Alex asked what another Legacy addon could teach us: cjber's Legacy Forever, a GPL-3.0 map and
tracker addon. It builds its data from the client's DB2 tables through wago.tools, so the read
turned into a DB2 cross-check at builds 69913, 70009 and 70124. The facts are in `CLAUDE.md`,
tagged `[DB2, 2026-09-30]`. The detail and the join are in `docs/legacy-internals.md`, under
"Client data (DB2)" and "Legacy Forever". Nothing it found changes code.

**The client data agrees with every capture we have.** All 26 challenges in `spec/fixtures/`
match on ID, `flags` and points. So DB2 can now answer questions that would otherwise cost a
round trip in game. It stays research evidence, never a runtime source.

What it found:

- **The tradeskill join.** All six tradeskill lines are tier-4 children of the Classic lines,
  as PR #2 inferred from source. S1 still decides what the live call returns.
- **Class levels are in the data.** Each class challenge has a type-5 criterion with 25, 45 or
  60. See the note under the professions-only decision below.
- **Two mirrored challenge sets.** Ours carry flag bit 27 and the mirror carries bit 28, with
  its own IDs. Who sees the mirror is unknown. That explains bit 27, one of two flag bits
  `docs/legacy-internals.md` had as unidentified. v1 must not assume two characters report the
  same challenge IDs.
- **CurseForge.** Legacy Forever's packager uploads land under CurseForge's `1.60.1` version,
  which closes the check that was open since 2026-09-19 (`docs/distribution.md` §3).
- **SavedVariables.** Legacy Forever and Blizzard's own challenge tracker both set
  `## LoadSavedVariablesFirst: 1`, and ours does not. S1 gained a fifth step that tries it,
  only if the plain load fails.
- **Newer builds.** wago.tools lists 1.60.1.70058 and 1.60.1.70124 after our pin. The bump is
  next.

Not taken:

- `RECEIVED_ACHIEVEMENT_LIST` in C2. It fires at login, before `/etrace` can be opened, and
  nothing of ours reads achievements at login. It is a note under Q12 in
  `docs/legacy-internals.md` instead.
- Their code. GPL-3.0 against our MIT means facts and approaches only.
- Their tooling: a type checker, six CI jobs and a locale pipeline. That is more than v0 needs.

Open for Alex, neither blocking S1:

- A "Works alongside" line in `README.md` that points to Legacy Forever for map pins. It
  covers where a challenge is. We cover which challenge is next and which alt should do it.
- Whether a Next Up row should open Blizzard's Legacy panel on that challenge. It takes three
  calls, all present at the pin and cited in `docs/legacy-internals.md`. An idea only, not
  planned.
- Whether class-level matching reopens. See the note under the decision below.

## PR #2 review — 2026-09-30

A code review of the Phase 4 branch, then fixes on the same branch. It found 14 problems. 13
are fixed, each in its own commit with a test that fails without the fix.

**The Phase 4 headline claim was false as first built.** "A failed part never overwrites a
good one" did not hold for either part. `Api.GetTreeSpend` returns a table even when every
`C_Traits` read fails, because the tree ids come from constants with fallbacks. So the
keep-previous branch never fired, and a logout with no trait config would have saved nils over
an alt's spend. Professions failed the same way: a slot whose `GetProfessionInfo` threw was
dropped silently, and the short list passed as complete. Now a tree read counts only if
`unspent` and every `spentInTree` are numbers. A profession read with a failed slot counts as
no read. An empty profession read never replaces a stored list either, because skill data may
not be ready when a snapshot fires. The cost is a stale row, until `/lgn roster forget`, for a
character who really drops both professions.

**One unknown event would have disabled the whole addon.** `RegisterEvent` throws on a name
the client does not know, and Core registered the three snapshot events bare. A beta rename of
`TRAIT_CONFIG_UPDATED` would have stopped Core before `OnEvent` and the slash commands were
set up, taking Next Up down with it. Now each event is checked with `C_EventUtils.IsEventValid`
where the client has it and registered under `pcall` regardless. Skipped events are listed in
`/lgn roster`, which makes every S1 paste C2 evidence too.

**S1's paste could not have answered S1.** Four gaps, all closed:

- `GetSkillLineParents` dropped `professionID` and turned 0 into nil. Now it keeps both ids
  and the raw struct.
- The login and logout snapshot results were never shown. Now they are logged, and the last
  10 are saved, so the next session shows the previous logout.
- A failed challenge read looked like "no tradeskill challenges". Now it prints the reason.
- A table assigned after `ADDON_LOADED` would have been missed. Now Store adopts it, replays
  this session's writes onto it, and reports `LATE LOAD`.

**The alt join depended on who ran the command.** If the skill-line lookup answers only for a
learned profession, a non-Alchemist running `/lgn roster` could never match the Alchemy alt.
The resolved map is now saved account-wide. A live answer with an id wins. A zeroed answer
never erases a saved one. Matching also falls back to `professionID`, as Blizzard's frame does
(`Blizzard_ProfessionsFrame.lua:41` at `bd2470a`).

Smaller fixes:

- A later event now restarts the 5 s snapshot delay, and the login snapshot is delayed too.
- A junk stored row is skipped instead of failing the whole `/lgn roster`.
- A carried-over part shows its own age and why the fresh read failed.
- The CHANGELOG entry says the roster has not run in game.
- `lifecycle_spec` now fires every snapshot event, with and without `C_Timer`.

**Not fixed: the TDD commit order.** `bfdd212` and `f49faf0` ship their tests inside `feat`
commits with no exception noted. Fixing that means rewriting pushed history, so it is left for
Alex to decide.

## Review pass — 2026-09-26

Two critical reviews, one of the code and one of the dev docs, then fixes. Alex settled the
three open choices the same day.

**The ranking misled a fresh character, and that was the headline finding.** With every
criterion at zero, the tiebreak did all the ordering. It summed raw units remaining across
skill points, reputation and dungeon counts, which put `Explorer` (one type-8 step, the whole
map underneath) second in the golden file. **Decided: three tiers.** In progress is ranked by
fraction, then criteria left, then client order. Not started stays in client order. No
progress shown is unchanged. Each tier present gets its own divider, so a fresh character's
list opens at "not started" and nothing claims to be close. Ranking decision 4 below records
it.

**Other classes' challenges are hidden, with a count.** Decided by Alex, and it closes the
open decision in the article section below. The match is structural: the category named like
`UnitClass`'s localized name marks its parent, and that parent's other children are hidden.
There is no "Classes" name and no ID. No match hides nothing. `Core.ReadViewInput` now reads
`Api.GetCharacterInfo` for this.

**`CRITERIA_UPDATE` coalesces over 5 s**, and `ACHIEVEMENT_EARNED` keeps 1 s. The event fires
for every criterion in the game, so at 1 s an open window cost a 21 ms sweep every second while
questing. A sooner request supersedes a later one through a token, and closing the window
cancels whatever is in flight.

Also fixed in code, each with a test:

- `UI.Refresh` `pcall`s the whole read. A throw now shows as the window's error state instead
  of a Lua error on every open. A test caught its own bug this way while being written.
- `Api.GetRewardTrack` skips non-table entries in the level and reward lists instead of
  indexing them.
- The first open in combat now waits for `PLAYER_REGEN_ENABLED` too, and says so in the window.
  Before, only event-driven refreshes waited.
- `Api.GetChallenges(categories)` reuses the category list `ReadViewInput` already read.
- `UI.filter` follows `BuildView`'s fallback, so a vanished group is forgotten.
- `UPDATE_GOLDEN=1` regenerates the uidump golden file. The golden now includes the Shaman
  character fixture, so it shows the view a real character gets.

Docs:

- **The vendor recreate recipe never checked out the pin.** It cloned the branch head.
  `vendor/PINS.md` now fetches and checks out the SHA from its own table, which is the same
  extraction `bump.sh` uses. The recipe was tested in a scratch directory and landed on
  `bd2470a` / `1.60.1.70009`. `docs/development.md` points to it instead of copying it.
- **`docs/legacy-internals.md` carried a second in-game queue**, C1–C9, whose IDs clashed with
  the live C1–C4. It is retired to a table mapping each old ID to where it was answered.
- `docs/ingame-commands.md` dropped the closed rows' instructions (they are in git history),
  replaced Scripts 1 and 2 with the `/lgn` commands that already read the same data, re-priced
  C3 as a ten-minute Alchemy session with D4 and C2, and added `ACHIEVEMENT_EARNED` to the C2
  trace. The `LNDump` EditBox block stays, because the `ingame-script` skill uses it as its
  template.
- `docs/development.md` gained a Workflows section: fixture intake, script parse-check, golden
  updates, re-pinning and citation checks.

~~**Tooling notes for Alex**, since the sandbox refuses writes under `.claude/skills/`:~~
**Done the same day.** The sandbox only blocks Bash writes there. The Edit tool works behind a
permission prompt, which is the documented route. Both scripts now pass an explicit
`${TMPDIR:-/tmp}` template to `mktemp`, and `check_script.sh` and `precommit.sh` both ran clean
inside the sandbox. The "script 1" references in both skills now point at the `LNDump`
section and queue row B. Original note:
`ingame-script/SKILL.md` (lines 105, 135-144) and `fixture-intake`'s examples still say
"script 1". Script 1 is gone from the doc, and the `LNDump` block is now its own section.
The evals in `ingame-script/evals/evals.json` ask to edit script 1. The `mktemp -d` issue in
`check_script.sh` and `precommit.sh` still stands, so this pass parse-checked the in-game
blocks by hand with `luac -p`, multi-line and flattened.

## Blizzard's Legacy overview article — 2026-09-26

Blizzard published a public overview of the system
(<https://news.blizzard.com/en-us/article/24307383/get-to-know-the-world-of-warcraft-forever-legacy-system>).
Nothing in it contradicts a client fact, and its per-category totals are the U1 filter bar
row for row — 27/18/12/2/3/3, 65 challenges, with the zero-point Explore achievements outside
Blizzard's own count. The four reward names match D6. Detail and quotes in
`docs/legacy-internals.md`, "Blizzard's public numbers".

Two things it adds that change plans rather than facts:

**One character can earn at most 29 of the 65.** Blizzard's breakdown: 3 leveling, up to 6
tradeskills, 12 PvP, 2 Adventure, 6 Dungeons and Raids. That is v1's premise in Blizzard's own
words. It also pins down v1's profession mapping: the six Tradeskills children are all
crafting, the unlock rule says "non-gathering primary tradeskill", and 6 = two primaries ×
three tiers. Gathering and secondary professions never map to a challenge.

**v0 shows 24 rows the current character cannot finish.** The character's own class covers 3
of the 27 class points; the other eight classes' challenges sit below the "no progress shown"
divider because they carry no criteria, but they are dead weight for that character — 24 of
the 34 rows under the divider. ~~**Open decision, Alex's:** hide them, or leave them as the
account-wide view.~~ **Settled 2026-09-26: hidden, with a count.** See "Review pass" above. Hiding would match the class subcategory name against the localized name
`UnitClass("player")` already returns through `Api.GetCharacterInfo` — a same-locale string compare
of two client values, not description parsing — and would be a `Model` change plus a golden
update. It is not a ship blocker either way.

Also from the article: the system unlocks on the first point (level 25, 150 in a crafting
profession, or the full map), yet every read we make worked on two zero-point characters, so
the addon works before Blizzard's own window does. Blizzard plans more challenges and reward
tiers "for each content update", which is the no-hardcoded-IDs rule earning its keep.

## Vendor pin moved to 1.60.1.70009 — 2026-09-26

First real build bump since the pin was set. `70ef1b2` → `bd2470a`. No symbol LegacyNext calls
appears in the diff, `LegacyConstantsDocumentation.lua` did not move, no doc file was deleted,
and `## Interface: 16001` is still what the version number computes to. `Blizzard_LegacySystem`
changed in three files, all gamepad bindings and pixel nudges on textures. Nothing in
`CLAUDE.md`'s client facts or constants table needed editing, and all 74 tests stay green.

What it cost: five pin-relative line numbers in `docs/ui-templates.md` had shifted and were
re-derived against the new checkout, not nudged. Full accounting in `docs/beta-builds.md`.

Also settled: the `.toc` Interface formula (`major*10000 + minor*100 + patch`) now has its
second data point and agrees. It was one observation at one pin before this.

## U1 — the frame drew, and D9 closed the last pending test, 2026-09-19 (night)

**The window renders, and the content is right.** Both templates resolved on the live client —
`frameTemplate = "BasicFrameTemplateWithInset"`, `scrollTemplate = "UIPanelScrollFrameTemplate"`,
neither a fallback — and `escapeCloses = true`. The header read
`Legacy Track  ·  0 pts  ·  15 to next` / `Next: Replica Ironforge Air Rifle`. The filter bar
came back exactly as predicted: `[All 65] | Classes 27 | Tradeskills 18 | Dungeons 3 |
Raids 3 | Player vs. Player 12 | Adventure 2`, summing to 65, in client category order with
every group named. 65 rows, 31 measurable above the `no progress shown` divider and 34 below,
no `?` figures. Longest name 27 characters, none over 30.

**`read took 21 ms`** for the whole sweep. That is the number nobody had, and it settles the
refresh policy: the 100 ms threshold that would have forced `CRITERIA_UPDATE` off the refresh
path is not close. The throttle stays as built.

**One Lua error, and it fired on the very first `/lgn` of a session.** `ensureFrame` published
`UI.frame` *after* `frame:Hide()`, but a frame is shown at creation, so that Hide fired
`OnHide`, which indexes `UI.frame` — nil at that instant. It is once per session and the frame
drew anyway, since `ensureFrame` had already finished building it and Toggle went on to Show.
Fixed by hiding and publishing `UI.frame` before the handlers are wired.

The UI widget double had not caught it because `Show`/`Hide` on the double were plain state
setters that never fired the scripts. They now fire `OnShow` and `OnHide` on a state change,
as the client does, which reproduces the exact stack; the regression test is
`spec/ui/ui_spec.lua`, "toggles open on the first call without touching a nil UI.frame".

**U1 stays open for the screenshot alone.** Row content is checkable here against
`spec/golden/`; only the look needs Alex's eyes, and it should be judged on a build with the
fix in it.

**D9: all 29 categories, in client order, summing to 111.** `spec/fixtures/categories_full.lua`
replaces the assembled `categories_partial.lua`, which it confirms field for field — all 16
rows, nothing contradicted. The 13 it adds are the class and tradeskill ids the section-B sweep
never recorded. Client order is not sorted by id, name or depth: `Do Not Display`, `Druid`,
`Alchemy`, `Ranks`, `Explorer`, `Tier 1 Gear`, `Eastern Kingdoms`, then the rest interleaved.
Two structural notes the partial could not show — **Raids and Adventure both hold achievements
of their own and have children**, while Classes, Tradeskills and Player vs. Player hold none,
so "a parent category is empty" was never a safe assumption. No `Model/` or golden output
changed when the fixture was swapped in, which is the check that the partial had not been
quietly shaping the tests.

## Phase 3 built — 2026-09-19

Everything below is tested here and unseen in the client. That distinction is the whole reason
U1 exists.

**3a, `Model/`.** One scoring block at the top of `Model.lua` holds the five locked decisions
and is the only place closeness is defined. `Progress` normalises criteria (quantity when
`need > 1`, boolean step otherwise, mean of fractions per challenge), `Rank` excludes completed
and zero-point challenges, `Compare` orders measurable-first, fraction remaining, steps
remaining, client order. `Groups` and `Filter` handle `parentCategoryId == -1` as top level
and drop empty groups by count. `RewardSummary` recomputes the next threshold from the sparse
list. `BuildView` produces the whole view: header lines, filter bar, rows with a divider, and
three distinct non-ok states (`error`, `empty`, `done`).

~~One consequence worth stating so it is not reported as a bug: **single-step challenges sort
first among untouched entries.**~~ **Superseded 2026-09-26.** It was a bug from the player's side.
Untouched challenges are now their own tier in client order. See "Review pass" above. `Explorer` (one type-8 criterion) and `Field of Honor: Week 4`
(one type-27 quest step) read `0/1`, and one step is fewer than 150. That is decision 3
(no recursion) meeting decision 4 (steps as the tiebreak). If it reads wrong in the client,
the fix is a scoring change in `Model.Compare`, not a rewrite.

**New Api read: `Api.GetCategories`.** A challenge only knows its parent's id; Classes,
Tradeskills and Player vs. Player hold no achievements of their own, so their names never
reach the challenge list. 58 calls, guarded like the rest, with a `categories` dump section.
Its fixture, `categories_partial.lua`, is assembled from the two earlier captures (16 of 29
categories, doc order, every row verbatim) and labelled as such; **D9** replaces it.

**The five open 3b decisions, settled:**

| | Decision | Settled as |
|---|---|---|
| Scroll | ScrollBox vs `UIPanelScrollFrameTemplate` | **`UIPanelScrollFrameTemplate`**, via `pcall`, falling back to a bare `ScrollFrame` with wheel scrolling by hand. ScrollBox is Tier A on the branch (`docs/ui-templates.md`) but unproven in game, and 65 text rows in a pool do not need a data provider. Revisit only if U1 shows a problem |
| Truncation | Long names in a ~40-char row | `SetWordWrap(false)` + `SetMaxLines(1)` on a fixed-width name string, tooltip on hover with the full name, description and every criterion. Whether the client draws `...` is Tier C: **U2** |
| States | Empty vs error | Three: `error` ("Could not read your challenges: <reason>"), `empty` ("No Legacy challenges found"), `done` ("Nothing left to earn", with a per-category variant). Header failures are separate and never blank the list |
| Refresh | Throttle policy | On show; `ACHIEVEMENT_EARNED` and `CRITERIA_UPDATE` registered only while shown; ~~coalesced to one rebuild per second~~ 1 s for `ACHIEVEMENT_EARNED`, 5 s for `CRITERIA_UPDATE` (2026-09-26), via `C_Timer.After` (feature-detected); deferred to `PLAYER_REGEN_ENABLED` when `InCombatLockdown()`, on first open too since 2026-09-26. The frame itself is not protected, the 900-call sweep is the reason |
| Escape | `UISpecialFrames` | Inserted when the table exists. The template's own close button is rewired to `frame:Hide()` because `UIPanelCloseButton_OnClick` routes through `HideUIPanel`, which refuses in combat (`UIParentPanelManager.lua:854-861`) |

Frame chrome is `BasicFrameTemplateWithInset` with a plain-frame fallback. `UI/` never touches
`Api/`: `Core.lua` injects `ns.ReadViewInput` as the data source, and `/lgn uidump` reads
through the same function, so the two cannot disagree on content.

**3c, from the three agents:**

The three release findings (packager fixed upstream and dry-run verified, README and
CHANGELOG rewritten with the `v0.1.0` tag scheme, every UI template Tier A at the pin with
two Tier C items queued as U2) are recorded once, under "Phase 3c — release prep" below.
The live checklist is "What must be true to ship v0".

**Not done, and why:** ~~the icon~~ (done later the same day, see 3c below); the TOC version
line (Alex's); CI packaging (wire `BigWigsMods/packager@v2` in once the CurseForge check
passes, no `-g` flag needed).

**Tooling notes for Alex** (the `mktemp` part fixed 2026-09-26, see "Review pass"): `precommit.sh` and `check_script.sh` both use `mktemp -d`, which
on macOS ignores `TMPDIR` and fails under the Claude sandbox (`Operation not permitted`). The
gate was run with the sandbox off for this session's commits: 0 failures, one pre-existing
warning (`LARGE_DUMP = 60000`, not an ID), all four in-game script blocks parsed. `mktemp -d
-t lgn` would fix both scripts; they live under `.claude/skills/`, which the sandbox refuses
to write, so the fix is yours. `verify_citations.py` only matches `.lua` citations;
`docs/ui-templates.md` carries 28 `.xml` ones that a bump will not re-check.

## D6 and D7 — the reward track works, and the criteria model was wrong, 2026-09-19

**D6: the reward track is alive.** Legacy Track, level 0 of 90, four thresholds at 15/25/40/55,
`pointsToNext` 15. All four rewards carry a name and an item: Replica Ironforge Air Rifle,
Spectral Bear Cub, Spectral Bear Tabard, Reins of the Spectral Bear. The v0 header has
everything it needs. `isCollected` reads **true** on the unreached level 40 tabard, confirming
the existing warning — it is account collection state and must never render as progress.

**D7 broke a client fact, and it is the most consequential finding since the mixin bug.**
`criteriaType` had three documented values. The full dump has **eight**: 0, 7, 8, 27, 43, 78,
165, 243. The three we knew were simply the three that happen to appear in the first 20
challenges. Any exhaustive switch on the type was already wrong.

Worse, one of the new types breaks the progress model directly. **Type-243 reputation criteria
carry `need = 42000` and `have = 0`, but `flags = 1024` and `isProgressBar = false`.** The
progress-bar bit is clear, so a checklist reading calls "Master of Alterac Valley" one step
from done when it is 0/42000 reputation. Closeness must use `need`/`have` whenever `need > 1`,
not only when the bar bit is set. That is a scoring rule, and it lands before Phase 3 rather
than after.

Also from the same dump:

- `parentCategoryId` is **-1** on top-level challenge categories (Dungeons, Raids, Adventure).
  The category filter must read that as "no parent" rather than looking it up.
- Type 78 puts alternatives in one criterion — "Ragefire Chasm or Hall of Thanes" — with
  `assetId = 0`. There is no way to tell which half was done.
- `character` returns `professions = {}`, an empty table rather than nil, and `realm` is
  populated ("Classic Beta PvP"). That answers Phase 4's open question about whether a
  realmless Forever setup breaks the character key. It does not.
- One criterion on the whole account is complete — Valley of Trials in Explore Durotar — and it
  carries `charName = "Bong"`. Partial C3 and C4 data: a challenge at 1 of 11, and `charName`
  populated on a per-character achievement.

Fixtures: `dump_rewards_fresh.lua`, `dump_criteria_types.lua`, `dump_character_shaman.lua`.
The full 111-challenge dump was **not** committed whole — the 46 zero-point Explore
achievements carry roughly 600 subzone criteria that Next Up excludes anyway. What was kept is
one challenge per distinct `criteriaType` plus the only completed criterion, each copied
verbatim and labelled as an excerpt.

## D5 — the mixin fix confirmed, 2026-09-19

Second character (level 1 Mage), fixed build installed. `ok=28 partial=1 nil=1 skipped=1` —
the `error` is gone and `GetMajorFactionData` now reads:

```
partial C_MajorFactions.GetMajorFactionData table, 19 entries; dropped
  return1.factionFontColor.color.{GetHSL, GetRGBA, IsRGBEqualTo, SetRGB, GetRGB, OnLoad,
  GenerateHexColorMarkup, WrapTextInColorCode, GenerateHexColor, IsEqualTo,
  GenerateHexColorNoAlpha, SetRGBA, GetRGBAsBytes, GetRGBAAsBytes}
```

All 14 dropped paths are ColorMixin methods, exactly where the documentation said the mixin
would be attached, and the struct comes back with 19 usable fields. The diagnosis and the fix
both hold.

**New finding, and it corrects a client fact:** `C_Traits.GetConfigIDByTreeID` returned
**4040613** on this character against **2938022** on the Shaman. The configID is
**per-character**, not a client constant — `CLAUDE.md` had recorded the Shaman's value as
though it were the value. Corrected there, and the trees fixture now carries a note that its
number is that character's. Nothing in `LegacyNext/` hardcoded it, so no code changed.

## Milestones

| Date | What | Notes |
|---|---|---|
| 2026-09-17 | Forever beta live | Build 1.60.1 (69913), the one everything here is verified against |
| **2026-11-04** | **Forever launches** | ~6½ weeks out as of 2026-09-19 |
| — | Hardcore Legacy | Later, no date. Out of scope regardless |

The deadline that actually binds is **launch**, not beta: an addon that lands after players
have already picked a Legacy tracker is competing uphill. As of 2026-09-18 no in-game Legacy
tracker existed, which is the whole opportunity — recheck before release, since that is a claim
with a shelf life.

Beta builds will churn the IDs and may churn the APIs. `beta-build-bump` exists for that; run
it whenever the forever branch moves, and re-run **D5** after any bump, since "no secrets on
our surface" is a per-build finding.

## What must be true to ship v0

Not a schedule — a checklist. Nothing here is guesswork about the UI; it is the set of things
that are currently known to be false or unverified.

**Blocking, build:**

- [x] `Model/` ranking, tested against `spec/fixtures/` — 2026-09-19
- [x] The v0 frame: reward track header, ranked list, category filter — written 2026-09-19
- [x] The v0 frame **seen in the client** — U1's uidump, 2026-09-19. Content correct, both
      templates resolved, 21 ms per read, one OnHide error found and fixed. Screenshot still
      wanted for the look; U1 stays open for that alone
- [x] Reward track header actually renders — D6 closed 2026-09-19, header built on it

**Blocking, release mechanics** (`docs/distribution.md`):

- [x] Packager dry-run against a tag — done 2026-09-19; the packager gained Forever support on
      2026-09-17 and emits `forever` / `1.60.1` from the TOC alone
- [x] `.pkgmeta` `move-folders` — verified by the same dry run, TOC at the zip root
- [ ] Confirm CurseForge's Forever version type (`88568`) exists — Alex, in a browser or with
      an API token; steps in `docs/distribution.md`
- [ ] `## Version: @project-version@` in the TOC, first tag `v0.1.0` — Alex's edit
- [ ] **Repo public.** The README header now carries the CI badge and the icon as absolute
      `github.com` / `raw.githubusercontent.com` URLs. Both 404 while `lxhwes/LegacyNext` is
      private, on GitHub and in the CurseForge listing alike. Alex's
- [x] Icon: `LegacyNext/Media/icon.tga` and the `## IconTexture` line — 2026-09-19, concept A
      from `docs/icon-design.md`; seen in the AddOns list is **U3**

**Should be true, not blocking:**

- [x] **D9** — categories capture in client order, `spec/fixtures/categories_full.lua`,
      2026-09-19
- [ ] **U2** — whether long names get `...` or need the tooltip alone
- [ ] **C2** — whether the achievement events fire; the frame registers them regardless
- [ ] Competition recheck immediately before release

Two of the three release-mechanics fears were reported problems nobody had reproduced, and
both turned out to be fixed upstream two days before we checked. The lesson stands either
way: the dry run cost twenty minutes and closed two blockers.

## Phases

| Phase | What | State |
|---|---|---|
| 0 | Scaffold — repo layout, TOC, hello-world addon, Lua 5.1 toolchain, CI, packaging notes, vendor pin | **Done** — `b66486e` |
| 1 | Read-only research into Blizzard's Legacy system, answering Q1–Q12 | **Done** — `0ad6e6c` plus in-game verification |
| — | Project skills: `forever-api-lookup`, `beta-build-bump` | **Done** — `d9bb4a6`, `c9db19c` |
| — | Project skills: `ingame-script`, `api-guard`, `fixture-intake`, `safe-commit` — the authoring loop | **Done** |
| 2 | `Api/` guard layer and `Debug/` dump+probe. No `Model/`, no `UI/`. | **Done** — ran in game 2026-09-19, one guard bug found and fixed |
| 3a | `Model/` — ranking, reward-track math, category list. Pure Lua, fully testable here. | **Done** — 2026-09-19 |
| 3b | `UI/` — the v0 frame. Needs in-game iteration; see the UI plan below. | **Done** — drawn in the client 2026-09-19 (U1 uidump). Screenshot still open; the 2026-09-26 changes are unseen |
| 3c | Release prep — LICENSE, icon, packager dry-run, version scheme, listing. **Was missing from the plan entirely.** | Done except ~~CurseForge check~~ (answered 2026-09-30, `docs/distribution.md` §3), TOC version line |
| 4 | v1 roster. ~~Blocked on SavedVariables, **and its stated approach is known broken** — see below.~~ Started 2026-09-30 on a report that the SV bug is fixed; mapping is professions only. See "Phase 4 — started" below | **In progress** — data layer built, unverified in game (S1); roster frame not started |

Phase 3 was one row until 2026-09-19. Splitting it is not bookkeeping: `Model/` is pure Lua
that I can finish and prove alone, `UI/` cannot be verified without Alex looking at it, and
release prep needs neither. Bundling them gave Phase 3 no honest definition of done.

## Phase 3b — the v0 UI, and the loop for building it

**The real problem is not the frame, it is that I cannot see it.** The dump/probe pipeline made
data questions cost one round trip each. Nothing equivalent exists for "is this readable, does
the long PvP description overflow, is the row too narrow". Without a loop, every UI change
costs a screenshot and a guess.

Proposed: **`/lgn uidump`** — serialize what the frame *would* render as text. Row strings,
truncation points, computed widths, the filter's category list, which empty state is showing.
That splits "is the content right" (answerable here, against fixtures) from "does it look
right" (only Alex). It reuses `Debug.Serialize`, so it is cheap.

**Built 2026-09-19.** `Debug.RenderView` is pure and golden-tested against
`spec/golden/uidump_combined.txt`; `/lgn uidump [category]` runs the same `ns.ReadViewInput`
the frame uses and appends a `== CLIENT ==` footer with the read time and the templates the
frame got. Computed pixel widths are not in it (no font metrics here); it reports the longest
name and every name over 30 characters instead.

### Layout — Alex, 2026-09-19

Single column: reward track header, category filter bar, scrolling list.

```
┌────────────────────────────────────────┐
│ Legacy Track  ·  0 pts  ·  15 to next  │
│ Next: Replica Ironforge Air Rifle      │
├────────────────────────────────────────┤
│ [All] Class Prof PvP Rep Dung Raid     │
├────────────────────────────────────────┤
│ Journeyman Alchemist        0/150  1pt │
│ Novice Spelunker              0/6  1pt │
│ Master of Alterac Valley  0/42000  1pt │
│ Conquerer of the Deeps        0/8  1pt │
│ Expert Alchemist            0/225  1pt │
│ ─────────── no progress shown ──────── │
│ Novice Druid                       1pt │
│ Rank 3                             1pt │
└────────────────────────────────────────┘
```

**Rows are text only.** One line each, right-aligned figure, no status-bar textures. The 34
measureless challenges sit under a divider rather than showing an empty bar — an empty bar
reads as 0%, which is exactly what Ranking decision 1 exists to prevent. The divider makes
"the API tells us nothing here" visible instead of implied.

Note the third row: `Master of Alterac Valley 0/42000` is why the type-243 quantity rule
matters. Under a checklist reading it would print `0/1` and sit near the top.

### ~~Still unmade~~ Settled 2026-09-19 — see "The five open 3b decisions, settled" above

Kept as written on the morning of 2026-09-19 so the reasoning that went into each is legible.

| | Decision | Notes |
|---|---|---|
| Scroll | `WowScrollBoxList` vs `UIPanelScrollFrameTemplate` | Blizzard's Legacy UI uses ScrollBox (`Blizzard_LegacyChallengeCategoryList.xml`), but only the older template is **proven in-game** by our dump window. Feature-detect, fall back |
| Truncation | Long names in a ~40-char row | "Master of Darkspear Islands", "Conquerer of the Wilds" fit; criterion text like "Reach exalted reputation with the Frostwolf Clan" does not. Tooltip on hover is the usual answer |
| States | Empty vs error, kept distinct | `Api` returns `nil` + reason precisely so the UI can say "nothing left to earn" and "could not read your challenges" differently. Wasted if the frame flattens them |
| Refresh | Throttle policy | `CRITERIA_UPDATE` fires in bursts. Queue past `PLAYER_REGEN_ENABLED`; never rebuild in combat |
| Escape | `UISpecialFrames` | One line, makes the frame feel native |

### Performance, unverified

One `GetChallenges` sweep is roughly **900 client calls** — 111 `GetAchievementInfo`, 111
`GetAchievementNumCriteria`, 674 `GetAchievementCriteriaInfo`, plus points lookups (counted
from the D7 dump's own tally). Acceptable on show. Unknown as a login hitch, and unknown under
a `CRITERIA_UPDATE` burst. ~~Needs a queue row once the frame exists.~~ **U1** carries it: the
uidump footer prints `read took N ms`. Nothing runs at login; the first read is on first show.

## Phase 3c — release prep, previously absent

Checked 2026-09-19; these do not exist yet:

- [x] **`LICENSE`** — MIT, Alex Howes, 2026. Added 2026-09-19. Was the one hard blocker on
      publishing at all.
- [x] **Icon.** Shipped 2026-09-19: `LegacyNext/Media/icon.tga` (64x64 32-bit TGA, original
      vector art, concept A "Almost full" from `docs/icon-design.md`), TOC line uncommented.
      Unseen in the client — **U3**.
- [x] **`CHANGELOG.md`** — added 2026-09-19, Keep a Changelog, `[Unreleased]` populated.
- [x] **Version scheme.** Decided 2026-09-19: SemVer `0.x.y` in beta, `1.0.0` at launch, tag
      is the version via `@project-version@`. The TOC line itself is still `0.0.1` — Alex's.
- [x] **README as a listing.** Rewritten 2026-09-19; the repo content moved to
      `docs/development.md`. Given a visual header later the same day: centred icon
      (`docs/icon-drafts/almost-full-256.png` at 120 px), six badges in the icon's navy/gold
      palette, the layout mock from Phase 3b, and a command table. Two caveats — the header is
      raw HTML, so how CurseForge's editor treats it is unchecked until the listing exists, and
      every image URL is absolute, so it needs the repo public (see the checklist above).
- [x] Packager dry-run and `.pkgmeta` `move-folders` — both verified 2026-09-19.
- [ ] CurseForge Forever version type — needs a browser or a token.

None of this needed Phase 3a or 3b finished, and the dry run was as cheap as predicted.

### Phase 4's premise needs rewriting before it starts

The bootstrap doc specifies candidate-alt mapping "driven by criteriaType/assetId from
fixtures, **NOT** by parsing challenge names", and says to stop and report if the fixtures
don't expose a usable criteria type. They don't, for half the target:

- **Profession challenges work.** `criteriaType` 7 carries the skill line in `assetID` and the
  threshold in `reqQuantity` — `Journeyman Alchemist` is `assetId = 2937, need = 150`. Mapping
  an alt's profession skill against that is exactly what was intended.
- **Class-leveling challenges cannot work that way.** `Novice Druid` has
  `criteriaExpected == 0`. The level 25 exists only in `description` prose. There is no
  criteria row, no `assetID`, nothing to key on.

So the honest options are to parse the description for a level (the thing the brief forbids,
and it breaks on localisation), to ship profession mapping only, or to drop the class half.
~~**Alex's call, not taken yet.** It does not block Phase 3.~~ **Decided 2026-09-30, Alex:
professions only.** Class challenges appear in the roster data but get no candidate alt. If a
later build exposes a machine-readable level, reopen this.

**New evidence the same day, and not a reversal.** The client data holds the level for every
class challenge: type 5, with `CriteriaTree.Amount` 25, 45 or 60, at builds 69913, 70009 and
70124. No API we know of returns it. That falls short of the reopen condition above, which
asks for a build that exposes the level to addon code. Reading it from DB2 would mean shipping
a generated table keyed by achievement ID, and the no-hardcoded-IDs rule forbids that today.
It could be relaxed to "never hand-maintain IDs", which is how Legacy Forever works: a daily
regenerated table plus an in-game audit. That is Alex's call. The decision stands until then.

Added 2026-09-26, from Blizzard's overview article: profession mapping only ever targets the
six crafting professions — Alchemy, Blacksmithing, Enchanting, Engineering, Leatherworking,
Tailoring — since those are the only Tradeskills children and the unlock rule reads
"non-gathering primary tradeskill". A roster snapshot should still record every profession
slot (the seven-return rule stands), but the mapper skips any skill line with no challenge.
The same article states the reason v1 exists: one character tops out at 29 of the 65 points.

## Phase 4 — started, 2026-09-30

Started on Alex's report that Blizzard fixed the SavedVariables bug. The report comes from
patch notes, not a test, so **S1** is the check. It is built so it answers from our own table,
with no second addon needed: `Store.Diagnostics()` records what came off disk before this
session touches anything.

Built and tested here, none of it run in game:

- **`Store/`**: schema 1, `LegacyNextDB.characters["Name-Realm"]`, and a session counter that
  is the S1 evidence. A table saved under a newer schema is left untouched and read-only, so a
  downgrade cannot wipe an alt list. `LegacyNextCharDB` is still declared and still unused.
- **Snapshots** (`Model/Roster.lua`): class, level, every profession slot, per-tree spend,
  unspent, cap. They are taken ~~at `PLAYER_LOGIN` and~~ at `PLAYER_LOGOUT`, and 5 s after
  `PLAYER_LOGIN` (moved by the PR #2 review), `PLAYER_LEVEL_UP`, `SKILL_LINES_CHANGED` or
  `TRAIT_CONFIG_UPDATED`. Whether those three fire is unverified (C2), and logout is the
  backstop. ~~**A failed part never overwrites a good one**: `MergeSnapshot` keeps the last
  good trees or professions with their old timestamp.~~ False as first built, for both parts.
  The PR #2 review above found it and fixed it the same day, so the claim holds now.
- **Roster order**: current character first, then level, then key.
- **Tradeskill candidates**: for each incomplete type-7 challenge, every stored character
  with the profession, closest first. Class challenges get none, per the decision above.
- **`/lgn roster`** prints all of it as copyable text with a `== RAW ==` block, and
  `/lgn roster forget <Name-Realm>` drops a deleted alt. This is a stand-in until the frame,
  and S1 needs it.
- `spec/core/lifecycle_spec.lua` loads every TOC file in TOC order and plays
  `ADDON_LOADED` → `PLAYER_LOGIN` → `PLAYER_LOGOUT` at them, so a file left out of the TOC now
  fails a test instead of failing silently in game.

**Found while building: the tradeskill join is probably not direct.** Tradeskill criteria name
skill line 2937 for Alchemy, not Classic's 171. At the pin, Forever's own profession frame
compares `GetProfessionInfo`'s `skillLine` against `parentProfessionID or professionID`
(`Blizzard_Professions/Camelot/Blizzard_ProfessionsFrame.lua:41-43`, `:56`). That suggests
`GetProfessionInfo` reports the parent line and 2937 is a child. Matching the two numbers
directly would then never find anyone. The mapper accepts either a direct match or a match
through `C_TradeSkillUI.GetProfessionInfoBySkillLineID(2937).parentProfessionID`, so it is
right either way. Whether that lookup answers for a line the character never learned is S1.
Both pending tests cite it.

Toolchain note: this session's network policy blocks lua.org and luarocks.org, so `hererocks`
could not build `tools/lua51`. Ubuntu's `lua5.1`, `lua-busted` (2.2.0) and `lua-check`
packages ran the same two gates (`busted --lua=lua5.1`, `luacheck LegacyNext spec`). CI is
unchanged.

Next, in order: S1 → the roster frame (a second view in the existing window, or its own; not
decided) → candidate lines in the Next Up detail for tradeskill rows.

## Research questions

All twelve answered. Detail and citations in `docs/legacy-internals.md`.

| | Question | State |
|---|---|---|
| Q1 | Challenge enumeration | Answered, verified in game |
| Q2 | Category representation | Answered, full 29-category tree captured |
| Q3 | Points per challenge | Answered from source |
| Q4 | Criteria in the detail pane | Answered from source; fixtures outstanding |
| Q5 | Account-wide vs per-character | Answered, flag value verified |
| Q6 | What the Challenge Tracker does | Answered from source |
| Q7 | Spent / unspent / cap | Answered; one recheck once points exist |
| Q8 | Tree 1189 display name | Answered — "Resourcefulness" |
| Q9 | `LEGACY_TREE_ADVENTURE_TALENTED_NODE_ID` | Answered — class-talent unlock level, out of scope |
| Q10 | Reward track | Answered, fully verified including reward contents |
| Q11 | Load-on-demand | Answered, verified in game |
| Q12 | Events | Answered from source; which ones fire is outstanding |

## Decisions locked in

These came out of research and should not be relitigated without new evidence.

- **Enumerate categories directly.** `GetCategoryNumAchievements` + `GetAchievementInfo(categoryID, index)`.
  Never `SetAchievementSearchString` or the filtered-achievement API — that is global state
  shared with Blizzard's Achievement UI and changes underneath us.
- **Never call `C_AddOns.LoadAddOn`.** `Blizzard_LegacySystem` is load-on-demand, and every C
  API we need works without it. Only its Lua scaffolding is absent, and we reimplement that.
- **Read constants from `Constants.LegacyConsts`** at runtime. Verified present before the LoD
  addon loads. The literals in `CLAUDE.md` are a fallback only.
- **The point cap comes from `C_Traits.GetMaxAvailableTraitCurrency(4225, true)`**, not from
  `TreeCurrencyInfo.maxQuantity`, which read 0 at zero points.
- **One shared 16-point pool** across all three trees — they share a configID and a currency.
- **Category filter is a flat list of six groups.** The tree is only two levels deep; we do not
  need Blizzard's recursive builder.
- **Drop empty categories by count, never by name.** "Do Not Display" is a real category the
  API returns.
- **Reward names come from `reward.name or reward.toastDescription`.** `name` is missing on
  some entries. No item lookup needed, so no async cache path.
- ~~**Ranking handles two criteria shapes.**~~ **Three.** The B sweep found 34 challenges with
  no criteria at all, which the two-shape reading would have flattened into 0%. Progress-bar
  criteria (`criteriaFlags` bit 1) give a fraction, checklists give a remaining count, and
  `criteriaExpected == 0` is its own case that sorts last — see Ranking decisions.
  Separately, `criteriaType` is a third axis and is open-ended: **eight values seen** — 0, 7,
  8, 27, 43, 78, 165, 243 — so never switch exhaustively on it. And type 243 proves a criterion
  can carry `need`/`have` with the progress-bar bit clear, so closeness must read quantities
  whenever `need > 1`.
- **Generated API docs are a floor, not a contract.** The live reward struct carries five
  fields that appear in no doc file. Feature-detect fields.

## Outstanding — needs the game

**The queue table at the top of `docs/ingame-commands.md` is the list.** It is not repeated
here — it used to be, and the two copies drifted within a day. Cite the ID when something is
blocked on a row.

What blocks what, as of 2026-09-26:

| Blocked | On |
|---|---|
| ~~Calling 3b done;~~ every look-and-feel question | U1 (3b is done, the screenshot is not) |
| ~~Un-pending the `GetCategories` fixture test; filter bar in client order~~ | ~~D9~~ closed 2026-09-19 |
| A real "in progress" row for the three-tier ranking | C3 |
| Whether long names ellipsise or only clip | U2 |
| `Api.GetCharacterInfo`'s profession slots (v1, not v0) | D4 |
| Real mid-progress ranking tests — derived values carry Phase 3a until then | C3 |
| Whether the registered events fire at all (the frame refreshes on show either way) | C2 |
| ~~Whether a ~900-call sweep is a visible hitch~~ | folded into U1 |

D5, D6 and D7 closed 2026-09-19. U1, U2, U3 and D9 opened 2026-09-19.

## Phase 3 readiness — checked 2026-09-19

Green. `Api` is verified against the live client on two characters, all four functions
returning usable data. ~~`Model/` and `UI/` are untouched 5-line placeholders, so nothing is
half-built.~~ (True at 16:13; both were built later the same day, see "Phase 3 built".) Frame creation is proven — `/lgn dump`'s window is a real frame that works in the
client.

Scoring inputs, all settled and not to be relitigated without new evidence:

1. Zero-point challenges excluded (Ranking decision 2)
2. `criteriaExpected == 0` sorts last (Ranking decision 1)
3. No meta-chain recursion (Ranking decision 3, superseded to "none")
4. Use `need`/`have` whenever `need > 1`, not only when the progress-bar bit is set (D7)
5. Mid-progress test values may be derived from captured shapes, labelled — see
   `spec/fixtures/README.md`
6. Added 2026-09-26: untouched measurable challenges are their own tier, in client order
   (Ranking decision 4)

**The known weakness, stated so it is not discovered later:** every captured point-bearing
criterion reads `have = 0`. Ordering by fewest absolute steps is testable from real data
(0/150 Alchemy against 0/300; 0/6 dungeons against 0/17), but partial-progress ordering — the
case the feature exists for — runs on derived values until **C3** lands.

Not blocking Phase 3: **C2** (events) — the v0 UI refreshes on `ACHIEVEMENT_EARNED`,
`CRITERIA_UPDATE` and on show, which is what Blizzard's own Legacy UI does. **D4**
(professions) — v0 does not read professions; that is v1's roster.

## What the first in-game run found — 2026-09-19

`ok=28 nil=1 error=1 skipped=1` on the probe, and one symbol tallied `secret=2 ok=0`:
`C_MajorFactions.GetMajorFactionData`, with `lastDetail = "unsupported type function"`.

Not a secret. Two defects in the guard, both now fixed:

1. **`plainCopy` rejected a whole table over one unusable field.** `MajorFactionData` carries
   `factionFontColor`, a `DBColorExport` (`MajorFactionsDocumentation.lua:281`) whose `color`
   field is declared `Mixin = "ColorMixin"` (`UIColorSharedDocumentation.lua:11`). The client
   attaches ColorMixin's methods, so the copy hit real functions two levels down and threw
   away `name`, `maxLevel`, `isUnlocked`, `renownLevel` along with them.
   `Api.GetRewardTrack()` returned `nil, "GetMajorFactionData unavailable"` — the entire
   reward track, a v0 feature, was dead.

   Unusable *fields* are now dropped and named in a third return; an unusable *value* still
   fails the read. A secret stays the exception and fails the table outright.

2. **Every `plainCopy` rejection was recorded as `secret`.** Cyclic, too-deep and
   unsupported-type all filed under the one status that means Midnight's restrictions reached
   us. The probe row said `error` for the same event the tally called `secret`. A partial copy
   now counts as `ok` plus a separate `partial` marker carrying the dropped paths, and
   `secret` means only what it says.

This is the value of the probe: the bug was in our guard, not the client, and only a live run
could have shown it. Everything else on the surface reads clean.

Confirmed the same run, all `(runtime)` rather than `(fallback)`:

- **`issecretvalue` exists and the guard is active.** "No secrets" is therefore a tested
  negative. Re-check per build.
- All six `Constants.LegacyConsts` values, plus `ACHIEVEMENT_FLAGS_ACCOUNT` (131072) and
  `EVALUATION_TREE_FLAG_PROGRESS_BAR` (1) — the latter two are live client globals even
  though neither appears in the pinned source.
- `GetMaxAvailableTraitCurrency` = 16 spendable, `GetConfigIDByTreeID` = 2938022 on a fresh
  character, `GetCurrentRenownLevel` = 0, `GetRenownLevels` = 4 sparse thresholds.
- `criteriaType` 7 renders as "150 Alchemy Skill", matching the skill-threshold reading.

Provenance note: this probe came back as an OCR'd screenshot (`Criterialnfo`,
`Is ValidAchievement`). Every number corroborates the 2026-09-18 sweep, so the transcription
is sound; the only claim without independent corroboration is the active secret guard.

## Fixtures landed — 2026-09-19

First real captures in `spec/fixtures/`, both from a fresh level 1 Shaman on build 69913:

| File | Covers |
|---|---|
| `dump_trees_fresh.lua` | Full `treeSpend`: one shared `configId` 2938022, cap 16, earnable 65, all three tree display names |
| `dump_challenges_page1_fresh.lua` | 20 of 111 challenges — all three `criteriaType` values, the no-criteria shape, and both point-bearing and zero-point entries |

Both parse under `luac -p`, and `#criteria == criteriaExpected` on all 20, so nothing was lost
in transcription. The `failures` tally from each capture is deliberately not in the fixture: it
records our guard's behaviour at capture time, not client data.

Captured on the pre-fix build. That bug rejected tables whole rather than truncating them, so
everything present is complete — and neither section reads `GetMajorFactionData`. `rewards` was
the only casualty, dumping `rewardTrack = { unavailable = "GetMajorFactionData unavailable" }`,
exactly as predicted. Not fixtured; it will be recaptured on the fixed build.

### Three findings that change the plan

1. **`criteriaType` 43 exists** — area discovery, `assetID` is an area ID. We had documented
   only 7 and 43's absence was invisible because it never appears on a point-bearing challenge.
   The lesson is the general one: treat the type list as open and never switch exhaustively.
2. **The Explore chain is three levels deep.** `Explore Azeroth` → `Explore Eastern Kingdoms`
   → `Explore Alterac Mountains` → 15 type-43 leaves. This puts the locked "recurse one level"
   decision in tension with itself: one level takes Explorer from "0/2" to "0/23" and still
   isn't the truth. **Resolved: v0 drops meta recursion entirely** — see decision 3 below.
3. **Class challenges have no machine-readable level.** `Novice Druid` is level 25, but
   `criteriaExpected == 0` and the 25 lives only in `description` prose. Phase 4 specifies
   candidate-alt mapping "driven by criteriaType/assetId, NOT by parsing challenge names" —
   for class-leveling challenges there is nothing to drive it with. Either v1 parses the
   description or class-leveling mapping drops to profession challenges only.

### One bug fixed

`/lgn dump characters` (the section is `character`, singular) produced a meta block and no
payload — indistinguishable from the client having nothing to say. `Debug.Build` now rejects an
unknown section and lists the valid ones.

## Ranking decisions — Alex, 2026-09-19

Raised by the section B sweep, all three settled. These are inputs to Phase 3's scoring
function; changing one is a scoring change, not a rewrite.

1. **Challenges with no criteria sort last.** One ranked list, not two, and nothing hidden
   behind a toggle. The 34 binary challenges — every class challenge, all five PvP Ranks, two
   others — sink below anything with measurable progress rather than sitting at a permanent
   0%. Detect them by `criteriaExpected == 0`, never by category or name.
2. **Zero-point challenges are excluded from Next Up.** That drops all 46 `Explore *`
   achievements, which are criteria substrate for the single `Explorer` challenge rather than
   rewards. `Explorer` itself still appears. Filter on the point value from
   `GetTraitCurrencyForAchievement`, never on the name — and don't hardcode the 0, since every
   point-bearing challenge awarding exactly 1 today is an observation, not a contract.
3. ~~**Meta chains recurse one level.**~~ **Superseded the same day — v0 does not recurse at
   all.** The 2026-09-19 capture showed the Explore chain is three levels deep
   (`Explore Azeroth` → `Explore Eastern Kingdoms` → `Explore Alterac Mountains` → type-43
   leaves), so one level would have bought a number that is larger but still not true. Combined
   with decision 2, the only entries that recursion would have fixed are zero-point Explore
   achievements that Next Up already excludes. `followMetaChains` stays in `Api`, stays off,
   and is a v1 question if a point-bearing meta challenge ever turns up — none has yet.
4. **Three tiers — Alex, 2026-09-26.** In progress (fraction above zero, ranked by fraction,
   then criteria left, then client order), not started (client order), no progress shown
   (client order). Replaces the raw-units tiebreak, which summed skill points, reputation and
   dungeon counts and ranked `Explorer` second on a fresh character.
5. **Other classes' challenges hidden, with a count — Alex, 2026-09-26.** Matched by structure
   against `UnitClass`'s localized name, never by a hardcoded name or ID. No match hides
   nothing.

## What Phase 2 built

| File | What it does |
|---|---|
| `LegacyNext/Api/Api.lua` | The guard layer plus `GetChallenges`, `GetRewardTrack`, `GetTreeSpend`, `GetCharacterInfo`, `Probe` |
| `LegacyNext/Debug/Debug.lua` | `Serialize` (pure), `Build`, the copyable window, `Dump`, `Probe` |
| `LegacyNext/Core.lua` | Slash routing for `/lgn probe` and `/lgn dump [section] [page]` |
| `spec/api/api_spec.lua` | Guard-layer behaviour: flags, secrets, cycles, the failure tally |
| `spec/debug/debug_spec.lua` | Serializer round-trips, pipe and newline escaping, stable ordering |

Decisions taken while building it:

- **Every WoW call goes through one `Api.Call`**, which feature-detects, `pcall`s, guards for
  secrets and tallies the outcome. It returns a packed table with an `n` field rather than
  varargs, so "the client returned nil" stays distinguishable from "the call failed".
- **Returned tables are deep-copied** before Api hands them out. The client may reuse its
  tables, and a secret can sit in a field while the table itself reads non-secret.
- **No `bit` dependency.** Single-bit flag tests are arithmetic, so the guard layer loads under
  plain Lua 5.1 and the tests can reach it.
- **Dumps are pure data, no comment lines.** A dump that loses its newlines on the way back
  still parses; a `--` header would swallow the file.
- **Two feature flags, both off:** `eventDrivenRefresh` (Q12 unresolved — Api is read-on-demand)
  and `followMetaChains` (Q4 unresolved — Api reports `assetId` and stops).
- **`maxQuantity` is reported raw and used for nothing.** The cap comes from
  `GetMaxAvailableTraitCurrency`, as decided in Phase 1.

Verified during the phase: `GetProfessions` returns **seven** values on Forever, not Mainline's
six, per `Blizzard_Professions/Camelot/Blizzard_ProfessionsFrame.lua:16`. Api iterates the
returns and never names a slot.

## Known risks

- ~~**SavedVariables are written but never loaded back** on the beta — Blizzard-side.~~
  **Reported fixed, 2026-09-30** (Alex, from Blizzard's notes). Not tested in game yet, so
  **S1** tests it with a `/reload` and a full restart. `Store/` is still the single place that
  names `LegacyNextDB`, so if the fix does not hold, the workaround is still a one-file
  change. Original entry: v1's roster
  depends on a workaround. Blizzard's own Challenge Tracker uses
  `SavedVariablesPerCharacter`, so if its unviewed dots survive a relog the bug is narrower
  than it looks. Cheap thing to watch. Added 2026-09-30: that tracker, and Legacy Forever,
  both set `## LoadSavedVariablesFirst: 1`, and ours does not. S1's step 5 tries it if the
  plain load fails.
- ~~**The packager tags unknown interface numbers as retail**, and wow-build-tools won't bump
  16001.~~ Both fixed upstream on 2026-09-17 and verified by dry run 2026-09-19 —
  `docs/distribution.md`. ~~What remains is the CurseForge version type, unverified.~~
  Answered 2026-09-30: another addon's packager uploads land under CurseForge's `1.60.1`
  version. Our own first upload is the remaining check.
- ~~**`.pkgmeta`'s `move-folders`** has never been run against the real packager.~~ Run
  2026-09-19; TOC at the zip root.
- ~~**The v0 frame has never been drawn.**~~ Drawn 2026-09-19, U1's uidump. Kept for the record: Every template it uses is cited at the pin and
  feature-detected with a fallback, and the render path is exercised through a widget double,
  but a widget double cannot tell a frame from a blank. U1 is the first look.
- **IDs churn during beta.** Nothing in `LegacyNext/` may hardcode an achievement, category or
  criteria ID. The ones recorded in docs are shape, not contract.
