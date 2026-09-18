# Legacy internals

Read-only research against the pinned `wow-ui-source` checkout (`forever`,
`70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e`, `version.txt` `1.60.1.69913`). See
`vendor/PINS.md`.

Citations are `path:line`, rooted at `vendor/wow-ui-source/Interface/AddOns/`.

Four files cited here sit outside the sparse set recorded in `vendor/PINS.md`
(`Blizzard_MicroMenu`, `Blizzard_SharedTalentUI`, `Blizzard_FrameXML`,
`Blizzard_FrameXMLBase`). They were read by temporarily widening the sparse checkout to
`Interface` at the same SHA, then narrowing back. To re-read them:

```sh
cd vendor/wow-ui-source && git sparse-checkout set Interface   # 53 MB, 4405 files
```

## Summary

| | Question | Status |
|---|---|---|
| Q1 | Challenge enumeration | **Answered**, with two unresolved sub-questions |
| Q2 | Category representation | **Answered** in mechanism; the actual category set is unresolved |
| Q3 | Points per challenge | **Answered** |
| Q4 | Criteria in the detail pane | **Answered** |
| Q5 | Account-wide vs per-character | **Answered**, one constant value unresolved |
| Q6 | What the Challenge Tracker does | **Answered** |
| Q7 | Spent / unspent / cap | **Answered** in fields; cap scope unresolved |
| Q8 | Tree 1189 display name | **UNRESOLVED: needs in-game check** |
| Q9 | `LEGACY_TREE_ADVENTURE_TALENTED_NODE_ID` | **Answered** |
| Q10 | Reward track math | **Answered**, reward *names* unresolved |
| Q11 | Load-on-demand | **Answered**, one unresolved sub-question |
| Q12 | Events | **Answered** |

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

- **UNRESOLVED: needs in-game check** — does `GetCategoryList()` return only Legacy
  categories on Forever, or every achievement category? The Legacy page applies no
  Legacy-specific filter, so either Forever narrowed the global or the Legacy frame would show
  ordinary achievements. See command **C3**.
- **UNRESOLVED: needs in-game check** — with an empty search string, does
  `GetNumFilteredAchievements()` return everything or zero? The Legacy page uses the filter
  set as a hard gate for visibility, so empty must mean "everything passes" for the UI to work
  at all. See command **C4**.

**Consequence for us:** `SetAchievementSearchString` is global client state shared with the
Achievement UI. Calling it would clobber whatever the user has typed there. v0 should
enumerate categories directly and never call it.

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

**UNRESOLVED: needs in-game check** — which categories actually exist, and whether the public
six-ish grouping (classes, professions, adventure/exploration, PvP, reputation,
dungeons/raids) is one top-level category each or a deeper tree. The IDs must not be
hardcoded; we need the shape so the category filter UI knows whether to render a flat list or
a tree. See command **C3**.

### Q3. Points per challenge

`C_Traits.GetTraitCurrencyForAchievement(traitCurrencyID, achievementID) → amount`.

- Doc: `Blizzard_APIDocumentationGenerated/SharedTraitsDocumentation.lua:454-468`. Both
  arguments `number`, non-nilable; single return `amount`, type `number`, non-nilable (so no
  nil-for-zero case). `SecretArguments = "AllowedWhenUntainted"`.
- Call site: `Blizzard_LegacyChallenges.lua:309-312`, inside the
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
`Blizzard_FrameXMLBase/Constants.lua:110` (outside the pinned set).

- **Flag set:** progress bar, `quantity` clamped into `0..reqQuantity`, label formatted with
  `GENERIC_FRACTION_STRING_WITH_SPACING` — lines 118-122. This is the `3/5` case.
- **Flag clear:** a text row with a checkmark when complete — lines 110-114. `quantity` and
  `reqQuantity` are *not* shown; remaining progress is a count of incomplete criteria.

**Consequence for us:** "criteria remaining" is two different calculations depending on the flag.
Ranking by closeness has to handle both: a fraction for progress-bar criteria, and
`incomplete / total` for boolean criteria lists.

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
  **UNRESOLVED: needs in-game check** — `ACHIEVEMENT_FLAGS_ACCOUNT` is not defined anywhere in
  the pinned dirs. See command **C5**.
- **`wasEarnedByMe` (position 13)** is what separates per-character from account completion.
  The Legacy detail pane explicitly counts other characters' completions as incomplete —
  `Blizzard_LegacySystem/Blizzard_LegacyChallengeDetailPane.lua:45-49`:

```lua
local achievementId, _,_,_,_,_,_,_,_,_,_,_, wasEarnedByMe = GetAchievementInfo(categoryInfo.id, index);
-- consider achievements earned by others incomplete
local shouldHideCompletedByOther = not wasEarnedByMe and hideIncomplete;
```

- And the completion override — `Blizzard_LegacyChallenges.lua:305-307`:

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
| Unspent / available points | `quantity` | `Blizzard_LegacySystem/Blizzard_LegacyTree.lua:311-313` |
| Cap (tooltip, `LEGACY_POINTS_SEASONAL_CAP`) | `maxQuantity` | `Blizzard_LegacyTree.lua:315` |
| Spent in the selected tree | `spentInTree` | `Blizzard_LegacyTree.lua:98` |
| Total earnable (bar maximum) | `C_Traits.GetMaxAvailableTraitCurrency(currencyID, false)` | `Blizzard_LegacyChallenges.lua:257` |
| Points earned account-wide | `C_MajorFactions.GetCurrentRenownLevel(2802)` | `Blizzard_LegacySystemUtil.lua:38` |

That last row is the surprising one: the number shown as "Legacy points earned" is the
**renown level** of faction 2802, stuffed onto the currency table as `renownCurrency` —
`Blizzard_LegacySystemUtil.lua:38`, `Blizzard_LegacyTree.lua:107`. The points bar is
`renownCurrency / GetMaxAvailableTraitCurrency(...)` —
`Blizzard_LegacyChallenges.lua:257-263`. So reward-track level and account points earned are
the same number.

`excludeStagedChanges` is passed `true` from `LegacySystem.UpdateCurrencyInfo` —
`Blizzard_LegacySystemUtil.lua:32-41`, which reads `LegacyTreeData[1]` (Professions) and uses
it as the account-wide summary. The talent panel instead passes
`self.excludeStagedChangesForCurrencies` —
`Blizzard_SharedTalentUI/Blizzard_SharedTalentFrame.lua:1353-1371` (outside the pinned set).

**UNRESOLVED: needs in-game check** — is the 16-point cap per character across all three
trees, or per tree? The source is suggestive but not conclusive: all three trees share
currency `4225`, and the struct carries both `spent` and `spentInTree` as separate fields,
which only makes sense if `spent` is currency-wide and `spentInTree` is per tree. That implies
a single shared 16-point pool. `LegacySystem.UpdateCurrencyInfo` reading only tree 1 for an
account-level summary points the same way. Confirm with command **C6**.

### Q8. Tree 1189 display name

**UNRESOLVED: needs in-game check.**

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
`ProfessionConstantsDocumentation.lua:318` and friends). Command **C2**.

Note the internal name is "Progression" while the public name is reportedly
"Resourcefulness" — do not assume the atlas name, the constant name, and the display string
agree.

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

Setup — lines 21, 43-48:

```lua
self.majorFactionData = C_MajorFactions.GetMajorFactionData(Constants.LegacyConsts.LEGACY_REWARD_TRACK_FACTION_ID);
self.renownLevelsInfo = C_MajorFactions.GetRenownLevels(self.majorFactionData.factionID);
self.maxLevel = self.majorFactionData.maxLevel;
for level, levelInfo in ipairs(self.renownLevelsInfo) do
    levelInfo.rewardInfo = C_MajorFactions.GetRenownRewardsForLevel(self.majorFactionData.factionID, levelInfo.level);
end
```

Current level — lines 168-172, `C_MajorFactions.GetCurrentRenownLevel(factionID)`, stored as
both `actualLevel` and `displayLevel`.

Visibility gate — line 182: `majorFactionData.isUnlocked and not
C_MajorFactions.IsMajorFactionHiddenFromExpansionPage(factionID)`.

**Progress to next is computed from the levels table, not from reputation.**
`SetupProgressDetails` — lines 187-205:

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

`threshold` and `progress` are dead locals — lines 189-190 assign them and nothing reads them.
Everything downstream (lines 207-236) is bar-pixel layout against the hardcoded card position
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

**UNRESOLVED: needs in-game check** — "next reward name" has no name field. The reward struct
carries IDs and an icon only, so a name means resolving `itemID`/`spellID`/`mountID`
separately, and the card mixin that renders them (`RewardTrackFrameMixin`, referenced at
`Blizzard_LegacyRewardTrack.lua:242`) is not in the pinned set. Command **C7** dumps a real
reward so we can see which ID fields are actually populated before picking a lookup strategy.

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
the rest waits. `Blizzard_LegacySystem_Bootstrap.lua:1-16`:

```lua
function LegacySystemFrame_LoadUI()
    return LoadAddOnWithErrorHandling(AddonName);
end

function ToggleLegacySystemUI()
    if not LegacySystemFrame then
        if not LegacySystemFrame_LoadUI() then return; end
    end
    if LegacySystemFrame then ToggleFrame(LegacySystemFrame); end
end
```

Triggered from exactly two places: the micro button at
`Blizzard_MicroMenu/Mainline/MainMenuBarMicroButtons.lua:1045`, and a key binding at
`Blizzard_FrameXML/Bindings_Camelot.xml:1218` (both outside the pinned set).

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

**UNRESOLVED: needs in-game check** — is `Constants.LegacyConsts` populated before
`Blizzard_LegacySystem` loads? It should be (the `Constants` table is client-provided, and
`Blizzard_MicroMenu` reads `Constants.LegacyConsts` at startup without the Legacy addon
loaded, which is strong evidence), but our whole constant-reading strategy depends on it.
Command **C1**.

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
precedent that they fire in this context. Command **C8** checks.

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

## In-game commands

Run these and paste the output back. Several are long; `/dump` output goes to the chat frame,
so for the big ones use the `/run ... print(...)` forms which chunk the output.

### C1 — Constants available before the LoD addon loads (Q11)

Run this **first thing after login, before opening the Legacy UI or pressing its key bind.**

```
/dump C_AddOns.IsAddOnLoaded("Blizzard_LegacySystem")
/dump Constants and Constants.LegacyConsts
```

Expected: `false`, then a table of six values. If the second is `nil`, our constant strategy
changes and we fall back to literals.

### C2 — Tree display names (Q8)

```
/dump LEGACY_TREE_PROFESSIONS, LEGACY_TREE_ADVENTURE, LEGACY_TREE_PROGRESSION
```

Settles whether 1189 is "Resourcefulness".

### C3 — Category list scope and shape (Q1, Q2)

```
/run local c=GetCategoryList() print("categories:", #c)
```

Then, to see the tree:

```
/run for _,id in ipairs(GetCategoryList()) do local n,p=GetCategoryInfo(id) local a,cm,ic=GetCategoryNumAchievements(id) print(id,n,"parent="..tostring(p),a,cm,ic) end
```

If that floods chat, cap it: replace `ipairs(GetCategoryList())` with a loop over the first 30.
What I need to know: is the count ~10 (Legacy only) or ~100 (all achievements), and are the
public groupings top level (`parent == -1`) or nested.

### C4 — Empty search string semantics (Q1)

At login, before typing in any search box:

```
/dump GetNumFilteredAchievements()
```

Then, and **only** if you do not mind clearing the Achievement UI's search state:

```
/run SetAchievementSearchString("") 
```

wait a moment for `ACHIEVEMENT_SEARCH_UPDATED`, then:

```
/dump GetNumFilteredAchievements()
```

I need to know whether empty means "everything" or "nothing".

### C5 — Account-wide flag (Q5)

```
/dump ACHIEVEMENT_FLAGS_ACCOUNT
```

And, for a challenge you know is account-wide, with its ID:

```
/dump select(9, GetAchievementInfo(<achievementID>))
/dump select(13, GetAchievementInfo(<achievementID>))
```

Ninth return is `flags`, thirteenth is `wasEarnedByMe`.

### C6 — Point cap: shared pool or per tree (Q7)

```
/run for _,id in ipairs({1187,1188,1189}) do local cfg=C_Traits.GetConfigIDByTreeID(id) local t=cfg and C_Traits.GetTreeCurrencyInfo(cfg,id,true) local c=t and t[1] print(id,"cfg="..tostring(cfg),"cur="..tostring(c and c.traitCurrencyID),"qty="..tostring(c and c.quantity),"max="..tostring(c and c.maxQuantity),"spent="..tostring(c and c.spent),"inTree="..tostring(c and c.spentInTree)) end
```

```
/dump C_Traits.GetMaxAvailableTraitCurrency(4225, false)
/dump C_Traits.GetMaxAvailableTraitCurrency(4225, true)
```

If `maxQuantity` reads 16 on all three trees while `spent` is identical across them and
`spentInTree` differs, the cap is one shared pool. Worth running once with points spent in
more than one tree.

### C7 — Reward track shape (Q10)

```
/dump C_MajorFactions.GetCurrentRenownLevel(2802)
/dump C_MajorFactions.GetMajorFactionData(2802)
/dump C_MajorFactions.GetRenownLevels(2802)
/dump C_MajorFactions.GetRenownRewardsForLevel(2802, 1)
```

Use a level you have not reached for the last one too, so I can see which of
`itemID`/`spellID`/`mountID`/`titleMaskID` are actually populated and whether a name can be
derived at all.

### C8 — Do the update events fire (Q12)

```
/run local f=CreateFrame("Frame") for _,e in ipairs({"TRAIT_CONFIG_UPDATED","TRAIT_TREE_CHANGED","MAJOR_FACTION_RENOWN_LEVEL_CHANGED","CRITERIA_UPDATE","ACHIEVEMENT_EARNED"}) do f:RegisterEvent(e) end f:SetScript("OnEvent",function(_,e,...) print("EVT",e,...) end) print("LegacyNext event probe armed")
```

Leave it running, then spend a Legacy point and make progress on a challenge. I need to know
which of these actually fire on Forever, and what `TRAIT_CONFIG_UPDATED` carries.

### C9 — Criteria shapes for fixtures (Q4)

Pick one challenge with a counted criterion ("3/5") and one with a checklist, and for each:

```
/dump GetAchievementNumCriteria(<achievementID>)
/dump GetAchievementCriteriaInfo(<achievementID>, 1)
/dump C_Traits.GetTraitCurrencyForAchievement(4225, <achievementID>)
```

These become the first entries in `spec/fixtures/`. Until they exist, the criteria-ranking
tests stay `pending`.
