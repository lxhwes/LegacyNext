# In-game work

## Queue

The one list of what needs the client. **IDs are stable — never renumber, never reuse, never
delete.** A row goes in the moment a question turns out to need the game, and moves to Closed
in the same change that consumes its data — so a `pending` test, a commit message or a
`docs/status.md` row can cite an ID and still have it resolve a year later.

Keeping it current is part of the task, not cleanup afterwards:

- **Opening.** The row exists before the code that needs it, not after.
- **Closing.** Same commit as the fixture, test or doc the data fed. A row closed in a later
  pass is a row that gets asked for twice.
- **Partial answers.** A paste that answers half a row leaves it open, with what is still
  missing written into it. Do not close on "close enough".
- **Never report work finished with this table stale.**

Open, roughly in the order worth doing:

| ID | Needs | Unblocks | Cost |
|---|---|---|---|
| C2 | **Partly answered 2026-10-01**: `CRITERIA_UPDATE` fires on an Alchemy skill-up, and none of the other four did. Still open: the four that need a completion or a spent point. `/etrace` during the C4 session for `ACHIEVEMENT_EARNED`, and the C1 session for `TRAIT_CONFIG_UPDATED`, `TRAIT_TREE_CHANGED` and `MAJOR_FACTION_RENOWN_LEVEL_CHANGED`. Section C2 below | Whether the frame's `ACHIEVEMENT_EARNED` refresh ever fires on Forever, and whether trait and faction events are worth adding | Free with C1 and C4 |
| D8 | `/lgn dump challenges 2` … `6` **only if a Model test needs a specific Explore zone** | The 46 zero-point Explore achievements' ~600 subzone criteria. Deliberately not fixtured: Next Up excludes zero-point challenges, so this is dead weight until something needs it | 5 min, low value |
| C1 | Points spent in **two different trees**, then `/lgn dump trees` | Confirms the single shared pool, and what `maxQuantity` becomes once non-zero | needs play |
| C4 | A completed challenge, then `/lgn dump challenges` on its page | `wasEarnedByMe` true on a real completion | needs play |

Closed — kept so a citation still resolves:

| ID | Closed | Answered | Result landed in |
|---|---|---|---|
| A | 2026-09-18 | Constants, tree names, account flag, trait config, point caps | `CLAUDE.md`, `docs/legacy-internals.md` |
| B | 2026-09-18 | The 29-category tree and the full 111-challenge sweep with criteria shapes and point values | `docs/legacy-internals.md` |
| D1 | 2026-09-19 | The addon loads and prints its version | `docs/status.md` |
| D2 | 2026-09-19 | Probe: no secrets on our surface, `issecretvalue` active, all constants runtime. Found the mixin bug | `CLAUDE.md`, `docs/status.md` |
| D3 | 2026-09-19 | `summary`, `trees` and `challenges 1` — reproduced the B sweep from a second code path | `spec/fixtures/dump_trees_fresh.lua`, `spec/fixtures/dump_challenges_page1_fresh.lua` |
| D5 | 2026-09-19 | Mixin fix confirmed on a second character: `partial`, 19 fields recovered, all 14 ColorMixin methods named. Also found `configID` is not stable | `CLAUDE.md`, `docs/status.md` |
| D6 | 2026-09-19 | Reward track alive. Legacy Track 0/90, four thresholds (15/25/40/55), all four rewards named with items. `isCollected` true on an unreached tier, confirming it is collection state | `spec/fixtures/dump_rewards_fresh.lua` |
| D7 | 2026-09-19 | Full `section = "all"` dump, all 111 challenges. Found **five undocumented `criteriaType` values** and the type-243 progress trap; plus the character shape and a part-done challenge | `spec/fixtures/dump_criteria_types.lua`, `dump_character_shaman.lua`, `CLAUDE.md` |
| D9 | 2026-09-19 | All 29 categories in client order, summing to 111. Confirms every row of the assembled partial field for field, and adds the 13 class and tradeskill ids the sweep never recorded | `spec/fixtures/categories_full.lua` (replaces `categories_partial.lua`), the un-pended test in `spec/api/api_spec.lua` |
| S1 | 2026-10-01 | SavedVariables load back across a character switch and off disk after a full restart. The skill-line lookup answers for all six lines on any character. `GetProfessionInfo` reports the Classic line for Alchemy (171), Herbalism and Cooking, so the join runs through `parentProfessionID` | `spec/fixtures/roster_geo.lua`, `roster_geo_restart.lua`, `CLAUDE.md`, the two un-pended tests |
| D4 | 2026-10-01 | `GetProfessions` on a character with three professions: primaries in slots 1 and 2, Cooking in slot 5 | `spec/fixtures/dump_character_geo.lua`, `CLAUDE.md` |
| U1 | 2026-10-01 | Screenshot of Next Up: the header's middle dot renders, the filter bar wraps to two lines, nothing is cropped. Also the first real "in progress" tier | `docs/status.md` |
| U3 | 2026-10-01 | The gold ring icon draws in the AddOns list | `docs/status.md` |
| U4 | 2026-10-01 | `/lgn uidump roster` and two screenshots: headings over their columns, the current character in gold, the footnote below the rows, and the tradeskill tooltip naming Geo | `roster_geo_restart.lua`, `docs/status.md` |
| D10 | 2026-10-01 | Probe on 70170, Geo Prizm: no secrets, the name calls' second return carries the surname, `UnitGUID` reads a `Player-` string. Also found `WOW_PROJECT_ID` reads 18, not 1 | `CLAUDE.md`, `docs/legacy-internals.md` |
| C3 | 2026-10-01 | `/lgn dump challenges 1` on Geo, 70170: the three Alchemy type-7 criteria at `have = 1`, `completed = false`, progress-bar bit set. The rest of page 1 matches 69913 field for field, apart from one description | `spec/fixtures/dump_challenges_page1_geo.lua`, `spec/model/model_spec.lua`, `spec/fixtures/README.md` |
| U5 | 2026-10-01 | The minimap's addon dropdown lists LegacyNext with the gold ring icon, and the click toggles the window, on `WOW_PROJECT_ID` 18 | `docs/legacy-internals.md`, `docs/status.md` |
| U7 | 2026-10-01 | The key binding lists, toggles the window, and works in combat. `## Category: Achievements` groups LegacyNext under Achievements in the AddOns list | `docs/legacy-internals.md`, `docs/status.md` |
| U6 | 2026-10-01 | The polish pass as built: Blizzard's top tabs, row and reward icons, class-coloured roster names with the current one tinted. Tab, filter and position come back after a `/reload` and after a relog | `docs/legacy-internals.md`, `docs/status.md` |
| U2 | 2026-10-01 | `IsProtected` `false,false`, all three templates present, `IsTruncated` true with `GetStringWidth` reading the unbounded width, and on 70170 the clipped test string drawn as "Reach exalted re...", so the client adds the ellipsis | `docs/ui-templates.md` |

See `docs/status.md` for what each finding changed.

Below is the detail behind each **open** row: what to type, and what I am reading it for. The
instructions for closed rows were cut on 2026-09-26. They are in git history
(`git log -p docs/ingame-commands.md`), and each row's result is in the Closed table above.
Prefer `/lgn dump`, `/lgn probe` and `/lgn uidump` over hand-written Lua. Raw Lua is only for
something the addon does not read yet, as U2 was.

**Before any session:** copy the inner `LegacyNext` folder (the one holding `LegacyNext.toc`)
over `_classic_beta_/Interface/AddOns/LegacyNext/`, then `/reload`. If the client throws a Lua
error, paste the first one. It stops reporting after 100.

---

## C2 — events, via `/etrace`

`CRITERIA_UPDATE` was seen firing on a skill-up, 2026-10-01. The other four stay open:
search the trace for them during the C1 and C4 sessions.

```
ACHIEVEMENT_EARNED
CRITERIA_UPDATE
TRAIT_CONFIG_UPDATED
TRAIT_TREE_CHANGED
MAJOR_FACTION_RENOWN_LEVEL_CHANGED
```

`ACHIEVEMENT_EARNED` fires only on
a completion, so it may take a later session (the same one as C4). The trait and faction
events need a point spent. Tell me which fire and what payload `TRAIT_CONFIG_UPDATED` carries.
Blizzard's Legacy UI registers none of the trait or faction ones, so there is no precedent.

## C1 and C4 — after real play

- **C1:** with points spent in two different trees, `/lgn dump trees`. `spent` identical on all
  three trees while `spentInTree` differs confirms the shared 16-point pool. What `maxQuantity`
  reads is the other half. It read 0 at zero points, so it is not the static cap.
- **C4:** after any challenge completes, `/lgn dump challenges <page>` for its page. I want
  `completed = true` and `wasEarnedByMe = true` on a real entry.

## D8 — only if a Model test needs it

`/lgn dump challenges 2` through `6`: the 46 zero-point Explore achievements and their ~600
subzone criteria. Next Up excludes them, so this stays unasked until something needs it.

---

## How to run raw Lua

Paste into **WoWLua** and hit run. Every script here survives having its newlines stripped.
Every statement is semicolon-terminated, and there are no `--` comments, so it parses as one
long line too. Keep both properties if you edit one. A `--` comment in a flattened script
swallows everything after it, and a missing semicolon gives
`malformed number near '2802local'`. Every block is run through
`.claude/skills/ingame-script/scripts/check_script.sh` before it lands here.

## Copyable output — the `LNDump` block

Past a few lines of output, end a raw script with this instead of `print`. It was the tail of
the old Script 1 (cut 2026-09-26, recoverable from git history, which is also where fixtures
citing "script 1" resolve) and is kept because the `ingame-script` skill uses it as the
template. It expects the script to have filled a table `out` with lines.

```lua
local text = table.concat(out, "\n");
text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", "!");
if not LNDump then local f = CreateFrame("Frame", "LNDump", UIParent); f:SetSize(760, 520); f:SetPoint("CENTER"); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing); local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0, 0, 0, 0.92); local sf = CreateFrame("ScrollFrame", "LNDumpScroll", f, "UIPanelScrollFrameTemplate"); sf:SetPoint("TOPLEFT", 12, -12); sf:SetPoint("BOTTOMRIGHT", -32, 12); local eb = CreateFrame("EditBox", nil, sf); eb:SetMultiLine(true); eb:SetFontObject(ChatFontNormal); eb:SetWidth(700); eb:SetAutoFocus(false); eb:SetScript("OnEscapePressed", function() f:Hide(); end); sf:SetScrollChild(eb); f.eb = eb; end;
LNDump:Show();
LNDump.eb:SetText(text);
LNDump.eb:HighlightText();
LNDump.eb:SetFocus();
```
```

If `UIPanelScrollFrameTemplate`, `ChatFontNormal` or `SetColorTexture` is ever missing after a
build bump, replace everything from `if not LNDump then` to the end with
`for _, line in ipairs(out) do print(line); end;` and say what errored.

## Note on idTip

It earns its keep for spot checks. Hover a challenge in the Legacy UI to get its ID, then ask me
about that one without running a sweep.
