local _, ns = ...

-- The only layer permitted to call WoW globals. Every read feature-detects the function,
-- wraps the call in pcall, guards the result with issecretvalue when that exists, and
-- returns plain Lua tables or nil plus a reason. No UI code lives here.
ns.Api = ns.Api or {}
local Api = ns.Api

-- Questions docs/legacy-internals.md could not close. Both default off; turning one on is a
-- deliberate act that needs a captured fixture behind it first.
Api.flags = {
	-- Q12: no Legacy addon registers TRAIT_* or MAJOR_FACTION_* events, and whether they fire
	-- on Forever is unconfirmed. Until in-game item C2 comes back, Api is read-on-demand only.
	eventDrivenRefresh = false,
	-- Q4: criteriaType 8 chains run hundreds of achievements deep. Api reports assetId and
	-- stops. Recursing here would multiply every sweep by that depth before Model has decided
	-- whether it wants the answer at all.
	followMetaChains = false,
}

-- Fallbacks only. Constants.LegacyConsts is read first and is the source of truth; these exist
-- so a dump still works if that table moves. Verified in game 2026-09-18, build 1.60.1.
local CONSTANT_FALLBACK = {
	LEGACY_REWARD_TRACK_FACTION_ID = 2802,
	LEGACY_POINTS_TRAIT_CURRENCY_ID = 4225,
	LEGACY_TREE_PROFESSIONS_ID = 1187,
	LEGACY_TREE_ADVENTURE_ID = 1188,
	LEGACY_TREE_PROGRESSION_ID = 1189,
}

-- Tree display names are client global strings, so they are read by name like everything else.
-- The constant, the atlas and the display string disagree on tree 1189 ("Progression" versus
-- "Resourcefulness"), which is why the mapping is spelled out rather than derived.
local TREE_NAME_GLOBAL = {
	LEGACY_TREE_PROFESSIONS_ID = "LEGACY_TREE_PROFESSIONS",
	LEGACY_TREE_ADVENTURE_ID = "LEGACY_TREE_ADVENTURE",
	LEGACY_TREE_PROGRESSION_ID = "LEGACY_TREE_PROGRESSION",
}

local TREE_CONSTANTS = {
	"LEGACY_TREE_PROFESSIONS_ID",
	"LEGACY_TREE_ADVENTURE_ID",
	"LEGACY_TREE_PROGRESSION_ID",
}

-- Neither flag mask is defined in the pinned Blizzard source, so both are feature-detected
-- from the client and fall back to the value verified in game.
local FLAG_FALLBACK = {
	ACHIEVEMENT_FLAGS_ACCOUNT = 131072,
	EVALUATION_TREE_FLAG_PROGRESS_BAR = 1,
}

local MAX_COPY_DEPTH = 6

--------------------------------------------------------------------------------------------
-- Failure tally
--------------------------------------------------------------------------------------------

local stats = {}

local function record(name, outcome, detail)
	local entry = stats[name]
	if not entry then
		entry = { calls = 0, ok = 0, missing = 0, errors = 0, secret = 0, partial = 0 }
		stats[name] = entry
	end

	entry.calls = entry.calls + 1
	entry[outcome] = (entry[outcome] or 0) + 1
	if detail then
		entry.lastDetail = detail
	end

	return entry
end

-- A snapshot, so callers cannot mutate the tally by holding onto it.
function Api.GetFailures()
	local out = {}
	for name, entry in pairs(stats) do
		out[name] = {
			calls = entry.calls,
			ok = entry.ok,
			missing = entry.missing,
			errors = entry.errors,
			secret = entry.secret,
			partial = entry.partial,
			lastDetail = entry.lastDetail,
			lastDropped = entry.lastDropped,
		}
	end
	return out
end

function Api.ResetFailures()
	stats = {}
end

--------------------------------------------------------------------------------------------
-- Guards
--------------------------------------------------------------------------------------------

local function pack(...)
	return { n = select("#", ...), ... }
end

-- Midnight's secret values. The guard is itself feature-detected: issecretvalue does not exist
-- on every client this addon might load on, and its absence is not an error.
local function isSecret(value)
	local check = rawget(_G, "issecretvalue")
	if type(check) ~= "function" then
		return false
	end

	local ok, secret = pcall(check, value)
	return ok and secret == true
end

Api.IsSecret = isSecret

-- Resolves a dotted global path without ever indexing a missing namespace.
local function resolve(path)
	local current = nil
	for segment in string.gmatch(path, "[^%.]+") do
		if current == nil then
			current = rawget(_G, segment)
		elseif type(current) == "table" then
			current = rawget(current, segment)
		else
			return nil
		end

		if current == nil then
			return nil
		end
	end
	return current
end

Api.Resolve = resolve

-- Api hands out plain tables it owns, never a client-owned one: the client may reuse or mutate
-- its tables, and a secret can sit in a field while the table itself reads non-secret.
--
-- An unusable *field* is dropped and named; an unusable *value* still fails the read. The
-- distinction exists because Blizzard mixes methods into returned structs -- MajorFactionData's
-- factionFontColor is a DBColorExport whose `color` carries ColorMixin
-- (MajorFactionsDocumentation.lua:281, UIColorSharedDocumentation.lua:11) -- and rejecting the
-- whole struct over a colour object we would never read costs us every scalar beside it.
-- A secret is the exception: it fails the table outright, because a guard that discards the
-- one thing it exists to detect is worse than no guard.
local function plainCopy(value, depth, seen, dropped, path)
	if isSecret(value) then
		return nil, "secret"
	end

	local kind = type(value)
	if kind ~= "table" then
		if kind == "function" or kind == "userdata" or kind == "thread" then
			return nil, "unsupported type " .. kind
		end
		return value
	end

	if depth > MAX_COPY_DEPTH then
		return nil, "deeper than " .. MAX_COPY_DEPTH
	end
	if seen[value] then
		return nil, "cyclic"
	end
	seen[value] = true

	local out = {}
	for key, item in pairs(value) do
		local fieldPath = path .. "." .. tostring(key)

		local copiedKey, keyReason = plainCopy(key, depth + 1, seen, dropped, fieldPath)
		local copiedItem, itemReason
		if copiedKey ~= nil then
			copiedItem, itemReason = plainCopy(item, depth + 1, seen, dropped, fieldPath)
		end

		if copiedKey == nil or copiedItem == nil then
			local reason = keyReason or itemReason or "unusable"
			if reason == "secret" then
				seen[value] = nil
				return nil, "secret"
			end
			dropped[#dropped + 1] = fieldPath .. " (" .. reason .. ")"
		else
			out[copiedKey] = copiedItem
		end
	end

	seen[value] = nil
	return out
end

-- Third return is the list of dropped field paths: empty means the copy is complete, and a
-- caller that needs a field can check rather than discovering the hole downstream.
function Api.PlainCopy(value)
	local dropped = {}
	local copy, reason = plainCopy(value, 1, {}, dropped, "")
	return copy, reason, dropped
end

-- Every WoW global call in the addon goes through here. Returns a packed result table with an
-- `n` field, or nil plus a reason. Packed rather than varargs so "the function returned nil"
-- and "the call failed" stay distinguishable at the call site.
local function call(path, ...)
	local fn = resolve(path)
	if type(fn) ~= "function" then
		record(path, "missing")
		return nil, "missing"
	end

	local raw = pack(pcall(fn, ...))
	if not raw[1] then
		local detail = tostring(raw[2])
		record(path, "errors", detail)
		return nil, "error: " .. detail
	end

	local out = { n = raw.n - 1 }
	local dropped = {}
	for index = 2, raw.n do
		local value = raw[index]
		if type(value) == "table" then
			local copied, reason = plainCopy(value, 1, {}, dropped, "return" .. (index - 1))
			if copied == nil then
				-- Only a secret is recorded as one. Cyclic and too-deep are our copy policy
				-- refusing a shape, not the client withholding a value, and filing them under
				-- the one status that means "Midnight restrictions reached us" turns the probe
				-- into a false alarm.
				local outcome = reason == "secret" and "secret" or "errors"
				record(path, outcome, reason)
				return nil, reason
			end
			value = copied
		elseif isSecret(value) then
			record(path, "secret")
			return nil, "secret"
		end
		out[index - 1] = value
	end

	-- A partial copy is still a successful read, so it counts as ok and carries a separate
	-- marker rather than a status of its own: the tally answers "is this symbol broken", and
	-- a dropped colour object is not a broken symbol.
	local entry = record(path, "ok")
	if dropped[1] then
		entry.partial = (entry.partial or 0) + 1
		entry.lastDropped = table.concat(dropped, ", ")
	end

	return out, nil, dropped
end

Api.Call = call

-- Single-bit masks only, which is all the Legacy surface uses. Written without `bit` so the
-- guard layer stays loadable under plain Lua 5.1 for tests.
local function hasFlag(value, mask)
	if type(value) ~= "number" or type(mask) ~= "number" or mask <= 0 then
		return false
	end
	return value % (mask + mask) >= mask
end

Api.HasFlag = hasFlag

--------------------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------------------

-- Returns the value and where it came from, so a dump shows when we are running on fallbacks.
function Api.GetConstant(name)
	local consts = resolve("Constants.LegacyConsts")
	if type(consts) == "table" then
		local value = rawget(consts, name)
		if type(value) == "number" and not isSecret(value) then
			record("Constants.LegacyConsts." .. name, "ok")
			return value, "runtime"
		end
	end

	record("Constants.LegacyConsts." .. name, "missing")
	local fallback = CONSTANT_FALLBACK[name]
	if fallback then
		return fallback, "fallback"
	end
	return nil, "unknown constant"
end

local function globalNumber(name)
	local value = rawget(_G, name)
	if type(value) == "number" and not isSecret(value) then
		record(name, "ok")
		return value, "runtime"
	end

	record(name, "missing")
	return FLAG_FALLBACK[name], "fallback"
end

local function globalString(name)
	local value = rawget(_G, name)
	if type(value) == "string" and not isSecret(value) then
		record(name, "ok")
		return value
	end

	record(name, "missing")
	return nil
end

--------------------------------------------------------------------------------------------
-- Categories
--------------------------------------------------------------------------------------------

--- Every Legacy category with its name, parent and own achievement count, in client order.
-- GetCategoryList() -> { categoryID, ... }          used: Blizzard_LegacyChallenges.lua:79
-- GetCategoryInfo(categoryID) -> name, parentID       used: Blizzard_LegacyChallenges.lua:108
-- GetCategoryNumAchievements(categoryID) -> numAchievements, numComplete, numIncomplete
--                                                      used: Blizzard_LegacyChallenges.lua:45
-- parentID == -1 is top level                          Blizzard_LegacyChallengeTracker.lua:6
-- pin:  70ef1b2 (1.60.1.69913)
--
-- Model needs this because a challenge only knows its parent's id: Classes, Tradeskills and
-- Player vs. Player hold no achievements of their own, so their names never reach the
-- challenge list. Empty categories are kept here -- dropping them is Model's job, by count.
function Api.GetCategories()
	local listResult = call("GetCategoryList")
	if not listResult then
		return nil, "GetCategoryList unavailable"
	end

	local ids = listResult[1]
	if type(ids) ~= "table" then
		return nil, "GetCategoryList returned no list"
	end

	local categories = {}
	for _, categoryId in ipairs(ids) do
		if type(categoryId) == "number" then
			local infoResult = call("GetCategoryInfo", categoryId)
			local countResult = call("GetCategoryNumAchievements", categoryId)
			categories[#categories + 1] = {
				id = categoryId,
				name = infoResult and infoResult[1],
				parentId = infoResult and infoResult[2],
				numAchievements = countResult and countResult[1],
				numComplete = countResult and countResult[2],
				numIncomplete = countResult and countResult[3],
			}
		end
	end

	return categories
end

--------------------------------------------------------------------------------------------
-- Challenges
--------------------------------------------------------------------------------------------

-- Returns the criteria list and the count the client reported for it. The second return is
-- what makes a partial read detectable: the loop below skips any criterion whose own call
-- failed, so #criteria can come back short of count with nothing in the list to say so, and
-- closeness computed from a truncated list is silently wrong rather than absent. Callers
-- compare the two; equal means complete, short means some reads failed.
--
-- nil        -- the count read itself failed
-- {}, 0     -- genuinely no criteria (34 of the 111 challenges are binary)
-- list, n   -- n criteria reported; #list of them actually read
local function readCriteria(achievementId, progressBarMask)
	local countResult = call("GetAchievementNumCriteria", achievementId)
	if not countResult then
		return nil
	end

	local count = countResult[1]
	if type(count) ~= "number" or count <= 0 then
		-- Not an error. 34 of the 111 challenges genuinely have no criteria and are binary;
		-- an empty list here is the honest answer and Model has to handle it as its own case.
		return {}, 0
	end

	local criteria = {}
	for index = 1, count do
		local result = call("GetAchievementCriteriaInfo", achievementId, index)
		if result then
			local flags = result[7]
			criteria[#criteria + 1] = {
				index = index,
				text = result[1],
				criteriaType = result[2],
				completed = result[3] and true or false,
				have = result[4],
				need = result[5],
				charName = result[6],
				flags = flags,
				assetId = result[8],
				quantityString = result[9],
				isProgressBar = hasFlag(flags, progressBarMask),
			}
		end
	end

	return criteria, count
end

-- Walks the category list directly. Never SetAchievementSearchString: that is global client
-- state shared with Blizzard's Achievement UI and it changes underneath us.
--
-- `categories` is optional Api.GetCategories output. The view reads that list anyway, for
-- the parents' names, so passing it saves the ~58 calls of reading it a second time.
function Api.GetChallenges(categories)
	local currencyId = Api.GetConstant("LEGACY_POINTS_TRAIT_CURRENCY_ID")
	local accountMask = globalNumber("ACHIEVEMENT_FLAGS_ACCOUNT")
	local progressBarMask = globalNumber("EVALUATION_TREE_FLAG_PROGRESS_BAR")

	if type(categories) ~= "table" then
		local reason
		categories, reason = Api.GetCategories()
		if not categories then
			return nil, reason
		end
	end

	local challenges = {}
	for _, category in ipairs(categories) do
		local categoryId = type(category) == "table" and category.id
		local total = type(category) == "table" and category.numAchievements

		-- Drop empty categories by count, never by name: "Do Not Display" is a real category
		-- the client hands back and its name is not a contract.
		if type(categoryId) == "number" and type(total) == "number" and total > 0 then
			local categoryName = category.name
			local parentId = category.parentId

			for index = 1, total do
				local result = call("GetAchievementInfo", categoryId, index)
				local achievementId = result and result[1]

				if type(achievementId) == "number" then
					local flags = result[9]
					local criteria, criteriaExpected =
						readCriteria(achievementId, progressBarMask)
					local points
					if currencyId then
						local pointsResult =
							call("C_Traits.GetTraitCurrencyForAchievement", currencyId, achievementId)
						points = pointsResult and pointsResult[1]
					end

					challenges[#challenges + 1] = {
						id = achievementId,
						name = result[2],
						categoryId = categoryId,
						categoryName = categoryName,
						parentCategoryId = parentId,
						categoryIndex = index,
						points = points,
						-- `completed` is account state, and Model reads it alone: every
						-- point-bearing challenge carries ACHIEVEMENT_FLAGS_ACCOUNT, and the
						-- per-character ones are the zero-point Explore set Next Up drops.
						-- wasEarnedByMe is kept for the dump and for v1.
						completed = result[4] and true or false,
						wasEarnedByMe = result[13] and true or false,
						earnedBy = result[14],
						description = result[8],
						rewardText = result[11],
						icon = result[10],
						flags = flags,
						isAccountWide = hasFlag(flags, accountMask),
						criteria = criteria,
						-- How many the client said there were. Short of #criteria means some
						-- criterion reads failed, so Model must not read closeness off it.
						criteriaExpected = criteriaExpected,
					}
				end
			end
		end
	end

	-- An empty list is not an error: every read above succeeded and the categories simply
	-- held nothing. Returning nil here made "worked, found nothing" indistinguishable from
	-- "the reads failed", so the dump reported a bug where the honest answer is an empty
	-- frame. The real failures already return nil with a reason further up, and a broken
	-- symbol lands in the failure tally either way.
	return challenges
end

--------------------------------------------------------------------------------------------
-- Reward track
--------------------------------------------------------------------------------------------

local function readRewards(factionId, level)
	local result = call("C_MajorFactions.GetRenownRewardsForLevel", factionId, level)
	local list = result and result[1]
	if type(list) ~= "table" then
		return nil
	end

	local rewards = {}
	for _, entry in ipairs(list) do
		-- The copy guard vouches for plain data, not for shape; a non-table entry is skipped
		-- rather than indexed.
		if type(entry) == "table" then
			rewards[#rewards + 1] = {
				-- `name` is absent on some entries and toastDescription is not, so the fallback
				-- is normal rather than an error path.
				name = entry.name or entry.toastDescription,
				rawName = entry.name,
				toastDescription = entry.toastDescription,
				description = entry.description,
				icon = entry.icon,
				itemID = entry.itemID,
				spellID = entry.spellID,
				mountID = entry.mountID,
				titleMaskID = entry.titleMaskID,
				rewardType = entry.rewardType,
				-- Account collection state, not "this threshold is reached". Read true at a
				-- threshold a renown-0 character had not hit. Never render it as progress.
				isCollected = entry.isCollected,
				isAccountUnlock = entry.isAccountUnlock,
				uiOrder = entry.uiOrder,
			}
		end
	end

	return rewards
end

function Api.GetRewardTrack()
	local factionId = Api.GetConstant("LEGACY_REWARD_TRACK_FACTION_ID")
	if not factionId then
		return nil, "no faction id"
	end

	local dataResult = call("C_MajorFactions.GetMajorFactionData", factionId)
	local data = dataResult and dataResult[1]
	if type(data) ~= "table" then
		return nil, "GetMajorFactionData unavailable"
	end

	local levelResult = call("C_MajorFactions.GetCurrentRenownLevel", factionId)
	local level = levelResult and levelResult[1] or data.renownLevel

	local hiddenResult = call("C_MajorFactions.IsMajorFactionHiddenFromExpansionPage", factionId)

	local track = {
		factionId = factionId,
		name = data.name,
		-- The renown level of faction 2802 *is* the account's earned Legacy point count.
		-- Two names for one client number, kept because both readings are used downstream.
		level = level,
		earned = level,
		maxLevel = data.maxLevel,
		isUnlocked = data.isUnlocked and true or false,
		isHidden = hiddenResult and hiddenResult[1] and true or false,
		thresholds = {},
	}

	local levelsResult = call("C_MajorFactions.GetRenownLevels", factionId)
	local levels = levelsResult and levelsResult[1]
	if type(levels) ~= "table" then
		return track, "GetRenownLevels unavailable"
	end

	-- The list is sparse: four reward thresholds, not one entry per level. Sorted defensively
	-- because every calculation below assumes ascending order.
	local thresholds = {}
	for _, info in ipairs(levels) do
		if type(info) == "table" and type(info.level) == "number" then
			thresholds[#thresholds + 1] = {
				level = info.level,
				locked = info.locked,
				isMilestone = info.isMilestone,
				isCapstone = info.isCapstone,
			}
		end
	end
	table.sort(thresholds, function(a, b) return a.level < b.level end)

	local reached = 0
	for _, threshold in ipairs(thresholds) do
		threshold.reached = type(level) == "number" and level >= threshold.level
		if threshold.reached then
			reached = reached + 1
		end
		threshold.rewards = readRewards(factionId, threshold.level)

		if not threshold.reached and not track.nextThreshold then
			track.nextThreshold = threshold.level
			track.nextRewards = threshold.rewards
			if type(level) == "number" then
				track.pointsToNext = threshold.level - level
			end
		end
	end

	track.thresholds = thresholds
	track.thresholdsReached = reached

	return track
end

--------------------------------------------------------------------------------------------
-- Trees and points
--------------------------------------------------------------------------------------------

function Api.GetTreeSpend()
	local currencyId = Api.GetConstant("LEGACY_POINTS_TRAIT_CURRENCY_ID")

	local spend = {
		currencyId = currencyId,
		-- The cap comes from GetMaxAvailableTraitCurrency, never from TreeCurrencyInfo's
		-- maxQuantity, which read 0 on a character at zero points. Q7 is still open on what
		-- maxQuantity actually tracks, so it is reported raw per tree and used for nothing.
		capSource = "C_Traits.GetMaxAvailableTraitCurrency",
		treeIds = {},
	}

	if currencyId then
		local capResult = call("C_Traits.GetMaxAvailableTraitCurrency", currencyId, true)
		spend.cap = capResult and capResult[1]

		local earnableResult = call("C_Traits.GetMaxAvailableTraitCurrency", currencyId, false)
		spend.earnable = earnableResult and earnableResult[1]
	end

	for _, constantName in ipairs(TREE_CONSTANTS) do
		local treeId = Api.GetConstant(constantName)
		if treeId then
			spend.treeIds[#spend.treeIds + 1] = treeId

			local tree = {
				treeId = treeId,
				constant = constantName,
				name = globalString(TREE_NAME_GLOBAL[constantName]),
			}

			-- Documented MayReturnNothing. A fresh character does have a config, but guard it.
			local configResult = call("C_Traits.GetConfigIDByTreeID", treeId)
			local configId = configResult and configResult[1]
			tree.configId = configId

			if configId then
				local stagedResult = call("C_Traits.ConfigHasStagedChanges", configId)
				tree.hasStagedChanges = stagedResult and stagedResult[1] and true or false

				local currencyResult = call("C_Traits.GetTreeCurrencyInfo", configId, treeId, true)
				local list = currencyResult and currencyResult[1]
				local info = type(list) == "table" and list[1] or nil
				if info then
					tree.traitCurrencyId = info.traitCurrencyID
					tree.quantity = info.quantity
					tree.spent = info.spent
					tree.spentInTree = info.spentInTree
					tree.maxQuantity = info.maxQuantity

					-- All three trees share one configID and one currency, so unspent and
					-- total spent are pool-wide numbers; only spentInTree differs.
					if spend.unspent == nil then
						spend.unspent = info.quantity
					end
					if spend.spent == nil then
						spend.spent = info.spent
					end
				end
			end

			spend[treeId] = tree
		end
	end

	if #spend.treeIds == 0 then
		return nil, "no tree constants"
	end

	return spend
end

--------------------------------------------------------------------------------------------
-- Character
--------------------------------------------------------------------------------------------

local function readProfessions()
	-- Verified on the forever branch: Blizzard_Professions/Camelot/Blizzard_ProfessionsFrame.lua
	-- destructures seven returns (two primary, five secondary) where Mainline uses six with
	-- different meanings. Slots are never named here, only iterated.
	local result = call("GetProfessions")
	if not result then
		return nil, "GetProfessions unavailable"
	end

	-- A slot whose GetProfessionInfo failed is named in the second return, so a short list is
	-- never mistaken for the character's whole set -- the roster would drop that profession.
	local professions, failures = {}, {}
	for slot = 1, result.n do
		local skillIndex = result[slot]
		if type(skillIndex) == "number" then
			local info, reason = call("GetProfessionInfo", skillIndex)
			if not info then
				failures[#failures + 1] = "slot " .. slot .. ": " .. tostring(reason)
			else
				professions[#professions + 1] = {
					slot = slot,
					skillIndex = skillIndex,
					name = info[1],
					icon = info[2],
					skill = info[3],
					max = info[4],
					skillLineId = info[7],
					modifier = info[8],
					skillLineName = info[11],
				}
			end
		end
	end

	if failures[1] then
		return professions, "partial: " .. table.concat(failures, "; ")
	end
	return professions
end

--- The roster key. Names moved under us: UnitName's first return was the full name on 69913
-- and the first name from 70124 (D10), so the GUID is what stays put.
-- UnitGUID(unit) -> result (WOWGUID, Nilable)  doc: UnitDocumentation.lua:1241
--   SecretWhenUnitIdentityRestricted, SecretArguments = "AllowedWhenUntainted"
-- used: Blizzard_SharedXML/UnitUtil.lua:2, Blizzard_SharedXMLBase/AddOnUtil.lua:65
-- pin:  9a789c0 (1.60.1.70170)
-- [verified in game 2026-10-01, 70170, D10]: reads a "Player-" string on the player, no secret.
local function readGuid()
	local result, reason = call("UnitGUID", "player")
	if not result then
		return nil, "UnitGUID " .. tostring(reason)
	end
	local guid = result[1]
	if guid == "" then
		return nil, "UnitGUID returned an empty string"
	end
	if type(guid) ~= "string" then
		return nil, "UnitGUID returned " .. type(guid)
	end
	return guid
end

function Api.GetCharacterInfo()
	local classResult = call("UnitClass", "player")
	local levelResult = call("UnitLevel", "player")
	-- Only the first return. On Forever the second is the surname, never the realm (D10).
	local nameResult = call("UnitName", "player")
	local realmResult = call("GetRealmName")

	if not classResult and not levelResult then
		return nil, "unit API unavailable"
	end

	local professions, professionsReason = readProfessions()
	local guid, guidReason = readGuid()

	return {
		guid = guid,
		guidReason = guidReason,
		name = nameResult and nameResult[1],
		realm = realmResult and realmResult[1],
		class = classResult and classResult[1],
		classToken = classResult and classResult[2],
		classId = classResult and classResult[3],
		level = levelResult and levelResult[1],
		professions = professions,
		professionsReason = professionsReason,
	}
end

--- Whether the client knows an event, checked before registering it: RegisterEvent throws on
-- an unknown name, and beta builds rename events.
-- C_EventUtils.IsEventValid(eventName) -> valid  doc: EventUtilsDocumentation.lua:26
--                                              used: Blizzard_SharedXML/EventUtil.lua:12
-- pin:  bd2470a (1.60.1.70009)
-- Returns true or false, or nil plus a reason when the check is unavailable. The caller still
-- pcalls the registration either way.
function Api.IsEventValid(event)
	local result, reason = call("C_EventUtils.IsEventValid", event)
	if not result then
		return nil, "C_EventUtils.IsEventValid " .. tostring(reason)
	end
	local valid = result[1]
	if type(valid) ~= "boolean" then
		return nil, "C_EventUtils.IsEventValid returned " .. type(valid)
	end
	return valid
end

--- Wall-clock seconds, for stamping roster snapshots.
-- GetServerTime() -> time                     doc: SystemTimeDocumentation.lua:30
-- pin:  bd2470a (1.60.1.70009)
function Api.GetServerTime()
	local result = call("GetServerTime")
	local now = result and result[1]
	if type(now) ~= "number" then
		return nil, "GetServerTime unavailable"
	end
	return now
end

local function positiveId(value)
	return (type(value) == "number" and value > 0) and value or nil
end

--- For each skill line asked about, the parent profession it belongs to.
-- C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID) -> ProfessionInfo
--                                              doc: TradeSkillUIDocumentation.lua:488
-- ProfessionInfo.professionID, .professionName, .parentProfessionID (Nilable),
-- .parentProfessionName (Nilable)              doc: TradeSkillUITypesDocumentation.lua:361
-- GetProfessionInfo's skillLine is compared against `parentProfessionID or professionID`
--                                              used: Blizzard_Professions/Camelot/
--                                                    Blizzard_ProfessionsFrame.lua:41-43
-- pin:  bd2470a (1.60.1.70009)
--
-- Why this exists: tradeskill challenges name skill line 2937 for Alchemy, which is not
-- Classic's 171, and Blizzard's own frame treats GetProfessionInfo's skillLine as the parent.
-- If that holds, a character's profession never equals the challenge's skill line directly.
-- Whether this function answers for a profession the character has not learned is S1.
--
-- Returns { [skillLineId] = { parentId, parentName, name, professionId, raw } }. parentId and
-- professionId read 0 as absent, for matching. `raw` is the whole struct, zeros kept: for an
-- unlearned line the client may hand back a zeroed ProfessionInfo (Nilable = false), and only
-- the raw fields tell that apart from a real top-level line -- which is the question S1 asks.
-- A line that failed to read is absent, and the reasons are in the second return; a missing
-- function fails the whole read.
function Api.GetSkillLineParents(skillLineIds)
	if type(resolve("C_TradeSkillUI.GetProfessionInfoBySkillLineID")) ~= "function" then
		record("C_TradeSkillUI.GetProfessionInfoBySkillLineID", "missing")
		return nil, "C_TradeSkillUI.GetProfessionInfoBySkillLineID missing"
	end

	local parents, failures = {}, {}
	for _, skillLineId in ipairs(skillLineIds or {}) do
		local result, reason = call("C_TradeSkillUI.GetProfessionInfoBySkillLineID", skillLineId)
		local info = result and result[1]
		if type(info) == "table" then
			parents[skillLineId] = {
				parentId = positiveId(info.parentProfessionID),
				parentName = info.parentProfessionName,
				name = info.professionName,
				professionId = positiveId(info.professionID),
				raw = info,
			}
		else
			failures[#failures + 1] = tostring(skillLineId) .. ": " .. (reason or "no info")
		end
	end

	return parents, failures[1] and table.concat(failures, "; ") or nil
end

--------------------------------------------------------------------------------------------
-- Actions on Blizzard's UI
--------------------------------------------------------------------------------------------

-- The only calls here that are not reads. Each does on a click what the player could do by
-- hand: open Blizzard's Legacy panel, or put a link in the chat box. No trait, purchase or
-- commit API is reachable from them, and we never load an addon ourselves: the toggle loads
-- Blizzard_LegacySystem the way the key binding does.

-- The Legacy panel's challenges page, a file-local in Blizzard_LegacySystem.lua:1.
local CHALLENGES_PAGE = 2

local function inCombat()
	local result = call("InCombatLockdown")
	return result and result[1] and true or false
end

-- A missing load-on-demand frame is closed; an unreadable existing frame stops the toggle.
local function frameShown(name)
	local path = name .. ".IsShown"
	local frame = resolve(name)
	if frame == nil then
		record(path, "missing")
		return false
	end
	if type(frame) ~= "table" or type(frame.IsShown) ~= "function" then
		record(path, "missing")
		return nil, "missing"
	end
	local ok, shown = pcall(frame.IsShown, frame)
	if not ok then
		record(path, "errors", tostring(shown))
		return nil, "error: " .. tostring(shown)
	end
	if isSecret(shown) then
		record(path, "secret")
		return nil, "secret"
	end
	if type(shown) ~= "boolean" then
		local reason = "unexpected " .. type(shown)
		record(path, "errors", reason)
		return nil, reason
	end
	record(path, "ok")
	return shown
end

--- Opens Blizzard's Legacy panel on one challenge. True, or nil plus a reason for chat.
-- ToggleLegacySystemUI()          used: Blizzard_LegacySystem/Blizzard_LegacySystem_Bootstrap.lua:7-21
--   returns at renown <= 0 (:8-10), loads on demand, then ToggleFrame -> ShowUIPanel, which
--   refuses addon calls in combat (Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua:854-860)
--   and can refuse a panel that does not fit (:185-188), hence the IsShown check after it
-- EventRegistry "Legacy.SelectPage" used: Blizzard_LegacySystem/Blizzard_LegacySystem.lua:12-15, :69-79
--   page 2 is ChallengesPage (Blizzard_LegacySystem.xml:16, :41); its OnShow builds the
--   category list (Blizzard_LegacyChallenges.lua:31-41), which the select needs
-- AchievementFrame_SelectAchievement(id, forceSelect)
--                                 used: Blizzard_LegacySystem/Blizzard_LegacyChallenges.lua:310-320
--   the Legacy override of Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.lua:2811;
--   it does not switch pages itself
-- AchievementFrame_FindDisplayedAchievement(id) -> displayedId
--   Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.lua:3441-3469, used by the override :315
-- AchievementFrameAchievements_GetSelectedAchievementId() -> id (0 if none)
--   Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.lua:950-956; Legacy uses the same
--   selection behavior (Blizzard_LegacyChallengeDetailPane.lua:6). Filters omit rows (:39-50),
--   and the select returns nothing even when no row was selected (Blizzard_LegacyChallenges.lua:310-320).
-- GetCurrentRenownLevel           doc:  MajorFactionsDocumentation.lua:11
-- InCombatLockdown                doc:  RestrictedActionsDocumentation.lua:45
-- pin:  9a789c0 (1.60.1.70170)
function Api.OpenLegacyChallenge(id)
	if type(id) ~= "number" then
		return nil, "no challenge id"
	end
	if inCombat() then
		return nil, "in combat"
	end
	-- An unreadable level is left to the toggle's own check.
	local factionId = Api.GetConstant("LEGACY_REWARD_TRACK_FACTION_ID")
	local level = factionId and call("C_MajorFactions.GetCurrentRenownLevel", factionId)
	if level and type(level[1]) == "number" and level[1] <= 0 then
		return nil, "no Legacy points yet"
	end

	-- Toggling an open panel would close it, so an unreadable state stops here.
	local shown, shownReason = frameShown("LegacySystemFrame")
	if shown == nil then
		return nil, "LegacySystemFrame.IsShown " .. tostring(shownReason)
	end
	if not shown then
		local toggled, reason = call("ToggleLegacySystemUI")
		if not toggled then
			return nil, "ToggleLegacySystemUI " .. tostring(reason)
		end
		if frameShown("LegacySystemFrame") ~= true then
			return nil, "Legacy panel did not open"
		end
	end

	local registry = resolve("EventRegistry")
	if type(registry) ~= "table" or type(registry.TriggerEvent) ~= "function" then
		record("EventRegistry.TriggerEvent", "missing")
		return nil, "panel opened, EventRegistry missing"
	end
	local paged, pageError = pcall(registry.TriggerEvent, registry, "Legacy.SelectPage", CHALLENGES_PAGE)
	if not paged then
		record("EventRegistry.TriggerEvent", "errors", tostring(pageError))
		return nil, "panel opened, Legacy.SelectPage error: " .. tostring(pageError)
	end
	record("EventRegistry.TriggerEvent", "ok")

	local displayed, displayReason = call("AchievementFrame_FindDisplayedAchievement", id)
	if not displayed or type(displayed[1]) ~= "number" then
		return nil, "panel opened, AchievementFrame_FindDisplayedAchievement " .. tostring(displayReason or "no id")
	end
	local selected, selectReason = call("AchievementFrame_SelectAchievement", id, true)
	if not selected then
		return nil, "panel opened, AchievementFrame_SelectAchievement " .. tostring(selectReason)
	end
	local current, currentReason = call("AchievementFrameAchievements_GetSelectedAchievementId")
	if not current or type(current[1]) ~= "number" then
		return nil, "panel opened, AchievementFrameAchievements_GetSelectedAchievementId "
			.. tostring(currentReason or "no id")
	end
	if current[1] ~= displayed[1] then
		return nil, "panel opened, challenge not selected; clear Blizzard's search and enable Completed and Incomplete"
			.. " filters, then try again"
	end
	return true
end

--- Puts one challenge's link in the open chat box. True, or nil plus a reason for chat.
-- GetAchievementLink(id) -> link  used: Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.lua:1133
-- ChatFrameUtil.InsertLink(link) -> handled
--                                 used: Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.lua:1135
--   Blizzard's Legacy rows link through the same mixin (Blizzard_LegacyChallengeButton.lua:202, :223-224).
--   Neither is in the generated docs, and ChatFrameUtil is defined outside the checkout.
--   ChatEdit_InsertLink is the older global, tried when ChatFrameUtil is missing.
-- pin:  9a789c0 (1.60.1.70170)
function Api.LinkChallenge(id)
	local result = call("GetAchievementLink", id)
	local link = result and result[1]
	if type(link) ~= "string" or link == "" then
		return nil, "GetAchievementLink unavailable"
	end
	local inserted, reason = call("ChatFrameUtil.InsertLink", link)
	if not inserted then
		-- Only the older global is tried, and only its success counts: the reason reported is
		-- the current API's.
		inserted = call("ChatEdit_InsertLink", link)
	end
	if not inserted then
		return nil, "ChatFrameUtil.InsertLink " .. tostring(reason)
	end
	if not inserted[1] then
		return nil, "open a chat box first"
	end
	return true
end

--- Whether the click in progress is the player's chat-link click, Shift unless rebound.
-- IsModifiedClick("CHATLINK")     used: Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.lua:1146
-- IsShiftKeyDown()                doc:  InputDocumentation.lua:217
-- pin:  9a789c0 (1.60.1.70170)
function Api.IsLinkClick()
	local result = call("IsModifiedClick", "CHATLINK")
	if not result then
		result = call("IsShiftKeyDown")
	end
	return result and result[1] and true or false
end

--------------------------------------------------------------------------------------------
-- Probe
--------------------------------------------------------------------------------------------

local function probeRow(path, every, ...)
	local result, reason, dropped = call(path, ...)
	if not result then
		if reason == "missing" then
			return { name = path, status = "missing" }
		end
		if reason == "secret" then
			return { name = path, status = "secret" }
		end
		return { name = path, status = "error", detail = reason }
	end

	if result.n == 0 or result[1] == nil then
		return { name = path, status = "nil" }
	end

	-- A table address tells nobody anything and changes every run, so report its size instead.
	local first = result[1]
	local detail
	if type(first) == "table" then
		local count = 0
		for _ in pairs(first) do count = count + 1 end
		detail = "table, " .. count .. " entries"
	else
		detail = tostring(first)
	end

	-- A name call can put the surname or realm past the first return.
	if every then
		for index = 2, result.n do
			local value = result[index]
			detail = detail .. ", " .. (type(value) == "table" and "table" or tostring(value))
		end
	end

	-- Say so on the probe line itself. A dropped field that only shows up in the dump's tally
	-- is a field nobody notices is gone until the UI renders a blank.
	if dropped and dropped[1] then
		return {
			name = path,
			status = "partial",
			detail = detail .. "; dropped " .. table.concat(dropped, ", "),
		}
	end

	return { name = path, status = "ok", detail = detail }
end

-- The first return only.
local function status(path, ...)
	return probeRow(path, false, ...)
end

-- Every return, comma-separated.
local function statusAll(path, ...)
	return probeRow(path, true, ...)
end

local function skipped(path, why)
	return { name = path, status = "skipped", detail = why }
end

-- One line per API we depend on, in dependency order: later probes reuse IDs the earlier ones
-- discovered, so a failure near the top explains the skips below it.
function Api.Probe()
	local rows = {}
	local function add(row) rows[#rows + 1] = row end

	local secretGuard = resolve("issecretvalue")
	add({
		name = "issecretvalue",
		status = type(secretGuard) == "function" and "ok" or "missing",
		detail = type(secretGuard) == "function" and "guard active" or "guard inert",
	})

	for name in pairs(CONSTANT_FALLBACK) do
		local value, source = Api.GetConstant(name)
		add({
			name = "Constants.LegacyConsts." .. name,
			status = source == "runtime" and "ok" or "missing",
			detail = tostring(value) .. " (" .. source .. ")",
		})
	end

	for name in pairs(FLAG_FALLBACK) do
		local value, source = globalNumber(name)
		add({
			name = name,
			status = source == "runtime" and "ok" or "missing",
			detail = tostring(value) .. " (" .. source .. ")",
		})
	end

	add(status("GetBuildInfo"))
	add(status("UnitClass", "player"))
	add(status("UnitLevel", "player"))

	-- Forever names have a first name and a surname (Alex, 2026-10-01), and UnitName read
	-- "Bong Wrip" on 69913 but "Bong" on 70124 for one character. These rows say which call
	-- carries the surname now, and whether the GUID reads, for a roster key that cannot shift.
	-- UnitName(unit) -> name, server             doc: UnitDocumentation.lua:2489
	-- UnitFullName(unit) -> name, server         doc: UnitDocumentation.lua:1224
	-- UnitNameUnmodified(unit) -> name, server   doc: UnitDocumentation.lua:2523
	-- UnitGUID(unit) -> guid                     doc: UnitDocumentation.lua:1241
	-- C_PlayerInfo.ShouldDisplaySurname() -> display   doc: PlayerInfoDocumentation.lua:358
	-- used: none in the sparse checkout. UnitFullName, UnitNameUnmodified and UnitGUID are
	-- SecretWhenUnitIdentityRestricted; UnitName is SecretWhenUnitNameIdentityRestricted.
	-- pin:  966519c (1.60.1.70124)
	add(statusAll("UnitName", "player"))
	add(statusAll("UnitFullName", "player"))
	add(statusAll("UnitNameUnmodified", "player"))
	add(status("UnitGUID", "player"))
	add(status("C_PlayerInfo.ShouldDisplaySurname"))

	local professionsResult = call("GetProfessions")
	add(status("GetProfessions"))
	local professionIndex
	if professionsResult then
		for slot = 1, professionsResult.n do
			if type(professionsResult[slot]) == "number" then
				professionIndex = professionsResult[slot]
				break
			end
		end
	end
	if professionIndex then
		add(status("GetProfessionInfo", professionIndex))
	else
		add(skipped("GetProfessionInfo", "character knows no professions"))
	end

	local categoriesResult = call("GetCategoryList")
	add(status("GetCategoryList"))

	local categories = categoriesResult and categoriesResult[1]
	local sampleCategory, sampleAchievement, criteriaAchievement
	if type(categories) == "table" then
		for _, categoryId in ipairs(categories) do
			local countResult = call("GetCategoryNumAchievements", categoryId)
			local total = countResult and countResult[1]
			if type(total) == "number" and total > 0 then
				sampleCategory = sampleCategory or categoryId
				for index = 1, total do
					local info = call("GetAchievementInfo", categoryId, index)
					local achievementId = info and info[1]
					if type(achievementId) == "number" then
						sampleAchievement = sampleAchievement or achievementId
						if not criteriaAchievement then
							local countCriteria = call("GetAchievementNumCriteria", achievementId)
							local n = countCriteria and countCriteria[1]
							if type(n) == "number" and n > 0 then
								criteriaAchievement = achievementId
							end
						end
					end
					if criteriaAchievement then
						break
					end
				end
			end
			if criteriaAchievement then
				break
			end
		end
	end

	if sampleCategory then
		add(status("GetCategoryInfo", sampleCategory))
		add(status("GetCategoryNumAchievements", sampleCategory))
		add(status("GetAchievementInfo", sampleCategory, 1))
	else
		add(skipped("GetCategoryInfo", "no category with achievements"))
		add(skipped("GetCategoryNumAchievements", "no category with achievements"))
		add(skipped("GetAchievementInfo", "no category with achievements"))
	end

	if sampleAchievement then
		add(status("GetAchievementNumCriteria", sampleAchievement))
		add(status("GetAchievementCategory", sampleAchievement))
		add(status("C_AchievementInfo.IsValidAchievement", sampleAchievement))
	else
		add(skipped("GetAchievementNumCriteria", "no achievement found"))
		add(skipped("GetAchievementCategory", "no achievement found"))
		add(skipped("C_AchievementInfo.IsValidAchievement", "no achievement found"))
	end

	if criteriaAchievement then
		add(status("GetAchievementCriteriaInfo", criteriaAchievement, 1))
	else
		add(skipped("GetAchievementCriteriaInfo", "no achievement with criteria"))
	end

	local currencyId = Api.GetConstant("LEGACY_POINTS_TRAIT_CURRENCY_ID")
	if currencyId and sampleAchievement then
		add(status("C_Traits.GetTraitCurrencyForAchievement", currencyId, sampleAchievement))
	else
		add(skipped("C_Traits.GetTraitCurrencyForAchievement", "no currency or achievement"))
	end

	if currencyId then
		add(status("C_Traits.GetMaxAvailableTraitCurrency", currencyId, true))
	else
		add(skipped("C_Traits.GetMaxAvailableTraitCurrency", "no currency id"))
	end

	local treeId = Api.GetConstant("LEGACY_TREE_PROFESSIONS_ID")
	local configResult = treeId and call("C_Traits.GetConfigIDByTreeID", treeId)
	if treeId then
		add(status("C_Traits.GetConfigIDByTreeID", treeId))
	else
		add(skipped("C_Traits.GetConfigIDByTreeID", "no tree id"))
	end

	local configId = configResult and configResult[1]
	if configId and treeId then
		add(status("C_Traits.GetTreeCurrencyInfo", configId, treeId, true))
		add(status("C_Traits.ConfigHasStagedChanges", configId))
	else
		add(skipped("C_Traits.GetTreeCurrencyInfo", "no config id"))
		add(skipped("C_Traits.ConfigHasStagedChanges", "no config id"))
	end

	local factionId = Api.GetConstant("LEGACY_REWARD_TRACK_FACTION_ID")
	if factionId then
		add(status("C_MajorFactions.GetMajorFactionData", factionId))
		add(status("C_MajorFactions.GetCurrentRenownLevel", factionId))
		add(status("C_MajorFactions.IsMajorFactionHiddenFromExpansionPage", factionId))

		local levelsResult = call("C_MajorFactions.GetRenownLevels", factionId)
		add(status("C_MajorFactions.GetRenownLevels", factionId))

		local levels = levelsResult and levelsResult[1]
		local firstLevel = type(levels) == "table" and levels[1] and levels[1].level
		if firstLevel then
			add(status("C_MajorFactions.GetRenownRewardsForLevel", factionId, firstLevel))
		else
			add(skipped("C_MajorFactions.GetRenownRewardsForLevel", "no reward thresholds"))
		end
	else
		add(skipped("C_MajorFactions.GetMajorFactionData", "no faction id"))
	end

	return rows
end
