# Api/ call patterns

The five shapes this codebase needs, plus the shared helpers they assume. Read this before
writing the second `Api/` function of a task — copying a shape from here is how the layer
stays uniform, and uniformity is what makes a review of it fast.

Citations in these examples are written as `<file>:<line>` placeholders. Fill them from
`api_lookup.sh`; a real-looking line number copied out of a template is worse than none,
because it reads as verified.

## Contents

- [Shared helpers](#shared-helpers)
- [1. Scalar read](#1-scalar-read)
- [2. Struct read, defensive fields](#2-struct-read-defensive-fields)
- [3. List enumeration](#3-list-enumeration)
- [4. Multi-return bare global](#4-multi-return-bare-global)
- [5. Constant with a labelled fallback](#5-constant-with-a-labelled-fallback)
- [Reason strings](#reason-strings)

## Shared helpers

Write these once in `Api/`. Every pattern below assumes them.

```lua
local _, ns = ...
ns.Api = ns.Api or {}

-- issecretvalue may not exist on this build, and the guard has to degrade to "not secret"
-- rather than erroring. Wrapped in pcall because a secret-value check on a secret value is
-- exactly the sort of thing Midnight's restrictions could make throw.
function ns.Api.isSecret(value)
	if type(issecretvalue) ~= "function" then
		return false
	end

	local ok, secret = pcall(issecretvalue, value)
	return ok and secret == true
end

-- Resolve a function only if it is really callable, so every caller's guard is one line.
local function resolve(namespace, name)
	local fn = namespace and namespace[name]
	if type(fn) ~= "function" then
		return nil
	end
	return fn
end

-- The whole guard for the common case: call it, refuse a secret result, name the symbol in
-- the failure. Returns ok, value... so callers can keep multiple returns.
function ns.Api.call(label, fn, ...)
	if type(fn) ~= "function" then
		return nil, label .. " missing"
	end

	local results = { pcall(fn, ...) }
	if not results[1] then
		return nil, label .. " errored"
	end

	for i = 2, #results do
		if ns.Api.isSecret(results[i]) then
			return nil, label .. " returned a secret value"
		end
	end

	return true, unpack(results, 2)
end
```

`unpack` rather than `table.unpack`: Lua 5.1 (CLAUDE.md, Conventions).

Note the `{ pcall(...) }` idiom drops trailing nils — `#results` is unreliable when a
function returns `nil` in the middle of its returns. Where that matters, use pattern 4, which
takes an explicit arity.

## 1. Scalar read

```lua
--- Points earnable account-wide.
-- C_Traits.GetMaxAvailableTraitCurrency(traitCurrencyID, excludeStagedChanges) -> number
-- doc:  <file>:<line>
-- pin:  <sha> (<version>)
function ns.Api.GetEarnablePoints()
	local currencyID, reason = ns.Api.GetConst("LEGACY_POINTS_TRAIT_CURRENCY_ID", 4225)
	if not currencyID then
		return nil, reason
	end

	local ok, value = ns.Api.call(
		"C_Traits.GetMaxAvailableTraitCurrency",
		resolve(C_Traits, "GetMaxAvailableTraitCurrency"),
		currencyID, false
	)
	if not ok then
		return nil, value
	end

	if type(value) ~= "number" then
		return nil, "C_Traits.GetMaxAvailableTraitCurrency returned a " .. type(value)
	end

	return value
end
```

The type check is not paranoia about this build; it is what turns next month's changed return
into a reason string instead of an arithmetic error in `Model/`.

## 2. Struct read, defensive fields

The rule that produced this shape: the live reward struct carries five fields that appear in
no documentation file, and `name` is **missing** on some reward entries while
`toastDescription` is present. A documented field list is a floor, not a contract — so read
fields defensively and never treat absence as impossible.

```lua
--- One reward-track threshold's display data.
-- C_MajorFactions.GetRenownRewardsForLevel(factionID, level) -> MajorFactionRenownRewardInfo[]
-- doc:  <file>:<line>    fields: <file>:<line>
-- pin:  <sha> (<version>)
function ns.Api.GetRewardsForLevel(level)
	local factionID, reason = ns.Api.GetConst("LEGACY_REWARD_TRACK_FACTION_ID", 2802)
	if not factionID then
		return nil, reason
	end

	local ok, rewards = ns.Api.call(
		"C_MajorFactions.GetRenownRewardsForLevel",
		resolve(C_MajorFactions, "GetRenownRewardsForLevel"),
		factionID, level
	)
	if not ok then
		return nil, rewards
	end

	if type(rewards) ~= "table" then
		return {}      -- worked, nothing at this level. Not an error.
	end

	local out = {}
	for i = 1, #rewards do
		local entry = rewards[i]
		if type(entry) == "table" and not ns.Api.isSecret(entry) then
			out[#out + 1] = {
				-- name is absent on some entries; toastDescription is the observed fallback.
				name = entry.name or entry.toastDescription,
				icon = entry.icon,
				-- isCollected read TRUE for an unreached threshold, so it is account
				-- collection state, not "this level is claimed". Never render it as progress.
				isCollected = entry.isCollected,
			}
		end
	end

	return out
end
```

Copy only the fields the layer above needs, and name them the way the client does. Renaming a
field here means a reader has to hold two vocabularies; adding a computed field here means
`Model/` logic has leaked into `Api/`.

## 3. List enumeration

The locked-in enumeration path, and the expensive one. Return the whole snapshot; the caller
holds it.

```lua
--- Every Legacy challenge, grouped by category.
-- GetCategoryList() -> number[]                      (Legacy categories only on this client)
-- GetCategoryNumAchievements(categoryID) -> total, completed, incomplete
-- GetAchievementInfo(categoryID, index) -> id, name, points, completed, ... (at least 14)
-- used: <file>:<line>
-- pin:  <sha> (<version>)
function ns.Api.GetChallenges()
	local ok, categories = ns.Api.call("GetCategoryList", resolve(_G, "GetCategoryList"))
	if not ok then
		return nil, categories
	end
	if type(categories) ~= "table" then
		return nil, "GetCategoryList returned a " .. type(categories)
	end

	local out = {}
	for _, categoryID in ipairs(categories) do
		local counted, total = ns.Api.call(
			"GetCategoryNumAchievements",
			resolve(_G, "GetCategoryNumAchievements"),
			categoryID
		)
		-- Drop empty categories by count, never by name: "Do Not Display" is a real
		-- category the API returns, and matching on its name would break in any locale.
		if counted and type(total) == "number" and total > 0 then
			for index = 1, total do
				local got, id, name = ns.Api.call(
					"GetAchievementInfo",
					resolve(_G, "GetAchievementInfo"),
					categoryID, index
				)
				if got and id then
					out[#out + 1] = { id = id, name = name, categoryID = categoryID }
				end
			end
		end
	end

	return out
end
```

Three things this shape gets right:

- **One partial failure does not empty the list.** A single bad index skips its entry; the
  sweep continues. The alternative — bailing on first error — turns one churned ID into a
  blank frame.
- **It never calls the filtered-achievement API.** That is global state shared with Blizzard's
  own UI, reading 0 at login and 111 after any call.
- **It is called once per refresh.** 111 challenges is already hundreds of API calls before
  criteria; `UI/` must never reach this from a draw path.

## 4. Multi-return bare global

`GetAchievementCriteriaInfo` returns at least 9 values and the tail is unverified. Take an
explicit arity so a trailing `nil` cannot silently shorten the list, and assert nothing about
returns past what a citation covers.

```lua
--- One criterion. Returns are positional; only the first 9 are cited.
-- GetAchievementCriteriaInfo(achievementID, index)
--   -> description, criteriaType, completed, quantity, reqQuantity,
--      charName, flags, assetID, quantityString   (at least 9; tail [unverified])
-- used: <file>:<line>      <- prefer the Mainline call site, never Blizzard_AchievementUI/Cata/
-- pin:  <sha> (<version>)
local CRITERIA_RETURNS = 9

function ns.Api.GetCriterion(achievementID, index)
	local fn = resolve(_G, "GetAchievementCriteriaInfo")
	if not fn then
		return nil, "GetAchievementCriteriaInfo missing"
	end

	local packed = { pcall(fn, achievementID, index) }
	if not packed[1] then
		return nil, "GetAchievementCriteriaInfo errored"
	end

	local values = {}
	for i = 1, CRITERIA_RETURNS do
		local value = packed[i + 1]
		if ns.Api.isSecret(value) then
			return nil, "GetAchievementCriteriaInfo returned a secret value"
		end
		values[i] = value
	end

	return {
		description = values[1],
		criteriaType = values[2],
		completed = values[3] and true or false,
		quantity = values[4],
		reqQuantity = values[5],
		flags = values[7],
		assetID = values[8],
		quantityString = values[9],
	}
end
```

`criteriaType` 7 is a skill threshold (`assetID` is a skill line) and 8 is a child achievement
(`assetID` is an achievement ID, forming meta chains). Resolving a chain is `Model/`'s
decision, not this layer's — `Api/` hands over the link, it does not follow it.

## 5. Constant with a labelled fallback

```lua
-- Verified present on a fresh login while Blizzard_LegacySystem was NOT loaded, so these are
-- client data rather than addon data [verified in game 2026-09-18].
-- The literals are a fallback for a build that moves them, never the primary source.
local CONST_FALLBACK = {
	LEGACY_REWARD_TRACK_FACTION_ID = 2802,
	LEGACY_POINTS_TRAIT_CURRENCY_ID = 4225,
	LEGACY_TREE_PROFESSIONS_ID = 1187,
	LEGACY_TREE_ADVENTURE_ID = 1188,
	LEGACY_TREE_PROGRESSION_ID = 1189,
}

--- Read a Legacy constant, preferring the client's own value.
-- @return value, nil            from Constants.LegacyConsts
-- @return value, "fallback"     from the literal above, so callers can report it
-- @return nil, reason           unknown name
function ns.Api.GetConst(name, fallback)
	local consts = Constants and Constants.LegacyConsts
	local value = type(consts) == "table" and consts[name] or nil

	if type(value) == "number" and not ns.Api.isSecret(value) then
		return value
	end

	value = fallback or CONST_FALLBACK[name]
	if type(value) == "number" then
		return value, "fallback"
	end

	return nil, "Constants.LegacyConsts." .. name .. " unavailable and no fallback"
end
```

Surfacing "fallback" matters: running on literals means the client disagrees with our
recorded values, which is a `beta-build-bump` finding rather than a normal day. `Debug/` should
print it.

Never extend this table with achievement, category or criteria IDs. Constants are named client
data with a stable name; those IDs are churn.

## Reason strings

Name the symbol, then what happened. These end up in front of a human who is holding a
screenshot and no context:

```
C_Traits.GetTreeCurrencyInfo missing
C_Traits.GetTreeCurrencyInfo errored
C_Traits.GetTreeCurrencyInfo returned a secret value
C_Traits.GetTreeCurrencyInfo returned a boolean
Constants.LegacyConsts.LEGACY_TREE_ADVENTURE_ID unavailable and no fallback
```

Not `"could not load points"`. The first set ends an investigation; the second starts one.
