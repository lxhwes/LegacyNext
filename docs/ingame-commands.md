# In-game commands to run

Working list for beta sessions. Sections get marked done as results come back; see
`docs/status.md` for what is still outstanding and what it blocks.

**Chat and macros cap at 255 characters.** Every `/run` below is under that on purpose. Keep
each one on a single line.

---

## Section A — done 2026-09-18

Constants, category tree, tree names, account flag, trait config, point caps, reward track.
All written up in `docs/legacy-internals.md`. Nothing to re-run.

What it settled, for context while running the rest:

- `GetCategoryList()` returns only Legacy categories — 29, two levels deep, **111 challenges**
- 65 earnable account-wide, 16 spendable per character, **one shared pool across all three trees**
- Tree 1189 is "Resourcefulness"; all three trees share configID 2866866
- Reward thresholds are **15, 25, 40, 55**; `renownLevel` is the earned point count

---

## Section B — runs now, no progress needed

Achievement and criteria *definitions* are static client data. None of this needs an earned
challenge. The only thing you can't get yet is a criterion sitting part-done — that's C3.

### B1 — sweep a category

Prints `id, name, numCriteria, points` for every challenge in one category.

```
/run local c=15593 for i=1,GetCategoryNumAchievements(c) do local id,n=GetAchievementInfo(c,i) print(id,n,GetAchievementNumCriteria(id),C_Traits.GetTraitCurrencyForAchievement(4225,id)) end
```

Change the `15593` and run it on a few. Good candidates, all small:

| ID | Category | Count | Why |
|---|---|---|---|
| 15593 | Dungeons | 3 | most likely to hold a counted "run N dungeons" criterion |
| 15587 | Alchemy | 3 | profession shape, matters for v1's alt mapping |
| 15597 | Ranks | 5 | PvP, largest of the PvP children |
| 15607 | Explorer | 3 | exploration shape |
| 15577 | Druid | 3 | class-leveling shape, matters for v1 |
| 15596 | Adventure | 2 | the only top-level group with challenges of its own |

*Looking for:* which challenges are worth 0 points — 111 challenges against 65 points means
plenty must be. And which have criteria worth dumping.

### B2 — all criteria of one challenge

Substitute an ID from B1 that showed a non-zero criteria count.

```
/run local a=AID for i=1,GetAchievementNumCriteria(a) do print(i,GetAchievementCriteriaInfo(a,i)) end
```

Prints all nine returns per criterion: `criteriaString, criteriaType, completed, quantity,
reqQuantity, charName, criteriaFlags, assetID, quantityString`.

*Looking for:* **one challenge where `criteriaFlags` has bit 1 set and one where it doesn't.**
That's the whole point of B — flag set means the progress-bar shape that gives us "3/5", flag
clear means a checklist where remaining is a count of unticked rows. Two challenges is enough
to seed `spec/fixtures/`.

### B3 — the full info row for one challenge

```
/dump GetAchievementInfo(AID)
```

All 14 returns in order: `id, name, points, completed, month, day, year, description, flags,
icon, rewardText, isGuild, wasEarnedByMe, earnedBy`.

*Looking for:* confirmation of the return order on Forever, and whether `flags` has 131072
(`ACHIEVEMENT_FLAGS_ACCOUNT`) set on any of them. Also whether `points` — the achievement's
own value, which the Legacy UI throws away — is 0 or something else.

### B4 — do the points add up to 65

```
/run local t=0 for _,c in ipairs(GetCategoryList()) do for i=1,GetCategoryNumAchievements(c) do local id=GetAchievementInfo(c,i) t=t+C_Traits.GetTraitCurrencyForAchievement(4225,id) end end print("total points",t)
```

*Looking for:* 65. If it comes out 65, `GetTraitCurrencyForAchievement` is complete and
trustworthy and our "points available from remaining challenges" number is sound. If it
doesn't, some points come from somewhere we haven't found.

### B5 — find every counted challenge at once (optional)

Two commands, in order. Only worth it if B1/B2 don't turn up a progress-bar criterion quickly.

```
/run function LNF(id) local n=GetAchievementNumCriteria(id) if not n or n<1 then return end local _,_,_,_,rq,_,f=GetAchievementCriteriaInfo(id,1) if bit.band(f or 0,1)==1 then print(id,rq) end end
```

```
/run for _,c in ipairs(GetCategoryList()) do for i=1,GetCategoryNumAchievements(c) do LNF((GetAchievementInfo(c,i))) end end
```

*Looking for:* every challenge whose first criterion uses a progress bar, with its
`reqQuantity`. Cross-reference IDs against B1 for names. Tells me how common the counted shape
is, which decides how much the ranking logic leans on it.

### B6 — the remaining two rewards

```
/dump C_MajorFactions.GetRenownRewardsForLevel(2802, 40)
/dump C_MajorFactions.GetRenownRewardsForLevel(2802, 55)
```

*Looking for:* whether `name` is present. Level 15 had no `name` field and level 25 did, both
had `toastDescription`. Two more samples tell me whether that's a beta authoring gap or normal,
and whether any reward is a mount or title rather than an item (`rewardType` was 1 on both
samples — I have no second value to compare).

---

## Section C — needs an actually played character

No rush on any of these. C1 and C2 want points spent; C3 and C4 want challenge progress.

### C1 — confirm the shared pool, and what maxQuantity really is

Needs points spent in **two different trees**.

```
/run for _,id in ipairs({1187,1188,1189}) do local c=C_Traits.GetConfigIDByTreeID(id) local t=c and C_Traits.GetTreeCurrencyInfo(c,id,true) local i=t and t[1] print(id,c,i and i.quantity,i and i.maxQuantity,i and i.spent,i and i.spentInTree) end
```

*Looking for:* two things. `spent` identical across all three trees while `spentInTree`
differs confirms the single shared 16-point pool. And `maxQuantity` — it read **0** at zero
points, so it is not the static cap. If it now reads 16, it's the cap after all; if it tracks
points earned, it's a different number entirely. Until this resolves, `Model/` takes the cap
from `GetMaxAvailableTraitCurrency(4225, true)`.

### C2 — which events actually fire

Two commands, in order:

```
/run LNP=CreateFrame("Frame") LNP:SetScript("OnEvent",function(_,e,...) print("EVT",e,...) end)
```

```
/run for _,e in ipairs({"TRAIT_CONFIG_UPDATED","TRAIT_TREE_CHANGED","MAJOR_FACTION_RENOWN_LEVEL_CHANGED","CRITERIA_UPDATE","ACHIEVEMENT_EARNED"}) do LNP:RegisterEvent(e) end
```

Then spend a Legacy point and make some challenge progress.

*Looking for:* which of the five fire, and what `TRAIT_CONFIG_UPDATED` carries. Blizzard's
Legacy UI registers none of the trait or faction ones — it re-reads on show instead — so I
have no precedent and our refresh strategy depends on this. Lasts until `/reload` or logout.

### C3 — a criterion sitting part-done

Once something is at 3/5, re-run **B2** on it.

*Looking for:* a non-zero `quantity`. Until this exists the ranking tests stay `pending` — I'm
not inventing a fixture shape.

### C4 — a completed challenge

Re-run **B3** on something you've earned.

*Looking for:* `wasEarnedByMe` (position 13) true, and a non-zero date. Also re-run **B1** on
that challenge's category: the source claims completed entries sort before incomplete ones in
index order, and that's only visible once a category has one of each.
