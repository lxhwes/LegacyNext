# Status

Last updated 2026-09-19.

**Where we are: Phase 2 ran in the client. D1–D3 pass, one guard bug found and fixed.**

`/lgn probe` and `/lgn dump summary` both work. The summary reproduces the section B sweep
exactly — 111 challenges, 65 points, 18 progress-bar, 59 checklist, 34 no-criteria — from a
completely different code path, so enumeration is confirmed twice over.

**No secrets on our surface.** The one `secret` in the tally was our own guard misfiring; see
below. Midnight's restrictions do not reach the Legacy APIs on build 1.60.1 (69913).

Every probe line is accounted for. The `nil` is `GetProfessions` on a level 1 Shaman who knows
none — the call succeeded and tallied `ok`, and only its first *value* was nil, which is the
absence-versus-failure distinction working in the field. The `skipped` is `GetProfessionInfo`,
correctly declining to invent a failure for a probe it had no index for.

`trees` and `challenges 1` landed as fixtures the same day. Still open: **D6** (`rewards`, dead
until the mixin fix ships), **D4** (professions — this character knew none) and **D7**
(challenge pages 2–6). See the queue in `docs/ingame-commands.md`.

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

- [ ] `Model/` ranking, tested against `spec/fixtures/`
- [ ] The v0 frame: reward track header, ranked list, category filter
- [ ] Reward track header actually renders — needs **D6**, dead until the mixin fix ships

**Blocking, release mechanics** (all unsolved, all in `docs/distribution.md`):

- [ ] Packager dry-run against a tag — it is reported to mis-tag interface 16001 as retail,
      and Forever ships on `wow_classic`. Wrong flavor means a broken upload
- [ ] `.pkgmeta` `move-folders` has never been run; a doubled `LegacyNext/LegacyNext` path in
      the zip is the symptom
- [ ] Confirm authors can publish to CurseForge's Forever category at all — a version filter
      was seen in search, but publishing was never verified

**Should be true, not blocking:**

- [ ] **D7** — challenge pages 2–6, so ranking is tested against 111 rather than 20
- [ ] **C2** — whether refresh can be event-driven, or stays read-on-show
- [ ] Competition recheck immediately before release

The release mechanics are the ones to be nervous about: every item is a reported problem nobody
has reproduced, and they all land at once, on the day, when there is no time to fix them.
Running the packager dry-run early is cheap and does not need Phase 3 finished.

## Phases

| Phase | What | State |
|---|---|---|
| 0 | Scaffold — repo layout, TOC, hello-world addon, Lua 5.1 toolchain, CI, packaging notes, vendor pin | **Done** — `b66486e` |
| 1 | Read-only research into Blizzard's Legacy system, answering Q1–Q12 | **Done** — `0ad6e6c` plus in-game verification |
| — | Project skills: `forever-api-lookup`, `beta-build-bump` | **Done** — `d9bb4a6`, `c9db19c` |
| — | Project skills: `ingame-script`, `api-guard`, `fixture-intake`, `safe-commit` — the authoring loop | **Done** |
| 2 | `Api/` guard layer and `Debug/` dump+probe. No `Model/`, no `UI/`. | **Done** — ran in game 2026-09-19, one guard bug found and fixed |
| 3 | `Model/` ranking and the v0 UI. Design questions settled 2026-09-19; fixtures landed, so only the reward header is blocked (**D6**). | Not started |
| 4 | v1 roster. Blocked on SavedVariables, **and its stated approach is known broken** — see below. | Blocked |

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
**Alex's call, not taken yet.** It does not block Phase 3.

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
  Separately, `criteriaType` is a third axis and is open-ended: 7, 8 and 43 seen so far, so
  never switch exhaustively on it.
- **Generated API docs are a floor, not a contract.** The live reward struct carries five
  fields that appear in no doc file. Feature-detect fields.

## Outstanding — needs the game

**The queue table at the top of `docs/ingame-commands.md` is the list.** It is not repeated
here — it used to be, and the two copies drifted within a day. Cite the ID when something is
blocked on a row.

What blocks what, as of 2026-09-19:

| Blocked | On |
|---|---|
| The reward track header, a v0 feature currently dead | D6 |
| Confirming the mixin fix landed | D5 |
| `Api.GetCharacterInfo`'s profession slots | D4 |
| Mid-progress ranking tests (every captured criterion reads 0) | C3 |
| Whether `UI/` can refresh on events or must re-read on show | C2 |

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

- **SavedVariables are written but never loaded back** on the beta — Blizzard-side. v1's roster
  depends on a workaround. Blizzard's own Challenge Tracker uses
  `SavedVariablesPerCharacter`, so if its unviewed dots survive a relog the bug is narrower
  than it looks. Cheap thing to watch.
- **The packager tags unknown interface numbers as retail**, and wow-build-tools won't bump
  16001. Not solved, not in scope yet — `docs/distribution.md`.
- **`.pkgmeta`'s `move-folders`** has never been run against the real packager.
- **IDs churn during beta.** Nothing in `LegacyNext/` may hardcode an achievement, category or
  criteria ID. The ones recorded in docs are shape, not contract.
