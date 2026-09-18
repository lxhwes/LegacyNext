# In-game work

Working list for beta sessions. See `docs/status.md` for what is still outstanding and what
it blocks.

Section A is done (2026-09-18) — constants, category tree, tree names, account flag, trait
config, point caps, reward track. Written up in `docs/legacy-internals.md`.

## How to run these

Paste into **WoWLua**, hit run. No 255-character limit, so these are whole scripts rather
than golfed one-liners.

Each script builds its output into a copyable EditBox instead of printing to chat. Select all,
ctrl-C, paste it back. If the window fails to appear, the script is still fine — see
**Fallback** at the bottom for a one-line change that prints to chat instead.

Script 1 is a prototype of what `Debug/` will eventually do properly.

---

## Script 1 — the whole of section B, one paste

Runs on any character, no progress needed. Answers B1 through B6 in a single pass: every
category, every challenge with its criteria count and point value, the point total, which
challenges use the progress-bar shape, full criteria for one of each shape, a full
`GetAchievementInfo` row, and the remaining reward entries.

```lua
local CUR, FACTION = 4225, 2802
local out = {}
local function w(s) out[#out+1] = s end
local function n(v) if v == nil then return "nil" end return tostring(v) end

local cats = GetCategoryList()

w("== CATEGORIES ==")
w("catID;name;parent;num;complete;incomplete")
for _, c in ipairs(cats) do
	local name, parent = GetCategoryInfo(c)
	local a, cm, ic = GetCategoryNumAchievements(c)
	w(n(c)..";"..n(name)..";"..n(parent)..";"..n(a)..";"..n(cm)..";"..n(ic))
end

w("")
w("== CHALLENGES ==")
w("catID;achID;name;numCriteria;points;completed;flags")
local total, count = 0, 0
local bars, checks = {}, {}
for _, c in ipairs(cats) do
	for i = 1, (GetCategoryNumAchievements(c) or 0) do
		local id, name, _, completed, _, _, _, _, flags = GetAchievementInfo(c, i)
		local nc = GetAchievementNumCriteria(id) or 0
		local pts = C_Traits.GetTraitCurrencyForAchievement(CUR, id) or 0
		total, count = total + pts, count + 1
		w(n(c)..";"..n(id)..";"..n(name)..";"..n(nc)..";"..n(pts)..";"..n(completed)..";"..n(flags))
		if nc > 0 then
			local _, _, _, _, _, _, cf = GetAchievementCriteriaInfo(id, 1)
			if cf and bit.band(cf, 1) == 1 then
				bars[#bars+1] = id
			else
				checks[#checks+1] = id
			end
		end
	end
end

w("")
w("== SUMMARY ==")
w("challenges="..count.."  totalPoints="..total)
w("progressBar="..#bars.."  checklist="..#checks)
w("barIDs="..table.concat(bars, ","))

local function criteria(id, label)
	w("")
	if not id then w("== CRITERIA "..label..": none found ==") return end
	local _, aname = GetAchievementInfo(id)
	w("== CRITERIA "..label.." ach="..n(id).." "..n(aname).." ==")
	w("i;string;type;completed;quantity;reqQuantity;charName;flags;assetID;quantityString")
	for i = 1, (GetAchievementNumCriteria(id) or 0) do
		local s, ct, comp, q, rq, cn, f, aid, qs = GetAchievementCriteriaInfo(id, i)
		w(i..";"..n(s)..";"..n(ct)..";"..n(comp)..";"..n(q)..";"..n(rq)..";"..n(cn)..";"..n(f)..";"..n(aid)..";"..n(qs))
	end
end
criteria(bars[1], "PROGRESSBAR")
criteria(checks[1], "CHECKLIST")

local sample = bars[1] or checks[1]
if sample then
	w("")
	w("== GetAchievementInfo("..sample..") 14 returns ==")
	local v, t = {GetAchievementInfo(sample)}, {}
	for i = 1, 14 do t[i] = n(v[i]) end
	w(table.concat(t, ";"))
end

w("")
w("== REWARDS ==")
w("level;idx;name;toastDescription;rewardType;itemID;spellID;mountID;titleMaskID;icon;isCollected")
for _, lvl in ipairs({15, 25, 40, 55}) do
	local r = C_MajorFactions.GetRenownRewardsForLevel(FACTION, lvl)
	if r and r[1] then
		for j, e in ipairs(r) do
			w(lvl..";"..j..";"..n(e.name)..";"..n(e.toastDescription)..";"..n(e.rewardType)..";"..n(e.itemID)..";"..n(e.spellID)..";"..n(e.mountID)..";"..n(e.titleMaskID)..";"..n(e.icon)..";"..n(e.isCollected))
		end
	else
		w(lvl..";none")
	end
end

local text = table.concat(out, "\n")
text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", "!")

if not LNDump then
	local f = CreateFrame("Frame", "LNDump", UIParent)
	f:SetSize(760, 520)
	f:SetPoint("CENTER")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.92)
	local sf = CreateFrame("ScrollFrame", "LNDumpScroll", f, "UIPanelScrollFrameTemplate")
	sf:SetPoint("TOPLEFT", 12, -12)
	sf:SetPoint("BOTTOMRIGHT", -32, 12)
	local eb = CreateFrame("EditBox", nil, sf)
	eb:SetMultiLine(true)
	eb:SetFontObject(ChatFontNormal)
	eb:SetWidth(700)
	eb:SetAutoFocus(false)
	eb:SetScript("OnEscapePressed", function() f:Hide() end)
	sf:SetScrollChild(eb)
	f.eb = eb
end
LNDump:Show()
LNDump.eb:SetText(text)
LNDump.eb:HighlightText()
LNDump.eb:SetFocus()
```

**What I need back:** all of it, but if it's too much, the `SUMMARY`, both `CRITERIA` blocks
and `REWARDS` are the parts that unblock work. The `CHALLENGES` block is 111 lines and is
mostly useful for the points breakdown.

**What I'm reading it for:**

- `totalPoints` should be **65**. If it isn't, points come from somewhere we haven't found.
- `progressBar` versus `checklist` counts — how much the ranking logic leans on fractions.
- The two `CRITERIA` blocks become the first fixtures in `spec/fixtures/`.
- `GetAchievementInfo` order confirmed on Forever, and whether any `flags` has 131072 set.
- Whether rewards at 40 and 55 have a `name`, and whether any is a mount or title rather than
  an item.

Note the script replaces `|` with `!` in output, so any pipes you see in names were colour
codes or literal bars in the game text.

---

## Script 2 — later, once you've played

Needs points spent in **two different trees**, and ideally one challenge part-done and one
completed. Covers C1, C3 and C4.

```lua
local CUR = 4225
local out = {}
local function w(s) out[#out+1] = s end
local function n(v) if v == nil then return "nil" end return tostring(v) end

w("== TREE CURRENCY ==")
w("treeID;configID;quantity;maxQuantity;spent;spentInTree")
for _, id in ipairs({1187, 1188, 1189}) do
	local cfg = C_Traits.GetConfigIDByTreeID(id)
	local t = cfg and C_Traits.GetTreeCurrencyInfo(cfg, id, true)
	local i = t and t[1]
	w(n(id)..";"..n(cfg)..";"..n(i and i.quantity)..";"..n(i and i.maxQuantity)..";"..n(i and i.spent)..";"..n(i and i.spentInTree))
end
w("maxAvailable(false)="..n(C_Traits.GetMaxAvailableTraitCurrency(CUR, false)))
w("maxAvailable(true)="..n(C_Traits.GetMaxAvailableTraitCurrency(CUR, true)))
w("renownLevel="..n(C_MajorFactions.GetCurrentRenownLevel(2802)))

w("")
w("== IN-PROGRESS AND COMPLETED CHALLENGES ==")
w("achID;name;i;criteria;completed;quantity;reqQuantity;flags;wasEarnedByMe")
for _, c in ipairs(GetCategoryList()) do
	for k = 1, (GetCategoryNumAchievements(c) or 0) do
		local id, name, _, done, _, _, _, _, _, _, _, _, mine = GetAchievementInfo(c, k)
		for i = 1, (GetAchievementNumCriteria(id) or 0) do
			local s, _, comp, q, rq, _, f = GetAchievementCriteriaInfo(id, i)
			if done or comp or (q and q > 0) then
				w(n(id)..";"..n(name)..";"..i..";"..n(s)..";"..n(comp)..";"..n(q)..";"..n(rq)..";"..n(f)..";"..n(mine))
			end
		end
	end
end

local text = table.concat(out, "\n")
text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", "!")
print(text)
```

This one prints to chat since the output should be short. If it floods, swap the last line for
the EditBox block from script 1.

**What I'm reading it for:**

- `spent` identical across all three trees while `spentInTree` differs confirms the single
  shared 16-point pool.
- What `maxQuantity` becomes once points exist — it read **0** at zero points, so it is not
  the static cap. Until this resolves, `Model/` uses `GetMaxAvailableTraitCurrency(4225, true)`.
- A criterion with non-zero `quantity` — the mid-progress fixture the ranking tests need.
- `wasEarnedByMe` true on anything you've completed.

---

## C2 — events, now just `/etrace`

The probe script is retired. Open the event trace, filter to these four, spend a Legacy point
and make some challenge progress:

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

## Fallback

If the EditBox window doesn't appear in script 1 — `UIPanelScrollFrameTemplate`,
`ChatFontNormal` or `SetColorTexture` not existing on this client would do it — replace
everything from `if not LNDump then` to the end with:

```lua
for _, line in ipairs(out) do print(line) end
```

and tell me which line errored. That's useful in itself: those are all things `Debug/` will
need, and I'd rather find out now than when writing it.

## Note on idTip

The scripts enumerate IDs themselves, so you don't need it for these. It earns its keep for
spot checks — hover a challenge in the Legacy UI, get its ID, and ask me about that one
specifically without running a sweep.
