# Legacy internals

Read-only research against the pinned `wow-ui-source` checkout (`forever`), written at
`70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e` (`version.txt` `1.60.1.69913`). Every citation here
still resolves unchanged at `bd2470aed543f72697a044e989285b6c83e63f73` (`1.60.1.70009`),
checked 2026-09-26, and at the current pin, `966519cf0ad2c10301ea011a88c14b25697c9687`
(`1.60.1.70124`), checked 2026-09-30. See `vendor/PINS.md`.

Citations are `path:line`, rooted at `Interface/AddOns/` in the shared checkout
(`vendor/wow-ui-source` until 2026-10-04, `$WOW_FOREVER_SRC/wow-ui-source` since).

Three directories cited here sit outside the sparse set recorded in `vendor/PINS.md`:
`Blizzard_MicroMenu`, `Blizzard_SharedTalentUI` and `Blizzard_MajorFactions`. PINS.md keeps
the full list. `Blizzard_FrameXML` and `Blizzard_FrameXMLBase` were on it until the 2026-09-19
widening brought them in. The three were read by temporarily widening the sparse checkout to
`Interface` at the same SHA, then narrowing back. To re-read them:

```sh
cd vendor/wow-ui-source && git sparse-checkout set Interface   # 53 MB, 4405 files
```

## Summary

| | Question | Status |
|---|---|---|
| Q1 | Challenge enumeration | **Answered**, verified in game |
| Q2 | Category representation | **Answered**, full category tree captured |
| Q3 | Points per challenge | **Answered** |
| Q4 | Criteria in the detail pane | **Answered** |
| Q5 | Account-wide vs per-character | **Answered**, flag value verified |
| Q6 | What the Challenge Tracker does | **Answered** |
| Q7 | Spent / unspent / cap | **Answered**; cap source found, one recheck at non-zero points |
| Q8 | Tree 1189 display name | **Answered** — "Resourcefulness" |
| Q9 | `LEGACY_TREE_ADVENTURE_TALENTED_NODE_ID` | **Answered** |
| Q10 | Reward track math | **Answered**, fully verified |
| Q11 | Load-on-demand | **Answered** |
| Q12 | Events | **Answered from source**; which ones fire live is queue row C2 |

---

## Challenges

### Q1. How Blizzard enumerates Legacy challenges

Not hardcoded, and there is no Legacy-specific enumeration API. The page walks the ordinary
achievement category list and filters it.

1. `GetCategoryList()` returns every category ID — `Blizzard_LegacySystem/Blizzard_LegacyChallenges.lua:79`.
   This is the same global the retail Achievement UI calls
   (`Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.lua:146,161`). No Legacy filtering
   is applied to it anywhere in the pinned source.
2. A category is kept if `HasChallenges(categoryID)` — `Blizzard_LegacyChallenges.lua:44-62` —
   which reads `GetCategoryNumAchievements(categoryID)` → `numAchievements, numComplete,
   numIncomplete` and compares against the two completed/incomplete filter toggles.
3. And if not `AllChallengesFiltered(categoryID)` — `Blizzard_LegacyChallenges.lua:64-75` —
   which walks the category's achievements and keeps it when at least one ID is in the
   *search filter* result set.

The search filter set comes from `LegacySystem.GetFilteredChallenges()` —
`Blizzard_LegacySystem/Blizzard_LegacySystemUtil.lua:3-10`:

```lua
local numResults = GetNumFilteredAchievements();
for index = 1, numResults do
    result[GetFilteredAchievementID(index)] = true;
end
```

**What sets that filter:** `SetAchievementSearchString(editBox:GetText())`, called from the
search box's `OnTextChanged` — `Blizzard_LegacyChallenges.lua:10-14`. It is called
unconditionally, including on an empty string. The retail Achievement UI instead gates on
`MIN_CHARACTER_SEARCH` before calling it
(`Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.lua:3603-3606`). Results arrive
asynchronously via `ACHIEVEMENT_SEARCH_UPDATED` — `Blizzard_LegacyChallenges.lua:23-28`.

**Index ordering matters.** `LegacySystem.GetChallengeIndices(categoryID)` —
`Blizzard_LegacySystemUtil.lua:12-30` — treats a category's achievement indices as *completed
first, then incomplete*: hiding completed sets `startOffset = numCompleted, count =
numIncomplete`; hiding incomplete sets `startOffset = 0, count = numCompleted`. Any
enumeration we write has to assume that same ordering or ignore the offsets entirely and walk
`1..numAchievements`.

The completed/incomplete toggles themselves are a plain Lua table, not an API —
`Blizzard_LegacySystem/Blizzard_LegacySystemConstants.lua:19-22`, keyed by
`ACHIEVEMENTFRAME_FILTER_COMPLETED` / `ACHIEVEMENTFRAME_FILTER_INCOMPLETE`.

Two sub-questions the source cannot answer:

- **Resolved in game, 2026-09-18** — `GetCategoryList()` returns **only Legacy categories**,
  29 of them. Forever narrowed the global; the Legacy page needs no discriminator and neither
  do we. Full tree under Q2.
- **Resolved in game, 2026-09-18** — the filter set is empty at login
  (`GetNumFilteredAchievements()` = 0, nobody has called `SetAchievementSearchString` yet).
  After `SetAchievementSearchString("")` it returns **111**, which is every challenge. So an
  empty string means "match everything", and the Legacy page renders because opening it fires
  the search box's `OnTextChanged` with an empty string
  (`Blizzard_LegacyChallenges.lua:10-14`).

  111 also independently confirms the category arithmetic under Q2 — summing
  `GetCategoryNumAchievements` across the 29 categories gives the same number, so
  `GetCategoryList()` covers the whole Legacy set with nothing missed and nothing double
  counted.

**Consequence for us:** `SetAchievementSearchString` is global client state shared with the
Achievement UI. Calling it would clobber whatever the user has typed there, and the filter set
changes underneath us whenever the user searches there or opens the Legacy frame. v0
enumerates categories directly with `GetCategoryNumAchievements` +
`GetAchievementInfo(categoryID, index)` and never calls it.

`GetNumFilteredAchievements` + `GetFilteredAchievementID` would give a flat list of all 111
challenges in two calls, which is tempting. We still do not use it: it only holds that list
because something else populated it, and that something can change it at any time. It is
useful as a one-off cross-check of our own enumeration, nothing more.

### Q2. How categories are represented

They are ordinary achievement categories, in a parent/child hierarchy. There is no separate
Legacy category concept in the source.

- `GetCategoryInfo(categoryID)` → `categoryName, parentID` —
  `Blizzard_LegacyChallenges.lua:89,108`.
- `parentID == -1` means top level — named explicitly in
  `Blizzard_LegacyChallengeTracker/Blizzard_LegacyChallengeTracker.lua:6`
  (`local TOP_LEVEL_CATEGORY_ID = -1`) and relied on at `Blizzard_LegacyChallenges.lua:87,111`.
- The tree is built by walking each category up to its root —
  `Blizzard_LegacyChallenges.lua:98-136` — so the sidebar is arbitrary-depth, not a flat
  six-item list.

### The live category tree

Captured in game 2026-09-18, fresh character, beta build 1.60.1. **IDs are recorded for shape
only — never hardcode them**, they will churn through beta.

29 categories, **exactly two levels deep**, six real top-level groups plus one junk bucket.
Counts are `numAchievements, numComplete, numIncomplete` from `GetCategoryNumAchievements`.

| Top level (`parent == -1`) | Own | Children |
|---|---|---|
| 15425 Do Not Display | 0 | — |
| 15568 Classes | 0 | Druid, Hunter, Mage, Paladin, Priest, Rogue, Shaman, Warlock, Warrior — 3 each |
| 15586 Tradeskills | 0 | Alchemy, Blacksmithing, Enchanting, Engineering, Leatherworking, Tailoring — 3 each |
| 15593 Dungeons | 3 | — |
| 15594 Raids | 3 | 15626 Tier 1 Gear (0) |
| 15595 Player vs. Player | 0 | Ranks (5), Reputations (4), Season Journey (3) |
| 15596 Adventure | 2 | Explorer (3), Eastern Kingdoms (23), Kalimdor (20) |

**111 challenges in total**, against 65 earnable points — so a challenge is not worth one
point, and some are presumably worth zero. `C_Traits.GetTraitCurrencyForAchievement` per
challenge is the only way to know which.

Notes that matter for the UI:

- Depth is 2, never more. The category filter can be a flat list of the six top-level groups;
  we do not need the recursive tree builder Blizzard uses at
  `Blizzard_LegacyChallenges.lua:98-136`.
- **"Do Not Display" (15425) is a real category** `GetCategoryList()` hands back. It has zero
  achievements, so Blizzard's `HasChallenges` check drops it incidentally rather than by name.
  Our enumeration must drop empty categories too, and must not match on the string.
- Classes covers the nine vanilla classes only — no Death Knight, Monk, Demon Hunter or
  Evoker. Relevant to v1's class-leveling → candidate-alt mapping.
- Three of the six top-level groups hold no achievements of their own and exist purely as
  parents.
- "Tradeskills" is the internal category name; the tree is publicly "Professions". Do not
  assume category names and tree names line up.

### Q3. Points per challenge

`C_Traits.GetTraitCurrencyForAchievement(traitCurrencyID, achievementID) → amount`.

- Doc: `Blizzard_APIDocumentationGenerated/SharedTraitsDocumentation.lua:454-468`. Both
  arguments `number`, non-nilable; single return `amount`, type `number`, non-nilable (so no
  nil-for-zero case). `SecretArguments = "AllowedWhenUntainted"`.
- Call site: `Blizzard_LegacyChallenges.lua:305-308`, inside the
  `AchievementFrame_GetOverridePoints` override:

```lua
function AchievementFrame_GetOverridePoints(points, achievementId)
    local legacyPoints = C_Traits.GetTraitCurrencyForAchievement(Constants.LegacyConsts.LEGACY_POINTS_TRAIT_CURRENCY_ID, achievementId);
    return legacyPoints;
end
```

The achievement's own point value is discarded. The shared achievement template calls the
override at `Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.lua:1337`, and a zero
result just hides the badge — `Blizzard_LegacySystem/Blizzard_LegacyChallengeButton.lua:310-312`.

### Live point data, 2026-09-18

Swept across all 111 challenges: **the total is exactly 65**, matching
`GetMaxAvailableTraitCurrency(4225, false)`. So `GetTraitCurrencyForAchievement` is complete
and trustworthy, and "points still available from incomplete challenges" is a sound number to
compute and show.

The distribution is flatter than expected:

- **65 challenges award exactly 1 point each.** No challenge awards 2 or more.
- **46 award 0** — every `Explore *` achievement, i.e. the whole exploration substrate.

Two consequences. First, no point-weighting is needed in ranking today; a challenge is worth a
point or it isn't. Do not hardcode 1, but do not build a weighting model either. Second, the
46 zero-point entries are arguably not "challenges" in the sense the user cares about — they
are the criteria substrate for `Explorer`. ~~**Open design question:** whether v0's Next Up
list filters to point-bearing challenges by default.~~ **Decided 2026-09-19 — zero-point
challenges are excluded**, filtered on the point value and never on the name. Blizzard's own UI
shows them all; ours is about points. See Ranking decisions in `docs/status.md`.

`GetAchievementInfo(62012)` confirmed the 14-return order matches retail exactly, and shows
the achievement's own `points` field is **0** — which is what the override exists to replace.
`rewardText` reads "Earn 1 Legacy Point.", a free display string.

`flags` on a point-bearing challenge is `134349824` — bits 10, 17 and 27. Bit 17 is
`ACHIEVEMENT_FLAGS_ACCOUNT`. ~~Bits 10 and 27 are unidentified and appear on all 65.~~ Bit 10
is still unidentified. **Bit 27 marks which of two mirrored challenge sets this is.** The
client data holds a second set of 65 that carries bit 28 instead (added 2026-09-30, "Client
data (DB2)" below). Both bits 10 and 27 appear on all 65 of ours. The 46
zero-point exploration achievements have `flags == 0`, so they are ordinary per-character
achievements. The correlation between "awards a point" and "is account-wide" holds across all
111, but it is an observation, not a documented invariant — do not branch on it.

### Blizzard's public numbers, 2026-09-26

Source: "Get to Know the World of Warcraft: Forever Legacy System",
<https://news.blizzard.com/en-us/article/24307383/get-to-know-the-world-of-warcraft-forever-legacy-system>.
A public article, not a client read, so nothing here re-tags a client fact. It is recorded
because every number in it agrees with a capture, which is the cheapest confirmation available
that the captures and the point filter are right.

Per-category totals, as published, against the U1 filter bar (`spec/golden/uidump_combined.txt`):

| Category | Article | Filter bar |
|---|---|---|
| Classes | 27 | 27 |
| Tradeskills | 18 | 18 |
| Player vs. Player | 12 | 12 |
| Adventure | 2 | 2 |
| Dungeons | 3 | 3 |
| Raids | 3 | 3 |

Blizzard counts **65 challenges**, so the 46 zero-point `Explore *` achievements are not
"challenges" in their accounting either. The point-value filter above matches the public
definition without ever looking at a name.

**One character can earn at most 29 of the 65.** Quoted: "A single character can earn 3 points
leveling, up to 6 points from tradeskills, 12 from PvP, 2 from Adventure, and 6 from Dungeons
and Raids, for a total of up to 29 possible points." The remaining 36 need alts, which is v1's
premise stated by Blizzard rather than inferred. The breakdown maps onto the category tree:

- 3 leveling = one class × `Novice / Experienced / Master` (25/45/60).
- 6 tradeskills = two primaries × three tiers. The Tradeskills category holds exactly six
  children, all crafting — Alchemy, Blacksmithing, Enchanting, Engineering, Leatherworking,
  Tailoring (`spec/fixtures/categories_full.lua`) — and the article's unlock wording is "150
  in a **non-gathering** primary tradeskill". Gathering and secondary professions have no
  challenge to map to.
- 6 Dungeons and Raids = 3 + 3. 12 PvP and 2 Adventure are the whole category each.

**Unlock.** "You gain access to the Legacy System as soon as you earn your first Legacy Point"
— level 25, 150 in a crafting profession, or the full world map. Both captured characters were
at zero points and every read on our surface worked (D3, D5, D6, D7, U1), so the data is
readable before Blizzard's own window is. `Blizzard_LegacySystem` carries no unlock gate of
its own; whatever hides the shield icon is client-side.

**Churn.** "Expansions planned for each content update" — more challenges and more reward
tiers. The sparse `GetRenownLevels` read and the no-hardcoded-IDs rule are what absorb that.

**Hardcore**, still out of scope: challenges earned in Hardcore grant in every ruleset,
non-Hardcore completions do not show in Hardcore, PvP challenges cannot be completed there,
and Hardcore launches with 12 challenges of its own.

### Q4. What the detail pane shows for criteria

`Blizzard_LegacyChallengeButton.lua:158-200`. Count from `GetAchievementNumCriteria(id)`
(line 162), then per index (line 172):

```lua
local criteriaString, _criteriaType, criteriaCompleted, quantity, reqQuantity, _charName, criteriaFlags = GetAchievementCriteriaInfo(id, i);
```

Used: `criteriaString`, `criteriaCompleted`, `quantity`, `reqQuantity`, `criteriaFlags`.
Ignored: `criteriaType`, `charName`, and positions 8-9 (`assetID`, `quantityString`) are not
even captured. Full return order is confirmed by the retail UI at
`Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.lua:1586`:
`criteriaString, criteriaType, criteriaCompleted, quantity, reqQuantity, charName,
criteriaFlags, assetID, quantityString`.

Two render modes, chosen by `ShouldShowCriteriaProgress(flags, quantity, reqQuantity)` —
`Blizzard_LegacyChallengeButton.lua:43-49`:

```lua
if not flags or not quantity or not reqQuantity or reqQuantity <= 0 then return false; end
return bit.band(flags, EVALUATION_TREE_FLAG_PROGRESS_BAR) == EVALUATION_TREE_FLAG_PROGRESS_BAR;
```

`EVALUATION_TREE_FLAG_PROGRESS_BAR = 0x00000001` —
`Blizzard_FrameXMLBase/Constants.lua:110` (outside the pinned set) [in the checkout since the 2026-09-19 widening; line re-verified].

- **Flag set:** progress bar, `quantity` clamped into `0..reqQuantity`, label formatted with
  `GENERIC_FRACTION_STRING_WITH_SPACING` — lines 118-122. This is the `3/5` case.
- **Flag clear:** a text row with a checkmark when complete — lines 110-114. `quantity` and
  `reqQuantity` are *not* shown; remaining progress is a count of incomplete criteria.

**Consequence for us:** "criteria remaining" is two different calculations depending on the flag.
Ranking by closeness has to handle both: a fraction for progress-bar criteria, and
`incomplete / total` for boolean criteria lists.

### Live criteria data, 2026-09-18

Full sweep of all 111 challenges. **There are three shapes, not two:**

| Shape | Count | How progress reads |
|---|---|---|
| Progress bar (`flags` bit 1 set) | 18 | `quantity / reqQuantity` |
| Checklist (`flags` bit 1 clear) | 59 | count of incomplete criteria |
| **No criteria at all** (`GetAchievementNumCriteria` = 0) | **34** | **nothing — binary** |

The 34 are every class challenge (9 × 3), all five PvP Ranks, `Conqueror of the Lair` and
`Lord Valthalak Laid to Rest`. They expose no progress through the API at all. Ranking must
treat them as a distinct case — not as 0%, which would park a third of the list at the top of
a "closest to done" sort forever.

This is also why v1's candidate-alt mapping is scoped to class-leveling and profession
challenges: those are the ones we can compute from character state (level, skill) when the
criteria tell us nothing.

Two captured samples, which are the first real fixtures:

```
ach 62012 "Journeyman Alchemist"  (progress bar)
i;string;type;completed;quantity;reqQuantity;charName;flags;assetID;quantityString
1;150 Alchemy Skill;7;false;0;150;nil;1;2937;0 / 150

ach 62053 "Explore Azeroth"  (checklist)
1;Eastern Kingdoms;8;false;0;1;nil;0;62353;0
2;Kalimdor;8;false;0;1;nil;0;62355;0
```

**`criteriaType` matters after all**, despite Blizzard's Legacy card discarding it:

- **Type 7 — skill threshold.** `assetID` is a skill line ID (2937 = Alchemy), `reqQuantity`
  is the skill level. Every one of the 18 progress-bar challenges is a profession skill gate.
- **Type 8 — child achievement.** `assetID` is another achievement ID. This is
  `CRITERIA_TYPE_ACHIEVEMENT`, which the retail UI special-cases at
  `Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.lua:1588`.

**Type 8 forms meta chains**, and they are deep. `Explorer` (1 point) has one criterion,
`Explore Azeroth`; that has two, `Explore Eastern Kingdoms` and `Explore Kalimdor`; those have
23 and 20 zone achievements; each zone has 7–27 subzone criteria. A naive read says `Explorer`
is "0/1 — one criterion left", which is wildly misleading. Honest closeness has to recurse
through `assetID`, or the UI has to say the chain is unexpanded. **Open design question, not
yet decided.**

`quantityString` ("0 / 150") is pre-formatted by the client and matches
`GENERIC_FRACTION_STRING_WITH_SPACING`. Using it saves us formatting, but it is a localised
string — fine for display, never for arithmetic.

### Q5. Account-wide vs per-character completion

Yes, on both axes, and the Legacy UI treats them differently from retail.

`GetAchievementInfo` returns 14 values, order confirmed at
`Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.lua:1329-1334`:

```
id, name, points, completed, month, day, year, description, flags, icon, rewardText, isGuild, wasEarnedByMe, earnedBy
```

- **`isAccountWide` is not a return value.** It is derived from `flags`:
  `bit.band(flags, ACHIEVEMENT_FLAGS_ACCOUNT) == ACHIEVEMENT_FLAGS_ACCOUNT` —
  `Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.lua:1340`. The Legacy card art
  branches on the resulting `self.accountWide` —
  `Blizzard_LegacyChallengeButton.lua:51-55,370,380`.
  **Verified in game, 2026-09-18:** `ACHIEVEMENT_FLAGS_ACCOUNT = 131072` (`0x20000`, bit 17).
  It is not defined anywhere in the pinned dirs, so feature-detect it and fall back to the
  literal.
- **`wasEarnedByMe` (position 13)** is what separates per-character from account completion.
  The Legacy detail pane explicitly counts other characters' completions as incomplete —
  `Blizzard_LegacySystem/Blizzard_LegacyChallengeDetailPane.lua:45-49`:

```lua
local achievementId, _,_,_,_,_,_,_,_,_,_,_, wasEarnedByMe = GetAchievementInfo(categoryInfo.id, index);
-- consider achievements earned by others incomplete
local shouldHideCompletedByOther = not wasEarnedByMe and hideIncomplete;
```

- And the completion override — `Blizzard_LegacyChallenges.lua:301-303`:

```lua
function AchievementFrame_ShowAsComplete(completed, wasEarnedByMe)
    return completed and wasEarnedByMe;
end
```

**Consequence for us:** `completed` alone is not "done". For a per-character view, use
`completed and wasEarnedByMe`. For "what still awards the account points", `completed` is the
right field, since points are account-wide.

### Q6. What Blizzard_LegacyChallengeTracker does

It is not a progress tracker. It is the unviewed-challenge notification store — the "new"
dot on category buttons — and it does no sorting by progress at all.

`Blizzard_LegacyChallengeTracker/Blizzard_LegacyChallengeTracker.lua`, 79 lines:

- Persists `LegacyChallengesUnviewed`, a map of `achievementID → categoryID`, as
  `SavedVariablesPerCharacter` — `Blizzard_LegacyChallengeTracker.toc:5`, with
  `LoadSavedVariablesFirst: 1` at `.toc:6`.
- On `ACHIEVEMENT_EARNED` it records `GetAchievementCategory(achievementID)` — lines 67-77.
- `RebuildUnviewedCategories` (21-33) flattens each entry up the `GetCategoryInfo` parent
  chain so a collapsed parent still shows a dot.
- `MarkCategoryViewed` (51-65) clears entries for exactly one category; descendants stay
  unviewed.

Tracking API used: none beyond `GetAchievementCategory` and `GetCategoryInfo`. It never calls
a `C_ContentTracking`-style API, never reads criteria, and never orders anything.

**Consequence for us:** nothing in Blizzard's Legacy code ranks challenges by closeness to
completion. Our core v0 feature has no in-client precedent to copy, and no API shortcut — it
is criteria arithmetic in `Model/`.

Also worth noting: this addon is a live consumer of `SavedVariablesPerCharacter`. If Blizzard's
own unviewed dots survive a relog on the beta, the SavedVariables load bug is narrower than
"nothing loads". Cheap signal to watch.

---

## Trees and points

### Q7. Spent / unspent / cap per character

All of it comes from one struct. `TreeCurrencyInfo` —
`Blizzard_APIDocumentationGenerated/SharedTraitsDocumentation.lua:1188-1197`:

| Field | Type | Nilable |
|---|---|---|
| `traitCurrencyID` | number | no |
| `quantity` | number | no |
| `maxQuantity` | number | **yes** |
| `spent` | number | no |
| `spentInTree` | number | **yes** |

`C_Traits.GetTreeCurrencyInfo(configID, treeID, excludeStagedChanges)` returns a *list* of
these — `SharedTraitsDocumentation.lua:537-552`. Both Legacy call sites take `[1]`.

How the UI maps them:

| Display | Field | Citation |
|---|---|---|
| Unspent / available points | `quantity` | `Blizzard_LegacySystem/Blizzard_LegacyTree.lua:313-315` |
| Cap (tooltip, `LEGACY_POINTS_SEASONAL_CAP`) | `maxQuantity` | `Blizzard_LegacyTree.lua:303` |
| Spent in the selected tree | `spentInTree` | `Blizzard_LegacyTree.lua:98` |
| Total earnable (bar maximum) | `C_Traits.GetMaxAvailableTraitCurrency(currencyID, false)` | `Blizzard_LegacyChallenges.lua:253` |
| Points earned account-wide | `C_MajorFactions.GetCurrentRenownLevel(2802)` | `Blizzard_LegacySystemUtil.lua:49` |

That last row is the surprising one: the number shown as "Legacy points earned" is the
**renown level** of faction 2802, stuffed onto the currency table as `renownCurrency` —
`Blizzard_LegacySystemUtil.lua:49`. Through 1.60.1.70124 `Blizzard_LegacyTree.lua` set it a
second time; since 70170 it calls `LegacySystem.UpdateCurrencyInfo()` instead (`:107`). The points bar is
`renownCurrency / GetMaxAvailableTraitCurrency(...)` —
`Blizzard_LegacyChallenges.lua:253-259`. So reward-track level and account points earned are
the same number.

~~`excludeStagedChanges` is passed `true` from `LegacySystem.UpdateCurrencyInfo` —
`Blizzard_LegacySystemUtil.lua:32-41`~~ (true through 1.60.1.70124). Since 70170 it is passed
`false`, from the local `RefreshCachedCurrencyInfo` that `UpdateCurrencyInfo` now calls —
`Blizzard_LegacySystemUtil.lua:34-53`. The comment at `:41` says it matches `TalentFrameBaseMixin`
so the panel and the summaries agree while changes are staged. `Api` still passes `true`
(`LegacyNext/Api/Api.lua:653`). The function reads `LegacyTreeData[1]` (Professions) and uses
it as the account-wide summary. The talent panel instead passes
`self.excludeStagedChangesForCurrencies` —
`Blizzard_SharedTalentUI/Blizzard_SharedTalentFrame.lua:1353-1371` (outside the pinned set).

### Where the 65 and the 16 actually come from

**Verified in game, 2026-09-18**, fresh character with zero points:

```
C_Traits.GetMaxAvailableTraitCurrency(4225, false) → 65   -- total earnable, account-wide
C_Traits.GetMaxAvailableTraitCurrency(4225, true)  → 16   -- spendable cap, per character
```

The `limitBySourcedMax` argument is the whole difference between the two headline numbers from
the BlizzCon deep dive. Neither comes from `maxQuantity`.

**All three trees share one config.** `C_Traits.GetConfigIDByTreeID` returned the same
`configID` (2866866) for 1187, 1188 and 1189. Combined with the single shared currency 4225,
that settles it: **the 16-point cap is one pool spent across all three trees, not 16 per
tree.** A character's total spend is `spent`; `spentInTree` splits it per tree.

A fresh character *does* have a config — `GetConfigIDByTreeID` returned a number, not nothing,
at zero points. Still guard it: the API is documented `MayReturnNothing`.

At zero points all three trees reported `quantity=0, maxQuantity=0, spent=0, spentInTree=0`.

**Open — recheck at non-zero points:** `maxQuantity` read **0**, not 16. So it is not the
static cap, despite the UI formatting it into `LEGACY_POINTS_SEASONAL_CAP`
(`Blizzard_LegacyTree.lua:303`) — which on a fresh character would render "cap 0". It is
probably dynamic, tracking points earned so far. Queue row **C1** rechecks it once points exist. Until
then `Model/` takes the cap from `GetMaxAvailableTraitCurrency(currencyID, true)`, not from
`maxQuantity`.

### Q8. Tree 1189 display name

**Answered.** `LEGACY_TREE_PROGRESSION` = **"Resourcefulness"**, verified in game 2026-09-18
alongside `LEGACY_TREE_PROFESSIONS` = "Professions" and `LEGACY_TREE_ADVENTURE` = "Adventure".
So tree 1189 is the public Resourcefulness tree.

The name is the global string `LEGACY_TREE_PROGRESSION` —
`Blizzard_LegacySystem/Blizzard_LegacySystemConstants.lua:11-16`:

```lua
[3] = {
    treeID = Constants.LegacyConsts.LEGACY_TREE_PROGRESSION_ID,
    iconAtlas = "UI-Legacy-Tree-Progression",
    name = LEGACY_TREE_PROGRESSION,
},
```

Global strings are client data, not source, so `wow-ui-source` cannot tell us the value — the
only three hits for `LEGACY_TREE_PROGRESSION` in the whole `Interface` tree are this reference,
the constant ID, and the doc file. Nothing named "Resourcefulness" appears in the Legacy code
(the only `Resourcefulness` hits are the unrelated profession stat in
`ProfessionConstantsDocumentation.lua:318` and friends). Settled in game by queue row A.

Note that three different names refer to the same tree: the constant is
`LEGACY_TREE_PROGRESSION_ID`, the atlas is `UI-Legacy-Tree-Progression`, and the display
string is "Resourcefulness". Never assume they agree. The same trap applies to the
"Tradeskills" category versus the "Professions" tree.

### Q9. `LEGACY_TREE_ADVENTURE_TALENTED_NODE_ID` (110298)

**Answered.** It lowers the character level at which class talents unlock.

`Blizzard_MicroMenu/Camelot/MainMenuBarMicroButtonsOverrides.lua:6-22` (outside the pinned
set):

```lua
-- Ranks in the legacy adventure tree lower the level at which the player can start spending talents.
function PlayerSpellsMicroButtonMixin:GetTalentUnlockLevel()
    local defaultUnlockLevel = Constants.LevelConstsExposed.MIN_TALENT_LEVEL;
    local configID = C_Traits.GetConfigIDByTreeID(Constants.LegacyConsts.LEGACY_TREE_ADVENTURE_ID);
    if not configID then return defaultUnlockLevel; end
    local nodeInfo = C_Traits.GetNodeInfo(configID, Constants.LegacyConsts.LEGACY_TREE_ADVENTURE_TALENTED_NODE_ID);
    if not nodeInfo then return defaultUnlockLevel; end
    local minUnlockLevel = 1;
    return math.max(minUnlockLevel, defaultUnlockLevel - nodeInfo.activeRank);
end
```

This is the only use in the entire `Interface` tree (verified by grepping the widened
checkout; the other hit is the constant's own doc entry at
`LegacyConstantsDocumentation.lua:15`).

Out of scope for v0 and v1 — it is a class-talent gate, not a Legacy challenge or reward. It
does add one API to the surface: `C_Traits.GetNodeInfo(configID, nodeID) → nodeInfo`, with
`activeRank`.

---

## Reward track

### Q10. Current level, progress to next, reward list

`Blizzard_LegacySystem/Blizzard_LegacyRewardTrack.lua`. The track is renown faction 2802.

Setup — lines 169 and 36-41. The faction read moved from `OnLoad` into `Refresh` at 70170, and
`Refresh` now returns `false` while the data is nil ("Can be nil if faction data isn't available
yet", line 168):

```lua
self.majorFactionData = C_MajorFactions.GetMajorFactionData(Constants.LegacyConsts.LEGACY_REWARD_TRACK_FACTION_ID);
self.renownLevelsInfo = C_MajorFactions.GetRenownLevels(self.majorFactionData.factionID);
self.maxLevel = self.majorFactionData.maxLevel;
for level, levelInfo in ipairs(self.renownLevelsInfo) do
    levelInfo.rewardInfo = C_MajorFactions.GetRenownRewardsForLevel(self.majorFactionData.factionID, levelInfo.level);
end
```

Current level — lines 161-165, `C_MajorFactions.GetCurrentRenownLevel(factionID)`, stored as
both `actualLevel` and `displayLevel`.

Visibility gate — line 177: `majorFactionData.isUnlocked and not
C_MajorFactions.IsMajorFactionHiddenFromExpansionPage(factionID)`.

**Progress to next is computed from the levels table, not from reputation.**
`SetupProgressDetails` — lines 183-201:

```lua
local level = self.majorFactionData.renownLevel;
local threshold = self.majorFactionData.renownLevelThreshold;   -- assigned, never used
local progress = self.majorFactionData.renownReputationEarned;  -- assigned, never used

local thresholdLevel = 0;
local progressToNextLevel = level;
local nextLevelThresholdDifference = 100;
local lastThreshold = 0;
for i, levelInfo in ipairs(self.renownLevelsInfo) do
    if level >= levelInfo.level then
        thresholdLevel = i;
        progressToNextLevel = progressToNextLevel - (levelInfo.level - lastThreshold);
    else
        nextLevelThresholdDifference = levelInfo.level - lastThreshold;
        break;
    end
    lastThreshold = levelInfo.level;
end
```

`threshold` and `progress` are dead locals — lines 185-186 assign them and nothing reads them.
Everything downstream (lines 203-232) is bar-pixel layout against the hardcoded card position
tables at lines 4-6.

So **points to next reward** = `nextLevelThresholdDifference - progressToNextLevel`, derived
entirely from `renownLevel` and the `GetRenownLevels` table. We can reimplement that in
`Model/` as pure arithmetic with no client call beyond the two reads.

Struct shapes, from `Blizzard_APIDocumentationGenerated/MajorFactionsDocumentation.lua`:

- `MajorFactionData` (lines 259-281): `factionID`, `renownLevel`, `maxLevel`,
  `renownReputationEarned`, `renownLevelThreshold`, `isUnlocked`, `name`, `description`,
  `textureKit`, plus toast/sound fields we do not need.
- `MajorFactionRenownLevelInfo` (311-320): `factionID`, `level`, `locked`, `isMilestone`,
  `isCapstone`.
- `MajorFactionRenownRewardInfo` (323-337): `renownRewardID`, `uiOrder`, `isAccountUnlock`,
  `itemID`, `spellID`, `mountID`, `transmogID`, `transmogSetID`, `titleMaskID`,
  `transmogIllusionSourceID`, `icon`.

### Live data, 2026-09-18, fresh character at zero points

`C_MajorFactions.GetMajorFactionData(2802)`, fields that matter:

```
name                   = "Legacy Track"
factionID              = 2802
renownLevel            = 0
maxLevel               = 90
renownReputationEarned = 0
renownLevelThreshold   = 1
isUnlocked             = true
textureKit             = "storm"
expansionID            = 0
```

`C_MajorFactions.GetRenownLevels(2802)` returned **four** entries:

| level | locked | isMilestone | isCapstone |
|---|---|---|---|
| 15 | true | false | false |
| 25 | true | false | false |
| 40 | true | false | false |
| 55 | true | false | false |

**The levels table is sparse.** It is not one entry per renown level the way retail major
factions work — it is the four *reward* levels only. `levelInfo.level` is a point threshold,
not an index. Anything we write has to treat it as a sorted list of thresholds.

Cross-check that this is intentional: `IsScrollingTrack()` is
`#self.renownLevelsInfo > MAX_STATIC_ITEMS` where `MAX_STATIC_ITEMS` is 4
(`Blizzard_LegacyRewardTrack.lua:9,31-33`), and `STATIC_CARD_POSITION_TO_PROGRESS` holds
exactly four card positions (line 6). Four rewards is the designed case, and the track renders
static rather than scrolling.

`renownLevel` is the account's earned Legacy point count — consistent with
`Blizzard_LegacySystemUtil.lua:49` using `GetCurrentRenownLevel` as the point total. So
`maxLevel = 90` is headroom against 65 earnable at launch; do not treat 90 as a point cap.

`renownLevelThreshold = 1` and `renownReputationEarned = 0` are confirmed irrelevant — they
are the two dead locals at `Blizzard_LegacyRewardTrack.lua:185-186`.

**The Blizzard arithmetic checks out against this data.** Worked through the loop at lines
192-201:

- At 0 points: `nextLevelThresholdDifference = 15 - 0 = 15`, `progressToNextLevel = 0` → 15
  points to the first reward. Correct.
- At 20 points: first entry passes (`20 >= 15`), so `progressToNextLevel = 20 - 15 = 5` and
  `lastThreshold = 15`; second entry fails (`20 < 25`), so
  `nextLevelThresholdDifference = 25 - 15 = 10` → 5 of 10 toward the next reward. Correct.

So `Model/` reimplements it as: given `renownLevel` and the sorted threshold list, the next
reward is the first threshold above the current level, and points remaining is
`threshold - renownLevel`. Two client reads, no other state.

### What a reward entry actually contains

**Verified in game, 2026-09-18.** `GetRenownRewardsForLevel` returns a *list*; each of these
thresholds holds exactly one reward.

Level 15:

```
toastDescription = "Replica Ironforge Air Rifle"
itemID           = 276236
icon             = 135614
rewardType       = 1
isCollected      = false
isAccountUnlock  = false
uiOrder          = 0
renownRewardID   = 0
description      = "Join a shootout with your air rifle. ... Visit Innkeeper Wiley in Ratchet to claim your reward."
```

All four thresholds, swept 2026-09-18 — every reward is a single item, `rewardType` 1:

| Level | `name` | `toastDescription` | itemID | isCollected |
|---|---|---|---|---|
| 15 | **nil** | Replica Ironforge Air Rifle | 276236 | false |
| 25 | Spectral Bear Cub | Spectral Bear Cub | 277714 | false |
| 40 | Spectral Bear Tabard | Spectral Bear Tabard | 277717 | **true** |
| 55 | Reins of the Spectral Bear | Reins of the Spectral Bear | 277718 | false |

`name` is missing on exactly one of four, so the `name or toastDescription` fallback stands.
`spellID`, `mountID` and `titleMaskID` are nil on all four — the Reins are an item, not a
mount entry.

**`isCollected` is true at level 40 on a character at renown 0.** It reports account
collection state, not whether the reward level is reached or claimed. Never render it as
progress; the reward readout derives reached-ness from `renownLevel` against the threshold.

Level 25, same shape **plus** a `name` field:

```
name             = "Spectral Bear Cub"
toastDescription = "Spectral Bear Cub"
itemID           = 277714
icon             = 294471
```

Three things here matter.

**The runtime struct exceeds the documented one.** `description`, `isCollected`,
`toastDescription`, `rewardType` and `name` appear in none of
`MajorFactionsDocumentation.lua:323-337`. The generated docs are a floor, not a contract —
feature-detect fields, never assume the documented list is complete.

**`name` is inconsistent and `toastDescription` is not.** The level-15 reward has no `name`;
the level-25 one has both, holding the same string. So the display name is
`reward.name or reward.toastDescription`, in that order, and `Model/` treats a missing name as
normal rather than as an error. Whether level 15 is genuinely nameless or an authoring gap on
the beta is unknown — the fallback covers either.

**We do not need an item lookup.** A usable name ships in the reward table itself, so the
reward readout avoids `GetItemInfo` and its async cache-miss path entirely. `icon` is a fileID
we can render directly, and `isCollected` gives us claimed-versus-unclaimed for free.

`renownRewardID` is 0 on both, so it is not a usable identifier. `uiOrder` is 0 on both.
`rewardType = 1` is an unlabelled enum; both samples are items, so we have no second value to
compare against and we do not branch on it.

Rewards are claimed from an NPC (Innkeeper Wiley in Ratchet), which is flavour for us but
explains `isCollected` being false at a threshold the character has not reached.

---

## Loading

### Q11. Is Blizzard_LegacySystem load-on-demand?

Yes. `Blizzard_LegacySystem/Blizzard_LegacySystem.toc:2-4`:

```
## LoadOnDemand: 1
## AllowLoadGameType: camelot
## Dependencies: Blizzard_SharedTalentUI, Blizzard_AchievementUI, Blizzard_ProfessionsTemplates, Blizzard_LegacyChallengeTracker
```

("camelot" is the internal game-type name for Forever.)

The bootstrap file is tagged `[Bootstrap]` in the TOC (line 6), so it loads at startup while
the rest waits. `Blizzard_LegacySystem_Bootstrap.lua:1-21`:

```lua
function LegacySystemFrame_LoadUI()
    return LoadAddOnWithErrorHandling(AddonName);
end

function ToggleLegacySystemUI()
    if (C_MajorFactions.GetCurrentRenownLevel(Constants.LegacyConsts.LEGACY_REWARD_TRACK_FACTION_ID) <= 0) then
        return;
    end
    if not LegacySystemFrame then
        if not LegacySystemFrame_LoadUI() then return; end
    end
    if LegacySystemFrame then ToggleFrame(LegacySystemFrame); end
end
```

Triggered from exactly two places: the micro button at
`Blizzard_MicroMenu/Mainline/MainMenuBarMicroButtons.lua:1054`, and a key binding at
`Blizzard_FrameXML/Bindings_Camelot.xml:1218` (both outside the pinned set) [`Blizzard_FrameXML` is in the checkout since the 2026-09-19 widening and the binding line re-verified; `Blizzard_MicroMenu` is still absent].

**Do the APIs we need work without it loaded?** The C APIs do — `C_Traits.*`,
`C_MajorFactions.*`, `C_AchievementInfo.*` and the achievement globals are client functions,
not addon code. What is gone before load is all the *Lua* scaffolding:

| Symbol | Defined in | Needed? |
|---|---|---|
| `LegacyTreeData` | `Blizzard_LegacySystemConstants.lua:1-17` | No — we read `Constants.LegacyConsts` ourselves |
| `LegacyChallengeFilters` | `Blizzard_LegacySystemConstants.lua:19-22` | No — we own our filter state |
| `LegacySystem.*` helpers | `Blizzard_LegacySystemUtil.lua` | No — reimplement in `Model/` |
| `LEGACY_TREE_*`, `LEGACY_POINTS_*` strings | client global strings | Available regardless of the addon |
| `LegacyChallengeViewedUtil` | the tracker addon, which is **not** LoD | Loaded at startup, but not something we should read |

So: **we never call `C_AddOns.LoadAddOn`.** Forcing a Blizzard LoD addon to load as a side
effect of opening our frame is exactly the kind of thing that breaks on a patch.

**Verified in game, 2026-09-18**, fresh login on the beta before opening the Legacy UI:
`C_AddOns.IsAddOnLoaded("Blizzard_LegacySystem")` returned `false, false` (`loaded`,
`finished`), while `Constants.LegacyConsts` returned all six values. The constants are client
data, not addon data, and are readable without the load-on-demand addon. `Api/` reads the
runtime table; the literals in `CLAUDE.md` stay a fallback for the case where the table shape
changes under us.

### Q12. Events

The Legacy addons register **four** frame events in total, and none of them are trait or
faction events.

| Event | Where | Handler |
|---|---|---|
| `ACHIEVEMENT_EARNED` | `Blizzard_LegacyChallenges.lua:4` | `OnAchievementComplete` (146-154) |
| `CRITERIA_UPDATE` | `Blizzard_LegacyChallenges.lua:5` | `OnCriteriaUpdate` (156-161) |
| `ACHIEVEMENT_SEARCH_UPDATED` | `Blizzard_LegacyChallenges.lua:6` | re-reads `GetNumFilteredAchievements` (23-28) |
| `ACHIEVEMENT_EARNED` | `Blizzard_LegacyChallengeTracker.lua:67` | records category for the unviewed dot |

**No `TRAIT_*` and no `MAJOR_FACTION_*` registration anywhere in the Legacy addons.** Points
and reward-track state are re-read on show and on internal callbacks instead. The relevant
events exist elsewhere:

- `TRAIT_CONFIG_UPDATED`, `CONFIG_COMMIT_FAILED`, `TRAIT_TREE_CHANGED` —
  `Blizzard_SharedTalentUI/Blizzard_SharedTalentFrame.lua:186-188` (outside the pinned set).
  The Legacy tree panel inherits this frame, so it gets them indirectly.
- `MAJOR_FACTION_RENOWN_LEVEL_CHANGED` —
  `Blizzard_MajorFactions/Blizzard_MajorFactionRenownToast.lua:5`.
- `MAJOR_FACTION_UNLOCKED` — `Blizzard_MajorFactions/Blizzard_MajorFactionUnlockToast.lua:5`.

Everything else is `EventRegistry` traffic, internal to the addon and only live once it loads:
`Legacy.SelectPage`, `Legacy.RefreshChallenges`, `Legacy.SelectChallenge`,
`Legacy.UpdateChallenge`, `Legacy.SelectChallengeCategory`, `Legacy.OpenToChallengeCategory`,
`Legacy.UpdateCurrencyInfo`, `Legacy.SelectTree`, `Legacy.UnviewedChallengesUpdated`,
`Legacy.RefreshCategoryButtonCollapseState`.

**Consequence for us:** the three achievement events cover challenge progress. For points and
reward-track changes we will have to register `TRAIT_CONFIG_UPDATED` / `TRAIT_TREE_CHANGED`
and `MAJOR_FACTION_RENOWN_LEVEL_CHANGED` ourselves — Blizzard's Legacy UI gives us no
precedent that they fire in this context. Queue row **C2** in `docs/ingame-commands.md` checks.

**`RECEIVED_ACHIEVEMENT_LIST`** (added 2026-09-30) is documented as a `UniqueEvent` with no
payload (`Blizzard_APIDocumentationGenerated/AchievementInfoDocumentation.lua:161`). No
Blizzard addon at the pin registers it. Legacy Forever invalidates on it, and tells its users
"if you just logged in, try again shortly". That suggests the achievement list can read empty
for a moment after login. It is a note rather than a C2 line for two reasons. It fires at
login, before `/etrace` can be opened. And nothing of ours reads achievements at login: the
window reads on open, and roster snapshots never read achievements. If anyone reports an empty
list right after login, this is the first event to try.

---

## Full dependency surface

Every global the Legacy addons touch, per file, extracted mechanically:

```sh
luacheck --std lua51 --no-config --only 113 \
  vendor/wow-ui-source/Interface/AddOns/Blizzard_LegacySystem/*.lua \
  vendor/wow-ui-source/Interface/AddOns/Blizzard_LegacyChallengeTracker/*.lua
```

**In the brief already:** `GetAchievementInfo`, `GetAchievementNumCriteria`,
`GetAchievementCriteriaInfo`, `GetAchievementCategory`, `GetCategoryNumAchievements`,
`GetNumFilteredAchievements`, `GetFilteredAchievementID`, `C_AchievementInfo`, `C_Traits`,
`C_MajorFactions`.

Everything below is **not** in the brief. Bold marks the ones that matter to v0/v1; the rest
are frame, gamepad, or art plumbing we will not reimplement.

**Blizzard_LegacyChallenges.lua**
> **`GetCategoryList`**, **`GetCategoryInfo`**, **`SetAchievementSearchString`**,
> **`Constants`**, **`ACHIEVEMENTFRAME_FILTER_COMPLETED`**,
> **`ACHIEVEMENTFRAME_FILTER_INCOMPLETE`**, **`LEGACY_POINTS_CURR_MAX`**,
> `LEGACY_CHALLENGE_FRAME_TITLE`, `AchievementFrame_FindDisplayedAchievement`,
> `AchievementFrameAchievements_GetSelectedElementData`, `CreateInterpolator`,
> `CreateTreeDataProvider`, `EventRegistry`, `FormatShortDate`, `GameTooltip`,
> `InterpolatorUtil`, `LegacyChallengeFilters`, `LegacySystem`, `LegacySystemFrame`,
> `ScrollBoxConstants`, `SearchBoxTemplate_OnTextChanged`

**Blizzard_LegacySystemUtil.lua**
> **`Constants`**, **`ACHIEVEMENTFRAME_FILTER_COMPLETED`**,
> **`ACHIEVEMENTFRAME_FILTER_INCOMPLETE`**, `EventRegistry`, `LegacyChallengeFilters`,
> `LegacyTreeData`

**Blizzard_LegacyChallengeButton.lua**
> **`bit`**, **`EVALUATION_TREE_FLAG_PROGRESS_BAR`**,
> **`GENERIC_FRACTION_STRING_WITH_SPACING`**, `ACHIEVEMENTBUTTON_COLLAPSEDHEIGHT`,
> `ACHIEVEMENTBUTTON_DESCRIPTIONHEIGHT`, `AchievementFrame`, `AchievementTemplateMixin`,
> `Clamp`, `CreateFramePool`, `CreateFromMixins`, `GRAY_FONT_COLOR`, `InputUtil`,
> `LegacyChallengeObjectives`, `LegacySystemFrame`, `PlaySound`, `SOUNDKIT`,
> `TextureKitConstants`, `WHITE_FONT_COLOR`

**Blizzard_LegacyChallengeDetailPane.lua**
> **`ACHIEVEMENTFRAME_FILTER_INCOMPLETE`**, `AchievementFrame_SelectAndScrollToAchievementId`,
> `AchievementFrameAchievements_OnLoad`, `CreateDataProvider`, `EventRegistry`, `InputUtil`,
> `LegacyChallengeFilters`, `LegacySystem`, `SmartNavigation`

**Blizzard_LegacyChallengeCategoryList.lua**
> `CallbackRegistryMixin`, `CreateFromMixins`, `CreateScrollBoxListTreeListView`,
> `EventRegistry`, `LegacyChallengeViewedUtil`, `NORMAL_FONT_COLOR`, `PlaySound`, `ScrollUtil`,
> `SelectionBehaviorMixin`, `SOUNDKIT`, `TextureKitConstants`, `TreeDataProviderConstants`,
> `WHITE_FONT_COLOR`

**Blizzard_LegacyRewardTrack.lua**
> **`Constants`**, `EventRegistry`, `GenerateFlatClosure`, `InputUtil`,
> `LEGACY_TRACK_FRAME_TITLE`, `LegacySystem`, `SMART_NAV_INPUT_DIRECTION`, `SmartNavigation`,
> `SmartNavigation_AddJumpNavigationOverride`, `SmartNavigation_ClearJumpNavigationOverrides`

**Blizzard_LegacyTree.lua**
> **`Constants`**, **`Enum`** (`Enum.TraitNodeEntryType`, `Enum.TraitNodeType`),
> **`LEGACY_POINTS_AMOUNT`**, **`LEGACY_POINTS_AVAILABLE`**, **`LEGACY_POINTS_SEASONAL_CAP`**,
> `LEGACY_TREE_FRAME_TITLE`, `ClassTalentSearchMixin`, `CreateFramePoolCollection`,
> `CreateFromMixins`, `EventRegistry`, `GenerateClosure`, `GetAppropriateTooltip`,
> `GlowEmitterFactory`, `InputUtil`, `LegacyTreeData`, `PlaySound`, `RingedMaskedButtonMixin`,
> `SelectableButtonMixin`, `SOUNDKIT`, `TalentButtonUtil`, `TalentFrameBaseMixin`

**Blizzard_LegacySystemConstants.lua**
> **`Constants`**, **`LEGACY_TREE_PROFESSIONS`**, **`LEGACY_TREE_ADVENTURE`**,
> **`LEGACY_TREE_PROGRESSION`**, **`ACHIEVEMENTFRAME_FILTER_COMPLETED`**,
> **`ACHIEVEMENTFRAME_FILTER_INCOMPLETE`**

**Blizzard_LegacySystem.lua** — gamepad and frame plumbing only, nothing we need
> `ACTION_LABEL_SELECT`, `CreateFromMixins`, `EventRegistry`, `FCFDock_GetSelectedWindow`,
> `FRAME_ACTION_CLOSE`, `FRAME_ACTION_NAVIGATE`, `GAMEPAD_DPAD`, `GAMEPAD_FACE_BOTTOM`,
> `GAMEPAD_FACE_LEFT`, `GAMEPAD_FACE_TOP`, `GAMEPAD_MENU_LEFT`, `GAMEPAD_MENU_RIGHT`,
> `GAMEPAD_STICK_RIGHT_PRESS`, `GAMEPAD_TALENT_ADD_POINT`, `GAMEPAD_TALENT_APPLY`,
> `GAMEPAD_TALENT_REMOVE_POINT`, `GAMEPAD_TRIGGER_RIGHT`, `GamepadMode`, `GamepadScrollBarHint`,
> `GamepadSharedUtility`, `GENERAL_CHAT_DOCK`, `GenerateClosure`, `InputUtil`,
> `LegacySystemFrame`, `LegacySystemFrameCloseButton`, `PlaySound`, `PROMPT_TOGGLE_TOOLTIPS`,
> `PromptedBindingMixin`, `SidePanelTabButtonMixin`, `SMART_NAV_INPUT_DIRECTION`,
> `SmartNavigation`, `SmartNavigation_AddBidirectionalJumpNavigationOverride`,
> `SmartNavigation_AddJumpNavigationOverride`, `SmartNavigation_ClearJumpNavigationOverrides`,
> `SOCIAL_SHARE_TEXT`, `SOUNDKIT`, `UpdateMicroButtons`

**Blizzard_LegacySystem_Bootstrap.lua**
> `LoadAddOnWithErrorHandling`, `ToggleFrame`, `LegacySystemFrame`, `LegacySystemFrame_LoadUI`

**Blizzard_LegacySystemRegistration.lua**
> `RegisterUIPanel`, `LegacySystemFrame`

**Blizzard_LegacyChallengeTracker.lua**
> **`GetCategoryInfo`**, `EventRegistry`, `LegacyChallengesUnviewed`, `LegacyChallengeViewedUtil`

From outside the two Legacy addons, but used by code we depend on:
`C_Traits.GetNodeInfo` (Q9), `ACHIEVEMENT_FLAGS_ACCOUNT` (Q5),
`EVALUATION_TREE_FLAG_PROGRESS_BAR` (Q4), `MIN_CHARACTER_SEARCH` (Q1 contrast).

### Guard-layer notes

Everything we call in `SharedTraitsDocumentation.lua` and `MajorFactionsDocumentation.lua` is
marked `SecretArguments = "AllowedWhenUntainted"`. That is an argument-side restriction, not a
return-side one, but it is one more reason every `Api/` call keeps its `issecretvalue` guard.

`GetCategoryList`, `GetCategoryInfo`, `GetAchievementInfo`, `GetAchievementCriteriaInfo`,
`GetAchievementNumCriteria`, `GetCategoryNumAchievements`, `GetNumFilteredAchievements`,
`GetFilteredAchievementID` and `SetAchievementSearchString` appear in **no** generated
documentation file — they are legacy FrameXML globals. Their signatures here are inferred from
call sites, so they get feature-detected and `pcall`ed like everything else, and the fixtures
in `spec/fixtures/` have to come from a live dump.

---

## Professions — joining a character to a tradeskill challenge (2026-09-30)

Source reading at `bd2470a` (1.60.1.70009), for v1's candidate-alt mapping. ~~**Not verified in
game; queue row S1.**~~ The lookup and the parent reading were verified in game 2026-10-01; see
"S1, first paste" below. ~~A crafting profession is still unread.~~ Alchemy was read the same
day and reports 171; see "S1 closed" below.

- Tradeskill challenges are `criteriaType` 7. `assetId` is a skill line and `need` is the skill
  level: `Journeyman Alchemist` is 2937 / 150 (`spec/fixtures/dump_challenges_page1_fresh.lua`).
  2937 is not Classic's Alchemy line, 171.
- A character's professions come from `GetProfessions` (seven slots on Forever) and then
  `GetProfessionInfo(index)`, whose seventh return is `skillLine`
  (`Blizzard_Professions/Camelot/Blizzard_ProfessionsFrame.lua:60`).
- The same frame matches a tab's `skillLine` against `Professions.GetEffectiveSkillLineID()`
  (`:40-42`), which returns `professionInfo.parentProfessionID or professionInfo.professionID`
  (`Blizzard_ProfessionsTemplates/Blizzard_Professions.lua:1678-1681`, outside the pinned set;
  moved out of the frame at 70170). So Blizzard's
  own code expects `GetProfessionInfo`'s line to be the **parent**, and the line a recipe or
  challenge names to be a possible child.
- `C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID)` returns `ProfessionInfo`
  (`TradeSkillUIDocumentation.lua:488`), which carries `professionID`, `professionName` and
  the Nilable `parentProfessionID` / `parentProfessionName`
  (`TradeSkillUITypesDocumentation.lua:361`). No Blizzard caller of it was in the sparse
  checkout, so this is doc-only evidence (Tier A).
- **The client data agrees** (added 2026-09-30, "Client data (DB2)" below). In `SkillLine`,
  every line a tradeskill challenge names is a `ParentTierIndex` 4 child of a Classic
  profession line: 2937 → 171 Alchemy, 2938 → 164 Blacksmithing, 2940 → 333 Enchanting,
  2941 → 202 Engineering, 2945 → 165 Leatherworking, 2948 → 197 Tailoring. It is the same at
  builds 69913, 70009 and 70124. That is the parent/child split the frame expects. It does not
  say what the live `GetProfessionInfo` returns, so S1 still decides.

Consequence: `Model.ProfessionCandidates` accepts a direct match **or** a match through the
parent, which is correct whichever way the client answers. S1 answers two questions. Does the
lookup work for a line the character never learned? And which number does an Alchemy
character's `GetProfessionInfo` report?

## S1, first paste — 2026-10-01

One `/lgn roster` from Alex on build 1.60.1 (70124), saved as `spec/fixtures/roster_geo.lua`
with the printed text verbatim at the bottom. It ran on Geo-Classic Beta PvP, a level 5 Druid
with Herbalism 13/75 and Cooking 1/75. That was session 2. Session 1 was Bong (level 1
Shaman), about a minute long, then a logout to character select. It answers the first of
S1's two questions and half of the second.

**SavedVariables came back** [verified in game]. `== STORE ==` read `attached=true
loadedType=table loadedSessions=1 loadedCharacters=1 sessions=2 characters=2`. The addon
loaded again from scratch on Geo's login, and the table it found was session 1's: Bong's
snapshot and both of session 1's log entries (`SKILL_LINES_CHANGED+PLAYER_LOGIN`, then
`PLAYER_LOGOUT`). No `LATE LOAD`, and `globalIsOurs = true`. The original bug report was
about the read after a restart, so S1 step 4 is still the paste that closes it.

**The lookup answers for lines the character never learned** [verified in game]. All six, on
a character with no crafting profession:

| Line | `parentProfessionID` | `professionName` | `profession` |
|---|---|---|---|
| 2937 | 171 | Alchemy | 3 |
| 2938 | 164 | Blacksmithing | 1 |
| 2940 | 333 | Enchanting | 9 |
| 2941 | 202 | Engineering | 8 |
| 2945 | 165 | Leatherworking | 2 |
| 2948 | 197 | Tailoring | 7 |

That is the DB2 map exactly. Each struct carries the eleven fields
`TradeSkillUITypesDocumentation.lua:361-376` documents at `966519c`, and no others.
`professionID` echoes the line asked for. `skillLevel` and `maxSkillLevel` read 0,
`isPrimaryProfession` true, `sourceCounter` 2 on all six, and `expansionName` repeats the
profession's name. Any character's lookup now answers, so the saved account-wide map is a
backstop rather than a necessity.

**`GetProfessionInfo` reports the Classic line** [verified in game for two lines]. Geo's
Herbalism read 182 and Cooking 185. In `SkillLine` at 70124 both have Forever tier-4
children, 2944 Herbalism and 2939 Cooking, built like the six crafting lines
(`curl "https://wago.tools/db2/SkillLine/csv?build=1.60.1.70124"`, rows 182, 185, 2939,
2944). So where a line has a Forever child, the client reports the parent. No crafting
profession has been read. If Alchemy follows the same rule, it reads 171 and joins through
`parentProfessionID`, which `Model.ProfessionCandidates` already does.

**Tree spend cannot be read at logout** [verified in game]. Bong's `PLAYER_LOGOUT` snapshot
reads `written; trees: unspent points not read`. The login read was kept with its own time,
`treesAt` 58 s before `takenAt`, which is what the PR #2 review fix was for. Logout never
carries spend. Login and events do.

**Events** [verified in game]. In about 45 minutes on Geo, `SKILL_LINES_CHANGED` set off 51
snapshots, roughly one per Herbalism skill-up, and four of them also carried
`PLAYER_LEVEL_UP`, for levels 2 to 5. Each event restarted the 5 s wait. The paste has no
`events not registered:` line, so `TRAIT_CONFIG_UPDATED` registered. The 51 log lines were
noise in the paste, so `/lgn roster` now prints the first entry and the last nine.

**A contradiction with an older fixture.** The Shaman's name reads `Bong`.
`spec/fixtures/dump_character_shaman.lua` (2026-09-19) has `"Bong Wrip"`, while a criterion's
`charName` in that same capture reads `"Bong"`. ~~A player name cannot hold a space, so the
older file's name probably changed somewhere between the client and the fixture.~~ **Answered
by Alex the same day: Forever names have a first name and a surname, a Legacy feature. Bong
is the first name.** The old fixture is a faithful capture. What changed is `UnitName`: on
69913 it returned the full name, and on 70124 the first name only. `C_PlayerInfo.ShouldDisplaySurname` (`PlayerInfoDocumentation.lua:358`) is present at all
three pins. `C_NameUtil.ReplaceSurnameSeparatorWithLinkSeparator`
(`NameUtilDocumentation.lua:11`), documented as replacing "the character surname separator
with a link separator in a full name string", arrived with 70009. Neither has a caller in the
sparse checkout. The roster keys characters as `Name-Realm`, so a build that moves the
surname in or out of `UnitName` again would give one character two rows. D10's probe now
reads `UnitName`, `UnitFullName`, `UnitNameUnmodified`, `UnitGUID` and
`ShouldDisplaySurname` side by side.

## S1 closed, and D4 and D10 — 2026-10-01, later the same morning

Five more captures from Alex on build 1.60.1 (70124), after a full client restart, on Geo
Prizm (Geo is the first name), now a level 6 Druid who has trained Alchemy:

- `/lgn roster` → `spec/fixtures/roster_geo_restart.lua`
- `/lgn uidump roster`, the same login, verbatim at the bottom of that file
- `/lgn dump character` → `spec/fixtures/dump_character_geo.lua`
- `/lgn dump probe`, written up here and not fixtured, as with D2 and D5
- two screenshots, the Roster tab and Next Up with a tooltip

**SavedVariables come back off disk** [verified in game]. The first read after a full restart:
`loadedType=table loadedSessions=2 loadedCharacters=2 sessions=3`, no `LATE LOAD`. The saved
log carried session 2's last ten entries, ending in its `PLAYER_LOGOUT`. S1's fallback step,
`## LoadSavedVariablesFirst`, is not needed.

**Alchemy reports the Classic line, 171** [verified in game]. `GetProfessionInfo`'s
`skillLine` for Alchemy is 171, not the 2937 the challenges name, so all three lines seen in
game report the parent. Geo joined Journeyman, Expert and Artisan Alchemist through
`parentProfessionID`, at 1/150, 1/225 and 1/300. With no parent map the same snapshot joins
nothing, and a test pins that.

**`GetProfessions` slots** [verified in game, D4]. Alchemy in slot 1, Herbalism in 2, Cooking
in 5, at `GetProfessionInfo` indexes 4, 5 and 6. Slot 5 is where Mainline puts cooking too.
Each entry carried `icon`, `modifier` and `skillLineName` besides the four the snapshot keeps.
How many values `GetProfessions` returns in all is not in the dump, and Api iterates them all
either way.

**Professions cannot be read at logout either** [verified in game]. Session 2's
`PLAYER_LOGOUT` snapshot read `trees: unspent points not read; professions: empty read, kept
stored`. `GetProfessions` returned nothing at logout, and the empty-read rule from the PR #2
review kept the login list.

**D10: no secrets on 70124** [verified in game]. Every probe row read `ok`, apart from
`GetMajorFactionData`'s expected `partial`, which drops the same 14 ColorMixin methods as D5.
No row and no tally entry read `secret`, `error` or `missing`. `issecretvalue` read `guard
active`, and all six constants and both flags read `(runtime)`. The trait config handle was
11385528 this time, another transient value. `wowProjectId` read 1, Mainline. The probe had no
name rows, since the installed build came from main rather than the branch that adds them.
That half of D10 is still open.

**The frame, seen** [verified in game, U1 and U4]. On Next Up the header's middle dot renders
as a dot. The filter bar wraps to two lines at `All (41)`, and the three Alchemy rows sit in
their own "in progress" tier, ordered by fraction. The tooltip carried every line, down to
"Geo 1/150, 149 to go". On Roster the `P/A/R` and `Free` headings sit over their columns, Geo
is in gold, and the footnote draws below the rows. The selected tab shows as white text on
the same red button, which reads, but faintly. The roster uidump said `read took 37 ms`
against U1's 21 ms. The window read now takes a snapshot and reads the roster too.

## D10 closed, and U6 — 2026-10-01, evening

Captures from Alex on build 1.60.1 (70170), with `main` at `eff7956` installed, on Geo Prizm,
a level 6 Druid with Alchemy 1:

- `/lgn dump probe`, Alex's gist "D10 lgn dump probe". Written up here and not fixtured, as
  with D2 and D5
- `/lgn uidump`, Alex's gist "lgn uidump"
- two screenshots, Next Up and Roster, plus Alex's answers on window state

**The surname is the second return** [verified in game]. `UnitName`, `UnitFullName` and
`UnitNameUnmodified` each read `Geo, Prizm`. The docs name that slot `server`
(`UnitDocumentation.lua:2489`, `:1224`, `:2523`). `C_PlayerInfo.ShouldDisplaySurname` read
`true`. With the morning section above, the history for `UnitName` is this. 69913 returned
`"Bong Wrip"` as the first value, and from 70124 the first value is the first name alone. The
70124 probe printed only the first return, so whether 70124 already put the surname second is
not known. The roster key reads `UnitName`'s first return and `GetRealmName`
(`Api.lua:732-733`), so the second slot never reached it.

**`UnitGUID` reads** [verified in game]: `ok`, `Player-4619-012F81BC`, not a secret. That
makes a GUID-keyed roster possible. Whether to switch is a decision, not a finding, and is in
`docs/status.md`.

**No secrets on 70170** [verified in game], the same result as 70124. Every row and tally
entry read `ok`, apart from `GetMajorFactionData`'s expected `partial`, which drops the same
14 ColorMixin methods. `issecretvalue` read `guard active`, and all six constants and both
flags read `(runtime)`. The trait config handle was 11385528, the same number as 70124's
probe, also on Geo. CLAUDE.md's rule against caching it stands.

**`WOW_PROJECT_ID` moved from 1 to 18** [verified in game]. Every earlier capture, the 70124
fixtures included, has `wowProjectId = 1`. This one has 18. The vendored constants files define
1, 2, 5, 11, 14 and 19 (`Blizzard_FrameXMLBase/Mists/Constants.lua:138-143`), and nothing for
18. We never gate on it. The probe's `GetProfessions` row reads `4`, which is the first
return (Alchemy's index), not a count.

**The polish pass, seen** [verified in game, U6]. The uidump's `tabTemplate` read
`PanelTopTabButtonTemplate`, so the client gave us Blizzard's top tabs, not the fallback. In
the screenshots the selected tab is raised and gold and the other is darker, which replaces
the faint selected state U1 saw. Every challenge row has its icon, and the names line up. The
next reward's icon (the air rifle) sits before "Next:". On Roster, Geo reads in Druid orange
on a gold band, and Bong in Shaman blue. Rows, tiers and counts match the uidump: 41 ranked,
the three Alchemy rows in progress at 1/150, 1/225 and 1/300. The read took 26 ms. After a
filter change, a drag and a switch to Roster, `/reload` brought back the tab, the filter and
the position. A relog was not reported. One cosmetic note: the scroll bar draws on Roster with
nothing to scroll.

**C3: real partial progress** [verified in game]. `/lgn dump challenges 1` on Geo, the same
login, is `spec/fixtures/dump_challenges_page1_geo.lua`. Journeyman, Expert and Artisan
Alchemist (62012-62014) each carry one type-7 criterion on line 2937 at `have = 1`, with
`completed = false`, `flags = 1`, `isProgressBar = true` and `quantityString` `"1 / 150"`.
`have` follows the character's skill, as the type-7 reading predicted. Compared field by field
with `dump_challenges_page1_fresh.lua` (69913), nothing else on the page changed in four
builds, IDs and flags included, apart from Rank 13's description, which gained an "of". The
failure tally was clean.

**U5 and U7** [verified in game]. The minimap's addon dropdown lists LegacyNext with the gold
ring icon, and the click toggles the window, so the compartment loads on Forever with
`WOW_PROJECT_ID` at 18. The key binding toggles the window, in combat too, so `Bindings.xml`
loads with no TOC line. The AddOns list groups LegacyNext under Achievements.

**U6's relog** [verified in game]. After logging out to another character and back, the
window kept its tab, filter and position, as it did across `/reload`. U6 is closed.

**C2, in part** [verified in game]. With `/etrace` running through an Alchemy skill-up,
`CRITERIA_UPDATE` fired and `ACHIEVEMENT_EARNED`, `TRAIT_CONFIG_UPDATED`, `TRAIT_TREE_CHANGED`
and `MAJOR_FACTION_RENOWN_LEVEL_CHANGED` did not. That is the first sighting of either event
the frame depends on. The other four need a completion or a spent point.

**U2: the ellipsis is free** [verified in game]. WoWLua does not load on 70170, so the test
ran as a 232-character `/run` line. The 120 px no-wrap string read `IsTruncated() = true` and
drew as "Reach exalted re...". Detail in `docs/ui-templates.md`.

---

## Client data (DB2) via wago.tools — 2026-09-30

wago.tools publishes the client's data tables (DB2) as CSV for every build. These are the rows
the client itself reads, so they answer some questions the API cannot, without a trip into the
game. **They are research evidence only, in the same way `vendor/` is.** They are never a
runtime source, never shipped, and never a reason to hardcode an ID.

```sh
curl -sS "https://wago.tools/api/builds" | jq -r '.wow_classic_beta[].version' | grep '^1\.6' | sort -V
# ... 1.60.1.69913, 1.60.1.69977, 1.60.1.70009, 1.60.1.70058, 1.60.1.70124 on 2026-09-30
curl -sS -o Achievement.csv "https://wago.tools/db2/Achievement/csv?build=1.60.1.70009"
```

Five tables were read: `Achievement`, `CriteriaTree`, `Criteria`, `TraitCurrencySource` and
`SkillLine`, each at builds **69913** (our fixtures), **70009** (the pin) and **70124** (the
newest). The join follows `Achievement.Criteria_tree` down the `CriteriaTree.Parent` chain to
the leaves that carry a `CriteriaID`. Each leaf gives `Criteria.Type` and `.Asset`, plus
`CriteriaTree.Amount` as the threshold. A challenge is point-bearing when it has a
`TraitCurrencySource` row with `TraitCurrencyID` 4225. The check was a throwaway Python
script and is not committed. Every result below is identical at all three builds.

**The data agrees with our captures.** All 26 challenges in `spec/fixtures/`, 16 of them
point-bearing, match on ID, `flags` and points, with zero mismatches. That is the grounds for
trusting the rest.

**Two mirrored sets of 65.** `TraitCurrencySource` has **130** rows for currency 4225. 65
carry flag bit 27 (`0x08000000`) and 65 carry bit 28 (`0x10000000`). Both sets split the same
way: Classes 27, Tradeskills 18, Player vs. Player 12, Dungeons 3, Raids 3, Adventure 2. Every
challenge ID in our captures is in the bit-27 set. The mirror uses its own IDs: Novice Warrior
is 61499 in ours and 63969 in the mirror, and Novice Spelunker is 62031 and 64016. Its criteria
have new IDs too (checked on those two: 110153 → 117712, 19213 → 117733). The client listed
only ours on two characters. **Which
ruleset or realm sees the mirror is unknown.** For v1, a character who sees the mirror would
report different challenge IDs for the same challenge.

**Class levels are in the data, not the API.** Each of our 27 class challenges has exactly one
leaf, `Criteria.Type` 5 with `Asset` 0, and a `CriteriaTree.Amount` of 25, 45 or 60 (nine of
each). The leaf also carries a `ModifierTree`, presumably the class restriction: 422101 on all
three Druid tiers. We have not decoded it. The live API reports `criteriaExpected == 0` for the same challenges
(`spec/fixtures/dump_challenges_page1_fresh.lua`). So the number exists in the client but no
API we know of hands it to addon code.

**Criteria types behind our 65**, grouped by what each challenge's leaves hold:

| Leaves | Challenges | Examples |
|---|---|---|
| one type 5 (level) | 27 | Novice / Experienced / Master of each class |
| one type 7 (skill) | 18 | Journeyman Alchemist, 2937 / 150 |
| one type 261 | 5 | Rank 3, Rank 7, Rank 10 |
| one type 27 (quest) | 4 | Lord Valthalak Laid to Rest, Field of Honor: Week 4 |
| one type 0 | 1 | Conqueror of the Lair |
| one type 8 | 1 | Explorer |
| several type 0 | 3 | Experienced Spelunker, Conquerer of the Deeps |
| type 0 and 78 | 1 | Novice Spelunker |
| type 0 and 165 | 1 | Conquerer of the Wilds |
| several type 243 | 4 | Master of Alterac Valley |

Types 5 and 261 never reached our dumps, because the API showed those 32 challenges with no
criteria at all. That is 32 of the 34 no-criteria challenges. Legacy Forever's generator calls
261 "rank". We have not decoded its `Asset` or `Amount`. Type 78 has `Asset` 0 and a
`ModifierTree` instead (455791 on Novice Spelunker). That is how "Ragefire Chasm or Hall of
Thanes" names two dungeons in one criterion.

**Tradeskill lines are children of the Classic lines.** See the Professions section above.

---

## Legacy Forever — what another Legacy addon shows, 2026-09-30

<https://github.com/cjber/legacy-forever>, v0.6.7, read at `c489de8`. It puts unfinished
challenges on the world map by zone, with a tracker and zone completion. Its data is generated
from the DB2 tables above, and a daily workflow opens a PR when wago.tools lists a new build.
**It is GPL-3.0-or-later and LegacyNext is MIT, so we take facts and approaches from it, never
code.** It does not rank challenges by closeness and does not track alts.

What it adds to our picture:

- **SavedVariables.** Its TOC sets `## LoadSavedVariablesFirst: 1`, and it ships features that
  depend on saved data. Its own code still guards against missing saves: "Forever's beta
  client can start without the saved variables loaded" (`UI/WhatsNew.lua:12`). Its audit marks
  whether Forever honours the directive as unproven. Blizzard's own challenge tracker also
  sets it (`Blizzard_LegacyChallengeTracker.toc:6`, Q6 above). Our TOC does not, which is why
  S1 has a fallback step.
- **Achievement tracking is refused.** It says Forever's ruleset makes `C_ContentTracking`
  report achievements as `Untrackable` (`UI/Tracker.lua:5`). The enum value is real
  (`Blizzard_APIDocumentationGenerated/ContentTrackingTypesDocumentation.lua:13`). We have not
  seen it refuse. Its own objective-tracker section then needed taint fixes in six releases
  (0.6.2 to 0.6.7). That supports the no-hooking rule.
- **Opening Blizzard's Legacy panel on one challenge.** Three calls, all present at our pin:
  `ToggleLegacySystemUI()` (`Blizzard_LegacySystem/Blizzard_LegacySystem_Bootstrap.lua:7`)
  loads and shows the panel. Since 70170 it does nothing at zero points (`:8-10`). `EventRegistry:TriggerEvent("Legacy.SelectPage", 2)`
  (`Blizzard_LegacySystem.lua:12`) switches to the challenges page, tab `id="2"` in
  `Blizzard_LegacySystem.xml:16`. `AchievementFrame_SelectAchievement(id, true)`
  (`Blizzard_LegacyChallenges.lua:310`) selects the challenge. These are calls, not hooks.
  One catch: `Blizzard_AchievementUI` defines a global with the same name
  (`Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.lua:2811`), and whichever file
  loads last owns it. Feature-detect it.
- **Criteria keyed by ID.** It keys criteria by `criteriaID`, the tenth return of
  `GetAchievementCriteriaInfo`, because DB2 order and API order need not agree. Worth copying
  as an approach for anything v1 persists.
- **Single-step challenges.** When `GetAchievementNumCriteria` is 0, it treats the whole
  achievement as its one step, using the description as the text. That matches our "no
  progress shown" tier.
- **Release evidence** that closed our CurseForge check. See `docs/distribution.md` §3.

## Beta2 UI research — 2026-10-02

Source only, at `9a789c0` (1.60.1.70170), after widening the checkout to `Blizzard_Settings`,
`Blizzard_Settings_Shared` and `Blizzard_Minimap`. Paths are under `Interface/AddOns/`. U9, U10
and U11 check it in game.

**`Blizzard_AchievementUI`'s Mainline code loads on Forever.** An earlier reading said only its
bootstrap and the one-line `Camelot/Blizzard_AchievementUI.lua` did. That was wrong. `[Family]`
resolves to Mainline: tocs pair `[Family]… [ExcludeLoadGameType camelot]` with `[Game]…
[AllowLoadGameType camelot]` (`Blizzard_FrameXMLBase.toc:15-16`, `Blizzard_Minimap.toc:13-14`).
And `Blizzard_LegacySystem` depends on the addon (`Blizzard_LegacySystem.toc:4`) and calls into
its Mainline functions. The camelot line (`Blizzard_AchievementUI.toc:8`) loads on top of it.

Opening the Legacy panel on one challenge, which supersedes the three-call sketch under
"Legacy Forever" above:

- `LegacySystemFrame` is a UI panel, `area="left"`, `pushable=1`, `width=1005`
  (`Blizzard_LegacySystem/Blizzard_LegacySystemRegistration.lua:2-11`). `ToggleFrame` goes
  through `ShowUIPanel`, which refuses addon calls in combat
  (`Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua:854-860`, `:886`). It can also
  refuse a panel that does not fit (`:185-188`), so the caller checks `IsShown` after it.
- The page switch has to come first. `AchievementFrame_SelectAchievement`'s Legacy override
  (`Blizzard_LegacyChallenges.lua:310-320`) fires `Legacy.OpenToChallengeCategory` and
  `Legacy.SelectChallenge` but never switches pages. The category list is built only in
  `ChallengesPage:OnShow` (`:31-41`), and `OpenToCategory` does nothing without it
  (`Blizzard_LegacyChallengeCategoryList.lua:136-153`). The order is: toggle, then
  `Legacy.SelectPage` with 2 (`Blizzard_LegacySystem.lua:1`, `:12-15`, `:69-79`), then select.
  First load selects page 1 (`:19`).
- Not provable from source: whether the page's `OnShow` runs inside `SetShown`, synchronously.
  U9 answers it.

Chat links: Blizzard's challenge rows inherit `AchievementTemplateMixin`
(`Blizzard_LegacySystem/Blizzard_LegacyChallengeButton.lua:202`, `:223-224`), whose click runs
`IsModifiedClick("CHATLINK")`, then `ChatFrameUtil.InsertLink(GetAchievementLink(id))`
(`Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.lua:1130-1159`). None of
`GetAchievementLink`, `IsModifiedClick` or `ChatFrameUtil` is in the generated docs or defined
in the checkout.

Settings (`Blizzard_Settings_Shared/Blizzard_Settings.lua` unless named):

- The shared addon has `## AllowLoad: Both` and no game-type gate (`Blizzard_Settings_Shared.toc:7`).
  `Blizzard_Settings` itself is load-on-demand and holds one line. `SettingsPanel:Open()`
  loads it (`Blizzard_SettingsPanel.lua:308-310`).
- `RegisterVerticalLayoutCategory(name)` `:154`, `RegisterProxySetting(category, variable,
  varType, name, default, get, set)` `:178`, `CreateCheckbox(category, setting, tooltip)` `:388`,
  `RegisterAddOnCategory(category)` `:134`, `OpenToCategory(categoryID)` `:144`, `VarType` `:11-16`.
- `RegisterAddOnSetting` keeps a reference to the table it is handed and writes defaults into it
  (`Blizzard_Setting.lua:398-427`). That is why we use proxy settings.
- `OpenToCategory` calls `C_SettingsUtil.OpenSettingsPanel`, documented `HasRestrictions`
  (`SettingsUtilDocumentation.lua:15-18`), and the panel then shows through `ShowUIPanel`. That
  is blocked in combat for addon calls.
- Nothing in the checkout calls these as an addon would. The only example is the readme comment
  (`Blizzard_ImplementationReadme.lua:53-98`), which no toc loads.

Minimap (`Blizzard_Minimap/`):

- `Minimap` is 198x198 inside `MinimapContainer` inside `MinimapCluster`
  (`Mainline/Minimap.xml:3-9`, `:186-199`). The camelot skin masks it round
  (`Camelot/Skin.lua:34`). No `GetMinimapShape` exists anywhere in the checkout.
- Edit Mode scales `MinimapContainer`, not `Minimap` (`Mainline/Minimap.lua:374-382`; Camelot
  wraps it, `Camelot/Diel.lua:47-67`). A child of `Minimap` scales with it, and its radius math
  stays in the minimap's own units.
- Nothing walks `Minimap`'s children or moves third-party ones. In some zones
  `C_Minimap.ShouldUseHybridMinimap` swaps in `HybridMinimap` (`Mainline/Minimap.lua:226-236`).
  That addon is outside the checkout, so whether our button shows over it is unknown.
- Textures with an in-pin user: `Interface\Minimap\MiniMap-TrackingBorder`
  (`Blizzard_FrameXML/ItemDisplay.xml:84`), `Interface\Minimap\UI-Minimap-ZoomButton-Highlight`
  (`Mainline/Minimap.xml:411`), and the round mask `Interface\CharacterFrame\TempPortraitAlphaMask`
  (`Blizzard_SharedXML/Shared/FrameTemplate/RingedFrameTemplate.xml:51`). The classic
  `UI-Minimap-Background` appears nowhere, so the button draws its own dark disc.

---

## PR #11 review research — 2026-10-02

Source-only at `9a789c0` (`1.60.1.70170`). U9 and U11 include the live regression checks.

- Blizzard's category provider excludes categories when completion or search filters hide
  their challenges (`Blizzard_LegacySystem/Blizzard_LegacyChallenges.lua:44-85`). Its detail
  provider also excludes rows (`Blizzard_LegacyChallengeDetailPane.lua:39-50`), and its select
  override returns no success flag (`Blizzard_LegacyChallenges.lua:310-320`). A successful
  `pcall` alone therefore cannot confirm selection.
- `AchievementFrame_FindDisplayedAchievement(id)` resolves a chain to its displayed tier
  (`Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.lua:3441-3469`). The override uses
  it at `Blizzard_LegacyChallenges.lua:315`. `AchievementFrameAchievements_GetSelectedAchievementId()`
  returns the selected id, or 0 when none is selected
  (`Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.lua:950-956`). The detail pane creates
  that shared selection behavior through `AchievementFrameAchievements_OnLoad`
  (`Blizzard_LegacyChallengeDetailPane.lua:6`). The addon compares these scalar ids and reports
  an unselected challenge with a filter-clearing hint. It does not change the shared search.
- `Settings.NotifyUpdate(variable)` calls the registered setting's `NotifyUpdate()`
  (`Blizzard_Settings_Shared/Blizzard_Settings.lua:206-210`). That method publishes the
  getter's current value (`Blizzard_Setting.lua:180-188`), which updates displayed controls.
  External visibility and lock writes now use it.
- Proxy setters' return values are discarded (`Blizzard_Setting.lua:333-335`), and
  `SettingMixin:ApplyValue` publishes the requested value after invoking the setter
  (`:124-136`). A refused write therefore needs both a chat explanation and a later
  notification to restore the checkbox. The addon queues the refresh with
  `C_Timer.After(0, callback)` (`UITimerDocumentation.lua:11-19`, a zero-delay caller at
  `Blizzard_SharedXMLGame/DressUpModelFrameMixin.lua:188`). Inline recorders test that order;
  these observations do not claim a live-client verification.

## The beta2 session — 2026-10-02, night

Alex, on `v0.1.0-beta2` from CurseForge, build 70170: Geo (level 7 Druid) first, then Bong
(level 1 Shaman). The account was at 0 Legacy points. Captures are in
`spec/fixtures/roster_bong_migrated.lua`, with the rendered pastes and the uidump at its bottom.

- **S2 closed.** Geo's first login logged `migrated from Geo-Classic Beta PvP`, and Bong's logged
  `migrated from Bong-Classic Beta PvP`. Each row is keyed by its GUID (`Player-4619-012F81BC`,
  `Player-4619-00BADC1B`), with `name` the first name and the professions and spend kept. Neither
  moved again across a `/reload`. Plymouth did not log in, so its row keeps `Plymouth-Classic Beta
  PvP`, as designed. The roster shows names only, never a `Player-` string.
- **Logout reads depend on how the session ends.** Sessions 21 (Geo) and 23 (Bong) ended in
  the runbook's `/reload` and logged a bare `PLAYER_LOGOUT -> written`: trees and professions both
  read. Session 22 (Geo again, after that `/reload`) ended in a logout to character select and
  logged `trees: unspent points not read; professions: empty read, kept stored`, as every logout
  on 2026-10-01 did. The rule in `CLAUDE.md` stands, with `/reload` as the exception.
- **U8 closed.** `resize = "SetResizeBounds"`, `grip = "PanelResizeButtonTemplate"`,
  `resizable = true`, and 961x684 restored after `/reload`.
- **U11 closed.** `options { registered = true }`. Blizzard's Settings API, proxy settings
  included, works for an addon on Forever.
- **U10, all but one step.** `minimap { angle = 228, created = true, masked = true }`, so
  `SetMask` with `TempPortraitAlphaMask` works. The `EDGE` offset of 5 put it on the rim, and the
  angle held across `/reload`. The dropdown hover was not reported.
- **U9, at 0 points only.** The hint, both chat refusals ("no Legacy points yet", "open a chat
  box first"), the combat refusal and the shift-click link in and out of combat all work. Nothing
  touched Blizzard's panel, so the select and the taint question wait for a point.
- The Next Up read took **24 ms** on 41 ranked rows, against 21 ms on U1.

## In-game commands (retired 2026-09-26)

This section used to hold the Phase 1 command list, C1 to C9. **Those IDs are retired and are
not the queue's.** The live queue in `docs/ingame-commands.md` reuses C1 to C4 for different
questions, and two lists with clashing IDs sent citations to the wrong one. Every command
below was answered or folded into a queue row. The table records where, so an old citation
still resolves. The commands are gone because `/lgn dump` and `/lgn probe` replace them.

| Old ID | Asked | Answered by | Result |
|---|---|---|---|
| ~~C1~~ | Constants before the LoD addon loads (Q11) | Queue A, 2026-09-18 | Present, `IsAddOnLoaded` false. Q11 above |
| ~~C2~~ | Tree display names (Q8) | Queue A, 2026-09-18 | 1189 is "Resourcefulness". Q8 above |
| ~~C3~~ | Category list scope and shape (Q1, Q2) | Queue B, 2026-09-18; D9, 2026-09-19 | Legacy only, 29 categories, two levels. `spec/fixtures/categories_full.lua` |
| ~~C4~~ | Empty search string semantics (Q1) | In game, 2026-09-18 | 0 at login, 111 after `SetAchievementSearchString("")`. We never call it. Q1 above |
| ~~C5~~ | Account-wide flag (Q5) | Queue A, 2026-09-18; D2, 2026-09-19 | `ACHIEVEMENT_FLAGS_ACCOUNT` = 131072, live global. Q5 above |
| ~~C6~~ | Point cap, shared pool or per tree (Q7) | Half: queue A at zero points | The recheck with points spent is **queue C1**, still open |
| ~~C7~~ | Reward track shape (Q10) | Queue B, 2026-09-18; D6, 2026-09-19 | `spec/fixtures/dump_rewards_fresh.lua` |
| ~~C8~~ | Do the update events fire (Q12) | Not yet | Now **queue C2**, still open |
| ~~C9~~ | Criteria shapes for fixtures (Q4) | Queue B; D3 and D7, 2026-09-19 | `spec/fixtures/dump_challenges_page1_fresh.lua`, `dump_criteria_types.lua` |
