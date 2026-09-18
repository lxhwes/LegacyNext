# Status

Last updated 2026-09-18.

**Where we are: Phase 1 complete. Phase 2 not started.**

Everything v0 needs from the client is verified except the criteria fixtures, which are
blocked on running two slash commands in game.

## Phases

| Phase | What | State |
|---|---|---|
| 0 | Scaffold — repo layout, TOC, hello-world addon, Lua 5.1 toolchain, CI, packaging notes, vendor pin | **Done** — `b66486e` |
| 1 | Read-only research into Blizzard's Legacy system, answering Q1–Q12 | **Done** — `0ad6e6c` plus in-game verification |
| — | Project skills: `forever-api-lookup`, `beta-build-bump` | **Done** — `d9bb4a6`, `c9db19c` |
| 2 | Not yet defined. See "What Phase 2 probably starts with" below. | Not started |

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

**Section B, runs on any character, blocks Phase 2:**

- B1/B2 — one challenge with `criteriaFlags` bit 1 set and one without. **This is the
  blocker.** Until these land, the ranking tests stay `pending` and `spec/fixtures/` is empty.
- B3 — confirm the 14-return `GetAchievementInfo` order on Forever
- B4 — do the per-challenge points sum to 65 across all 111 challenges
- B5 — optional sweep for every counted challenge at once
- B6 — rewards at thresholds 40 and 55, to see whether the missing `name` field is a pattern

**Section C, needs a played character, does not block Phase 2:**

- C1 — confirm the shared pool with points spent in two trees, and what `maxQuantity` really is
- C2 — which of `TRAIT_CONFIG_UPDATED`, `TRAIT_TREE_CHANGED`,
  `MAJOR_FACTION_RENOWN_LEVEL_CHANGED` actually fire
- C3 — a criterion sitting part-done, for a real mid-progress fixture
- C4 — `wasEarnedByMe` true, and whether completed entries sort before incomplete ones

## What Phase 2 probably starts with

Not agreed yet — Alex sets the phase. Two candidates:

1. **`Debug/` first.** The `/legacynext dump` copyable EditBox. SavedVariables are broken, so
   this is the only fixture pipeline we have, and every future in-game question gets cheaper
   once it exists. Inverts the usual order of tool-before-feature, but we build it either way.
2. **`Api/` + `Model/` for the challenge list.** Everything it needs is verified. Would have to
   start against hand-typed fixtures from section B rather than dumped ones.

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
