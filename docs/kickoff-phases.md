# LegacyNext: Claude Code bootstrap

> **Historical. Do not treat any of this as current.** This is the document the project was
> started from on 2026-09-17, kept for provenance — it explains why the codebase is shaped the
> way it is. It is not maintained and it has already been overtaken in places: Part 1's brief
> became `CLAUDE.md`, Part 3's Q1–Q12 are all answered in `docs/legacy-internals.md`, and the
> Phase 3 and 4 prompts predate decisions that contradict them.
>
> Live documents, in the order to read them:
>
> | | |
> |---|---|
> | `CLAUDE.md` | Durable client facts, constraints, architecture |
> | `docs/status.md` | Where the project is, what is decided, what blocks what |
> | `docs/ingame-commands.md` | The queue of work that needs the live client |
> | `docs/legacy-internals.md` | Research findings with citations |
> | `docs/distribution.md` | Packaging problems awaiting release |

Working name `LegacyNext`; rename freely. This file has three parts:

1. **Project brief.** Paste it into Claude Code as the first message; it becomes the basis for `CLAUDE.md`.
2. **Phase prompts.** Paste one per session and stop at each checkpoint.
3. **Open research.** What we don't know yet, who resolves it (Claude Code reading source vs. you in-game), and exactly how.

Rule for everything below: facts marked **[verified]** come from Blizzard's UI source (Gethe/wow-ui-source `forever` branch, build 1.60.1.69913) or confirmed community reports. Everything else is **[unverified]** and must not be hardcoded until resolved.

---

## Part 1: Project brief (paste first)

```
We're building a WoW: Forever addon called LegacyNext. Forever is Blizzard's Classic+ game
(beta live since Sept 17 2026, launch Nov 4 2026). Read this whole brief, then create
CLAUDE.md from it, then wait for phase instructions.

## What Legacy is
Forever's account-wide progression system. Legacy Challenges (achievement-like) award Legacy
Points to the account. Each character spends those points independently in three Legacy Trees
(publicly named Professions, Adventure, Resourcefulness). Launch numbers from Blizzard's
BlizzCon deep dive: 65 points earnable, 16 spendable per character. Points past the cap feed a
cosmetic Legacy Reward Track. Hardcore has its own separate Legacy challenges/perks and
launches later; out of scope.

## What we're building
v0 "Next Up" (single character, no saved data needed):
- List incomplete Legacy challenges sorted by closeness to completion
- Per challenge: name, category, points awarded, criteria remaining (e.g. "3/5 dungeons")
- Category filter
- Reward track readout: current level, points to next reward, next reward name
- Opened via slash command; standalone frame (no hooking Blizzard frames in v0)

v1 "Roster" (needs SavedVariables):
- Per-character snapshot on login/logout/relevant events: class, level, professions + skill,
  Legacy points spent per tree, unspent points
- Roster view: every alt, its tree spend, its unspent points
- Challenge → candidate alt mapping, ONLY for class-leveling and profession challenges at
  first (e.g. "your level 34 Druid is 6 levels from this")

Explicit non-goals: a Legacy build/tree planner (Wowhead and wowforeverbuilds.com already have
web calculators), anything combat-related, Hardcore, cross-account or guild sync, writing to
trait configs (never call C_Traits.ResetTree / purchase / commit APIs).

## Client facts [verified unless noted]
- Interface 16001, build 1.60.1. Ships on the wow_classic product line; beta folder is
  _classic_beta_.
- It is the RETAIL API: WOW_PROJECT_ID reports Mainline, 269 C_* namespaces, most Classic-era
  globals are gone. Blizzard: "shares Mainline WoW's UI architecture, including the vast
  majority of APIs available in 12.1.5".
- Forever's API docs differ from live retail 12.1.0 (26 extra doc files, ~6k line diff).
  Do NOT assume retail behavior; check the forever branch source.
- Midnight addon restrictions (secret values) apply. Irrelevant to our APIs as far as we know,
  but every API read goes through a guard (see architecture).
- BUG: SavedVariables are written but never loaded back. Blizzard-side, confirmed by other
  addon authors. Workarounds exist (Thunderz96/forever-addon-kit "sv_bridge";
  Wicksmods/WickCore Profiles). v1 depends on this.
- ReloadUI() is protected (users type /reload). Client stops surfacing Lua errors after 100.
- Version-check trap: many addons test interface >= 100000 for "modern client". Never gate on
  the interface number; feature-detect.

## Legacy API surface [verified: used by Blizzard_LegacySystem / Blizzard_LegacyChallengeTracker]
Constants (Blizzard_APIDocumentationGenerated/LegacyConstantsDocumentation.lua):
  LEGACY_REWARD_TRACK_FACTION_ID          = 2802
  LEGACY_POINTS_TRAIT_CURRENCY_ID         = 4225
  LEGACY_TREE_PROFESSIONS_ID              = 1187
  LEGACY_TREE_ADVENTURE_ID                = 1188
  LEGACY_TREE_PROGRESSION_ID              = 1189   -- public name presumably "Resourcefulness" [unverified]
  LEGACY_TREE_ADVENTURE_TALENTED_NODE_ID  = 110298 -- purpose unknown
Read these via the global constant table at runtime if exposed; literals only as fallback.

Challenges = achievements:
  GetAchievementInfo, GetAchievementNumCriteria, GetAchievementCriteriaInfo,
  GetAchievementCategory, GetCategoryNumAchievements, GetNumFilteredAchievements,
  GetFilteredAchievementID, C_AchievementInfo.IsValidAchievement
  Events: ACHIEVEMENT_EARNED, CRITERIA_UPDATE, ACHIEVEMENT_SEARCH_UPDATED
Trees/points = trait system:
  C_Traits.GetConfigIDByTreeID, C_Traits.GetTreeCurrencyInfo,
  C_Traits.GetTraitCurrencyForAchievement (challenge -> points),
  C_Traits.GetMaxAvailableTraitCurrency, C_Traits.ConfigHasStagedChanges
  (READ ONLY. Blizzard also calls C_Traits.ResetTree; we never do.)
Reward track = renown faction:
  C_MajorFactions.GetMajorFactionData, GetCurrentRenownLevel, GetRenownLevels,
  GetRenownRewardsForLevel, IsMajorFactionHiddenFromExpansionPage

Reference source (read-only): Interface/AddOns/Blizzard_LegacySystem/*,
Interface/AddOns/Blizzard_LegacyChallengeTracker/*,
Interface/AddOns/Blizzard_APIDocumentationGenerated/* on the forever branch.

## Architecture
- Api/      thin adapters. The ONLY place WoW globals are called. Every call:
            feature-detect (function exists?), pcall, issecretvalue guard (if issecretvalue
            exists), return plain Lua tables or nil + reason. No UI code here.
- Model/    pure Lua: ranking, reward-track math, roster mapping. No WoW globals at all.
            This is where the tests live.
- UI/       frames. Talks to Model, never to Api directly.
- Store/    SavedVariables access behind an interface, so the SV-bug workaround (or its
            removal) is a one-file change.
- Debug/    /legacynext dump: serializes Api output to a copyable multiline EditBox, so the
            user can paste real client data back as test fixtures (SavedVariables are broken).

## Conventions
- Lua 5.1 semantics. No external libs in v0 (no Ace3, no LibStub) unless I approve.
- luacheck clean; busted tests for Model/ with fixtures in spec/fixtures/.
- Api/ has a stub layer (spec/stubs/) driven by captured fixtures, never invented data.
  If no fixture exists for a shape, write the test as pending, don't guess the shape.
- Feature-detect everything; never branch on interface number or WOW_PROJECT_ID alone.
- Never hardcode achievement IDs, category IDs, or criteria. They will churn during beta.
- Small commits, conventional-commit messages. Never push without asking.
- You cannot run the game. Anything that needs in-game verification: write the exact /run or
  /dump command for me, and stop.
```

---

## Part 2: Phase prompts

### Phase 0: Scaffold

```
Phase 0: scaffold. Do the following, then stop and report.

1. git init. Layout: LegacyNext/ (addon folder: LegacyNext.toc, Api/, Model/, UI/, Store/,
   Debug/), spec/ (busted), spec/fixtures/, spec/stubs/, docs/, vendor/ (gitignored).
2. vendor/wow-ui-source: sparse, shallow clone of https://github.com/Gethe/wow-ui-source.git,
   branch `forever`, with only:
     Interface/AddOns/Blizzard_LegacySystem
     Interface/AddOns/Blizzard_LegacyChallengeTracker
     Interface/AddOns/Blizzard_APIDocumentationGenerated
     Interface/AddOns/Blizzard_AchievementUI (if present)
     version.txt
   Record the commit SHA + version.txt in vendor/PINS.md.
3. TOC: "## Interface: 16001", Title, Notes, Version, SavedVariables: LegacyNextDB,
   SavedVariablesPerCharacter: LegacyNextCharDB, file list. Add IconTexture later.
4. Toolchain: Lua 5.1, luarocks, busted, luacheck. Install what's missing, tell me what you
   installed. .luacheckrc with WoW globals we actually use (read from the brief), std lua51.
5. .github/workflows/ci.yml: luacheck + busted on push/PR.
6. .pkgmeta for BigWigsMods/packager. Note in docs/distribution.md that the packager is
   reported to tag unknown interface numbers as retail, and that wow-build-tools won't bump
   16001. Don't solve it; just note it.
7. Hello-world: addon loads, prints version on PLAYER_LOGIN, /legacynext prints "ok".

Checkpoint: tree of the repo, pinned SHA and build, tool versions, CI file.
```

### Phase 1: Read Blizzard's implementation

```
Phase 1: read-only research in vendor/. No addon code yet. Produce docs/legacy-internals.md
answering each question below with file:line citations. If the source doesn't answer it,
say "UNRESOLVED: needs in-game check" and write the exact /dump or /run command I should
run. Do not guess.

Challenges
 Q1. How does Blizzard enumerate Legacy challenges? Category IDs? Filter calls
     (GetNumFilteredAchievements etc.) and what sets the filter? Is it hardcoded or
     derived from a constant/API?
 Q2. How are challenge categories (the six-ish: classes, professions, adventure/exploration,
     PvP, reputation, dungeons/raids) represented: achievement categories, or something else?
 Q3. How does the UI get points-per-challenge? (C_Traits.GetTraitCurrencyForAchievement:
     arguments, return shape.)
 Q4. What does the detail pane show for criteria? Which GetAchievementCriteriaInfo return
     values does it use (quantity, reqQuantity, criteriaType, assetID, completed)?
 Q5. Does anything indicate account-wide vs per-character completion (e.g. wasEarnedByMe,
     isAccountWide flags from GetAchievementInfo)?
 Q6. What does Blizzard_LegacyChallengeTracker do? Does it already sort/track by progress?
     What tracking API does it use?

Trees / points
 Q7. How does the UI compute spent / unspent / cap per character? Which currency info
     fields (GetTreeCurrencyInfo) carry spent vs max? Is the 16 cap per character across all
     three trees, or per tree?
 Q8. Tree ID 1189 is LEGACY_TREE_PROGRESSION_ID. Find where its display name comes from.
     Does it map to the public "Resourcefulness" tree?
 Q9. What is LEGACY_TREE_ADVENTURE_TALENTED_NODE_ID (110298) used for?

Reward track
 Q10. How does the reward track UI compute current level, progress to next, and the reward
      list? Which renown fields does it use?

Loading
 Q11. Is Blizzard_LegacySystem load-on-demand? What triggers it (Bootstrap file)? Do the
      APIs we need work without it loaded, or must we call C_AddOns.LoadAddOn?
 Q12. Events the Legacy UI registers for, beyond ACHIEVEMENT_EARNED / CRITERIA_UPDATE /
      ACHIEVEMENT_SEARCH_UPDATED (e.g. TRAIT_* events, MAJOR_FACTION_* events).

Also: list every global/C_ API the Legacy addons call that is NOT in the brief, grouped by
file. That's our full dependency surface.

Checkpoint: summary table Q1-Q12 (answered / unresolved), plus the list of in-game commands
for me to run.
```

### Phase 2: Api layer + debug dump

```
Phase 2: implement LegacyNext/Api/ and LegacyNext/Debug/ only, based on
docs/legacy-internals.md. Answers marked UNRESOLVED stay behind a feature flag or return
nil + reason; don't build on guesses.

Api surface (plain tables out, nil + reason on failure):
- Api.GetChallenges() -> list of { id, name, categoryId, categoryName, points, completed,
  criteria = { {text, have, need, completed, criteriaType, assetId}... } }
- Api.GetRewardTrack() -> { level, maxLevel, earned, nextThreshold, nextRewards = {...} }
- Api.GetTreeSpend() -> { [treeId] = { spent, ... }, unspent, cap }
- Api.GetCharacterInfo() -> { class, level, professions = {{name, skill, max}} }
  (professions API: identify from forever-branch source, retail-style, feature-detected)

Every Api function: feature-detect, pcall, secret guard; tally failures per API in memory.

Debug: /legacynext dump opens a scrollable, select-all EditBox with a Lua-literal
serialization of every Api function's output plus the failure tally, build string, and
interface number. This is how I'll hand you fixtures.

Also /legacynext probe: one line per API — ok / nil / missing / error / secret.

Checkpoint: file list, how to use dump/probe, and the exact in-game test steps for me.
```

**You, between Phase 2 and 3:** load it in beta, run `/legacynext probe` and `/legacynext dump` on at least two characters (different classes, one with professions), paste the dumps into `spec/fixtures/`.

### Phase 3: Model + v0 UI

```
Phase 3: build Model/ and the v0 UI.

Model (pure Lua, fully tested against spec/fixtures/*):
- rankChallenges(challenges, opts): incomplete only; score = weighted criteria completion;
  ties -> fewer absolute steps remaining, then points desc. Keep the scoring function
  isolated and documented; I'll tune it.
- rewardTrackSummary(track): level, pct to next, points to next, next reward names.
- Tests: golden outputs per fixture; a test that fails if Model/ references any WoW global.

UI (v0):
- Standalone movable frame, /legacynext to toggle. Remember position only in memory for now
  (Store/ is v1).
- Header: reward track summary. Body: ranked list (name, category, points, "have/need"
  per remaining criterion). Category filter dropdown.
- Refresh on ACHIEVEMENT_EARNED / CRITERIA_UPDATE (throttled), and on show.
- Use Blizzard's native tracking for "track this challenge" ONLY if Phase 1 found the API;
  otherwise omit.
- No combat lockdown concerns expected, but don't rebuild the frame in combat; queue until
  PLAYER_REGEN_ENABLED.

Checkpoint: screenshot-free description of the UI, test results, in-game test steps.
```

### Phase 4: Store + v1 Roster (blocked until SavedVariables work)

```
Phase 4: v1 roster. Precondition: SavedVariables load in the current beta build, OR I've
picked a workaround (forever-addon-kit sv_bridge vs WickCore Profiles). If neither, stop and
say so.

- Store/: versioned schema, per-account roster keyed by a stable character key. Decide
  whether the realmless Forever setup changes the key (UNRESOLVED; ask me). Migrations from
  day one.
- Snapshot on PLAYER_LOGIN, PLAYER_LOGOUT, level-up, skill change, trait config change,
  ACHIEVEMENT_EARNED.
- Roster view: per character: class, level, per-tree spend, unspent.
- Candidate-alt mapping for class-leveling and profession challenges only, driven by
  criteriaType/assetId from fixtures, NOT by parsing challenge names. If the fixtures don't
  expose a usable criteria type for these, stop and report.
- Tests with multi-character fixtures.

Checkpoint: schema doc, mapping coverage (which challenges map, which don't, why).
```

---

## Part 3: Open research

### Resolved by Claude Code reading the vendored source (Phase 1)

| # | Question | Blocks |
|---|---|---|
| Q1–Q2 | How challenges and their categories are enumerated | v0 |
| Q3 | Points per challenge via `C_Traits.GetTraitCurrencyForAchievement` | v0 |
| Q4 | Criteria fields available | v0 ranking, v1 mapping |
| Q5 | Account-wide vs per-character completion | v1 |
| Q6 | What Blizzard's tracker already does (overlap check) | v0 scope |
| Q7 | Spend/cap semantics: 16 total vs per tree | v1 |
| Q8–Q9 | Tree 1189 naming; node 110298 | cosmetic |
| Q10 | Reward track math | v0 |
| Q11–Q12 | Load-on-demand, full event list | v0 |

### Resolved only in-game (you)

1. **Your judgment:** open Blizzard's Legacy UI for an evening. Does it already sort by progress or surface near-complete challenges? If yes, v0 shrinks and v1 becomes the product. Do this before Phase 3.
2. **API behavior:** `/legacynext probe` on 2+ characters. Any `secret`, `missing`, or `error` results change the plan.
3. **Fixtures:** `/legacynext dump` from characters at different stages. Model work doesn't start without them.
4. **Whether completion is account-wide:** compare the same challenge's criteria on two characters.
5. **SavedVariables status:** check each new beta build (Gethe's `forever` branch commits track builds). This gates v1.

### External / distribution (not blocking until release)

1. **CurseForge Forever category:** an addon search URL showed a Forever version filter, but whether authors can publish to it yet is unverified.
2. **Packager mapping for 16001:** reported to mis-tag unknown interfaces as retail. Check BigWigsMods/packager issues before first release.
3. **Competition recheck** just before launch: CurseForge, GitHub, and any DataStore or Altoholic port. As of Sept 18, no in-game Legacy tracker was found; coverage was limited.

### Deliberately not researched (stay out of the rabbit hole)

- Legacy perk contents or balance.
- Hardcore Legacy.
- Talent-string import/export for Legacy trees.
- Guild or party sync.
- Any combat-restricted API.
