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
- I cannot run the game. Anything needing in-game verification: write the exact `/run` or
  `/dump` command for me and stop.

## Client facts [verified]

- Interface 16001, build 1.60.1. Ships on the `wow_classic` product line; beta folder is
  `_classic_beta_`.
- **It is the retail API.** `WOW_PROJECT_ID` reports Mainline, 269 `C_*` namespaces, most
  Classic-era globals are gone. Blizzard: "shares Mainline WoW's UI architecture, including
  the vast majority of APIs available in 12.1.5".
- Forever's API docs differ from live retail 12.1.0 — 26 extra doc files, ~6k line diff.
  **Do not assume retail behavior**; check the forever branch source.
- Midnight addon restrictions (secret values) apply. Believed irrelevant to our APIs, but
  every API read still goes through the guard.
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
- All three trees share **one** `configID`. The 16-point cap is a single pool spent across
  all three, not 16 per tree.
- `C_Traits.GetMaxAvailableTraitCurrency(4225, false)` = 65 earnable account-wide;
  `(4225, true)` = 16 spendable per character. The cap does **not** come from
  `TreeCurrencyInfo.maxQuantity`, which read 0 at zero points.
- `ACHIEVEMENT_FLAGS_ACCOUNT` = 131072.
- Reward track faction 2802 is named "Legacy Track", `maxLevel` 90, `isUnlocked` true.
  `GetRenownLevels` returns a **sparse** list of the four reward thresholds (15, 25, 40, 55),
  not one entry per level. `renownLevel` is the account's earned point count.
- Reward entries carry a usable display name — `reward.name or reward.toastDescription`, since
  `name` is missing on some entries — plus `icon` and `isCollected`. No item lookup needed.

**The generated API docs are a floor, not a contract.** The live reward struct carries five
fields that appear in no documentation file. Feature-detect fields; never assume a documented
field list is complete.

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

## Conventions

- Lua 5.1 semantics.
- No external libs in v0 — no Ace3, no LibStub — unless I approve first.
- luacheck clean. busted tests for `Model/`, fixtures in `spec/fixtures/`.
- `Api/` has a stub layer in `spec/stubs/`, driven by captured fixtures, never invented data.
- Small commits, conventional-commit messages. Never push without asking.
