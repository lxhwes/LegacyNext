# LegacyNext

WoW: Forever addon. Forever is Blizzard's Classic+ line — beta live 2026-09-17, launch
2026-11-04.

## Domain

Legacy is Forever's account-wide progression system. Legacy Challenges (achievement-like)
award Legacy Points to the **account**. Each character spends those points **independently**
across three Legacy Trees: Professions, Adventure, Resourcefulness (public names). Launch
numbers from Blizzard's BlizzCon deep dive: 65 points earnable, 16 spendable per character.
Points past the cap feed a cosmetic Legacy Reward Track. **One character can earn at most 29**
(3 leveling, 6 tradeskills, 12 PvP, 2 Adventure, 6 Dungeons and Raids — Blizzard's Legacy
overview article, 2026-09-26); the other 36 need alts, which is why v1 exists. Tradeskill
challenges cover only the six crafting professions, three tiers each; gathering and secondary
skills have none. The system unlocks on the first point earned, but every read on our surface
works at zero points.

Hardcore has separate Legacy challenges/perks and launches later. Out of scope. (Challenges
earned there grant in every ruleset; PvP challenges cannot be done there.)

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
  and the guard is active** [verified in game 2026-09-19 via `/lgn probe`, and again on 70124
  on 2026-10-01, D10], and no API the probe read returned a secret. That is a tested negative,
  not an assumption, but it is a per-build one, so re-run the probe after any bump. It does
  **not** yet cover `UnitFullName`, `UnitNameUnmodified` or `UnitGUID`, which are documented
  `SecretWhenUnitIdentityRestricted` and were added to the probe after that run. D10's name
  rows are their first read.
- **SavedVariables load back** [verified in game 2026-10-01, build 70124, queue row S1]:
  across a logout and a character switch, and off disk after a full client restart, with no
  `LATE LOAD` either time. The beta bug that wrote them but never loaded them back is fixed,
  and our TOC needs no `## LoadSavedVariablesFirst`. `Store/` stays the only file that names
  `LegacyNextDB`, so a regression would still be a one-file change.
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

Runtime facts, all from a fresh character on build 1.60.1 (69913). Each carries its own
verification date — the section does not have one, because it accretes with every capture.
Deeper detail and the raw captures are in `docs/legacy-internals.md`; this list is the part
that changes how code gets written.

- `GetCategoryList()` returns **only Legacy categories** — 29 of them, exactly two levels
  deep, six real top-level groups plus a "Do Not Display" bucket holding zero achievements.
  111 challenges total, confirmed three times by separate code paths. Full tree in
  `docs/legacy-internals.md`; the complete capture is `spec/fixtures/categories_full.lua`
  [2026-09-19].
- **Category order is the client's and is sorted by nothing** [2026-09-19] — not id, not name,
  not depth. Parents appear after some of their own children. Preserve the returned order and
  never re-derive the tree from a sort.
- **A parent category can hold achievements of its own** [2026-09-19]. Raids (3) and Adventure
  (2) both do, while Classes, Tradeskills and Player vs. Player hold none. "Has children"
  and "is empty" are independent.
- The filter API (`GetNumFilteredAchievements` / `GetFilteredAchievementID`) reads 0 at login
  and 111 after any `SetAchievementSearchString("")`. It is global state shared with
  Blizzard's Achievement UI — we never call it, and never read it as a source of truth.
- All three trees share **one** `configID`, and **the number is a transient handle — not a
  constant, not even stable per character** [2026-09-19]: 2938022, then 4040613 on a second
  character, then **4103142 on the first character again**. Read it via
  `C_Traits.GetConfigIDByTreeID` every time. Never hardcode it, never cache it across a
  session, never persist it to SavedVariables, and treat the numbers in `spec/fixtures/` as
  that capture's, not the client's. The claim that survives is structural: all three trees
  return the *same* configID as each other within one read. The 16-point cap is a single pool
  spent across all three, not 16 per tree.
- **`parentCategoryId` is `-1` for top-level challenge categories** [2026-09-19] — Dungeons,
  Raids and Adventure challenges carry it. The category filter must treat `-1` as "no parent"
  rather than looking it up and finding nothing.
- **Class challenges carry no machine-readable level threshold through the API** [2026-09-19].
  `Novice / Experienced / Master Druid` (61502–61504) are levels 25/45/60, but
  `criteriaExpected == 0` and the number appears only in `description` prose. Profession
  challenges are the opposite — `criteriaType` 7 gives `assetId` 2937, `need` 150.
  **The client data does hold the level** [DB2, 2026-09-30]. Each class challenge has one
  type-5 criterion whose `CriteriaTree.Amount` is 25, 45 or 60. We know of no API that returns
  it. The PvP rank challenges are the same case, with type 261 in the data.
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
- **Criteria come in three shapes** [2026-09-18]: 18 progress-bar (`criteriaFlags` bit 1, a
  real `quantity`/`reqQuantity` fraction), 59 checklist (boolean each, remaining is a count),
  and **34 with no criteria at all** (`criteriaExpected == 0`). The 34 expose no progress
  whatsoever and are binary — handle them as their own case, never as 0%.
- **`criteriaType` is a separate, open-ended axis — eight values seen** [2026-09-19, full
  111-challenge dump]: 0 = encounter/dungeon (`assetID` is an encounter or instance ID),
  7 = skill threshold (skill line, e.g. 2937 Alchemy), 8 = child achievement (achievement ID),
  27 = journey/quest step (quest ID), 43 = area discovery (area ID), 78 = dungeon with
  alternatives — "X or Y" in one criterion, `assetID` is **0**, 165 = raid encounter variant,
  243 = reputation threshold (faction ID). A previous pass recorded only 7/8/43 and was wrong
  within a day. Never switch exhaustively on the type.
- **A criterion can carry real quantities without the progress-bar bit** [2026-09-19]. Type-243
  reputation criteria read `need = 42000`, `have = 0`, `flags = 1024`, `isProgressBar = false`.
  Scored as a checklist, "Master of Alterac Valley" looks one step from done when it is 0/42000.
  **Closeness must use `need`/`have` whenever `need > 1`**, not only when the bar bit is set.
- **Type 8 forms meta chains, and they are deep** [2026-09-19] — `Explorer` reaches subzone
  criteria four hops down. Chain map in `docs/legacy-internals.md`. Every chain found so far is
  zero-point.
- `GetAchievementInfo` return order matches retail exactly. The achievement's own `points` is
  **0** on Legacy challenges, which is why Blizzard overrides it. `rewardText` reads
  "Earn 1 Legacy Point." and is usable for display.
- `flags` is `134349824` on point-bearing challenges and `0` on the 46 zero-point exploration
  ones, so the latter are per-character. `isAccountWide` is **derived** from `flags`, not
  returned. Bit breakdown in `docs/legacy-internals.md`.
- **The client data holds two mirrored sets of 65 point-bearing challenges** [DB2,
  2026-09-30]. Ours carry flag bit 27 (`0x08000000`). The mirror carries bit 28
  (`0x10000000`) and has its own challenge and criteria IDs: Novice Warrior is 61499 in ours
  and 63969 in the mirror. The client listed only ours on both characters. Which ruleset sees
  the mirror is unknown. **Never assume two characters see the same challenge IDs**, which
  matters for anything v1 compares across alts.

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
`GetAchievementCategory`, `GetCategoryList`, `GetCategoryInfo`, `GetCategoryNumAchievements`,
`GetNumFilteredAchievements`, `GetFilteredAchievementID`, `C_AchievementInfo.IsValidAchievement`.
The category filter needs `GetCategoryInfo` on the **parents** too: Classes, Tradeskills and
Player vs. Player hold no achievements of their own, so their names never reach a challenge
record. `Api.GetCategories` is that read.
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
different things. Never name the slots; iterate every return. Seen in game 2026-10-01 (D4):
primaries in slots 1 and 2, Cooking in slot 5, the rest empty on that character.
`GetProfessionInfo(index)` → `name, texture, rank, maxRank, numSpells, spellOffset, skillLine,
rankModifier, specializationIndex, specializationOffset, skillLineName`
(`Blizzard_ProfessionsFrame.lua:60` at `9a789c0`).
**That `skillLine` is the parent profession line, not the one tradeskill challenges name**
[verified in game 2026-10-01] for Alchemy (171), Herbalism (182) and Cooking (185), all three of
which have Forever children in the client data (2937, 2944, 2939). For those three, a
character's profession reaches a challenge's line (Alchemy's 2937) only through the lookup's
`parentProfessionID`, and the direct match never fires. The same frame compares it against
`parentProfessionID or professionID` (`:40-42`, via `Professions.GetEffectiveSkillLineID`). Join through
`C_TradeSkillUI.GetProfessionInfoBySkillLineID(...).parentProfessionID` as well as directly,
never by name: the direct match costs nothing, and five of the six crafting professions have
not been seen on a character in game. `GetServerTime` stamps roster snapshots.
**Forever characters have a first name and a surname**, a Legacy feature (Alex, 2026-10-01).
`UnitName("player")` read `"Bong Wrip"` on 69913 and `"Bong"` on 70124 for the same
character, and `"Geo"` for Geo Prizm on 70124, so **a name is not a stable character key**, and the roster's `Name-Realm` key can
split one character into two rows across builds. `C_PlayerInfo.ShouldDisplaySurname` exists
at every pin (`PlayerInfoDocumentation.lua:358`).
`C_NameUtil.ReplaceSurnameSeparatorWithLinkSeparator` arrived in 70009
(`NameUtilDocumentation.lua:11`), and its doc says full names carry a "surname separator".
Which call carries the surname now, and whether `UnitGUID` reads, is D10.
The client data backs the parent reading [DB2, 2026-09-30]. All six tradeskill lines are
tier-4 children of the Classic lines: 2937 → 171, 2938 → 164, 2940 → 333, 2941 → 202,
2945 → 165, 2948 → 197. **The live lookup returns exactly that map** [verified in game
2026-10-01], on a character who knows none of the six. Each answer is a full `ProfessionInfo`
with all eleven documented fields (`TradeSkillUITypesDocumentation.lua:361-376`), with
`professionID` echoing the line and `skillLevel` 0.
**Neither tree spend nor professions can be read at `PLAYER_LOGOUT`** [verified in game
2026-10-01]. Logout snapshots came back "unspent points not read" and "professions: empty
read, kept stored", and the login reads were kept. Both reach the roster at login and on
events, never at logout.
`PLAYER_LEVEL_UP` and `SKILL_LINES_CHANGED` fire, and the second fires on every skill-up
[verified in game 2026-10-01]. `TRAIT_CONFIG_UPDATED` registers without error. Whether it
fires is C2.

Reference source, read-only, on the forever branch: the directories `vendor/PINS.md` lists
(the Legacy addons, the generated API docs, `Blizzard_AchievementUI`, and the UI template,
font and panel directories added 2026-09-19). PINS.md is the list; `ls
vendor/wow-ui-source/Interface/AddOns` is the check.

Client data, read-only, for any build: the DB2 tables at
`https://wago.tools/db2/<Table>/csv?build=<build>`. `https://wago.tools/api/builds` lists builds;
Forever's are the `1.6*` versions under `wow_classic_beta`, and it is the quickest way to learn
a new beta build shipped. A fact from there is tagged `[DB2, <date>]` and names its builds in
`docs/legacy-internals.md`. **It is research evidence, the same as `vendor/`.** It is never a
runtime source, never shipped, and never licenses a hardcoded ID. It answers questions the API
cannot, and some that would otherwise need a round trip in game.

## Architecture

| Dir | Rule |
|---|---|
| `Api/` | The **only** place WoW globals are called. Every call: feature-detect (does the function exist?), `pcall`, `issecretvalue` guard (if `issecretvalue` exists). Returns plain Lua tables, or `nil` + reason. No UI code. |
| `Model/` | Pure Lua: ranking, reward-track math, roster mapping. **No WoW globals at all.** This is where the tests live. |
| `UI/` | Frames. Talks to `Model`, never to `Api` directly: `Core.lua` injects `ns.ReadViewInput` as its data source, and `/lgn uidump` reads through the same function. One frame, two tabs: Next Up draws `Model.BuildView`, Roster draws `Model.BuildRosterView`, from the same read. Frame templates and font objects are looked up by name with `pcall`/`rawget` and a plain-frame fallback; the citations are in `docs/ui-templates.md`. |
| `Store/` | SavedVariables behind an interface, so the SV-bug workaround (or its removal) is a one-file change. |
| `Debug/` | `/lgn dump`: serializes `Api` output into a copyable multiline EditBox so I can paste real client data back as test fixtures. Built because SavedVariables were broken, and still the capture path. `/lgn roster`: v1's stored characters and tradeskill candidates as text. `/lgn uidump [roster]`: a tab's content as text via the pure `Debug.RenderView`, golden-tested in `spec/golden/`. |

**Adding a source file means editing `LegacyNext.toc`.** Load order is explicit and `Core.lua`
must stay last — it registers the slash commands and reads `ns.Debug`. A file missing from the
TOC simply never loads, with no error, on a client I cannot debug interactively.

## Toolchain

Project-local, built by hererocks into `tools/` (gitignored). Homebrew has no `lua@5.1`
formula, so the interpreter is PUC Lua 5.1.5 rather than the system LuaJIT.

```sh
./tools/lua51/bin/luacheck LegacyNext spec   # lint
./tools/lua51/bin/busted                     # test — picks up spec/**/*_spec.lua
./tools/lua51/bin/luac -p <file>             # parse-check, used on in-game scripts
```

Both gate CI (`.github/workflows/ci.yml`) on push and PR. **A new WoW global called from `Api/`
gets a `read_globals` entry in `.luacheckrc`** — by convention, not because lint would fail
without it: every read goes through `rawget`/`resolve`, so luacheck never sees the symbol. The
list is the manifest of what we depend on, and an entry there does not excuse the runtime
feature-detect.

Rebuild: `python3 -m venv tools/venv && tools/venv/bin/pip install hererocks &&
tools/venv/bin/hererocks tools/lua51 --lua 5.1 --luarocks latest`, then
`./tools/lua51/bin/luarocks install --no-doc busted luacheck`.

Vendored Blizzard source is pinned in `vendor/PINS.md` — read-only reference, never imported.

## Project docs

Read `docs/status.md` first in a new session, and again before proposing any phase of work — it
is the only document that says where the project actually is, and it carries decisions that are
settled and should not be reopened without new evidence.

Each doc owns one thing. The test for where something goes:

| Doc | Owns | Belongs here if… |
|---|---|---|
| `CLAUDE.md` | Client facts, constraints, architecture | it is still true after v1 ships |
| `docs/status.md` | Where we are, what was decided and why, what blocks what | it is true *as of now* |
| `docs/ingame-commands.md` | The queue needing the live client | it needs Alex in the game |

Also `docs/legacy-internals.md` (research with `file:line` citations), `docs/ui-templates.md`
(frame templates, fonts and FontString methods verified at the pin), `docs/distribution.md`
(what the packager dry-run showed, and how CurseForge was confirmed), `docs/icon-design.md`
(the icon decision and how to re-render it) and `docs/development.md` (bootstrap, toolchain and
the capture commands, for contributors).
`README.md` is the CurseForge listing, not a repo guide. `docs/kickoff-phases.md` is
**history** — it predates decisions that contradict it, so never cite it as current.

Maintaining `docs/status.md`:

- **Update it in the same change as the work**, and move the `Last updated` date at the top. A
  multi-step task is not done until status is current — that includes the "Where we are" banner,
  which is the line most likely to be quietly false.
- **Supersede, never silently edit.** A reversed decision gets struck through with the evidence
  that reversed it; ranking decision 3 is the worked example. Deleting it loses the why, and the
  why is what stops the same argument being had twice.
- **Never re-list the queue.** Name the IDs that block something and stop. Both copies existed
  once and drifted within a day.
- **A client fact goes in `CLAUDE.md`**, with `status.md` keeping only the story of how it was
  found. A number recorded in two places is a number that can disagree with itself.
- **Dated findings sections are append-only.** Do not tidy them into the present tense — "what
  we believed on 2026-09-19" is what makes a later contradiction legible instead of confusing.

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
- **Write output into a copyable EditBox**, not chat, past a few lines. `/lgn dump`
  (including `/lgn dump probe`) and `/lgn uidump` now do this properly, while bare `/lgn probe`
  prints to chat. Prefer them over a new ad-hoc script,
  and only hand over raw Lua for something the addon does not read yet. For anything about
  the frame, ask for `/lgn uidump` before a screenshot: row content is checkable here against
  `spec/golden/`, and only the look needs Alex's eyes.
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
- `Api/` specs stub WoW globals inline (`spec/api/api_spec.lua`) with trivial values; they test
  the guard, not client shapes. `spec/stubs/` is reserved for a fixture-driven stub environment
  and holds only its README today. Any stub that lands there is driven by captured fixtures,
  never invented data.
- Small commits, conventional-commit messages. Never push without asking.
