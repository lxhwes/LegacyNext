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
| U1 | Install the Phase 3 build, `/lgn`, then `/lgn uidump` and paste it, plus one screenshot of the window | Whether the v0 frame renders at all, which templates it got (`BasicFrameTemplateWithInset`, `UIPanelScrollFrameTemplate`, Escape), whether the header and rows read right, and the cost of one read (`read took N ms`). Section U1 below | 5 min |
| U3 | Look at the AddOns list at character select (or Escape > AddOns) after installing this build | Whether `## IconTexture` draws our 64x64 TGA at 20 px beside the addon name instead of the question mark. Section U3 below | 30 s |
| D9 | `/lgn dump categories` | A complete `Api.GetCategories` capture in client order. Replaces `spec/fixtures/categories_partial.lua` (16 of 29, doc order) and un-pends the test in `spec/api/api_spec.lua` | 1 min |
| U2 | The WoWLua block under U2 below | Whether a one-line FontString with word wrap off draws `...` or just clips (Tier C in `docs/ui-templates.md`), `IsTruncated()` on it, and `IsProtected()` on our frame | 2 min |
| D4 | `/lgn dump character` on a character with professions | `GetProfessions`' seven Forever slots, still unverified against a real return. Two primaries plus cooking is the useful case. Two characters so far knew none | needs an alt |
| D8 | `/lgn dump challenges 2` … `6` **only if a Model test needs a specific Explore zone** | The 46 zero-point Explore achievements' ~600 subzone criteria. Deliberately not fixtured: Next Up excludes zero-point challenges, so this is dead weight until something needs it | 5 min, low value |
| C1 | Points spent in **two different trees** | Confirms the single shared pool, and what `maxQuantity` becomes once non-zero | needs play |
| C3 | A criterion sitting part-done | The mid-progress ranking fixture. Every captured criterion so far reads 0 | needs play |
| C4 | A completed challenge | `wasEarnedByMe` true, and whether completed entries sort before incomplete | needs play |
| C2 | `/etrace` on the four events below | Which of the four fire. The frame already registers `ACHIEVEMENT_EARNED` and `CRITERIA_UPDATE` and refreshes on show regardless; this decides whether the trait and faction events are worth adding | needs play |

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

See `docs/status.md` for what each finding changed.

Everything below is the detail behind a queue row: what to paste, and what I am reading it for.
Prefer `/lgn dump` and `/lgn probe` over the hand-written scripts — script 1 is kept only for
re-running after a build bump, when the addon itself is the thing in doubt.

---

## Section D — first run of the addon itself

Install: copy the `LegacyNext` folder (the inner one, with `LegacyNext.toc` in it) into
`_classic_beta_/Interface/AddOns/`, so you end up with
`_classic_beta_/Interface/AddOns/LegacyNext/LegacyNext.toc`. Enable it at the character
select screen, log in.

**D1 — does it load.** On login you should see one line in chat:

```
LegacyNext: 0.0.1 loaded. /lgn to open, /lgn help for commands.
```

(The Phase 3 build dropped the `v` prefix and added the hint; the D1 run saw
`LegacyNext: v0.0.1 loaded.`)

If nothing appears, check the addon is enabled and not marked out of date. Tell me the exact
error text if the client throws one — the client stops reporting Lua errors after 100, so grab
the first, not the last.

**D2 — the probe.** This is the important one. It prints one line per API we depend on.

```
/lgn probe
```

Expected: every line `ok` except `issecretvalue`, which may legitimately be `missing` on this
build. **Paste the whole thing back.** What I am reading it for:

- any `missing` — the API is not on this client and `Api/` has to route around it
- any `error` — we are calling it with the wrong arguments
- any `secret` — the Midnight restrictions do reach our surface after all, which would be the
  most important thing to come out of this whole phase
- `Constants.LegacyConsts.*` reading `(fallback)` rather than `(runtime)` — means the constants
  table moved and the hardcoded literals are carrying us

**D3 — the dump.** Opens a movable window with a Lua literal in it. Ctrl-A, Ctrl-C, paste back.

```
/lgn dump summary
```

Start with `summary`: it is a few lines and confirms the numbers agree with the section B
sweep (111 challenges, 65 points, 18 progress-bar, 59 checklist, 34 with no criteria). If those
match, the enumeration is correct and everything below is just volume.

Then the sections, smallest first:

```
/lgn dump character
/lgn dump trees
/lgn dump rewards
/lgn dump challenges 1
```

`challenges` is paged 20 at a time because the full list is large — `/lgn dump challenges 2`
for the next page, and so on. `/lgn dump` with no argument dumps everything in one go; try it,
but if the copy comes back truncated, fall back to sections. The window tells you the character
count when it is big enough to be a risk.

Each dump is a `return { ... }` table and nothing else — no comment lines, so it still parses
if the paste path eats the newlines. These go straight into `spec/fixtures/`.

**D4 — professions, if the character has any.** `/lgn dump character` is the check. Forever's
own code reads seven slots from `GetProfessions` where retail reads six, and we iterate rather
than naming them, so I want to see what a real character comes back with. A character with two
primaries and cooking is the useful case.

**What section D unblocks:** everything. Once `dump` works, section C below stops needing
hand-written scripts — the answers fall out of `/lgn dump trees` and `/lgn dump challenges`
once you have points spent and progress made.

### D4–D7 — the re-run, after the guard fix (queued 2026-09-19)

D1–D3 passed and found one bug in our own copy guard, now fixed: `GetMajorFactionData` was
thrown away whole because of a ColorMixin field, which killed the reward track.
**Copy the addon folder over again before this run** — the installed copy is the broken one.

One session, in this order:

```
/lgn probe                     D5
/lgn dump rewards              D6
/lgn dump character            D4  (on a character with professions, if you have one)
/lgn dump challenges 2         D7  (through 6)
```

- **D5** should read `ok=29 partial=1` or similar, with
  `partial C_MajorFactions.GetMajorFactionData ... dropped return1.factionFontColor.color.<method>`.
  A `partial` line naming the dropped method is the fix working. Still `error` means the drop
  policy did not catch it and I need the new detail string.
- **D6** is the one that was dead. It should carry `name`, `maxLevel`, four thresholds and
  reward entries.
- **D4** needs an alt. Forever reads seven slots from `GetProfessions` where retail reads six;
  the level 1 Shaman knew none, so the shape is unverified. Two primaries plus cooking is ideal.
- **D7** is optional. Page 1 already covers every criteria shape; 2–6 only widen the sample.

Note the section name is `character`, singular. `characters` used to dump nothing at all; it
now tells you the valid list instead.

## Section U — the v0 frame (queued 2026-09-19)

**Copy the addon folder over again first.** This build adds `Model/`, `UI/`, `/lgn` as a
window, `/lgn uidump` and a `categories` dump section.

**U1 — does the window render.** Log in, then:

```
/lgn
/lgn uidump
```

`/lgn` opens the Next Up window. Look at it, take a screenshot, press Escape (it should
close), `/lgn` again. Then `/lgn uidump` opens the copyable window with what the frame
rendered as text: header lines, filter bar with counts, every row, a state line, and a
`== CLIENT ==` footer with `read took N ms` and which templates the frame got. **Paste the
whole uidump back.** What I am reading it for:

- The header should read `Legacy Track  ·  0 pts  ·  15 to next` then
  `Next: Replica Ironforge Air Rifle` (or your current numbers). If the middle dot renders as
  a box in the screenshot, say so; `Model.SEPARATOR` is one line to change.
- `== FILTERS ==` should be `[All 65] | Classes 27 | Tradeskills 18 | Dungeons 3 | Raids 3 |
  Player vs. Player 12 | Adventure 2` on an untouched account, in the client's category order
  (Adventure holds two point-bearing challenges of its own; the 46 Explore entries are
  zero-point and excluded).
  A group named `Category 15568` means `GetCategories` did not return names.
- Rows: measurable ones first with `0/150`-style figures, a `no progress shown` divider, then
  the 34 measureless ones. Any row showing `?` means a criteria list came back short.
- `read took N ms` is the one number nobody has: the ~900-call sweep. Under 100 ms and the
  event refresh is fine as built; over 500 ms and refresh needs to move off `CRITERIA_UPDATE`.
- `frame { ... }` names the templates. `frameTemplate = "plain"` or `scrollTemplate = "plain"`
  means a fallback fired and the screenshot will look bare; still usable, but tell me.
- Filter buttons: click a couple. `/lgn uidump classes` shows the same filtered view as text.

If `/lgn` throws a Lua error, paste the first one; the client stops after 100.

**U2 — truncation and protection.** One WoWLua block, run with the window open:

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
or is simply cut off mid-word. That decides whether rows need a tooltip-only fallback for
long names or get an ellipsis for free. `IsProtected` should read `false,false`.

**U3 — the icon.** Nothing to type. Open the AddOns list at character select, or in game via
Escape > AddOns. `LegacyNext` should show the gold ring icon at 20 px where every addon without
an icon shows a question mark. If it is still the question mark, or a green square (the
client's "texture failed to load"), say which. The file is `LegacyNext/Media/icon.tga`; the
line is `## IconTexture: Interface\AddOns\LegacyNext\Media\icon` in the TOC. PNG support on
this client is unverified, which is why the file is TGA (`docs/icon-design.md`).

**D9 — categories.** `/lgn dump categories`, paste it. Goes straight into
`spec/fixtures/`, replacing the assembled partial one.

## How to run these

Paste into **WoWLua**, hit run. Output goes to a copyable EditBox; select all, ctrl-C, paste
it back.

**These scripts survive having their newlines stripped.** Every statement is
semicolon-terminated and there are no `--` comments, so they parse as one long line too. If
you edit them, keep both properties — a `--` comment in a flattened script swallows everything
after it, and a missing semicolon produces `malformed number near '2802local'`.

Script 1 was the prototype for `Debug/`, which has since shipped as `/lgn dump`.

---

## Script 1 — the whole of section B, one paste

Runs on any character, no progress needed. Answers B1 through B6 in a single pass: every
category, every challenge with its criteria count and point value, the point total, which
challenges use the progress-bar shape, full criteria for one of each shape, a full
`GetAchievementInfo` row, and every reward entry.

```lua
local CUR, FACTION = 4225, 2802;
local out = {};
local function w(s) out[#out+1] = s; end;
local function n(v) if v == nil then return "nil"; end return tostring(v); end;
local cats = GetCategoryList();
w("== CATEGORIES ==");
w("catID;name;parent;num;complete;incomplete");
for _, c in ipairs(cats) do local nm, pa = GetCategoryInfo(c); local a, cm, ic = GetCategoryNumAchievements(c); w(n(c)..";"..n(nm)..";"..n(pa)..";"..n(a)..";"..n(cm)..";"..n(ic)); end;
w("");
w("== CHALLENGES ==");
w("catID;achID;name;numCriteria;points;completed;flags");
local total, count, bars, checks = 0, 0, {}, {};
for _, c in ipairs(cats) do for i = 1, (GetCategoryNumAchievements(c) or 0) do local id, nm, _, done, _, _, _, _, fl = GetAchievementInfo(c, i); local nc = GetAchievementNumCriteria(id) or 0; local pts = C_Traits.GetTraitCurrencyForAchievement(CUR, id) or 0; total = total + pts; count = count + 1; w(n(c)..";"..n(id)..";"..n(nm)..";"..n(nc)..";"..n(pts)..";"..n(done)..";"..n(fl)); if nc > 0 then local _, _, _, _, _, _, cf = GetAchievementCriteriaInfo(id, 1); if cf and bit.band(cf, 1) == 1 then bars[#bars+1] = id; else checks[#checks+1] = id; end; end; end; end;
w("");
w("== SUMMARY ==");
w("challenges="..count.."  totalPoints="..total);
w("progressBar="..#bars.."  checklist="..#checks);
w("barIDs="..table.concat(bars, ","));
local function crit(id, label) w(""); if not id then w("== CRITERIA "..label..": none found =="); return; end; local _, an = GetAchievementInfo(id); w("== CRITERIA "..label.." ach="..n(id).." "..n(an).." =="); w("i;string;type;completed;quantity;reqQuantity;charName;flags;assetID;quantityString"); for i = 1, (GetAchievementNumCriteria(id) or 0) do local s, ct, cp, q, rq, cn, f, ai, qs = GetAchievementCriteriaInfo(id, i); w(i..";"..n(s)..";"..n(ct)..";"..n(cp)..";"..n(q)..";"..n(rq)..";"..n(cn)..";"..n(f)..";"..n(ai)..";"..n(qs)); end; end;
crit(bars[1], "PROGRESSBAR");
crit(checks[1], "CHECKLIST");
local sample = bars[1] or checks[1];
if sample then w(""); w("== GetAchievementInfo("..sample..") 14 returns =="); local v, t = {GetAchievementInfo(sample)}, {}; for i = 1, 14 do t[i] = n(v[i]); end; w(table.concat(t, ";")); end;
w("");
w("== REWARDS ==");
w("level;idx;name;toast;rewardType;itemID;spellID;mountID;titleMaskID;icon;isCollected");
for _, lvl in ipairs({15, 25, 40, 55}) do local r = C_MajorFactions.GetRenownRewardsForLevel(FACTION, lvl); if r and r[1] then for j, e in ipairs(r) do w(lvl..";"..j..";"..n(e.name)..";"..n(e.toastDescription)..";"..n(e.rewardType)..";"..n(e.itemID)..";"..n(e.spellID)..";"..n(e.mountID)..";"..n(e.titleMaskID)..";"..n(e.icon)..";"..n(e.isCollected)); end; else w(lvl..";none"); end; end;
local text = table.concat(out, "\n");
text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", "!");
if not LNDump then local f = CreateFrame("Frame", "LNDump", UIParent); f:SetSize(760, 520); f:SetPoint("CENTER"); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing); local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0, 0, 0, 0.92); local sf = CreateFrame("ScrollFrame", "LNDumpScroll", f, "UIPanelScrollFrameTemplate"); sf:SetPoint("TOPLEFT", 12, -12); sf:SetPoint("BOTTOMRIGHT", -32, 12); local eb = CreateFrame("EditBox", nil, sf); eb:SetMultiLine(true); eb:SetFontObject(ChatFontNormal); eb:SetWidth(700); eb:SetAutoFocus(false); eb:SetScript("OnEscapePressed", function() f:Hide(); end); sf:SetScrollChild(eb); f.eb = eb; end;
LNDump:Show();
LNDump.eb:SetText(text);
LNDump.eb:HighlightText();
LNDump.eb:SetFocus();
```

**What I need back:** all of it ideally, but `SUMMARY`, both `CRITERIA` blocks and `REWARDS`
are the parts that unblock work. `CHALLENGES` is 111 lines and mostly useful for the points
breakdown.

**What I'm reading it for:**

- `totalPoints` should be **65**. If it isn't, points come from somewhere we haven't found.
- `progressBar` versus `checklist` counts — how much the ranking logic leans on fractions.
- The two `CRITERIA` blocks become the first fixtures in `spec/fixtures/`.
- `GetAchievementInfo` return order confirmed on Forever, and whether any `flags` has 131072.
- Whether rewards at 40 and 55 carry a `name`, and whether any is a mount or title.

Output has `|` replaced with `!`, so any bars you see were colour codes in the game text.

---

## Script 2 — later, once you've played

Needs points spent in **two different trees**, and ideally one challenge part-done and one
completed. Covers C1, C3 and C4. Prints to chat since the output should be short.

```lua
local CUR = 4225;
local out = {};
local function w(s) out[#out+1] = s; end;
local function n(v) if v == nil then return "nil"; end return tostring(v); end;
w("== TREE CURRENCY ==");
w("treeID;configID;quantity;maxQuantity;spent;spentInTree");
for _, id in ipairs({1187, 1188, 1189}) do local cfg = C_Traits.GetConfigIDByTreeID(id); local t = cfg and C_Traits.GetTreeCurrencyInfo(cfg, id, true); local i = t and t[1]; w(n(id)..";"..n(cfg)..";"..n(i and i.quantity)..";"..n(i and i.maxQuantity)..";"..n(i and i.spent)..";"..n(i and i.spentInTree)); end;
w("maxAvailable(false)="..n(C_Traits.GetMaxAvailableTraitCurrency(CUR, false)));
w("maxAvailable(true)="..n(C_Traits.GetMaxAvailableTraitCurrency(CUR, true)));
w("renownLevel="..n(C_MajorFactions.GetCurrentRenownLevel(2802)));
w("");
w("== PROGRESS AND COMPLETIONS ==");
w("achID;name;i;criteria;completed;quantity;reqQuantity;flags;wasEarnedByMe");
for _, c in ipairs(GetCategoryList()) do for k = 1, (GetCategoryNumAchievements(c) or 0) do local id, nm, _, done, _, _, _, _, _, _, _, _, mine = GetAchievementInfo(c, k); for i = 1, (GetAchievementNumCriteria(id) or 0) do local s, _, cp, q, rq, _, f = GetAchievementCriteriaInfo(id, i); if done or cp or (q and q > 0) then w(n(id)..";"..n(nm)..";"..i..";"..n(s)..";"..n(cp)..";"..n(q)..";"..n(rq)..";"..n(f)..";"..n(mine)); end; end; end; end;
local text = table.concat(out, "\n");
text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", "!");
print(text);
```

**What I'm reading it for:**

- `spent` identical across all three trees while `spentInTree` differs confirms the single
  shared 16-point pool.
- What `maxQuantity` becomes once points exist — it read **0** at zero points, so it is not
  the static cap. Until this resolves, `Model/` uses `GetMaxAvailableTraitCurrency(4225, true)`.
- A criterion with non-zero `quantity` — the mid-progress fixture the ranking tests need.
- `wasEarnedByMe` true on anything completed.

If it floods chat, swap the final `print(text);` for the `LNDump` block from script 1.

---

## C2 — events, now just `/etrace`

The probe script is retired. Open the event trace, filter to these four, then spend a Legacy
point and make some challenge progress:

```
TRAIT_CONFIG_UPDATED
TRAIT_TREE_CHANGED
MAJOR_FACTION_RENOWN_LEVEL_CHANGED
CRITERIA_UPDATE
```

Tell me which fire and what payload `TRAIT_CONFIG_UPDATED` carries. Blizzard's Legacy UI
registers none of the trait or faction ones — it re-reads on show — so we have no precedent
and our refresh strategy depends on this.

---

## If script 1 errors

The EditBox block uses `UIPanelScrollFrameTemplate`, `ChatFontNormal` and `SetColorTexture`.
All three were verified on Forever 2026-09-19: the `/lgn dump` window is built on exactly
them and produced every committed fixture. The fallback stays because a build bump can remove
any of them. If one is missing, replace
everything from `if not LNDump then` to the end with:

```lua
for _, line in ipairs(out) do print(line); end;
```

and tell me what errored. That's worth knowing either way — those are the primitives `Debug/`
will be built on.

## Note on idTip

The scripts enumerate IDs themselves, so you don't need it here. It earns its keep for spot
checks — hover a challenge in the Legacy UI, get its ID, ask me about that one without running
a sweep.
