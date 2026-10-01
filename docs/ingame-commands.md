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
| S1 | `/lgn roster` at four points: after login, after `/reload`, on a second character, and after a full client restart. A fifth step, a one-line TOC edit and another restart, **only if the saved file did not come back**. **Best done as the C3 Alchemy session**, with the Alchemy character second. Section S1 below | Whether SavedVariables really load back now (reported fixed 2026-09-30, untested), and if not, whether `LoadSavedVariablesFirst` is the workaround. Everything in v1 rests on it. Also what `C_TradeSkillUI.GetProfessionInfoBySkillLineID(2937)` returns, and whether an Alchemy character's `GetProfessionInfo` skill line is 2937 or its parent. That decides the tradeskill→alt join. Unblocks both `pending` tests | ~5 min incl. a full restart, plus ~3 min if step 5 runs; the Alchemy half is free with C3 |
| D10 | `/lgn dump probe` on build 1.60.1.70124, **at the start of the S1 session**. Section D10 below | Whether "no secrets on our surface" still holds. It is a per-build finding, last tested on 69913, and the pin is now two builds past that | 30 s |
| U4 | `/lgn uidump roster`, then three screenshots: the Roster tab, the same tab scrolled to the bottom, and Next Up with the mouse over Journeyman Alchemist. **After S1's step 3**, so two characters are saved. Section U4 below | Whether the Roster tab reads right: the `P/A/R` and `Free` headings over their columns, the current character in gold, a tradeskill row naming the Alchemy character, the collapsed filter bar, and the footnote's last line in view. Content is checkable against `spec/golden/uidump_roster.txt`. Only the look needs your eyes | 2 min, same login as S1 |
| U1 | **Partly answered 2026-09-19** — the uidump came back and is written up in `docs/status.md`. Still open for the one thing it cannot show: **one screenshot of the window**, after a `/reload` on a build with the OnHide fix | Look only: spacing, alignment, whether the inset crops anything. Row content is already checked against `spec/golden/`. Section U1 below | 1 min |
| U3 | Look at the AddOns list at character select (or Escape > AddOns) after installing this build | Whether `## IconTexture` draws our 64x64 TGA at 20 px beside the addon name instead of the question mark. Section U3 below | 30 s |
| U5 | Click the minimap's addon dropdown (the small numbered button by the clock), then click `LegacyNext` in it, twice. Section U5 below | Whether Forever shows Blizzard's Addon Compartment at all, and whether our `## AddonCompartmentFunc` entry lists and toggles the window. Read from source only: the TOC loads it for `mainline`, and Forever's `camelot` type is inferred to count as `mainline` | 30 s, any login |
| U2 | The WoWLua block under U2 below | Whether a one-line FontString with word wrap off draws `...` or just clips (Tier C in `docs/ui-templates.md`), `IsTruncated()` on it, and `IsProtected()` on our frame | 2 min |
| C3 | A criterion sitting part-done. **Cheap way: train Alchemy and craft a few potions**, then `/lgn dump challenges 1` (Alchemy is on page 1). Section C3/D4 below | The mid-progress ranking fixture, and the first real "in progress" row for the three-tier ranking. Every captured criterion so far reads 0 | ~10 min, same session as D4. Forever's level requirement for training a profession is unchecked |
| D4 | `/lgn dump character` after training Alchemy for C3. A second primary plus cooking makes it more useful | `GetProfessions`' seven Forever slots, still unverified against a real return. Two characters so far knew none | Free with C3 |
| C2 | `/etrace` on the five events in section C2 below, during the C3 session | Which fire. The frame depends on `ACHIEVEMENT_EARNED` and `CRITERIA_UPDATE`, and neither has been seen firing on Forever. The other three decide whether trait and faction events are worth adding | Free with C3 |
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

## U1 — one screenshot of the window

The uidump half closed 2026-09-19 (`docs/status.md`, "U1 — the frame drew"). Still wanted:
`/lgn`, then a screenshot of the open window. I am judging the look only, since row content is
already checked against `spec/golden/`. Say if the middle dot in the header renders as a box.
`Model.SEPARATOR` is one line to change.

## U2 — truncation and protection

One WoWLua block, run with the window open:

```lua
local out = {};
local function w(s) out[#out+1] = s; end;
local f = LegacyNextFrame;
w("frame=" .. tostring(f ~= nil));
if f then local p, e = f:IsProtected(); w("IsProtected=" .. tostring(p) .. "," .. tostring(e)); end;
local fs = UIParent:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
fs:SetPoint("CENTER", 0, 200);
fs:SetWidth(120);
fs:SetWordWrap(false);
fs:SetText("Reach exalted reputation with the Frostwolf Clan");
w("truncated=" .. tostring(fs:IsTruncated()));
w("stringWidth=" .. tostring(fs:GetStringWidth()));
w("unbounded=" .. tostring(fs:GetUnboundedStringWidth()));
local x = C_XMLUtil and C_XMLUtil.GetTemplateInfo;
w("WowScrollBoxList=" .. tostring(x and x("WowScrollBoxList") ~= nil));
w("MinimalScrollBar=" .. tostring(x and x("MinimalScrollBar") ~= nil));
w("BasicFrameTemplateWithInset=" .. tostring(x and x("BasicFrameTemplateWithInset") ~= nil));
print(table.concat(out, " | "));
```

It prints one chat line and leaves a 120-pixel-wide test string near the top of the screen
(`/reload` clears it). Tell me the chat line, and whether the string on screen ends in `...`
or is cut off mid-word. That decides whether rows get an ellipsis for free or rely on the
tooltip alone. `IsProtected` should read `false,false`.

## U4 — the Roster tab

Do this after S1's step 3, on character B, so the roster holds two characters.

1. `/lgn uidump roster`. Paste it.
2. `/lgn`, click **Roster**, and take a screenshot. Then scroll to the bottom and take a second
   one, so the footnote's last line shows.
3. Click **Next Up**, hover Journeyman Alchemist, and take a screenshot with the tooltip showing.

What I am reading it for: in the paste, both characters with a tree figure and a `Free` number
instead of `?`, and a tradeskill row naming B if B trained Alchemy. In the screenshots, the
headings sitting over their columns, and whether a long tradeskill row is cut off. Since
2026-10-01 the footnote under the list is sized from its wrapped height, so its last line
should scroll fully into view. The tooltip should list B under "Saved characters with this profession". The middle dot in a
tradeskill row is the same `Model.SEPARATOR` as U1's header, so one answer covers both.

## U3 — the icon

Nothing to type. Open the AddOns list at character select, or Escape > AddOns. `LegacyNext`
should show the gold ring icon at 20 px instead of the question mark. If it is still the
question mark, or a green square (the client's "texture failed to load"), say which. The file
is `LegacyNext/Media/icon.tga`, and the TOC line is
`## IconTexture: Interface\AddOns\LegacyNext\Media\icon`.

## U5 — the minimap addon dropdown

Nothing to type. Look at the minimap for a small round button with a number on it, just below
the clock. Click it. `LegacyNext` should be listed with the gold ring icon. Click that entry
once and the window should open. Open the dropdown and click it again, and the window should
close. Say which of these happened:

- No numbered button at all. Forever does not load the compartment, or hides it.
- The button, but no `LegacyNext` in it. The compartment lists only addons enabled for **all
  characters** (`AddonCompartment.lua:80`), so check the AddOns list's character dropdown first.
- Listed, but the click does nothing or errors. Paste the error.

Also say whether the icon beside the name is the ring or a question mark. That is U3's question
from a second place.

## S1 — SavedVariables and the tradeskill join, via `/lgn roster`

No script. Each `/lgn roster` opens the copy window; paste all of it each time, `== RAW ==`
block included. The four pastes are four questions, so label them 1–4. Step 5 is conditional
and adds two more, 5a and 5b.

1. Log in character A, then `/lgn roster`. On the first run the `== STORE ==` line should read
   `loadedType=nil` (nothing saved yet) and `sessions=1`.
2. `/reload`, then `/lgn roster`. **This is the fix, or not:** `loadedType=table`,
   `loadedSessions=1` and `loadedCharacters=1` mean the file came back. `loadedType=nil` again
   means the bug is still there. A `snapshots saved by earlier sessions:` block with a
   `PLAYER_LOGOUT` line means the logout write ran and came back too. A `LATE LOAD` line means
   the client assigned the table after `ADDON_LOADED`, which would explain the original bug.
3. Log out to character select and log in character B, ideally the one that trained Alchemy
   for C3. Then `/lgn roster`. Both characters should be listed. B's professions line shows its
   skill line number in brackets, and the tradeskill section shows
   `[line 2937, parent N, profession M]`. Those numbers are the join. `parentsLive` in the RAW
   block is what the client said this session, zeros included, and is the fixture for the
   pending `api_spec` test.
4. Quit the game completely, relaunch, log in either character, then `/lgn roster`. A
   `/reload` can be served from memory; a restart has to come off disk. The original bug
   report was about the disk read, so this is the paste that closes the question.
5. **Only if 2 or 4 read `loadedType=nil` with no `LATE LOAD` line.** Quit the game. In
   `_classic_beta_/Interface/AddOns/LegacyNext/LegacyNext.toc`, add this line under the
   `## SavedVariablesPerCharacter:` line:

   ```
   ## LoadSavedVariablesFirst: 1
   ```

   Relaunch, log in, then `/lgn roster` (paste 5a). Then `/reload` and `/lgn roster` again
   (paste 5b). Blizzard's own challenge tracker loads its saved data with this line
   (`Blizzard_LegacyChallengeTracker.toc:6`), and ours does not have it. `loadedType=table` in
   5a or 5b means the line is the workaround, and it goes into our TOC. The next install
   overwrites your edit either way.

What I am reading it for: the `loaded*` fields in 2 and 4 (and in 5a and 5b if step 5 ran), whether `parent` is a number in
3, and whether B's bracketed skill line equals 2937 or that parent. If the lookup reads
`missing` or errors for 2937, say so. It means the join needs another route. Any
`events not registered:` line in any paste is C2 data. It lists an event this build does not
know.

## D10 — the probe on 1.60.1.70124

`/lgn dump probe`, then paste the whole window. Do it before S1's first `/lgn roster`, so the
two share a login.

What I am reading it for: the meta block's `build` reading 70124, `issecretvalue` reading
`guard active`, every constant and flag reading `(runtime)`, and no row reading `secret`. D2
and D5 are the baseline. A `secret` row is the finding that matters. It means Midnight's
restrictions reached an API we call, and it goes into `CLAUDE.md` before anything else.

## C3 and D4 — one Alchemy session

Tradeskill challenges are type-7 skill thresholds (`Journeyman Alchemist` is skill line 2937,
`need = 150`), so any Alchemy skill above zero is real partial progress. That is the one shape
C3 needs, and it does not need a long play session.

1. Start `/etrace` with the C2 filter below, and leave it running.
2. Train Alchemy. Craft until the skill reads a few points.
3. `/lgn dump challenges 1`. Journeyman, Expert and Artisan Alchemist are on page 1. Paste it.
4. `/lgn dump character`. Paste it. That is D4. If the character also has a second primary or
   cooking, better still.
5. `/lgn uidump`. Paste it. It should show Journeyman Alchemist in its own "in progress" tier
   above everything untouched.

What I am reading it for: `have` above 0 on a type-7 criterion, whether `completed` stays false
with it, and seven `GetProfessions` slots with the trained ones filled.

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
