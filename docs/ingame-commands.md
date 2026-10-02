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
| S2 | Install `main` (after `e513d27`), log in on **Geo** first, then `/lgn roster` and paste it. Then log in on **Bong** and `/lgn roster` again. Section S2 below | Whether a stored `Name-Realm` row moves to the GUID on that character's login, keeping its professions and tree spend, with one row per character after | 2 min |
| U8 | With the same install, open `/lgn`, then `/lgn uidump` and paste it; drag the corner grip; `/reload`. Section U8 below | Whether the resize grip draws and works, the bounds hold, the layout follows the size, and the size comes back | 2 min |
| U9 | Install `feat/beta2`. Click a Next Up row; shift-click another with the chat box open. Section U9 below | Whether a row click opens Blizzard's Legacy panel on that challenge, and whether shift-click puts its link in chat. Both paths are source-only at `9a789c0` | 2 min |
| U10 | Same install. Find the LegacyNext button on the minimap edge, drag it, hover it, `/reload`. Section U10 below | Whether the hand-rolled minimap button draws, drags round the edge, keeps its spot, and shows the summary tooltip | 2 min |
| U11 | Same install. Esc > Options > AddOns > LegacyNext: untick and retick the minimap button. Section U11 below | Whether the Settings category registers on Forever and its toggles take effect | 1 min |
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

## S2 — the GUID move

1. Log in on Geo. Run `/lgn roster` and paste the whole window.
2. Log out to Bong. Run `/lgn roster` again and paste it.
3. `/reload` on Bong and run `/lgn roster` once more. Only say whether a new "migrated" line
   appeared.

What I am reading it for:

- On Geo's login, the session log reads `PLAYER_LOGIN -> written; migrated from Geo-Classic
  Beta PvP`. The RAW block has one Geo row, keyed by Geo's GUID (D10 read
  `Player-4619-012F81BC`), with `name = "Geo"` and the realm. Alchemy, Herbalism, Cooking and
  the tree spend are still there.
- The character lines and the Roster tab say `Geo`, never a `Player-` string.
- After Bong's login, the same for Bong, and the roster shows exactly two characters.
- No second "migrated" line after the `/reload`.
- Any `Bong Wrip-…` key left in the RAW block. That is a 69913-era row, which does not move by
  design. Say so and I will give you the forget command.

## U8 — the resize grip

1. `/lgn`, then `/lgn uidump`. Paste it.
2. Look at the bottom-right corner. Is there a small grip, clear of the scroll bar's down arrow?
   Does the cursor change over it?
3. Drag it bigger, then as small as it goes. Does the top-left corner stay put? Does it stop at
   a minimum? Does the filter bar re-wrap and the right-hand columns follow the edge? Any Lua
   error?
4. Leave it at an odd size and `/reload`. Did the size come back?

What I am reading it for: the uidump's `== CLIENT ==` frame line reading `resize =
"SetResizeBounds"`, `grip = "PanelResizeButtonTemplate"`, `resizable = true` and the live
`width` and `height`. A missing grip with `resizable = false` means the client lacks the resize
methods, and the window stays fixed, which is the designed fallback. In combat and after a
relog are worth one try each if it is quick.

## U9 — row clicks: Blizzard's Legacy panel and the chat link

Needs a character with at least one Legacy point. At zero points Blizzard's panel does not open
for anyone, and the addon says so instead.

1. `/lgn`. Hover a Next Up row. Does the tooltip end with "Click to open in the Legacy panel.
   Shift-click to link it."?
2. Click a row. Does Blizzard's Legacy panel open on the Challenges tab, with that challenge's
   category open and the challenge selected? Paste any chat line starting `LegacyNext:`.
3. Click a different row with the panel already open. Does the selection move, and the panel
   stay open?
4. Close the panel. Open the chat box (Enter), then shift-click a row. Does a challenge link
   appear in the box? Send it to yourself and hover it.
5. Shift-click with the chat box closed. Paste the `LegacyNext:` line.
6. If it is quick: click a row in combat. Paste the line. Then, still in combat or just after,
   watch for "Interface action failed because of an AddOn".

What I am reading it for: step 2 is the open question. The select only works if the challenges
page builds its list inside the same call that shows it. If the panel opens on Challenges with
nothing selected, the page builds later, and the select needs a one-frame delay. A `could not
open the Legacy panel:` line names the failing step. Step 6's message would mean opening
Blizzard's panel from our click taints its panel manager.

## U10 — the minimap button

1. Find the LegacyNext button on the minimap's edge, lower left. Is the gold ring icon round,
   inside the usual minimap-button border?
2. Hover it. Paste or describe the tooltip: the reward track line, your unspent points, three
   challenges and "and N more", then the hint.
3. Left-click: does the window toggle? Right-click: does the settings page open?
4. Drag it round the edge to somewhere else. Does it follow the rim? `/reload`. Is it still
   there?
5. `/lgn minimap` twice: hidden, then back.
6. `/lgn uidump` and paste it.

What I am reading it for: the uidump's `== CLIENT ==` `minimap` line, with `created = true`,
`masked = true`, the `angle` you left it at and no `reason`. A button sitting off the rim or
inside the map means the edge offset is wrong. Say roughly how far.

## U11 — the settings page

1. Esc > Options > AddOns. Is there a LegacyNext entry, with "Show minimap button" ticked and
   "Lock minimap button" unticked?
2. Untick "Show minimap button". Does the button go? Tick it again.
3. Tick "Lock minimap button" and try to drag the button. Does it stay put? Untick it.
4. `/lgn config` out of combat: does it open on LegacyNext?

What I am reading it for: the uidump's `options` line from U10 reading `registered = true`. A
`reason` there names the missing piece of Blizzard's Settings API.

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
