# Status

Last updated 2026-09-19.

**Where we are: Phase 2 is done and verified in the client. Phase 3 is ready to start.**

`Api/` and `Debug/` work on two characters. Enumeration confirmed three times by separate code
paths — 111 challenges, 65 points. **No secrets on our surface**, and that is a tested negative
rather than an assumption: `issecretvalue` exists and the guard is active.

Five fixtures in `spec/fixtures/`, covering the challenge shape, all eight `criteriaType`
values, the full reward track, tree spend and character state. `Model/` and `UI/` are untouched
placeholders.

Open in the queue: **D4** (professions), **C1–C4** (need a played character), **D8** (Explore
subzone criteria, low value). None block Phase 3. See `docs/ingame-commands.md`.

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
| 3a | `Model/` — ranking, reward-track math, category list. Pure Lua, fully testable here. | **Ready** |
| 3b | `UI/` — the v0 frame. Needs in-game iteration; see the UI plan below. | Ready, after 3a |
| 3c | Release prep — LICENSE, icon, packager dry-run, version scheme, listing. **Was missing from the plan entirely.** | Not started |
| 4 | v1 roster. Blocked on SavedVariables, **and its stated approach is known broken** — see below. | Blocked |

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

### Design decisions still unmade

| | Decision | Notes |
|---|---|---|
| Layout | Frame size, header/list/filter arrangement | Alex's call — see the options raised 2026-09-19 |
| Row | What a challenge row shows, and in what order | Name, category, points, progress. Long descriptions overflow |
| Progress | How three criteria shapes render in one row | Bar `0/150`, checklist `2/6`, and the 34 with nothing to show |
| Scroll | `WowScrollBoxList` vs `UIPanelScrollFrameTemplate` | Blizzard's Legacy UI uses ScrollBox (`Blizzard_LegacyChallengeCategoryList.xml`), but only the older template is **proven in-game** by the dump window. Feature-detect, fall back |
| Filter | Dropdown, tabs, or a row of buttons | Six real groups plus "all" |
| States | Empty vs error, kept distinct | `Api` returns `nil` + reason precisely so the UI can say "nothing left to earn" and "could not read your challenges" differently. Wasted if the frame flattens them |
| Refresh | Throttle policy | `CRITERIA_UPDATE` fires in bursts. Queue past `PLAYER_REGEN_ENABLED`; never rebuild in combat |
| Escape | `UISpecialFrames` | One line, makes the frame feel native |

### Performance, unverified

One `GetChallenges` sweep is roughly **900 client calls** — 111 `GetAchievementInfo`, 111
`GetAchievementNumCriteria`, 674 `GetAchievementCriteriaInfo`, plus points lookups (counted
from the D7 dump's own tally). Acceptable on show. Unknown as a login hitch, and unknown under
a `CRITERIA_UPDATE` burst. Needs a queue row once the frame exists.

## Phase 3c — release prep, previously absent

Checked 2026-09-19; these do not exist yet:

- [ ] **`LICENSE` — there is no license file at all.** CurseForge requires one to publish, so
      this blocks release outright. Alex's call which.
- [ ] **Icon.** `## IconTexture` is commented out in `LegacyNext.toc` and `LegacyNext/Media/`
      does not exist.
- [ ] **`CHANGELOG.md`** — none.
- [ ] **Version scheme.** Still `0.0.1`. Decide what ships.
- [ ] **README as a listing.** `README.md` exists but is written for the repo, not for a user
      browsing CurseForge.
- [ ] Packager dry-run, `.pkgmeta` `move-folders`, CurseForge Forever category — all three in
      "What must be true to ship v0" and all three still unreproduced.

None of this needs Phase 3a or 3b finished. The packager dry-run especially is cheap now and
expensive on release day.

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

What blocks what, as of 2026-09-19:

| Blocked | On |
|---|---|
| `Api.GetCharacterInfo`'s profession slots (v1, not v0) | D4 |
| Real mid-progress ranking tests — derived values carry Phase 3a until then | C3 |
| Whether `UI/` refreshes on events or stays read-on-show | C2 |
| Whether a ~900-call sweep is a visible hitch | needs the frame first |

D5, D6 and D7 closed 2026-09-19.

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

## Phase 3 readiness — checked 2026-09-19

Green. `Api` is verified against the live client on two characters, all four functions
returning usable data. `Model/` and `UI/` are untouched 5-line placeholders, so nothing is
half-built. Frame creation is proven — `/lgn dump`'s window is a real frame that works in the
client.

Scoring inputs, all settled and not to be relitigated without new evidence:

1. Zero-point challenges excluded (Ranking decision 2)
2. `criteriaExpected == 0` sorts last (Ranking decision 1)
3. No meta-chain recursion (Ranking decision 3, superseded to "none")
4. Use `need`/`have` whenever `need > 1`, not only when the progress-bar bit is set (D7)
5. Mid-progress test values may be derived from captured shapes, labelled — see
   `spec/fixtures/README.md`

**The known weakness, stated so it is not discovered later:** every captured point-bearing
criterion reads `have = 0`. Ordering by fewest absolute steps is testable from real data
(0/150 Alchemy against 0/300; 0/6 dungeons against 0/17), but partial-progress ordering — the
case the feature exists for — runs on derived values until **C3** lands.

Not blocking Phase 3: **C2** (events) — the v0 UI refreshes on `ACHIEVEMENT_EARNED`,
`CRITERIA_UPDATE` and on show, which is what Blizzard's own Legacy UI does. **D4**
(professions) — v0 does not read professions; that is v1's roster.

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
