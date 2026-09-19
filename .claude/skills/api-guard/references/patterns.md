# Api/ call patterns

`LegacyNext/Api/Api.lua` is written and green. **It is the canonical example** — read it before
this file, and prefer copying a shape out of it over anything described here. This reference
exists for the decisions that are hard to see by reading one function: what the shared helpers
guarantee, which shape fits which kind of read, and where the traps are.

Cited line numbers are into `LegacyNext/Api/Api.lua` at the merge that introduced it. They
shift; find by name if one misses.

## Contents

- [The shared helpers](#the-shared-helpers)
- [1. Scalar read](#1-scalar-read)
- [2. Struct read, defensive fields](#2-struct-read-defensive-fields)
- [3. List enumeration](#3-list-enumeration)
- [4. Multi-return bare global](#4-multi-return-bare-global)
- [5. Constant with a labelled source](#5-constant-with-a-labelled-source)
- [Reason strings](#reason-strings)

## The shared helpers

Four, already written. Use them; do not write a second guard beside them.

| Helper | Line | What it gives you |
|---|---|---|
| `call(path, ...)` | 191 | The whole guard: resolve, feature-detect, `pcall`, secret-check, plain-copy. Returns a packed result table or `nil, reason` |
| `resolve(path)` | 120 | A dotted global path (`"C_Traits.GetTreeCurrencyInfo"`) without ever indexing a missing namespace |
| `isSecret(value)` | 107 | The `issecretvalue` guard, itself feature-detected, degrading to "not secret" |
| `Api.GetConstant(name)` | 244 | `value, "runtime"` or `value, "fallback"` — the source travels with the value |

Two things about `call` that shape every caller:

**It takes a string path, not a function.** `call("C_Traits.GetTreeCurrencyInfo", configId, treeId, true)`.
That is what lets one helper do the feature-detection, and what makes the failure tally
(`record`, line 61) able to name the symbol without every call site repeating it. Passing a
resolved function instead would work and would silently lose both.

**It returns a packed table, indexed from 1.** `result[1]` is the first return, `result.n` the
count. So the idiom throughout is:

```lua
local result = call("C_MajorFactions.GetCurrentRenownLevel", factionId)
local level = result and result[1]
```

The packing is not ceremony: `{ pcall(fn) }` drops trailing nils, so `#` lies whenever a
function returns `nil` in or at the end of its returns. `pack` (line 101) keeps `n` explicit,
which is the only way to tell "returned 3 values, the third nil" from "returned 2".

`call` also deep-copies any table it returns (`plainCopy`, line 142, depth-capped at 6). The
client may reuse or mutate a table it handed us, and **a secret can sit in a field while the
table itself reads non-secret** — so the copy is a correctness guard, not hygiene. Never hand a
client-owned table upward.

## 1. Scalar read

```lua
local result = call("C_Traits.GetMaxAvailableTraitCurrency", currencyId, true)
local cap = result and result[1]
if type(cap) ~= "number" then
	return nil, "GetMaxAvailableTraitCurrency unavailable"
end
```

The type check is not paranoia about this build; it is what turns next month's changed return
into a reason string instead of an arithmetic error up in `Model/`.

Use `GetMaxAvailableTraitCurrency(id, true)` for the per-character spendable cap and `false`
for the account-wide earnable total. Not `TreeCurrencyInfo.maxQuantity`, which read 0 at zero
points and is still unexplained (`docs/status.md`, C1).

## 2. Struct read, defensive fields

`Api.GetRewardTrack` (line 436) is the worked example. The rule it encodes: **a documented
field list is a floor, not a contract.** The live reward struct carries five fields that appear
in no documentation file, and `name` is *missing* on some entries while `toastDescription` is
present.

```lua
name = reward.name or reward.toastDescription,
```

Two traps this layer already handles, both worth not re-learning:

- **`isCollected` read `true` for an unreached threshold.** It is account collection state, not
  "this level is claimed". Pass it through; never render it as progress.
- **`GetRenownLevels` returns a sparse list** — four thresholds (15, 25, 40, 55), not one entry
  per level. Anything that indexes it by level is wrong.

Copy only the fields the layer above needs, and keep the client's own names. Renaming here
means a reader holds two vocabularies; computing here means `Model/` logic has leaked down.

## 3. List enumeration

`Api.GetChallenges` (line 327) is the expensive one and the locked-in path:
`GetCategoryList()` → `GetCategoryNumAchievements(categoryID)` → `GetAchievementInfo(categoryID, index)`.

Three properties worth preserving in anything like it:

- **One partial failure does not empty the list.** A bad index skips its entry and the sweep
  continues. Bailing on first error turns one churned ID into a blank frame.
- **Empty categories drop by count, never by name.** "Do Not Display" is a real category the
  API returns, and matching its name breaks in every other locale.
- **It is called once per refresh.** 111 challenges is already hundreds of calls before
  criteria; `UI/` must never reach this from a draw path.

`Api.flags.eventDrivenRefresh` is off (line 14) because which of `TRAIT_CONFIG_UPDATED`,
`TRAIT_TREE_CHANGED` and `MAJOR_FACTION_RENOWN_LEVEL_CHANGED` actually fire is unconfirmed
(C2). Until a capture settles it, read on show — which is what Blizzard's own Legacy UI does,
and the only precedent we have. Turning that flag on needs a fixture behind it.

## 4. Multi-return bare global

`readCriteria` (line 288) takes the returns positionally and stops where the evidence stops.
`GetAchievementCriteriaInfo` is destructured to 9 values in a Mainline call site; nothing
proves 9 is the arity, so 9 is a **lower bound** and the tail is `[unverified]`. Do not name a
tenth field.

The three criteria shapes, which anything touching progress must handle:

| Shape | Count | Progress |
|---|---|---|
| Progress bar (`EVALUATION_TREE_FLAG_PROGRESS_BAR`, mask 1) | 18 | `quantity` / `reqQuantity` |
| Checklist | 59 | boolean each; remaining is a count |
| **No criteria at all** | **34** | none — binary, and a distinct case |

The 34 are not 0%. Treating them as 0% parks a third of the list permanently at the top of a
closest-to-done sort.

`criteriaType` 7 is a skill threshold (`assetID` is a skill line); 8 is a child achievement
(`assetID` is an achievement ID) and forms meta chains hundreds deep. `Api.flags.followMetaChains`
is off: this layer reports `assetId` and stops. Recursing would multiply every sweep by that
depth before `Model/` has decided it wants the answer.

`quantityString` ("0 / 150") is pre-formatted and localised — fine for display, never for
arithmetic.

## 5. Constant with a labelled source

`Api.GetConstant` returns `value, "runtime"` or `value, "fallback"`. Keep that second return
travelling: running on literals means the client disagrees with our recorded values, which is a
`beta-build-bump` finding rather than a normal day, and `Debug/` surfaces it precisely so a
dump shows it.

Never extend `CONSTANT_FALLBACK` (line 23) with achievement, category or criteria IDs.
Constants are named client data with a stable name; those IDs are churn.

Note `TREE_NAME_GLOBAL` (line 34): the constant, the atlas and the display string disagree
about tree 1189 ("Progression" versus "Resourcefulness"), so the mapping is spelled out rather
than derived. Resist tidying that into a pattern.

## Reason strings

Name the symbol, then what happened. `call` returns the short forms — `"missing"`,
`"error: <detail>"`, `"secret"` — and records the path in the failure tally, so
`Api.GetFailures()` and `/lgn probe` can report which symbol produced them. A reason a caller
writes itself should be just as specific:

```
GetMajorFactionData unavailable
no faction id
Constants.LegacyConsts.LEGACY_TREE_ADVENTURE_ID unavailable and no fallback
```

Not `"could not load points"`. The first set ends an investigation; the second starts one, and
it will be Alex investigating from a screenshot.
