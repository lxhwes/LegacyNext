# Status

Last updated 2026-09-18.

**Where we are: Phase 2 written, not yet run in game.**

`Api/` and `Debug/` are implemented and green on lint and tests, but no line of either has
executed inside the client. Section D in `docs/ingame-commands.md` is the first run.

## Phases

| Phase | What | State |
|---|---|---|
| 0 | Scaffold — repo layout, TOC, hello-world addon, Lua 5.1 toolchain, CI, packaging notes, vendor pin | **Done** — `b66486e` |
| 1 | Read-only research into Blizzard's Legacy system, answering Q1–Q12 | **Done** — `0ad6e6c` plus in-game verification |
| — | Project skills: `forever-api-lookup`, `beta-build-bump` | **Done** — `d9bb4a6`, `c9db19c` |
| — | Project skills: `ingame-script`, `api-guard`, `fixture-intake`, `safe-commit` — the authoring loop | **Done** |
| 2 | `Api/` guard layer and `Debug/` dump+probe. No `Model/`, no `UI/`. | **Written**, unrun in game — section D |
| 3 | Not yet defined. `Model/` ranking is the obvious candidate, blocked on the three design questions below. | Not started |

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
- **Ranking handles two criteria shapes.** Progress-bar criteria (`criteriaFlags` bit 1) give a
  fraction; the rest are boolean checklists where remaining is a count.
- **Generated API docs are a floor, not a contract.** The live reward struct carries five
  fields that appear in no doc file. Feature-detect fields.

## Outstanding — needs the game

Commands and what each answers are in `docs/ingame-commands.md`.

**Section B — done 2026-09-18.** Full sweep captured: all 29 categories, all 111 challenges
with criteria counts and point values, both criteria shapes, a full `GetAchievementInfo` row,
and all four reward entries. Written up in `docs/legacy-internals.md`. Phase 2 is unblocked.

**Section D — first run of the addon. Runs on any character, blocks everything.** Install,
`/lgn probe`, `/lgn dump summary`. The probe is the one that matters: it says per API whether
we get `ok`, `nil`, `missing`, `error` or `secret`, and a single `secret` would be the most
consequential finding of the phase.

**Section C, needs a played character. Mostly absorbed by `/lgn dump` once D passes:**

- C1 — confirm the shared pool with points spent in two trees, and what `maxQuantity` really is
- C2 — which of `TRAIT_CONFIG_UPDATED`, `TRAIT_TREE_CHANGED`,
  `MAJOR_FACTION_RENOWN_LEVEL_CHANGED` actually fire
- C3 — a criterion sitting part-done, for a real mid-progress fixture
- C4 — `wasEarnedByMe` true, and whether completed entries sort before incomplete ones

## Open design questions

Raised by the section B sweep. Both need a decision before the ranking model is written, and
both are Alex's call rather than mine.

1. **How to rank the 34 challenges with no criteria.** A third of the list exposes no progress
   at all — every class challenge, all five PvP Ranks, two others. Treating them as 0% parks
   them at the top of a "closest to done" sort permanently. Options: a separate section, sort
   them last, or hide them behind a toggle.
2. **Whether the 46 zero-point `Explore *` achievements belong in Next Up.** They are the
   criteria substrate for the single `Explorer` challenge rather than rewards in themselves.
   Blizzard's UI shows them; ours is about points.
3. **How deep to follow meta chains.** `Explorer` reads "0/1 criteria" while actually being
   hundreds of subzones deep through `criteriaType` 8 `assetID` links. Recursing gives honest
   closeness and costs a lot of API calls; not recursing means one entry in the list is a lie.

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
