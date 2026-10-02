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
| D10 | **Partly answered 2026-10-01**: the secrets half is done, with no row `secret`, `error` or `missing` on 70124. Still open: **the five name rows**, which the installed build did not have. Install from the branch that adds them (or from main once it merges), `/reload`, then `/lgn dump probe` on a character with a surname. Section D10 below | Which name call carries Forever's surname, and whether `UnitGUID` reads, for a roster key that cannot shift | 30 s |
| U5 | Click the minimap's addon dropdown (the small numbered button under the calendar), then click `LegacyNext` in it, twice. Section U5 below | Whether Forever shows Blizzard's Addon Compartment at all, and whether our `## AddonCompartmentFunc` entry lists and toggles the window. Read from source only: the TOC loads it for `mainline`, and Forever's `camelot` type is inferred to count as `mainline` | 30 s, any login |
| U7 | Escape > Options > Key Bindings > AddOns, bind a key to "Open or close LegacyNext", press it twice in and out of combat; then the AddOns list. Section U7 below | Whether `Bindings.xml` loads without a TOC line and lands under AddOns, and whether `## Category: Achievements` groups the addon in the AddOns list | 1 min |
| U2 | **Partly answered 2026-10-01** (v2 of the block): `IsProtected` `false,false`, `IsTruncated` true, and all three templates present. Still open: **whether the test string near the top of the screen ends in `...` or is cut off mid-word**, which only a look at the screen answers. Run the block under U2 below, or Alex's gist "LegacyNext U2 v2", and look | Whether long rows get an ellipsis for free or rely on the tooltip alone | 30 s |
| C3 | **Geo now has Alchemy at 1**, so this is two commands: `/lgn dump challenges 1` and `/lgn uidump`, on Geo. The in-progress tier was already seen in a screenshot 2026-10-01. Section C3 below | The mid-progress ranking fixture: a real type-7 criterion with `have` above 0, to replace the derived values in the Model tests | 1 min |
| C2 | `/etrace` on the five events in section C2 below, during any session that raises a skill or earns a challenge | Which fire. **Partly answered 2026-10-01 for the roster's own events**: `PLAYER_LEVEL_UP` and `SKILL_LINES_CHANGED` fire, and `TRAIT_CONFIG_UPDATED` registers without error. None of the five below has been seen yet. The frame depends on `ACHIEVEMENT_EARNED` and `CRITERIA_UPDATE`, and neither has been seen firing on Forever. The other three decide whether trait and faction events are worth adding | Free with C3 |
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

See `docs/status.md` for what each finding changed.

Below is the detail behind each **open** row: what to type, and what I am reading it for. The
instructions for closed rows were cut on 2026-09-26. They are in git history
(`git log -p docs/ingame-commands.md`), and each row's result is in the Closed table above.
Prefer `/lgn dump`, `/lgn probe` and `/lgn uidump` over hand-written Lua. Raw Lua is only for
something the addon does not read yet, like U2.

**Before any session:** copy the inner `LegacyNext` folder (the one holding `LegacyNext.toc`)
over `_classic_beta_/Interface/AddOns/LegacyNext/`, then `/reload`. If the client throws a Lua
error, paste the first one. It stops reporting after 100.

---

## U2 — truncation and protection

One WoWLua block, run with the window open. **Rewritten 2026-10-01**: the first version printed
nothing in chat. WoWLua may send `print` to its own output pane, and an error before the last
line would have stopped it with no message. This one guards every step, writes straight to the
chat frame as well as through `print`, and names any step that errors instead of stopping.

```lua
local out = {};
local function w(s) out[#out+1] = tostring(s); end;
local function try(label, fn) local ok, v = pcall(fn); w(label .. "=" .. (ok and tostring(v) or ("ERROR " .. tostring(v)))); end;
local f = LegacyNextFrame;
w("frame=" .. tostring(f ~= nil));
if f then
  try("shown", function() return f:IsShown(); end);
  try("IsProtected", function() local p, e = f:IsProtected(); return tostring(p) .. "," .. tostring(e); end);
end;
local fs;
try("fontstring", function() fs = UIParent:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); fs:SetPoint("CENTER", 0, 200); fs:SetWidth(120); fs:SetWordWrap(false); fs:SetText("Reach exalted reputation with the Frostwolf Clan"); return fs ~= nil; end);
if fs then
  try("truncated", function() return fs:IsTruncated(); end);
  try("stringWidth", function() return fs:GetStringWidth(); end);
  try("unbounded", function() return fs:GetUnboundedStringWidth(); end);
end;
local x = C_XMLUtil and C_XMLUtil.GetTemplateInfo;
w("GetTemplateInfo=" .. tostring(x ~= nil));
if x then
  for _, name in ipairs({ "WowScrollBoxList", "MinimalScrollBar", "BasicFrameTemplateWithInset" }) do
    try(name, function() return x(name) ~= nil; end);
  end;
end;
local bar = string.char(124);
local line = ("LGN U2: " .. table.concat(out, " ; ")):gsub(bar, "!");
local cf = DEFAULT_CHAT_FRAME;
if cf and cf.AddMessage then cf:AddMessage(line); end;
print(line);
```

It writes one line starting `LGN U2:` to the main chat window, and leaves a 120-pixel-wide test
string near the top of the screen (`/reload` clears it). If chat stays empty, look in WoWLua's
own output pane. Any `|` comes back as `!`.

**What I need back:** that line, and whether the test string on screen ends in `...` or is cut
off mid-word.

**What I'm reading it for:**

- `frame=true`, `shown=true` and `IsProtected=false,false`. Anything else means the frame
  picked up protection, and the combat handling in `UI/` needs another look.
- `truncated=true`. Already seen in v2, along with `stringWidth` equal to `unbounded` rather
  than at or under 120, so `IsTruncated()` is the only width check that detects a clipped
  string (`docs/status.md`). Only your answer about `...` is still open, and it decides
  whether long rows get an ellipsis for free or rely on the tooltip alone.
- The three template rows `true`. `WowScrollBoxList` and `MinimalScrollBar` are what a later
  scroll rewrite would use. `BasicFrameTemplateWithInset` is the frame we already draw.
- Any `ERROR` names the step and the message. That is a finding in its own right.

## U7 — the key binding and the AddOns-list category

1. Escape > Options > Key Bindings. Look for an **AddOns** section holding "Open or close
   LegacyNext". Bind any free key, then press it twice to open and close the window. Do it once
   more in combat.
2. Open the AddOns list and say whether LegacyNext sits under an **Achievements** group.

What I am reading it for: the row under AddOns, which proves `Bindings.xml` loaded from the
folder with no TOC line, and the window toggling both times, in combat too. Missing from Key
Bindings means the file did not load; say so and I will look for another route.

## U5 — the minimap addon dropdown

Nothing to type. At the minimap's top right is the calendar button, which shows today's date.
Directly below it is a smaller round button showing how many addons it lists
(`AddonCompartment.xml` anchors it to `GameTimeFrame`, the calendar). Click that one, not the
calendar. `LegacyNext` should be listed with the gold ring icon on the right. Click that entry
once and the window should open. Open the dropdown and click it again, and the window should
close. Say which of these happened:

- No small button under the calendar. Forever does not load the compartment, or hides it.
- The button, but no `LegacyNext` in it. The compartment lists only addons enabled for **all
  characters** (`AddonCompartment.lua:80`), so check the AddOns list's character dropdown first.
- Listed, but the click does nothing or errors. Paste the error.

Also say what is at the right of the entry: the ring, a green square (the texture failed to
load) or nothing. The compartment draws `## IconTexture` itself at 16 x 16
(`AddonCompartment.lua:40-52`). It is a different path from U3's 20 px markup in the AddOns
list, so one can work without the other.

## D10 — the probe on 1.60.1.70124

`/lgn dump probe`, then paste the whole window. Do it before S1's first `/lgn roster`, so the
two share a login.

What I am reading it for: the meta block's `build` reading 70124, `issecretvalue` reading
`guard active`, every constant and flag reading `(runtime)`, and no row reading `secret`. D2
and D5 are the baseline. A `secret` row is the finding that matters. It means Midnight's
restrictions reached an API we call, and it goes into `CLAUDE.md` before anything else.

Added 2026-10-01: five name rows, `UnitName`, `UnitFullName`, `UnitNameUnmodified`,
`UnitGUID` and `C_PlayerInfo.ShouldDisplaySurname`. Run it on a character whose surname is
set, and say which one that is. The three name rows show every return, comma-separated
(`Geo, nil` or `Geo, Classic Beta PvP`), so a surname or realm in the second slot shows up
too. I am reading which name row carries the surname, and whether
`UnitGUID` reads `ok` with a `Player-` value rather than `secret`. That decides whether the
roster can key characters by GUID instead of by a name that has already changed shape once.

## C3 — one dump on an Alchemist

Tradeskill challenges are type-7 skill thresholds (`Journeyman Alchemist` is skill line 2937,
`need = 150`), so any Alchemy skill above zero is real partial progress. Geo has Alchemy at 1.

1. On Geo, `/lgn dump challenges 1`. Journeyman, Expert and Artisan Alchemist are on page 1.
   Paste it.
2. `/lgn uidump`. Paste it.

What I am reading it for: `have` above 0 on the three type-7 criteria, and whether `completed`
stays false with it. The screenshot of 2026-10-01 already showed the three in their own "in
progress" tier, so the uidump is the text form of what you saw.

## C2 — events, via `/etrace`

Filter the trace to these five, then do the C3 session:

```
ACHIEVEMENT_EARNED
CRITERIA_UPDATE
TRAIT_CONFIG_UPDATED
TRAIT_TREE_CHANGED
MAJOR_FACTION_RENOWN_LEVEL_CHANGED
```

`CRITERIA_UPDATE` should fire as the Alchemy skill rises. `ACHIEVEMENT_EARNED` fires only on
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
