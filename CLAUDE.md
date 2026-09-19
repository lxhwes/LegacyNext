# LegacyNext

WoW: Forever addon. Forever is Blizzard's Classic+ line — beta live 2026-09-17, launch
2026-11-04.

## Domain

Legacy is Forever's account-wide progression system. Legacy Challenges (achievement-like)
award Legacy Points to the **account**. Each character spends those points **independently**
across three Legacy Trees: Professions, Adventure, Resourcefulness (public names). Launch
numbers from Blizzard's BlizzCon deep dive: 65 points earnable, 16 spendable per character.
Points past the cap feed a cosmetic Legacy Reward Track.

Hardcore has separate Legacy challenges/perks and launches later. Out of scope.

## Scope

**v0 "Next Up"** — single character, no saved data:
- Incomplete Legacy challenges sorted by closeness to completion
- Per challenge: name, category, points awarded, criteria remaining ("3/5 dungeons")
- Category filter
- Reward track readout: current level, points to next reward, next reward name
- Slash-command-opened standalone frame. No hooking Blizzard frames in v0.

**v1 "Roster"** — needs SavedVariables:
- Per-character snapshot on login/logout/relevant events: class, level, professions + skill,
  points spent per tree, unspent points
- Roster view: every alt, tree spend, unspent points
- Challenge → candidate alt mapping, **only** class-leveling and profession challenges at
  first ("your level 34 Druid is 6 levels from this")

**Non-goals** (do not build, do not propose): Legacy build/tree planner (Wowhead and
wowforeverbuilds.com already have web calculators), anything combat-related, Hardcore,
cross-account or guild sync, writing to trait configs.

## Hard constraints

- **Never call** `C_Traits.ResetTree`, any purchase API, or any commit API. Read-only trait
  access, always. Blizzard's own code calls these; we don't.
- **Never gate on the interface number** or `WOW_PROJECT_ID` alone. Many addons test
  `interface >= 100000` for "modern client" and break here. Feature-detect everything.
- **Never hardcode** achievement IDs, category IDs, or criteria. They will churn during beta.
- **Never invent API response shapes.** If no captured fixture exists for a shape, write the
  test as `pending`.
- I cannot run the game. Anything needing in-game verification becomes a queue row, and a
  script if one is needed, in `docs/ingame-commands.md` — see In-game workflow — and I stop
  there.

## Client facts [verified]

- Interface 16001, build 1.60.1. Ships on the `wow_classic` product line; beta folder is
  `_classic_beta_`.
- **It is the retail API.** `WOW_PROJECT_ID` reports Mainline, 269 `C_*` namespaces, most
  Classic-era globals are gone. Blizzard: "shares Mainline WoW's UI architecture, including
  the vast majority of APIs available in 12.1.5".
- Forever's API docs differ from live retail 12.1.0 — 26 extra doc files, ~6k line diff.
  **Do not assume retail behavior**; check the forever branch source.
- Midnight addon restrictions (secret values) apply. **`issecretvalue` exists on this client
  and the guard is active** [verified in game 2026-09-19 via `/lgn probe`], and no API on our
  surface returned a secret. That is a tested negative, not an assumption — but it is a
  per-build one, so re-run the probe after any bump.
- **BUG: SavedVariables are written but never loaded back.** Blizzard-side, confirmed by
  other addon authors. v1 depends on a workaround — see Thunderz96/forever-addon-kit
  `sv_bridge`, Wicksmods/WickCore Profiles.
- `ReloadUI()` is protected; users type `/reload`. Client stops surfacing Lua errors after 100.

## Legacy API surface [verified: used by Blizzard_LegacySystem / Blizzard_LegacyChallengeTracker]

Constants — read at runtime via `Constants.LegacyConsts.<NAME>` [verified in game 2026-09-18:
all six values present on a fresh login while
`C_AddOns.IsAddOnLoaded("Blizzard_LegacySystem")` returned `false, false`, so they are client
data, not addon data]. These literals are a fallback only.

| Constant | Value |
|---|---|
| `LEGACY_REWARD_TRACK_FACTION_ID` | 2802 |
| `LEGACY_POINTS_TRAIT_CURRENCY_ID` | 4225 |
| `LEGACY_TREE_PROFESSIONS_ID` | 1187 |
| `LEGACY_TREE_ADVENTURE_ID` | 1188 |
| `LEGACY_TREE_PROGRESSION_ID` | 1189 — display name "Resourcefulness" [verified in game 2026-09-18] |
| `LEGACY_TREE_ADVENTURE_TALENTED_NODE_ID` | 110298 — lowers the class-talent unlock level; out of scope |

Runtime facts [verified in game 2026-09-18, build 1.60.1, fresh character]:

- `GetCategoryList()` returns **only Legacy categories** — 29 of them, exactly two levels
  deep, six real top-level groups plus a "Do Not Display" bucket holding zero achievements.
  111 challenges total, confirmed twice. Full tree in `docs/legacy-internals.md`.
- The filter API (`GetNumFilteredAchievements` / `GetFilteredAchievementID`) reads 0 at login
  and 111 after any `SetAchievementSearchString("")`. It is global state shared with
  Blizzard's Achievement UI — we never call it, and never read it as a source of truth.
- All three trees share **one** `configID` — 2938022 on a fresh character
  [verified in game 2026-09-19]. The 16-point cap is a single pool spent across all three, not
  16 per tree.
- **Class challenges carry no machine-readable level threshold** [verified in game 2026-09-19].
  `Novice / Experienced / Master Druid` (61502–61504) are levels 25/45/60, but they have
  `criteriaExpected == 0` and the number appears only in `description` prose. v1's
  candidate-alt mapping cannot key off criteria for these — see `docs/status.md`.
- `C_Traits.GetMaxAvailableTraitCurrency(4225, false)` = 65 earnable account-wide;
  `(4225, true)` = 16 spendable per character. The cap does **not** come from
  `TreeCurrencyInfo.maxQuantity`, which read 0 at zero points.
- `ACHIEVEMENT_FLAGS_ACCOUNT` = 131072 and `EVALUATION_TREE_FLAG_PROGRESS_BAR` = 1 are both
  **live client globals** [verified in game 2026-09-19], despite appearing nowhere in the
  pinned source. Keep reading them at runtime; the literals in `Api` stay a fallback.
- All six `Constants.LegacyConsts` values read `(runtime)`, not `(fallback)`
  [verified in game 2026-09-19]. The literals in the table above are not carrying us.
- Reward track faction 2802 is named "Legacy Track", `maxLevel` 90, `isUnlocked` true.
  `GetRenownLevels` returns a **sparse** list of the four reward thresholds (15, 25, 40, 55),
  not one entry per level. `renownLevel` is the account's earned point count.
- Reward entries carry a usable display name — `reward.name or reward.toastDescription`, since
  `name` is missing on some entries — plus `icon` and `isCollected`. No item lookup needed.
  `isCollected` read **true** for an unreached threshold, so it is account collection state,
  not "this reward level is claimed". Never render it as progress.
- **Every point-bearing challenge awards exactly 1 point.** 65 challenges × 1 = 65; the other
  46 (all `Explore *`) award 0. Do not hardcode 1 — but no point-weighting is needed today.
- **Three criteria shapes, not two:** 18 progress-bar, 59 checklist, **34 with no criteria at
  all**. The 34 expose no progress through the API and are binary; ranking must handle that
  as a distinct case rather than treating them as 0%.
- **Three `criteriaType` values seen, not two** [verified in game 2026-09-19]: 7 = skill
  threshold (`assetID` is a skill line, e.g. 2937 Alchemy), 8 = child achievement (`assetID` is
  an achievement ID), **43 = area discovery** (`assetID` is an area ID). Type 43 is the leaf of
  the Explore tree and never appears on a point-bearing challenge. Treat the list as open —
  feature-detect the type, never switch exhaustively on it.
- **The Explore meta chain is three levels deep, not two** [verified in game 2026-09-19]:
  `Explore Azeroth` (62053, 2 criteria) → type 8 → `Explore Eastern Kingdoms` (62353, 23
  criteria) → type 8 → `Explore Alterac Mountains` (760, 15 type-43 criteria). One level of
  recursion improves the number without making it true, so **v0 does not recurse at all** and
  `followMetaChains` stays off — every chain found so far is zero-point, and Next Up excludes
  those.
- `GetAchievementInfo` return order matches retail exactly. The achievement's own `points` is
  **0** on Legacy challenges, which is why Blizzard overrides it. `rewardText` reads
  "Earn 1 Legacy Point." and is usable for display.
- `flags` on point-bearing challenges is `134349824` = bits 10, 17, 27. Bit 17 is
  `ACHIEVEMENT_FLAGS_ACCOUNT`; bits 10 and 27 are unidentified. The 46 zero-point exploration
  achievements have `flags == 0`, so they are per-character.

**The generated API docs are a floor, not a contract.** The live reward struct carries five
fields that appear in no documentation file. Feature-detect fields; never assume a documented
field list is complete.

**A documented struct field can be an object with methods.** `MajorFactionData.factionFontColor`
is a `DBColorExport` whose `color` is declared `Mixin = "ColorMixin"`
(`MajorFactionsDocumentation.lua:281`, `UIColorSharedDocumentation.lua:11`), so the client hands
back functions nested inside a struct of otherwise plain scalars. `Api`'s copy drops such fields
and names them rather than rejecting the struct — verified in game 2026-09-19, where rejecting it
had killed the whole reward track.

Challenges are achievements:
`GetAchievementInfo`, `GetAchievementNumCriteria`, `GetAchievementCriteriaInfo`,
`GetAchievementCategory`, `GetCategoryNumAchievements`, `GetNumFilteredAchievements`,
`GetFilteredAchievementID`, `C_AchievementInfo.IsValidAchievement`.
Events: `ACHIEVEMENT_EARNED`, `CRITERIA_UPDATE`, `ACHIEVEMENT_SEARCH_UPDATED`.

Trees and points are the trait system (read only):
`C_Traits.GetConfigIDByTreeID`, `C_Traits.GetTreeCurrencyInfo`,
`C_Traits.GetTraitCurrencyForAchievement` (challenge → points),
`C_Traits.GetMaxAvailableTraitCurrency`, `C_Traits.ConfigHasStagedChanges`.

Reward track is a renown faction:
`C_MajorFactions.GetMajorFactionData`, `GetCurrentRenownLevel`, `GetRenownLevels`,
`GetRenownRewardsForLevel`, `IsMajorFactionHiddenFromExpansionPage`.

Character state, for the dump and for v1's roster:
`UnitClass`, `UnitLevel`, `UnitName`, `GetRealmName`, `GetProfessions`, `GetProfessionInfo`.
**`GetProfessions` returns seven values on Forever, not six** — verified on the forever branch at
`Blizzard_Professions/Camelot/Blizzard_ProfessionsFrame.lua:16`, which destructures
`prim1, prim2, sec1..sec5`. Mainline's six (`prof1, prof2, arch, fish, cook, firstAid`) mean
different things. Never name the slots; iterate every return.
`GetProfessionInfo(index)` → `name, texture, rank, maxRank, numSpells, spellOffset, skillLine,
rankModifier, specializationIndex, specializationOffset, skillLineName`
(`Blizzard_ProfessionsFrame.lua:55`).

Reference source, read-only, on the forever branch:
`Interface/AddOns/Blizzard_LegacySystem/*`,
`Interface/AddOns/Blizzard_LegacyChallengeTracker/*`,
`Interface/AddOns/Blizzard_APIDocumentationGenerated/*`.

## Architecture

| Dir | Rule |
|---|---|
| `Api/` | The **only** place WoW globals are called. Every call: feature-detect (does the function exist?), `pcall`, `issecretvalue` guard (if `issecretvalue` exists). Returns plain Lua tables, or `nil` + reason. No UI code. |
| `Model/` | Pure Lua: ranking, reward-track math, roster mapping. **No WoW globals at all.** This is where the tests live. |
| `UI/` | Frames. Talks to `Model`, never to `Api` directly. |
| `Store/` | SavedVariables behind an interface, so the SV-bug workaround (or its removal) is a one-file change. |
| `Debug/` | `/legacynext dump`: serializes `Api` output into a copyable multiline EditBox so I can paste real client data back as test fixtures. Needed because SavedVariables are broken. |

## Toolchain

Project-local, built by hererocks into `tools/` (gitignored). Homebrew has no `lua@5.1`
formula, so the interpreter is PUC Lua 5.1.5 rather than the system LuaJIT.

```sh
./tools/lua51/bin/luacheck LegacyNext spec   # lint
./tools/lua51/bin/busted                     # test
```

Rebuild: `python3 -m venv tools/venv && tools/venv/bin/pip install hererocks &&
tools/venv/bin/hererocks tools/lua51 --lua 5.1 --luarocks latest`, then
`./tools/lua51/bin/luarocks install --no-doc busted luacheck`.

Vendored Blizzard source is pinned in `vendor/PINS.md` — read-only reference, never imported.

## In-game workflow

Alex runs everything in game and pastes output back, so **round trips are the scarcest
resource**. Batch every open question into one script rather than a sequence of commands.

Available: **WoWLua** (multi-line editor, so the 255-character chat limit no longer shapes
anything) and **idTip** (IDs in tooltips, for spot checks). In the client: `/etrace` — use it
instead of writing an event probe — plus `/api` (runtime API browser, worth cross-checking
against our pin) and `/tinspect` (beats `/dump` on nested tables).

Rules for any script I hand over:

- **Semicolon-terminate every statement, and never use `--` comments.** Paste paths strip
  newlines. A missing semicolon gives `malformed number near '2802local'`; a `--` comment in a
  flattened script silently swallows everything after it, which is worse.
- **Verify it parses first.** Extract the block and run `./tools/lua51/bin/luac -p` over both
  the multi-line form and a flattened copy. Never hand over an unparsed script.
- **Write output into a copyable EditBox**, not chat, past a few lines. `/legacynext dump` and
  `/legacynext probe` now do this properly — prefer them over a new ad-hoc script, and only
  hand over raw Lua for something the addon does not read yet.
- **The queue table at the top of `docs/ingame-commands.md` is the one list of what needs the
  game.** Add the row the moment a question turns out to need the client, not at the end of the
  task, and give it a stable ID that is never renumbered, reused or deleted. Pending tests,
  commit messages and `docs/status.md` cite that ID — the row is what connects a blocked test
  to the session that unblocks it.
- **Close the row in the same change that consumes its data**, moving it to the Closed table
  with the date and where the result landed. A half-answered row stays open and says what is
  still missing. Never report work finished with the queue stale — a row closed a pass later is
  a row Alex gets asked for twice.
- Scripts live in the same file under their ID. Results get written up in
  `docs/legacy-internals.md` and `CLAUDE.md` — never left only in chat.
- **Surface the open queue rows without being asked.** Alex will not go looking. Name the ID,
  what it unblocks, and how long it takes. Do it when: a session starts or I'm asked what's
  next; a task finishes and the next step is blocked on a row; I'm about to write or leave a
  `pending` test; Alex mentions logging in, playing, or an alt; or I'm proposing work that a
  row blocks. Not every turn — that is noise, and noise is how the D4 row got skipped while
  sitting in two documents.

## Conventions

- Lua 5.1 semantics.
- No external libs in v0 — no Ace3, no LibStub — unless I approve first.
- luacheck clean. busted tests for `Model/`, fixtures in `spec/fixtures/`.
- `Api/` has a stub layer in `spec/stubs/`, driven by captured fixtures, never invented data.
- Small commits, conventional-commit messages. Never push without asking.
